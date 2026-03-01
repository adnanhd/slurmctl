#!/bin/bash
# resubmitall — resubmit all failed jobs from history
cmd_help "${CYAN}slurmctl resubmitall${RESET} — Resubmit all failed jobs

${YELLOW}Usage:${RESET}  slurmctl resubmitall

Iterates over all FAILED jobs in history, marks each as 'resubmitted',
and submits a fresh run of each script." "$@"

if [ ! -f "$HIST_FILE" ]; then
  printf "${YELLOW}No history${RESET}\n"
  exit 0
fi

count=0
while IFS= read -r line; do
  state=$(echo "$line" | grep -o '"state":"[^"]*"' | sed 's/"state":"//;s/"//g')

  # Only resubmit jobs with FAILED state
  case "$state" in
    FAILED*) ;;
    *) continue ;;
  esac

  jid=$(json_get "$line" job_id)
  script=$(json_get "$line" script)

  if [ -z "$script" ]; then
    printf "${RED}Cannot find script for job %s, skipping${RESET}\n" "$jid" >&2
    continue
  fi

  # Mark old entry as resubmitted
  sed -i "/\"job_id\":\"$jid\"/{s/ *,\? *\"state\":\"[^\"]*\"//g;s/}$/, \"state\":\"resubmitted\"}/;}" "$HIST_FILE"

  printf "${CYAN}Resubmitting${RESET} %s (was job %s)\n" "$script" "$jid"
  bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/submit.sh" "$script"
  ((count++))
done < "$HIST_FILE"

printf "${GREEN}Resubmitted${RESET} %d job(s)\n" "$count"
