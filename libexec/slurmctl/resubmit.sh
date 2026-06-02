#!/bin/bash
# resubmit — resubmit failed tasks or jobs
cmd_help "${CYAN}slurmctl resubmit${RESET} — Resubmit failed tasks or jobs

${YELLOW}Usage:${RESET}
  slurmctl resubmit [-j JOBID]                Resubmit failed tasks of current/specified job
  slurmctl resubmit --all                     Resubmit all failed jobs from history
  slurmctl resubmit --all -p PARTITION        Resubmit failed jobs that used PARTITION
  slurmctl resubmit --all --node=NODE         Resubmit failed jobs that ran on NODE
  slurmctl resubmit --all --cancelled         Also resubmit cancelled jobs
  slurmctl resubmit --all --since yesterday   Only jobs submitted since yesterday

${YELLOW}Options:${RESET}
  --failed                Default: resubmit involuntary failures
                          (FAILED, TIMEOUT, OOM, NODE_FAIL, BOOT_FAIL, DEADLINE).
                          Excludes CANCELLED/PREEMPTED/REVOKED unless requested.
  --cancelled             Also include CANCELLED jobs
  --timeout               Also include TIMEOUT jobs
  --node-fail             Also include NODE_FAIL jobs
  --all                   Iterate all matching jobs from history
  --since DATETIME        Only jobs submitted on/after DATETIME
  --until DATETIME        Only jobs submitted before DATETIME
  -p, --partition PART    Filter to jobs on PARTITION
  -n, --node=NODE         Filter to jobs that ran on NODE

DATETIME accepts: 2026-04-14, yesterday, now-3days, 1h.

${YELLOW}Examples:${RESET}
  slurmctl resubmit                         Resubmit failed tasks of current job
  slurmctl -j 12345 resubmit                Resubmit failed tasks of job 12345
  slurmctl resubmit --all                   Resubmit all failed jobs
  slurmctl resubmit --all --failed --timeout  Failed or timed-out jobs
  slurmctl resubmit --all -p kolyoz-cuda    Resubmit failed kolyoz-cuda jobs" "$@"

ALL=false
FILTER_PARTITION=""
FILTER_NODE=""
SINCE=""
UNTIL=""
STATE_FILTERS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --all)         ALL=true; shift ;;
    --failed)      STATE_FILTERS+=(retryable); shift ;;
    --cancelled)   STATE_FILTERS+=(cancelled); shift ;;
    --timeout)     STATE_FILTERS+=(timeout); shift ;;
    --node-fail)   STATE_FILTERS+=(node_fail); shift ;;
    -p|--partition) [ $# -lt 2 ] && { echo "error: --partition requires an argument" >&2; exit 1; }; FILTER_PARTITION="$2"; shift 2 ;;
    --partition=*)  FILTER_PARTITION="${1#*=}"; shift ;;
    --node=*)      FILTER_NODE="${1#*=}"; shift ;;
    -n|--node)    [ $# -lt 2 ] && { echo "error: --node requires an argument" >&2; exit 1; }; FILTER_NODE="$2"; shift 2 ;;
    --since=*)    SINCE="${1#*=}"; shift ;;
    --since)      [ $# -lt 2 ] && { echo "error: --since requires an argument" >&2; exit 1; }; SINCE="$2"; shift 2 ;;
    --until=*)    UNTIL="${1#*=}"; shift ;;
    --until)      [ $# -lt 2 ] && { echo "error: --until requires an argument" >&2; exit 1; }; UNTIL="$2"; shift 2 ;;
    *) break ;;
  esac
done

# Default state filter is "retryable" (involuntary failures) if none given.
# This deliberately excludes CANCELLED/PREEMPTED/REVOKED so a bare `resubmit`
# never re-launches tasks you cancelled on purpose; use --cancelled to opt in.
[ "${#STATE_FILTERS[@]}" -eq 0 ] && STATE_FILTERS=(retryable)
STATE_REGEX=$(state_filter_regex "$(IFS=,; echo "${STATE_FILTERS[*]}")")

SINCE_ISO=""
UNTIL_ISO=""
[ -n "$SINCE" ] && { SINCE_ISO=$(parse_datetime "$SINCE") || exit 1; }
[ -n "$UNTIL" ] && { UNTIL_ISO=$(parse_datetime "$UNTIL") || exit 1; }

# --- Resubmit all failed jobs from history ---
if $ALL; then
  if [ ! -f "$HIST_FILE" ]; then
    printf "${YELLOW}No history${RESET}\n"
    exit 0
  fi

  count=0
  while IFS= read -r line; do
    state=$(json_get_state "$line")
    # Match against split-state regex (FAILED/CANCELLED/TIMEOUT/NODE_FAIL)
    [[ ! "$state" =~ $STATE_REGEX ]] && continue

    # Date-range filter on "created"
    created=$(json_get_or_empty "$line" created)
    if [ -n "$SINCE_ISO" ] && [ -n "$created" ] && [[ "$created" < "$SINCE_ISO" ]]; then continue; fi
    if [ -n "$UNTIL_ISO" ] && [ -n "$created" ] && [[ "$created" > "$UNTIL_ISO" ]]; then continue; fi

    jid=$(json_get "$line" job_id)
    script=$(json_get "$line" script)

    if [ -z "$script" ]; then
      printf "${RED}Cannot find script for job %s, skipping${RESET}\n" "$jid" >&2
      continue
    fi

    # Apply partition filter
    if [ -n "$FILTER_PARTITION" ]; then
      job_part=$(sacct_job_field "$jid" Partition)
      [ "$job_part" != "$FILTER_PARTITION" ] && continue
    fi

    # Apply node filter
    if [ -n "$FILTER_NODE" ]; then
      job_nodes=$(sacct_job_nodelist "$jid")
      [[ "$job_nodes" != *"$FILTER_NODE"* ]] && continue
    fi

    mark_job_state "$jid" "resubmitted"

    printf "${CYAN}Resubmitting${RESET} %s (was job %s)\n" "$script" "$jid"
    bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/submit.sh" "$script"
    count=$((count + 1))
  done < "$HIST_FILE"

  printf "${GREEN}Resubmitted${RESET} %d job(s)\n" "$count"
  exit 0
fi

# --- Resubmit failed tasks of a specific job ---
JOBID=$(require_jobid)

# Use the user's state filters (--failed/--timeout/--cancelled/--node-fail).
# Defaults to "failed" from earlier in the script. Joined with "," so
# state_filter_regex returns a multi-state alternation.
_state_filter_arg=$(IFS=,; echo "${STATE_FILTERS[*]}")
FAILED=$(get_task_ids "$JOBID" "$_state_filter_arg" || true)
if [ -z "$FAILED" ]; then
  printf "${GREEN}No failed tasks to resubmit${RESET}\n"
  exit 0
fi

hist_line=$(get_history_entry "$JOBID")
SCRIPT=$(json_get "$hist_line" script)
if [ -z "$SCRIPT" ]; then
  printf "${RED}Cannot find script for job %s in history${RESET}\n" "$JOBID" >&2
  exit 1
fi

mark_job_state "$JOBID" "resubmitted"

printf "${CYAN}Resubmitting${RESET} %s ${YELLOW}--array=%s${RESET}\n" "$SCRIPT" "$FAILED"
bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/submit.sh" "$SCRIPT" --array="$FAILED"
