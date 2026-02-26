#!/bin/bash
# clean — remove SLURM output files

printf "${RED}Cleaning${RESET} SLURM output files in %s\n" "$SLURMCTL_LOG_DIR"
rm -f "$SLURMCTL_LOG_DIR"/*.out "$SLURMCTL_LOG_DIR"/*.err
