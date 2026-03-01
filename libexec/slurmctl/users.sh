#!/bin/bash
# users — jobs per user
cmd_help "${CYAN}slurmctl users${RESET} — Jobs per user

${YELLOW}Usage:${RESET}  slurmctl users

Shows top 10 users by number of queued jobs." "$@"

printf "${CYAN}Jobs per User:${RESET}\n"
squeue -o "%u" -h | sort | uniq -c | sort -rn | head -10 | \
  awk -v y="$YELLOW" -v r="$RESET" '{printf "  %s%12s%s %4d job%s\n", y, $2, r, $1, ($1==1?"":"s")}'
