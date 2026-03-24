#!/bin/bash
# failed — list failed array task IDs (comma-separated)
cmd_help "${CYAN}slurmctl failed${RESET} — List failed array task IDs

${YELLOW}Usage:${RESET}  slurmctl failed [-j JOBID]

Outputs comma-separated task IDs suitable for --array= resubmission.
Use 'failed-list' for detailed info, or 'resubmit' to resubmit directly." "$@"

JOBID=$(require_jobid)

FAILED=$(get_failed_task_ids "$JOBID")

if [ -z "$FAILED" ]; then
  printf "${GREEN}No failed tasks for %s${RESET}\n" "$JOBID" >&2
else
  echo "$FAILED"
fi
