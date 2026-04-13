#!/bin/bash
# cancel — cancel jobs
cmd_help "${CYAN}slurmctl cancel${RESET} — Cancel jobs

${YELLOW}Usage:${RESET}
  slurmctl cancel [-j JOBID]              Cancel current/specified job
  slurmctl cancel --all                   Cancel all active project jobs
  slurmctl cancel --node=NODE             Cancel your jobs on a specific node
  slurmctl cancel -p PARTITION            Cancel your jobs on a partition

${YELLOW}Options:${RESET}
  --all                   Cancel all active project jobs from history
  -n, --node=NODE         Cancel jobs running on NODE
  -p, --partition PART    Cancel jobs in PARTITION

${YELLOW}Examples:${RESET}
  slurmctl cancel                         Cancel current job
  slurmctl cancel -j 12345                Cancel specific job
  slurmctl cancel --all                   Cancel all project jobs
  slurmctl cancel --node=kolyoz23         Cancel jobs on kolyoz23
  slurmctl cancel -p palamut-cuda         Cancel jobs on palamut partition" "$@"

CANCEL_ALL=false
CANCEL_NODE=""
CANCEL_PARTITION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all)        CANCEL_ALL=true; shift ;;
    --node=*)      CANCEL_NODE="${1#*=}"; shift ;;
    -n|--node)    [ $# -lt 2 ] && { echo "error: --node requires an argument" >&2; exit 1; }; CANCEL_NODE="$2"; shift 2 ;;
    -p|--partition) [ $# -lt 2 ] && { echo "error: --partition requires an argument" >&2; exit 1; }; CANCEL_PARTITION="$2"; shift 2 ;;
    --partition=*) CANCEL_PARTITION="${1#*=}"; shift ;;
    *) break ;;
  esac
done

# --- Cancel all active project jobs ---
if $CANCEL_ALL; then
  if [ ! -f "$HIST_FILE" ]; then
    printf "${YELLOW}No history${RESET}\n"
    exit 0
  fi

  count=0
  while IFS= read -r line; do
    state=$(json_get_state "$line")
    case "$state" in
      cancelled|archived|COMPLETED|FAILED*|TIMEOUT*|resubmitted) continue ;;
    esac

    jid=$(json_get "$line" job_id)
    printf "${RED}Cancelling${RESET} job %s\n" "$jid"
    scancel "$jid" 2>/dev/null
    count=$((count + 1))
  done < "$HIST_FILE"

  if [ "$count" -gt 0 ]; then
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
  JOBS=$(squeue -u "$USER" -h -w "$CANCEL_NODE" -o "%i" 2>/dev/null)
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
  JOBS=$(squeue -u "$USER" -h -p "$CANCEL_PARTITION" -o "%i" 2>/dev/null)
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
