#!/bin/bash
# resubmit — resubmit failed tasks

JOBID=$(require_jobid)

FAILED=$(sacct -j "$JOBID" --format="JobID,State,ExitCode" -n | \
  grep -v '\.' | \
  grep -E 'FAILED|COMPLETED' | grep -v '0:0' | \
  grep -oP '(?<=_)\d+(?= )' | \
  sort -n | uniq | tr '\n' ',' | sed 's/,$//')

if [ -z "$FAILED" ]; then
  printf "${GREEN}No failed tasks to resubmit${RESET}\n"
  exit 0
fi

SCRIPT=$(grep "\"job_id\":\"$JOBID\"" "$HIST_FILE" | sed 's/.*"script":"\([^"]*\)".*/\1/')
if [ -z "$SCRIPT" ]; then
  printf "${RED}Cannot find script for job %s in history${RESET}\n" "$JOBID" >&2
  exit 1
fi

printf "${CYAN}Resubmitting${RESET} %s ${YELLOW}--array=%s${RESET}\n" "$SCRIPT" "$FAILED"
exec bash "$SLURMCTL_ROOT/libexec/slurmctl/submit.sh" "$SCRIPT" --array="$FAILED"
