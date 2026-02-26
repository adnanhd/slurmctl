#!/bin/bash
# running — summary counts for array job

JOBID=$(require_jobid)

line=$(sacct_summary "$JOBID")
eval "$line"

printf "${CYAN}Summary for %s:${RESET}\n" "$JOBID"
printf "  ${GREEN}Completed:${RESET} %d\n" "$completed"
printf "  ${YELLOW}Running:${RESET}   %d\n" "$running"
printf "  ${BLUE}Pending:${RESET}   %d\n" "$pending"
printf "  ${RED}Failed:${RESET}    %d\n" "$failed"
