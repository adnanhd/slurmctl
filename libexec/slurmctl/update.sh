#!/bin/bash
# update — refresh job states from sacct into history
cmd_help "${CYAN}slurmctl update${RESET} — Refresh job states from sacct

${YELLOW}Usage:${RESET}  slurmctl update

Queries sacct for every job in history and updates their state.
Terminal states (cancelled, resubmitted) are preserved." "$@"

if [ ! -f "$HIST_FILE" ]; then
  printf "${YELLOW}No history${RESET}\n"
  exit 0
fi

while IFS= read -r line; do
  old_state=$(json_get_state "$line")

  # Skip terminal states — only query sacct for jobs still in progress
  case "$old_state" in
    cancelled|resubmitted|COMPLETED|FAILED*|TIMEOUT*|OUT_OF_MEMORY)
      echo "$line"
      continue
      ;;
    *" / "*)
      # Array job summary — skip if no running or pending tasks
      if ! echo "$old_state" | grep -qE '\b(run|pend)\b'; then
        echo "$line"
        continue
      fi
      ;;
  esac

  jid=$(json_get "$line" job_id)
  state=$(sacct_summary_compact "$jid")

  json_set_state "$line" "$state"
done < "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"

printf "${GREEN}Updated${RESET} job states in history\n"
