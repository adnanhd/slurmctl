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
  old_state=$(echo "$line" | grep -o '"state":"[^"]*"' | sed 's/"state":"//;s/"//g')

  # Preserve terminal states
  if [ "$old_state" = "cancelled" ] || [ "$old_state" = "resubmitted" ]; then
    echo "$line"
    continue
  fi

  jid=$(json_get "$line" job_id)
  state=$(sacct_summary_compact "$jid")

  json_set_state "$line" "$state"
done < "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"

printf "${GREEN}Updated${RESET} job states in history\n"
