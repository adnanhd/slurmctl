#!/bin/bash
# resubmit — resubmit failed tasks or jobs
cmd_help "${CYAN}slurmctl resubmit${RESET} — Resubmit failed tasks or jobs

${YELLOW}Usage:${RESET}
  slurmctl resubmit [-j JOBID]              Resubmit failed tasks of current/specified job
  slurmctl resubmit --all                   Resubmit all failed jobs from history
  slurmctl resubmit --all -p PARTITION      Resubmit failed jobs that used PARTITION
  slurmctl resubmit --all --node=NODE       Resubmit failed jobs that ran on NODE

${YELLOW}Options:${RESET}
  --failed                Default: resubmit failed array tasks
  --all                   Resubmit all failed jobs from history
  -p, --partition PART    Filter to jobs on PARTITION
  -n, --node=NODE         Filter to jobs that ran on NODE

${YELLOW}Examples:${RESET}
  slurmctl resubmit                         Resubmit failed tasks of current job
  slurmctl -j 12345 resubmit               Resubmit failed tasks of job 12345
  slurmctl resubmit --all                   Resubmit all failed jobs
  slurmctl resubmit --all -p kolyoz-cuda    Resubmit failed kolyoz-cuda jobs" "$@"

ALL=false
FILTER_PARTITION=""
FILTER_NODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all)         ALL=true; shift ;;
    --failed)      shift ;;  # default behavior, accepted for explicitness
    -p|--partition) [ $# -lt 2 ] && { echo "error: --partition requires an argument" >&2; exit 1; }; FILTER_PARTITION="$2"; shift 2 ;;
    --partition=*)  FILTER_PARTITION="${1#*=}"; shift ;;
    --node=*)      FILTER_NODE="${1#*=}"; shift ;;
    -n|--node)    [ $# -lt 2 ] && { echo "error: --node requires an argument" >&2; exit 1; }; FILTER_NODE="$2"; shift 2 ;;
    *) break ;;
  esac
done

# --- Resubmit all failed jobs from history ---
if $ALL; then
  if [ ! -f "$HIST_FILE" ]; then
    printf "${YELLOW}No history${RESET}\n"
    exit 0
  fi

  count=0
  while IFS= read -r line; do
    state=$(json_get_state "$line")
    case "$state" in
      FAILED*) ;;
      *) continue ;;
    esac

    jid=$(json_get "$line" job_id)
    script=$(json_get "$line" script)

    if [ -z "$script" ]; then
      printf "${RED}Cannot find script for job %s, skipping${RESET}\n" "$jid" >&2
      continue
    fi

    # Apply partition filter
    if [ -n "$FILTER_PARTITION" ]; then
      job_part=$(sacct -j "$jid" --format=Partition -n -P 2>/dev/null | head -1)
      [ "$job_part" != "$FILTER_PARTITION" ] && continue
    fi

    # Apply node filter
    if [ -n "$FILTER_NODE" ]; then
      job_nodes=$(sacct -j "$jid" --format=NodeList -n -P 2>/dev/null | head -1)
      [[ "$job_nodes" != *"$FILTER_NODE"* ]] && continue
    fi

    mark_job_state "$jid" "resubmitted"

    printf "${CYAN}Resubmitting${RESET} %s (was job %s)\n" "$script" "$jid"
    bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/submit.sh" "$script"
    ((count++))
  done < "$HIST_FILE"

  printf "${GREEN}Resubmitted${RESET} %d job(s)\n" "$count"
  exit 0
fi

# --- Resubmit failed tasks of a specific job ---
JOBID=$(require_jobid)

FAILED=$(get_task_ids "$JOBID" failed || true)
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
