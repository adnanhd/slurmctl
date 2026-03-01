#!/bin/bash
# info — partition/node info
cmd_help "${CYAN}slurmctl info${RESET} — Partition and node info

${YELLOW}Usage:${RESET}  slurmctl info

Shows all partitions with node names, state, CPUs, memory, and GPUs (sinfo)." "$@"

printf "${CYAN}Cluster Info:${RESET}\n"
sinfo --all -o "%12P %36N %8t %6c %8m %14G" | \
  sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
