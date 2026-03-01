#!/bin/bash
# nodes — jobs per node
cmd_help "${CYAN}slurmctl nodes${RESET} — Jobs per node

${YELLOW}Usage:${RESET}  slurmctl nodes

Shows how many of your jobs are running on each node." "$@"

printf "${CYAN}Jobs per Node:${RESET}\n"
squeue -u "$USER" -o "%N" -h | sort | uniq -c | \
  awk -v g="$GREEN" -v r="$RESET" '{printf "  %4d job%s on %s%s%s\n", $1, ($1==1?" ":"s"), g, $2, r}'
