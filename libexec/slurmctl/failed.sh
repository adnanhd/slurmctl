#!/bin/bash
# failed — list failed array task IDs (comma-separated)

JOBID=$(require_jobid)

FAILED=$(sacct -j "$JOBID" --format="JobID,State,ExitCode" -n | \
  grep -v '\.' | \
  grep -E 'FAILED|COMPLETED' | grep -v '0:0' | \
  grep -oP '(?<=_)\d+(?= )' | \
  sort -n | uniq | tr '\n' ',' | sed 's/,$//')

if [ -z "$FAILED" ]; then
  printf "${GREEN}No failed tasks for %s${RESET}\n" "$JOBID" >&2
else
  echo "$FAILED"
fi
