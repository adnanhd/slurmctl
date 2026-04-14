#!/bin/bash
# history — display submission history from .slurm.log
cmd_help "${CYAN}slurmctl history${RESET} — Show submission history

${YELLOW}Usage:${RESET}  slurmctl history [-n N] [--all] [--oneline] [STATE FLAGS] [--since DT] [--until DT]

${YELLOW}Options:${RESET}
  -n, -N              Show last N entries (default: 10)
  --all               Show full history
  --oneline           Compact one-line format
  --failed            Only FAILED jobs
  --completed         Only COMPLETED jobs
  --running           Only RUNNING jobs
  --pending           Only PENDING jobs
  --cancelled         Only CANCELLED jobs
  --timeout           Only TIMEOUT jobs
  --since DATETIME    Only jobs submitted on/after DATETIME
  --until DATETIME    Only jobs submitted before DATETIME
  --script=NAME       Filter by script name (substring match)

DATETIME accepts: 2026-04-14, yesterday, now-3days, 1h.

${YELLOW}Examples:${RESET}
  slurmctl history                      Last 10 entries
  slurmctl history -5                   Last 5 entries
  slurmctl history --all                Full history
  slurmctl history --failed             Only failed jobs
  slurmctl history --since yesterday    Jobs since yesterday
  slurmctl history --oneline --all      Compact full listing" "$@"

N=10
SHOW_ALL=false
ONELINE=false
STATE_FILTERS=()
FILTER_SCRIPT=""
SINCE=""
UNTIL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --all|all)          SHOW_ALL=true; shift ;;
    --oneline)          ONELINE=true; shift ;;
    --failed)           STATE_FILTERS+=(failed); shift ;;
    --completed)        STATE_FILTERS+=(completed); shift ;;
    --running)          STATE_FILTERS+=(running); shift ;;
    --pending)          STATE_FILTERS+=(pending); shift ;;
    --cancelled)        STATE_FILTERS+=(cancelled); shift ;;
    --timeout)          STATE_FILTERS+=(timeout); shift ;;
    --node-fail)        STATE_FILTERS+=(node_fail); shift ;;
    --script=*)         FILTER_SCRIPT="${1#*=}"; shift ;;
    --script)           FILTER_SCRIPT="$2"; shift 2 ;;
    --since=*)          SINCE="${1#*=}"; shift ;;
    --since)            [ $# -lt 2 ] && { echo "error: --since requires an argument" >&2; exit 1; }; SINCE="$2"; shift 2 ;;
    --until=*)          UNTIL="${1#*=}"; shift ;;
    --until)            [ $# -lt 2 ] && { echo "error: --until requires an argument" >&2; exit 1; }; UNTIL="$2"; shift 2 ;;
    -n)                 N="$2"; shift 2 ;;
    0)                  SHOW_ALL=true; shift ;;
    -[0-9]*)            N="${1#-}"; shift ;;
    [0-9]*)             N="$1"; shift ;;
    *) shift ;;
  esac
done

STATE_REGEX=""
if [ "${#STATE_FILTERS[@]}" -gt 0 ]; then
  STATE_REGEX=$(state_filter_regex "$(IFS=,; echo "${STATE_FILTERS[*]}")")
  # Any state filter implies --all, otherwise -n 10 may cut before finding matches
  SHOW_ALL=true
fi

SINCE_ISO=""
UNTIL_ISO=""
[ -n "$SINCE" ] && { SINCE_ISO=$(parse_datetime "$SINCE") || exit 1; SHOW_ALL=true; }
[ -n "$UNTIL" ] && { UNTIL_ISO=$(parse_datetime "$UNTIL") || exit 1; SHOW_ALL=true; }

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
  if [ -n "$STATE_REGEX" ]; then
    [[ ! "$state" =~ $STATE_REGEX ]] && continue
  fi
  if [ -n "$FILTER_SCRIPT" ]; then
    echo "$script" | grep -qi "$FILTER_SCRIPT" || continue
  fi
  if [ -n "$SINCE_ISO" ] && [ -n "$created" ] && [[ "$created" < "$SINCE_ISO" ]]; then continue; fi
  if [ -n "$UNTIL_ISO" ] && [ -n "$created" ] && [[ "$created" > "$UNTIL_ISO" ]]; then continue; fi

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
