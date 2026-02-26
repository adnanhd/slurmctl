#!/bin/bash
# users — jobs per user

printf "${CYAN}Jobs per User:${RESET}\n"
squeue -o "%u" -h | sort | uniq -c | sort -rn | head -10 | \
  awk -v y="$YELLOW" -v r="$RESET" '{printf "  %s%12s%s %4d job%s\n", y, $2, r, $1, ($1==1?"":"s")}'
