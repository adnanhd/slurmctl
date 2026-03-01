#!/bin/bash
# clear — clear all history
cmd_help "${CYAN}slurmctl clear${RESET} — Clear all history

${YELLOW}Usage:${RESET}  slurmctl clear

Empties the project history file. This cannot be undone." "$@"

> "$HIST_FILE"
printf "${GREEN}History cleared${RESET}\n"
