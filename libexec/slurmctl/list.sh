#!/bin/bash
# list — show your running jobs
cmd_help "${CYAN}slurmctl list${RESET} — List your running jobs

${YELLOW}Usage:${RESET}  slurmctl list

Shows all your jobs in the queue (squeue) with partition, name, state, and runtime." "$@"

printf "${CYAN}Your Jobs:${RESET}\n"
squeue -u "$USER" -o '%.20i %.12P %.40j %.8u %.2t %.10M %.6D %R' | \
  sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
