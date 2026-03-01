#!/bin/bash
# acct — job accounting details
cmd_help "${CYAN}slurmctl acct${RESET} — Job accounting details

${YELLOW}Usage:${RESET}  slurmctl acct [-j JOBID]

Shows elapsed time, memory usage, exit codes, and node assignments via sacct." "$@"

JOBID=$(require_jobid)
printf "${CYAN}Accounting for %s:${RESET}\n" "$JOBID"
sacct -j "$JOBID" --format="JobID,JobName%20,State,ExitCode,Elapsed,MaxRSS,NodeList" | head -20
