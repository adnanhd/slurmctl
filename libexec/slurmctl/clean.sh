#!/bin/bash
# clean — remove SLURM output files

printf "${RED}Cleaning${RESET} SLURM output files in %s\n" "$SLURM_PREFIX"
rm -f "$SLURM_PREFIX"/*.out "$SLURM_PREFIX"/*.err
