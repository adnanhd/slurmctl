#!/bin/bash
# clean — remove SLURM output files
cmd_help "${CYAN}slurmctl clean${RESET} — Remove SLURM output files

${YELLOW}Usage:${RESET}  slurmctl clean

Deletes all .out and .err files from the log directory (\$SLURMCTL_LOG_DIR)." "$@"

printf "${RED}Cleaning${RESET} SLURM output files in %s\n" "$SLURMCTL_LOG_DIR"
rm -f "$SLURMCTL_LOG_DIR"/*.out "$SLURMCTL_LOG_DIR"/*.err
