#!/bin/bash
# history — display submission history from .slurm.log
cmd_help "${CYAN}slurmctl history${RESET} — Show submission history

${YELLOW}Usage:${RESET}  slurmctl history [-n N] [--all] [--oneline] [--state=STATE] [--script=NAME]

${YELLOW}Options:${RESET}
  -n, -N              Show last N entries (default: 10)
  --all               Show full history
  --oneline           Compact one-line format
  --state=STATE       Filter by state (e.g. FAILED, COMPLETED, RUNNING)
  --script=NAME       Filter by script name (substring match)

${YELLOW}Examples:${RESET}
  slurmctl history                      Last 10 entries
  slurmctl history -5                   Last 5 entries
  slurmctl history --all                Full history
  slurmctl history --state=FAILED       Only failed jobs
  slurmctl history --oneline --all      Compact full listing" "$@"

N=10
SHOW_ALL=false
ONELINE=false
FILTER_STATE=""
FILTER_SCRIPT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --all|all)          SHOW_ALL=true; shift ;;
    --oneline)          ONELINE=true; shift ;;
    --state=*)          FILTER_STATE="${1#*=}"; shift ;;
    --state)            FILTER_STATE="$2"; shift 2 ;;
    --script=*)         FILTER_SCRIPT="${1#*=}"; shift ;;
    --script)           FILTER_SCRIPT="$2"; shift 2 ;;
    -n)                 N="$2"; shift 2 ;;
    0)                  SHOW_ALL=true; shift ;;
    -[0-9]*)            N="${1#-}"; shift ;;
    [0-9]*)             N="$1"; shift ;;
    *) shift ;;
  esac
done

if [ ! -f "$HIST_FILE" ]; then
  printf "${YELLOW}No history${RESET}\n"
  exit 0
fi

# Read lines in reverse (newest first, like git log)
lines=()
while IFS= read -r line; do
  lines+=("$line")
done < "$HIST_FILE"

count=0
for ((i=${#lines[@]}-1; i>=0; i--)); do
  line="${lines[$i]}"

  jid=$(json_get "$line" job_id)
  script=$(json_get "$line" script)
  commit=$(json_get "$line" commit)
  created=$(json_get "$line" created)
  state=$(json_get_state "$line")
  dep=$(json_get_or_empty "$line" depends_on)

  # Show DEPENDING instead of PENDING for jobs waiting on a dependency
  if [ -n "$dep" ] && echo "$state" | grep -qi "pend"; then
    state="DEPENDING (after $dep)"
  fi

  # Apply filters
  if [ -n "$FILTER_STATE" ]; then
    echo "$state" | grep -qi "$FILTER_STATE" || continue
  fi
  if [ -n "$FILTER_SCRIPT" ]; then
    echo "$script" | grep -qi "$FILTER_SCRIPT" || continue
  fi

  if $ONELINE; then
    printf "${GREEN}%s${RESET} %-20s %s\n" "$jid" "$script" "$(color_state "$state")"
  else
    printf "${GREEN}%s${RESET} %s\n" "$jid" "$(color_state "$state")"
    printf "    Script: %s\n" "$script"
    printf "    Date:   %s\n" "$created"
    [ -n "$commit" ] && printf "    Commit: ${YELLOW}%s${RESET}\n" "$commit"
    [ -n "$dep" ] && printf "    After:  %s\n" "$dep"
    echo ""
  fi

  count=$((count + 1))
  if ! $SHOW_ALL && [ "$count" -ge "$N" ]; then
    break
  fi
done
