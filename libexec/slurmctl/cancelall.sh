#!/bin/bash
# cancelall — cancel all active project jobs
cmd_help "${CYAN}slurmctl cancelall${RESET} — Cancel all active project jobs

${YELLOW}Usage:${RESET}  slurmctl cancelall

Cancels every non-terminal job in the project history and marks them as 'cancelled'." "$@"

if [ ! -f "$HIST_FILE" ]; then
  printf "${YELLOW}No history${RESET}\n"
  exit 0
fi

count=0
while IFS= read -r line; do
  state=$(json_get_state "$line")

  # Skip terminal states
  case "$state" in
    cancelled|archived|COMPLETED|FAILED*|TIMEOUT*|resubmitted) continue ;;
  esac

  jid=$(json_get "$line" job_id)
  printf "${RED}Cancelling${RESET} job %s\n" "$jid"
  scancel "$jid" 2>/dev/null
  ((count++))
done < "$HIST_FILE"

# Update states in history file
if [ "$count" -gt 0 ]; then
  while IFS= read -r line; do
    state=$(json_get_state "$line")
    case "$state" in
      cancelled|archived|COMPLETED|FAILED*|TIMEOUT*|resubmitted)
        echo "$line"
        ;;
      *)
        json_set_state "$line" "cancelled"
        ;;
    esac
  done < "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
fi

printf "${GREEN}Cancelled${RESET} %d project job(s)\n" "$count"
