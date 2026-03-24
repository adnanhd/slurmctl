#!/bin/bash
# resubmit — resubmit failed tasks
cmd_help "${CYAN}slurmctl resubmit${RESET} — Resubmit failed tasks

${YELLOW}Usage:${RESET}  slurmctl resubmit [-j JOBID]

Finds failed array tasks via sacct, marks the old job as 'resubmitted',
and submits a new job with --array= set to the failed task IDs." "$@"

JOBID=$(require_jobid)

FAILED=$(get_failed_task_ids "$JOBID")

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
