#!/bin/bash
# watch — live tail of job output
cmd_help "${CYAN}slurmctl watch${RESET} — Live tail of job output

${YELLOW}Usage:${RESET}  slurmctl watch [-j JOBID]

Runs tail -f on the job's stdout and stderr files. Press Ctrl+C to stop." "$@"

JOBID=$(require_jobid)

resolve_job_output_files "$JOBID"

FILES=""
[ -n "$OUT_FILE" ] && FILES="$OUT_FILE"
[ -n "$ERR_FILE" ] && FILES="$FILES $ERR_FILE"

if [ -z "$FILES" ]; then
  printf "${RED}No output files found for job %s${RESET}\n" "$JOBID" >&2
  exit 1
fi

printf "${CYAN}Watching${RESET} %s\n" "$FILES"
exec tail -f $FILES
