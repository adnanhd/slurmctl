#!/bin/bash
# resubmit — resubmit failed tasks or jobs
cmd_help "${CYAN}slurmctl resubmit${RESET} — Resubmit failed tasks or jobs

${YELLOW}Usage:${RESET}
  slurmctl resubmit [-j JOBID]           Resubmit failed tasks of current/specified job
  slurmctl resubmit --all                Resubmit all failed jobs from history

${YELLOW}Options:${RESET}
  --failed                Default: resubmit failed array tasks
  --all                   Resubmit all failed jobs from history

${YELLOW}Examples:${RESET}
  slurmctl resubmit                      Resubmit failed tasks of current job
  slurmctl -j 12345 resubmit             Resubmit failed tasks of job 12345
  slurmctl resubmit --all                Resubmit all failed jobs in history" "$@"

ALL=false
while [ $# -gt 0 ]; do
  case "$1" in
    --all)     ALL=true; shift ;;
    --failed)  shift ;;  # default behavior, accepted for explicitness
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
