#!/bin/bash
# sacct.sh — thin API over the `sacct` CLI plus the slurmctl state-filter model.
#
# This module owns three things:
#   1. The state taxonomy (FAIL/RETRYABLE regexes, state_filter_regex) and the
#      shared --failed/--timeout/... flag parser (filter_consume).
#   2. sacct task queries: IDs by state (get_task_ids), the colorized per-task
#      table (sacct_task_table), summaries (sacct_summary/batch_states), and
#      accounting/efficiency rows.
#   3. is_array_job — the array-vs-single test used across endpoints.
#
# Real pending counts for array jobs come from lib/squeue.sh (squeue -r expands
# the compressed ranges sacct collapses); that module is sourced alongside this.
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

# Shared parser for the state/window filter flags that every endpoint accepts:
#   --failed --completed --running --pending --cancelled --timeout --node-fail
#   --retryable --since[=]DT --until[=]DT
# Call as the FIRST thing in an endpoint's arg loop:
#
#   FILTER_STATES=(); FILTER_SINCE=""; FILTER_UNTIL=""
#   while [ $# -gt 0 ]; do
#     if filter_consume "$@"; then shift "$FILTER_CONSUMED"; continue; fi
#     case "$1" in  ...command-specific flags...  esac
#   done
#
# On a recognized leading flag it records it (FILTER_STATES[] / FILTER_SINCE /
# FILTER_UNTIL), sets FILTER_CONSUMED to how many argv tokens it spans (1 or 2),
# and returns 0. Otherwise returns 1. Aborts if a window flag lacks its argument.
filter_consume() {
  FILTER_CONSUMED=1
  case "$1" in
    --failed)    FILTER_STATES+=(failed) ;;
    --completed) FILTER_STATES+=(completed) ;;
    --running)   FILTER_STATES+=(running) ;;
    --pending)   FILTER_STATES+=(pending) ;;
    --cancelled) FILTER_STATES+=(cancelled) ;;
    --timeout)   FILTER_STATES+=(timeout) ;;
    --node-fail) FILTER_STATES+=(node_fail) ;;
    --retryable) FILTER_STATES+=(retryable) ;;
    --since=*)   FILTER_SINCE="${1#*=}" ;;
    --until=*)   FILTER_UNTIL="${1#*=}" ;;
    --since)     [ $# -ge 2 ] || { echo "error: --since requires an argument" >&2; exit 1; }
                 FILTER_SINCE="$2"; FILTER_CONSUMED=2 ;;
    --until)     [ $# -ge 2 ] || { echo "error: --until requires an argument" >&2; exit 1; }
                 FILTER_UNTIL="$2"; FILTER_CONSUMED=2 ;;
    *)           FILTER_CONSUMED=0; return 1 ;;
  esac
  return 0
}

# Join FILTER_STATES[] into a comma-separated filter string ("" if none set).
filter_states_csv() {
  [ "${#FILTER_STATES[@]}" -gt 0 ] || { echo ""; return; }
  local IFS=,; echo "${FILTER_STATES[*]}"
}

# True if the job is an array (has _N task rows in sacct).
is_array_job() {
  sacct -j "$1" --format=JobID -n -P 2>/dev/null | grep -q "${1}_[0-9]"
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
    real_pend=$(squeue_pending_count "$jobid")
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
    squeue_counts=$(squeue_pending_counts_by_job "$array_ids")
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
    state=$(sacct_job_state "$jobid")
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

# First-row State of a job (the leading word; e.g. "COMPLETED").
sacct_job_state() {
  sacct -j "$1" -n --format='State' 2>/dev/null | head -1 | awk '{print $1}'
}

# First-row value of an arbitrary sacct field for a job.
# Usage: sacct_job_field <jobid> <Field>   (e.g. Elapsed, NodeList, JobName)
sacct_job_field() {
  sacct -j "$1" --format="$2" -n -P 2>/dev/null | head -1
}

# Colorized per-task table for an array job, filtered by a state regex.
# Usage: sacct_task_table <jobid> [state_regex] [sort:time|node]
# Columns: JobID State ExitCode Elapsed NodeList. Emits nothing if no task matches.
sacct_task_table() {
  local jobid="$1" state_regex="${2:-.}" sort_by="${3:-}"
  local rows
  rows=$(sacct -j "$jobid" --format="JobID%20,State%12,ExitCode,Elapsed,NodeList%15" -n 2>/dev/null \
    | grep -E "${jobid}_[0-9]+ " | grep -v '\.' | grep -E "$state_regex")
  case "$sort_by" in
    time) rows=$(echo "$rows" | sort -k4) ;;
    node) rows=$(echo "$rows" | sort -k5) ;;
  esac
  [ -n "$rows" ] && echo "$rows" | colorize_states
}

# Your jobs in a submission window (for `list --since/--until`), raw '|'-rows.
# Usage: sacct_user_window [since] [until]
sacct_user_window() {
  local args=(-u "$USER" -X \
    --format='JobID%15,JobName%25,Partition%15,State%12,Elapsed,Start,NodeList%20' -n -P)
  [ -n "$1" ] && args+=(-S "$1")
  [ -n "$2" ] && args+=(-E "$2")
  sacct "${args[@]}" 2>/dev/null
}

# First NodeList of a job (for resubmit's --node filter).
sacct_job_nodelist() {
  sacct -j "$1" --format=NodeList -n -P 2>/dev/null | head -1
}

# Per-task accounting rows for `status --acct` on an array job (raw, colorize at
# the call site). Columns: JobID State ExitCode Elapsed MaxRSS NodeList.
sacct_acct_rows() {
  sacct -j "$1" --format="JobID%20,State%12,ExitCode,Elapsed,MaxRSS,NodeList%15" -n 2>/dev/null \
    | grep -E "${1}_[0-9]+ " | grep -v '\.'
}

# Single-job accounting line for `status --acct` on a non-array job.
sacct_acct_single() {
  sacct -j "$1" --format="JobID%20,JobName%20,State%12,ExitCode,Elapsed,MaxRSS,NodeList%15"
}

# `.batch`-step efficiency rows for `status --eff` ('|'-separated):
# JobID State Elapsed TotalCPU MaxRSS ReqMem AllocCPUS TimelimitRaw
sacct_eff_rows() {
  sacct -j "$1" --format=JobID%20,State%12,Elapsed,TotalCPU,MaxRSS,ReqMem,AllocCPUS,TimelimitRaw -n -P 2>/dev/null \
    | grep '\.batch|'
}

# Single completed-job summary line for `status` default view ('|'-separated):
# JobID JobName State Elapsed ExitCode Start End NodeList AllocCPUS ReqMem
sacct_job_line() {
  sacct -j "$1" --format=JobID%20,JobName%30,State%12,Elapsed,ExitCode,Start,End,NodeList%20,AllocCPUS,ReqMem -n -P 2>/dev/null \
    | grep "^${1}|" | head -1
}
