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

# Checkpoint: lines before this are known terminal — copy with head, skip loop
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

# Pre-checkpoint lines are confirmed terminal — copy directly, no loop
if [ "$checkpoint_line" -gt 1 ]; then
  head -n $((checkpoint_line - 1)) "$HIST_FILE" > "${HIST_FILE}.tmp"
else
  : > "${HIST_FILE}.tmp"
fi

# Load post-checkpoint lines, stripping the checkpoint marker in one pass
mapfile -t post_lines < <(tail -n +$checkpoint_line "$HIST_FILE" | sed 's/, "checkpoint":true}/}/')

# Phase 1: collect active job IDs — no sacct calls yet.
# Only accept well-formed numeric IDs (or N_M array tasks) so a malformed
# history line can't smuggle junk into the sacct -j batch (sacct fails
# atomically on any bad token, producing zero output).
active_jids=()
for line in "${post_lines[@]}"; do
  state=$(json_get_state "$line")
  if ! _is_terminal "$state"; then
    jid="$(json_get "$line" job_id)"
    if [[ "$jid" =~ ^[0-9]+(_[0-9]+)?$ ]]; then
      active_jids+=("$jid")
    fi
  fi
done

# Phase 2: one batch sacct+squeue call for all active jobs
declare -A new_states
if [ ${#active_jids[@]} -gt 0 ]; then
  jids_csv=$(IFS=,; echo "${active_jids[*]}")
  batch_out=$(batch_states "$jids_csv")
  if [ -z "$batch_out" ]; then
    printf "${YELLOW}Warning${RESET}: sacct returned no data for %d active jobs\n" "${#active_jids[@]}" >&2
  else
    while read -r jid rest; do
      new_states["$jid"]="$rest"
    done <<< "$batch_out"
  fi
fi

# Phase 3: rewrite post-checkpoint lines with updated states
current_line=$((checkpoint_line - 1))
first_active_line=0

for line in "${post_lines[@]}"; do
  current_line=$((current_line + 1))
  state=$(json_get_state "$line")

  if _is_terminal "$state"; then
    echo "$line"
    continue
  fi

  jid=$(json_get "$line" job_id)
  new_state="${new_states[$jid]:-$state}"
  line=$(json_set_state "$line" "$new_state")

  if ! _is_terminal "$new_state" && [ "$first_active_line" -eq 0 ]; then
    first_active_line=$current_line
  fi

  echo "$line"
done >> "${HIST_FILE}.tmp"

# Mark oldest still-active entry so the next run skips above it
if [ "$first_active_line" -gt 0 ]; then
  sed -i "${first_active_line}s/}$/, \"checkpoint\":true}/" "${HIST_FILE}.tmp"
fi

mv "${HIST_FILE}.tmp" "$HIST_FILE"

printf "${GREEN}Updated${RESET} job states in history\n"
