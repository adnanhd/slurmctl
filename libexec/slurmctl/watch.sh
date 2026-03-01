#!/bin/bash
# watch — live tail of job output
cmd_help "${CYAN}slurmctl watch${RESET} — Live tail of job output

${YELLOW}Usage:${RESET}  slurmctl watch [-j JOBID]

Runs tail -f on the job's stdout and stderr files. Press Ctrl+C to stop." "$@"

JOBID=$(require_jobid)

# Try to resolve paths from history log
OUT_FILE=""
ERR_FILE=""

hist_line=$(grep "\"job_id\":\"$JOBID\"" "$HIST_FILE" 2>/dev/null | tail -1)
if [ -n "$hist_line" ]; then
  logged_out=$(json_get_or_empty "$hist_line" out_path)
  logged_err=$(json_get_or_empty "$hist_line" err_path)

  if [ -n "$logged_out" ]; then
    pattern=$(resolve_output_pattern "$logged_out" "$JOBID")
    OUT_FILE=$(ls -t $pattern 2>/dev/null | head -1)
  fi
  if [ -n "$logged_err" ]; then
    pattern=$(resolve_output_pattern "$logged_err" "$JOBID")
    ERR_FILE=$(ls -t $pattern 2>/dev/null | head -1)
  fi
fi

# Fallback to legacy glob
if [ -z "$OUT_FILE" ]; then
  OUT_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".out "$SLURMCTL_LOG_DIR/${JOBID}"_*.out 2>/dev/null | head -1)
fi
if [ -z "$ERR_FILE" ]; then
  ERR_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".err "$SLURMCTL_LOG_DIR/${JOBID}"_*.err 2>/dev/null | head -1)
fi

FILES=""
[ -n "$OUT_FILE" ] && FILES="$OUT_FILE"
[ -n "$ERR_FILE" ] && FILES="$FILES $ERR_FILE"

if [ -z "$FILES" ]; then
  printf "${RED}No output files found for job %s${RESET}\n" "$JOBID" >&2
  exit 1
fi

printf "${CYAN}Watching${RESET} %s\n" "$FILES"
exec tail -f $FILES
