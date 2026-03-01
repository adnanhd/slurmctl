#!/bin/bash
# running — summary counts for array job
cmd_help "${CYAN}slurmctl running${RESET} — Array job summary counts

${YELLOW}Usage:${RESET}  slurmctl running [-j JOBID]

Shows completed, running, pending, and failed task counts for an array job." "$@"

JOBID=$(require_jobid)

line=$(sacct_summary "$JOBID")
eval "$line"

printf "${CYAN}Summary for %s:${RESET}\n" "$JOBID"
printf "  ${GREEN}Completed:${RESET} %d\n" "$completed"
printf "  ${YELLOW}Running:${RESET}   %d\n" "$running"
printf "  ${BLUE}Pending:${RESET}   %d\n" "$pending"
printf "  ${RED}Failed:${RESET}    %d\n" "$failed"
