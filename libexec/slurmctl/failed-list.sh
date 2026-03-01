#!/bin/bash
# failed-list — detailed list of failed tasks
cmd_help "${CYAN}slurmctl failed-list${RESET} — Detailed list of failed tasks

${YELLOW}Usage:${RESET}  slurmctl failed-list [-j JOBID]

Shows state, exit code, and elapsed time for each failed array task." "$@"

JOBID=$(require_jobid)

printf "${RED}Failed Tasks for %s:${RESET}\n" "$JOBID"
sacct -j "$JOBID" --format="JobID%15,State,ExitCode,Elapsed" -n | \
  grep -v '\.' | \
  grep -E 'FAILED|COMPLETED' | grep -v '0:0'
