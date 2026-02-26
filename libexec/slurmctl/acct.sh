#!/bin/bash
# acct — job accounting details

JOBID=$(require_jobid)
printf "${CYAN}Accounting for %s:${RESET}\n" "$JOBID"
sacct -j "$JOBID" --format="JobID,JobName%20,State,ExitCode,Elapsed,MaxRSS,NodeList" | head -20
