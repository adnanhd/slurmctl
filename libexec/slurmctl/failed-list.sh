#!/bin/bash
# failed-list — detailed list of failed tasks

JOBID=$(require_jobid)

printf "${RED}Failed Tasks for %s:${RESET}\n" "$JOBID"
sacct -j "$JOBID" --format="JobID%15,State,ExitCode,Elapsed" -n | \
  grep -v '\.' | \
  grep -E 'FAILED|COMPLETED' | grep -v '0:0'
