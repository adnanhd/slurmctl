#!/bin/bash
# sacct.sh — single sacct call with awk-based parsing
#
# Usage:
#   source lib/sacct.sh
#   sacct_summary <JOBID>          # prints: completed=N running=N pending=N failed=N total=N
#   sacct_summary_compact <JOBID>  # prints: "12 done, 8 run / 72" or "COMPLETED"

# Canonical set of terminal "failure" states: any state in which a task ended
# unsuccessfully. Single source of truth so that the word "fail" means the same
# thing in the --failed filter, the history compact line, and the summary count.
# --timeout/--cancelled remain narrow sub-filters of this set.
FAIL_STATE_REGEX='CANCELLED|FAILED|TIMEOUT|BOOT_FAIL|OUT_OF_MEMORY|NODE_FAIL|DEADLINE|PREEMPTED|REVOKED'

# Subset of FAIL_STATE_REGEX worth automatically retrying: involuntary failures
# where the work didn't finish through no deliberate choice of yours. Excludes
# CANCELLED/PREEMPTED/REVOKED (typically intentional), so `resubmit` never
# re-launches a task you cancelled on purpose. Used as the resubmit default.
RETRYABLE_FAIL_STATE_REGEX='FAILED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|BOOT_FAIL|DEADLINE'

# Map a filter name to a State column regex.
# Usage: state_filter_regex <filter>
#   failed|completed|running|pending|cancelled|timeout|node_fail|all
#   Also accepts comma-separated combinations: failed,cancelled,timeout
state_filter_regex() {
  local filter="${1:-all}" out="" part r
  IFS=',' read -ra parts <<< "$filter"
  for part in "${parts[@]}"; do
    case "$part" in
      failed)    r="$FAIL_STATE_REGEX" ;;
      retryable) r="$RETRYABLE_FAIL_STATE_REGEX" ;;
      completed) r='COMPLETED' ;;
      running)   r='RUNNING' ;;
      pending)   r='PENDING' ;;
      cancelled) r='CANCELLED' ;;
      timeout)   r='TIMEOUT' ;;
      node_fail) r='NODE_FAIL' ;;
      all)       echo '.'; return ;;
      *)         r="$part" ;;
    esac
    [ -z "$out" ] && out="$r" || out="${out}|${r}"
  done
  echo "$out"
}

# Get comma-separated task IDs matching a state filter.
# Usage: get_task_ids <jobid> <filter>
get_task_ids() {
  local jobid="$1" filter="${2:-all}"
  local state_grep
  state_grep=$(state_filter_regex "$filter")

  sacct -j "$jobid" --format="JobID%20,State%12" -n | \
    grep -E "${jobid}_[0-9]+" | \
    grep -v '\.' | \
    grep -E "$state_grep" | \
    grep -oP '(?<=_)\d+' | \
    sort -n | uniq | tr '\n' ',' | sed 's/,$//'
}

# Backward compat alias
get_failed_task_ids() { get_task_ids "$1" failed; }

sacct_summary() {
  local jobid="$1"
  local sacct_out squeue_pend
  sacct_out=$(sacct -j "$jobid" -n --format='JobID,State,ExitCode' 2>/dev/null \
    | grep -v '\.' \
    | awk -v failre="^($FAIL_STATE_REGEX)" '
      NF >= 2 {
        total++
        if      ($2 == "COMPLETED" && $3 == "0:0") done++
        else if ($2 ~ failre)      fail++
        else if ($2 == "RUNNING")  run++
        else if ($2 == "PENDING")  pend++
      }
      END {
        printf "completed=%d running=%d pending=%d failed=%d total=%d\n",
          done+0, run+0, pend+0, fail+0, total+0
      }
    ')

  # sacct counts compressed array ranges (e.g. 123_[5-44]) as 1 entry.
  # Use squeue -r to get the real pending count for array jobs.
  local completed running pending failed total
  eval "$sacct_out"
  if [ "$total" -gt 1 ]; then
    local real_pend
    real_pend=$(squeue -j "$jobid" -h -t PD -r -o "%i" 2>/dev/null \
      | grep -c "${jobid}_" || true)
    if [ "$real_pend" -gt "$pending" ]; then
      total=$((total - pending + real_pend))
      pending=$real_pend
      sacct_out="completed=$completed running=$running pending=$pending failed=$failed total=$total"
    fi
  fi

  echo "$sacct_out"
}

# Batch version of sacct_summary_compact.
# Args: comma-separated job IDs
# Output: one "JOBID compact_state" line per job found in sacct
batch_states() {
  local jids="$1"
  [ -z "$jids" ] && return

  # One sacct call for all IDs — aggregate per base job ID in awk
  local sacct_counts
  sacct_counts=$(sacct -j "$jids" --format="JobID,State,ExitCode" -n 2>/dev/null \
    | grep -v '\.' \
    | awk -v failre="^($FAIL_STATE_REGEX)" '
      NF >= 2 {
        jobid = $1; state = $2; exitcode = $3
        base = jobid; sub(/_[0-9]+$/, "", base)
        if (!(base in seen)) { last[base] = state; seen[base] = 1 }
        total[base]++
        if      (state == "COMPLETED" && exitcode == "0:0") done[base]++
        else if (state ~ failre) fail[base]++
        else if (state == "RUNNING") run[base]++
        else if (state == "PENDING") pend[base]++
      }
      END {
        for (b in total)
          printf "%s %d %d %d %d %d %s\n", b, done[b]+0, run[b]+0, pend[b]+0, fail[b]+0, total[b]+0, last[b]
      }
    ')

  # One squeue call for array jobs to get real pending counts
  local array_ids squeue_counts=""
  array_ids=$(awk '$6 > 1 {printf "%s,", $1}' <<< "$sacct_counts" | sed 's/,$//')
  if [ -n "$array_ids" ]; then
    squeue_counts=$(squeue -j "$array_ids" -h -t PD -r -o "%i" 2>/dev/null \
      | grep -oE '^[0-9]+' | sort | uniq -c | awk '{print $2, $1}')
  fi

  # Merge squeue corrections and emit compact state strings
  awk 'NR == FNR { if (NF == 2) sq[$1] = $2+0; next }
  {
    base=$1; done=$2; run=$3; pend=$4; fail=$5; total=$6; lst=$7
    if (total > 1 && (base in sq) && sq[base] > pend) {
      total = total - pend + sq[base]; pend = sq[base]
    }
    if (total <= 1) {
      print base, lst
    } else {
      p = ""
      if (done > 0) p = done " done"
      if (run  > 0) { if (p != "") p = p ", "; p = p run " run" }
      if (pend > 0) { if (p != "") p = p ", "; p = p pend " pend" }
      if (fail > 0) { if (p != "") p = p ", "; p = p fail " fail" }
      print base, p " / " total
    }
  }' <(printf '%s\n' "$squeue_counts") <(printf '%s\n' "$sacct_counts")
}

sacct_summary_compact() {
  local jobid="$1"
  local line
  line=$(sacct_summary "$jobid")

  local completed running pending failed total
  eval "$line"

  if [ "$total" -le 1 ]; then
    # Single job — just get the state
    local state
    state=$(sacct -j "$jobid" -n --format='State' 2>/dev/null | head -1 | awk '{print $1}')
    echo "${state:-UNKNOWN}"
    return
  fi

  # Array job — build compact string
  local parts=""
  [ "$completed" -gt 0 ] && parts="$completed done"
  if [ "$running" -gt 0 ]; then
    [ -n "$parts" ] && parts="$parts, "
    parts="${parts}$running run"
  fi
  if [ "$pending" -gt 0 ]; then
    [ -n "$parts" ] && parts="$parts, "
    parts="${parts}$pending pend"
  fi
  if [ "$failed" -gt 0 ]; then
    [ -n "$parts" ] && parts="$parts, "
    parts="${parts}$failed fail"
  fi
  echo "$parts / $total"
}
