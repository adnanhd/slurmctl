#!/bin/bash
# errors — show recent errors
cmd_help "${CYAN}slurmctl errors${RESET} — Show recent stderr output

${YELLOW}Usage:${RESET}  slurmctl errors [-j JOBID]

Shows the last 5 lines of the most recent stderr files for the job." "$@"

JOBID=$(require_jobid)

# Try to resolve error paths from history log
err_files=()

hist_line=$(grep "\"job_id\":\"$JOBID\"" "$HIST_FILE" 2>/dev/null | tail -1)
if [ -n "$hist_line" ]; then
  logged_err=$(json_get_or_empty "$hist_line" err_path)
  if [ -n "$logged_err" ]; then
    pattern=$(resolve_output_pattern "$logged_err" "$JOBID")
    while IFS= read -r f; do
      err_files+=("$f")
    done < <(ls -t $pattern 2>/dev/null | head -5)
  fi
fi

# Fallback to legacy glob
if [ ${#err_files[@]} -eq 0 ]; then
  while IFS= read -r f; do
    err_files+=("$f")
  done < <(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".err "$SLURMCTL_LOG_DIR/${JOBID}"_*.err 2>/dev/null | head -5)
fi

printf "${RED}Recent Errors:${RESET}\n"
for f in "${err_files[@]}"; do
  if [ -s "$f" ]; then
    printf "${YELLOW}%s:${RESET}\n" "$f"
    tail -5 "$f"
    echo ""
  fi
done
