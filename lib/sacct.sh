#!/bin/bash
# sacct.sh — single sacct call with awk-based parsing
#
# Usage:
#   source lib/sacct.sh
#   sacct_summary <JOBID>          # prints: completed=N running=N pending=N failed=N total=N
#   sacct_summary_compact <JOBID>  # prints: "12 done, 8 run / 72" or "COMPLETED"

# Get comma-separated task IDs matching a state filter.
# Usage: get_task_ids <jobid> <filter>
#   filter: failed, completed, running, pending, all
get_task_ids() {
  local jobid="$1" filter="${2:-all}"
  local state_grep

  case "$filter" in
    failed)    state_grep='FAILED|TIMEOUT|CANCELLED|NODE_FAIL' ;;
    completed) state_grep='COMPLETED' ;;
    running)   state_grep='RUNNING' ;;
    pending)   state_grep='PENDING' ;;
    all)       state_grep='.' ;;
    *)         state_grep="$filter" ;;
  esac

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
  sacct -j "$jobid" -n --format='JobID,State,ExitCode' 2>/dev/null \
    | grep -v '\.' \
    | awk '
      /./          { total++ }
      /COMPLETED/  { if ($3 == "0:0") done++; else fail++ }
      /FAILED/     { fail++ }
      /TIMEOUT/    { fail++ }
      /CANCELLED/  { fail++ }
      /RUNNING/    { run++ }
      /PENDING/    { pend++ }
      END {
        printf "completed=%d running=%d pending=%d failed=%d total=%d\n",
          done+0, run+0, pend+0, fail+0, total+0
      }
    '
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
