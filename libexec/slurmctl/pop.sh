#!/bin/bash
# pop — archive job from active history (mark as cancelled)
cmd_help "${CYAN}slurmctl pop${RESET} — Archive job from active history

${YELLOW}Usage:${RESET}  slurmctl pop [-j JOBID]

Marks the current (or specified) job as 'cancelled' in history so it is no
longer treated as the active job." "$@"

JOBID=$(require_jobid)

printf "${YELLOW}Archiving${RESET} %s in history\n" "$JOBID"

mark_job_state "$JOBID" "cancelled"
