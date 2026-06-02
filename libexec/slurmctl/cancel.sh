#!/bin/bash
# cancel — cancel jobs
cmd_help "${CYAN}slurmctl cancel${RESET} — Cancel jobs

${YELLOW}Usage:${RESET}
  slurmctl cancel [-j JOBID]              Cancel current/specified job
  slurmctl cancel --all                   Cancel all active project jobs
  slurmctl cancel --node=NODE             Cancel your jobs on a specific node
  slurmctl cancel -p PARTITION            Cancel your jobs on a partition
  slurmctl cancel --all --since 1h        Cancel project jobs submitted in last hour
  slurmctl cancel --pending               Cancel all your pending jobs

${YELLOW}Options:${RESET}
  --all                   Cancel all active project jobs from history
  --pending               Restrict to pending jobs (use with --all)
  --running               Restrict to running jobs (use with --all)
  --since DATETIME        Only jobs submitted on/after DATETIME
  --until DATETIME        Only jobs submitted before DATETIME
  -n, --node=NODE         Cancel jobs running on NODE
  -p, --partition PART    Cancel jobs in PARTITION

DATETIME accepts: 2026-04-14, yesterday, now-3days, 1h.

${YELLOW}Examples:${RESET}
  slurmctl cancel                         Cancel current job
  slurmctl cancel -j 12345                Cancel specific job
  slurmctl cancel --all                   Cancel all project jobs
  slurmctl cancel --node=kolyoz23         Cancel jobs on kolyoz23
  slurmctl cancel -p palamut-cuda         Cancel jobs on palamut partition
  slurmctl cancel --all --since yesterday Only jobs since yesterday" "$@"

CANCEL_ALL=false
CANCEL_NODE=""
CANCEL_PARTITION=""
FILTER_STATES=()
FILTER_SINCE=""
FILTER_UNTIL=""
while [ $# -gt 0 ]; do
  # Shared state/window flags. A state filter (--pending/--running) implies --all.
  if filter_consume "$@"; then shift "$FILTER_CONSUMED"; continue; fi
  case "$1" in
    --all)        CANCEL_ALL=true; shift ;;
    --node=*)      CANCEL_NODE="${1#*=}"; shift ;;
    -n|--node)    [ $# -lt 2 ] && { echo "error: --node requires an argument" >&2; exit 1; }; CANCEL_NODE="$2"; shift 2 ;;
    -p|--partition) [ $# -lt 2 ] && { echo "error: --partition requires an argument" >&2; exit 1; }; CANCEL_PARTITION="$2"; shift 2 ;;
    --partition=*) CANCEL_PARTITION="${1#*=}"; shift ;;
    *) break ;;
  esac
done
[ "${#FILTER_STATES[@]}" -gt 0 ] && CANCEL_ALL=true

# Resolve date bounds to ISO-8601 (for lexicographic compare with "created")
SINCE_ISO=""
UNTIL_ISO=""
[ -n "$FILTER_SINCE" ] && { SINCE_ISO=$(parse_datetime "$FILTER_SINCE") || exit 1; }
[ -n "$FILTER_UNTIL" ] && { UNTIL_ISO=$(parse_datetime "$FILTER_UNTIL") || exit 1; }

# --- Cancel all active project jobs ---
if $CANCEL_ALL; then
  if [ ! -f "$HIST_FILE" ]; then
    printf "${YELLOW}No history${RESET}\n"
    exit 0
  fi

  # Build current-state filter regex (from --pending/--running)
  state_regex=""
  if [ "${#FILTER_STATES[@]}" -gt 0 ]; then
    state_regex=$(state_filter_regex "$(filter_states_csv)")
  fi

  count=0
  # For state-filtered cancels, build the scancel --state flag once.
  scancel_state_upper=""
  if [ -n "$state_regex" ]; then
    scancel_state_upper=$(echo "${FILTER_STATES[0]}" | tr '[:lower:]' '[:upper:]')
  fi

  while IFS= read -r line; do
    # For state-filtered cancels: only skip truly terminal/archived entries
    # (history state "cancelled" does NOT imply the job's tasks are gone —
    # a prior `cancel --all` may have marked history but left pending tails
    # of mixed-state arrays alive, which we still need to be able to cancel).
    state=$(json_get_state "$line")
    if [ -n "$state_regex" ]; then
      case "$state" in
        archived|COMPLETED|FAILED*|TIMEOUT*|CANCELLED*|resubmitted) continue ;;
      esac
    else
      case "$state" in
        cancelled|archived|COMPLETED|FAILED*|TIMEOUT*|CANCELLED*|resubmitted) continue ;;
      esac
    fi

    # Date-range filter on "created"
    created=$(json_get_or_empty "$line" created)
    if [ -n "$SINCE_ISO" ] && [ -n "$created" ] && [[ "$created" < "$SINCE_ISO" ]]; then continue; fi
    if [ -n "$UNTIL_ISO" ] && [ -n "$created" ] && [[ "$created" > "$UNTIL_ISO" ]]; then continue; fi

    jid=$(json_get "$line" job_id)

    if [ -n "$state_regex" ]; then
      # Only act if the job currently has tasks in the requested state.
      # squeue exits non-zero when no tasks match; set -e would abort the loop,
      # and `| head -1` + pipefail + SIGPIPE has the same issue. `|| true`
      # swallows the non-match exit, and empty `$live` drives the continue.
      live=$(squeue_live_tasks "$jid" "$scancel_state_upper")
      [ -z "$live" ] && continue
      printf "${RED}Cancelling${RESET} %s tasks of job %s\n" "$scancel_state_upper" "$jid"
      scancel --state="$scancel_state_upper" "$jid" 2>/dev/null
      count=$((count + 1))
    else
      printf "${RED}Cancelling${RESET} job %s\n" "$jid"
      scancel "$jid" 2>/dev/null
      count=$((count + 1))
    fi
  done < "$HIST_FILE"

  # History: only mark as "cancelled" when the whole job was cancelled.
  # State-filtered cancels (--pending/--running) leave some tasks alive, so
  # the job is not fully cancelled — leave history untouched and let
  # `slurmctl update` refresh state from sacct later.
  if [ "$count" -gt 0 ] && [ -z "$state_regex" ]; then
    while IFS= read -r line; do
      state=$(json_get_state "$line")
      case "$state" in
        cancelled|archived|COMPLETED|FAILED*|TIMEOUT*|resubmitted)
          echo "$line" ;;
        *)
          json_set_state "$line" "cancelled" ;;
      esac
    done < "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
  fi

  printf "${GREEN}Cancelled${RESET} %d project job(s)\n" "$count"
  exit 0
fi

# --- Cancel by node ---
if [ -n "$CANCEL_NODE" ]; then
  JOBS=$(squeue_jobs_on_node "$CANCEL_NODE")
  if [ -z "$JOBS" ]; then
    printf "${YELLOW}No jobs on %s${RESET}\n" "$CANCEL_NODE"
    exit 0
  fi
  count=0
  while IFS= read -r jid; do
    jid=$(echo "$jid" | xargs)
    [ -z "$jid" ] && continue
    printf "${RED}Cancelling${RESET} %s on %s\n" "$jid" "$CANCEL_NODE"
    scancel "$jid" 2>/dev/null
    count=$((count + 1))
  done <<< "$JOBS"
  printf "${GREEN}Cancelled${RESET} %d job(s) on %s\n" "$count" "$CANCEL_NODE"
  exit 0
fi

# --- Cancel by partition ---
if [ -n "$CANCEL_PARTITION" ]; then
  JOBS=$(squeue_jobs_on_partition "$CANCEL_PARTITION")
  if [ -z "$JOBS" ]; then
    printf "${YELLOW}No jobs on %s${RESET}\n" "$CANCEL_PARTITION"
    exit 0
  fi
  count=0
  while IFS= read -r jid; do
    jid=$(echo "$jid" | xargs)
    [ -z "$jid" ] && continue
    printf "${RED}Cancelling${RESET} %s on %s\n" "$jid" "$CANCEL_PARTITION"
    scancel "$jid" 2>/dev/null
    count=$((count + 1))
  done <<< "$JOBS"
  printf "${GREEN}Cancelled${RESET} %d job(s) on %s\n" "$count" "$CANCEL_PARTITION"
  exit 0
fi

# --- Cancel single job ---
JOBID=$(require_jobid)
printf "${RED}Cancelling${RESET} job %s\n" "$JOBID"
scancel "$JOBID"
mark_job_state "$JOBID" "cancelled"
