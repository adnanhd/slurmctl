#!/bin/bash
# errors — show recent errors
cmd_help "${CYAN}slurmctl errors${RESET} — Show recent stderr output

${YELLOW}Usage:${RESET}  slurmctl errors [-j JOBID]

Shows the last 5 lines of the most recent stderr files for the job." "$@"

JOBID=$(require_jobid)

resolve_job_output_files "$JOBID"

err_files=()
if [ -n "$ERR_FILE" ]; then
  # Re-resolve to get multiple error files for array jobs
  local_hist=$(get_history_entry "${JOBID%%_*}")
  logged_err=$(json_get_or_empty "$local_hist" err_path)
  logged_err="${logged_err%% #*}"
  if [ -n "$logged_err" ]; then
    pattern=$(resolve_output_pattern "$logged_err" "${JOBID%%_*}")
    while IFS= read -r f; do
      err_files+=("$f")
    done < <(ls -t $pattern 2>/dev/null | head -5)
  else
    err_files=("$ERR_FILE")
  fi
else
  # Fallback glob for multiple files
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
