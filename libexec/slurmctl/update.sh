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

# Lines before the checkpoint are known-terminal; skip sacct for them.
checkpoint_line=1
if grep -q '"checkpoint":true' "$HIST_FILE" 2>/dev/null; then
  checkpoint_line=$(grep -n '"checkpoint":true' "$HIST_FILE" | head -1 | cut -d: -f1)
fi

_is_terminal() {
  case "$1" in
    cancelled|archived|resubmitted|COMPLETED|FAILED*|TIMEOUT*|OUT_OF_MEMORY*|NODE_FAIL*|BOOT_FAIL*|DEADLINE*|PREEMPTED*|REVOKED*)
      return 0 ;;
    *" / "*)
      echo "$1" | grep -qE '\b(run|pend)\b' && return 1 || return 0 ;;
    *)
      return 1 ;;
  esac
}

# Pre-checkpoint lines are confirmed terminal — copy them directly, no loop
if [ "$checkpoint_line" -gt 1 ]; then
  head -n $((checkpoint_line - 1)) "$HIST_FILE" > "${HIST_FILE}.tmp"
else
  : > "${HIST_FILE}.tmp"
fi

# Loop starts at the checkpoint; everything above has already been written
current_line=$((checkpoint_line - 1))
first_active_line=0

while IFS= read -r line; do
  current_line=$((current_line + 1))

  # Strip checkpoint marker — we'll re-add it to the correct line after the loop
  line=$(echo "$line" | sed 's/, "checkpoint":true}/}/')

  old_state=$(json_get_state "$line")

  if _is_terminal "$old_state"; then
    echo "$line"
    continue
  fi

  jid=$(json_get "$line" job_id)
  new_state=$(sacct_summary_compact "$jid")
  line=$(json_set_state "$line" "$new_state")

  # Track the first line that is still active after the sacct query
  if ! _is_terminal "$new_state" && [ "$first_active_line" -eq 0 ]; then
    first_active_line=$current_line
  fi

  echo "$line"
done < <(tail -n +$checkpoint_line "$HIST_FILE") >> "${HIST_FILE}.tmp"

# Mark the oldest still-active entry so the next run can skip above it
if [ "$first_active_line" -gt 0 ]; then
  sed -i "${first_active_line}s/}$/, \"checkpoint\":true}/" "${HIST_FILE}.tmp"
fi

mv "${HIST_FILE}.tmp" "$HIST_FILE"

printf "${GREEN}Updated${RESET} job states in history\n"
