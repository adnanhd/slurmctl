#!/bin/bash
# history — display submission history from .slurm.log

if [ ! -f "$HIST_FILE" ]; then
  printf "${YELLOW}No history${RESET}\n"
  exit 0
fi

printf "${CYAN}Submission History:${RESET}\n"
tail -10 "$HIST_FILE" | while IFS= read -r line; do
  jid=$(json_get "$line" job_id)
  script=$(json_get "$line" script)
  commit=$(json_get "$line" commit)
  created=$(json_get "$line" created)
  state=$(echo "$line" | grep -o '"state":"[^"]*"' | sed 's/"state":"//;s/"//g')

  if [ -n "$state" ]; then
    printf "  ${GREEN}%s${RESET} %-30s ${YELLOW}%s${RESET} %s [%s]\n" \
      "$jid" "$script" "$commit" "$created" "$(color_state "$state")"
  else
    printf "  ${GREEN}%s${RESET} %-30s ${YELLOW}%s${RESET} %s\n" \
      "$jid" "$script" "$commit" "$created"
  fi
done
