#!/bin/bash
# list — list jobs and tasks
cmd_help "${CYAN}slurmctl list${RESET} — List jobs and tasks

${YELLOW}Usage:${RESET}
  slurmctl list                          Your running/pending jobs (squeue)
  slurmctl list [-j JOBID] --summary     Task count by state
  slurmctl list [-j JOBID] --failed      Failed task IDs (comma-separated)
  slurmctl list [-j JOBID] --completed   Completed task IDs
  slurmctl list [-j JOBID] --running     Running task IDs
  slurmctl list [-j JOBID] --pending     Pending task IDs
  slurmctl list [-j JOBID] --cancelled   Cancelled task IDs
  slurmctl list [-j JOBID] --timeout     Timed-out task IDs
  slurmctl list [-j JOBID] --failed -v   Failed tasks with details
  slurmctl list [-j JOBID] --sort time|node
  slurmctl list --since DATETIME         All your jobs submitted after DATETIME
  slurmctl list --since 1h --failed      Jobs failed in the last hour

${YELLOW}Options:${RESET}
  --summary               Count tasks/steps by state
  --visual, --graphical   Render as a TUI bar chart (job/task states)
  --failed                Filter to failed tasks (any terminal-failure state:
                          FAILED, TIMEOUT, CANCELLED, OOM, NODE_FAIL, ...)
  --completed             Filter to COMPLETED tasks
  --running               Filter to RUNNING tasks
  --pending               Filter to PENDING tasks
  --cancelled             Filter to CANCELLED tasks
  --timeout               Filter to TIMEOUT tasks
  --since DATETIME        Only jobs on/after DATETIME (sacct -S)
  --until DATETIME        Only jobs before DATETIME (sacct -E)
  -v, --verbose           Detailed view with exit codes and nodes
  --sort time|node        Sort order for detailed view

DATETIME accepts anything sacct -S accepts: 2026-04-14, yesterday, now-3days, 1h.

Without filters, shows your squeue. With filters and -j, shows task/step
breakdown for the current job. With --since/--until and no -j, shows all
your jobs in the window (sacct-backed)." "$@"

FILTERS=()
VERBOSE=false
SUMMARY=false
VISUAL=false
SORT_BY=""
SINCE=""
UNTIL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --summary)    SUMMARY=true; shift ;;
    --visual|--graphical) VISUAL=true; shift ;;
    --failed)     FILTERS+=(failed); shift ;;
    --completed)  FILTERS+=(completed); shift ;;
    --running)    FILTERS+=(running); shift ;;
    --pending)    FILTERS+=(pending); shift ;;
    --cancelled)  FILTERS+=(cancelled); shift ;;
    --timeout)    FILTERS+=(timeout); shift ;;
    -v|--verbose|--list) VERBOSE=true; shift ;;
    --sort)       [ $# -lt 2 ] && { echo "error: --sort requires an argument (time|node)" >&2; exit 1; }; SORT_BY="$2"; shift 2 ;;
    --since=*)    SINCE="${1#*=}"; shift ;;
    --since)      [ $# -lt 2 ] && { echo "error: --since requires an argument" >&2; exit 1; }; SINCE="$2"; shift 2 ;;
    --until=*)    UNTIL="${1#*=}"; shift ;;
    --until)      [ $# -lt 2 ] && { echo "error: --until requires an argument" >&2; exit 1; }; UNTIL="$2"; shift 2 ;;
    *) break ;;
  esac
done

# Join FILTERS with comma for state_filter_regex
FILTER=""
if [ "${#FILTERS[@]}" -gt 0 ]; then
  FILTER=$(IFS=,; echo "${FILTERS[*]}")
fi

# --- Global sacct mode: --since/--until without a specific -j ---
if [ -n "$SINCE" ] || [ -n "$UNTIL" ]; then
  if [ -z "${SLURMCTL_JOBID:-}" ]; then
    sacct_args=(-u "$USER" -X --format='JobID%15,JobName%25,Partition%15,State%12,Elapsed,Start,NodeList%20' -n -P)
    [ -n "$SINCE" ] && sacct_args+=(-S "$SINCE")
    [ -n "$UNTIL" ] && sacct_args+=(-E "$UNTIL")

    state_grep='.'
    [ -n "$FILTER" ] && state_grep=$(state_filter_regex "$FILTER")

    printf "${CYAN}Your jobs"
    [ -n "$SINCE" ] && printf " since %s" "$SINCE"
    [ -n "$UNTIL" ] && printf " until %s" "$UNTIL"
    printf ":${RESET}\n"

    sacct "${sacct_args[@]}" 2>/dev/null | \
      awk -F'|' -v re="$state_grep" '$4 ~ re {printf "%s  %-25s  %-15s  %-12s  %-10s  %-19s  %s\n", $1, $2, $3, $4, $5, $6, $7}' | \
      sed "s/COMPLETED/$(printf "${GREEN}COMPLETED${RESET}")/g" | \
      sed "s/FAILED/$(printf "${RED}FAILED${RESET}")/g" | \
      sed "s/RUNNING/$(printf "${YELLOW}RUNNING${RESET}")/g" | \
      sed "s/PENDING/$(printf "${BLUE}PENDING${RESET}")/g" | \
      sed "s/TIMEOUT/$(printf "${RED}TIMEOUT${RESET}")/g" | \
      sed "s/CANCELLED/$(printf "${RED}CANCELLED${RESET}")/g"
    exit 0
  fi
  # If -j is set, --since/--until fall through and are ignored for per-job views
fi

# --- No filter: squeue listing ---
if ! $SUMMARY && [ -z "$FILTER" ]; then
  if $VISUAL; then
    printf "${CYAN}Your jobs by state:${RESET}\n"
    squeue -u "$USER" -h -o '%t' 2>/dev/null | sort | uniq -c | \
      awk '{
        c=$1; k=$2
        name=(k=="R"?"running":k=="PD"?"pending":k=="CG"?"completing":k=="CD"?"completed":k)
        col =(k=="R"?"yellow":k=="PD"?"blue":k=="CG"||k=="CD"?"green":"red")
        print name, c, col
      }' | bar_chart
    exit 0
  fi
  printf "${CYAN}Your Jobs:${RESET}\n"
  squeue -u "$USER" -o '%.20i %.12P %.40j %.8u %.2t %.10M %.6D %R' | \
    sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
  exit 0
fi

# --- Filter/summary mode: need a job ID ---
JOBID=$(require_jobid)

# Detect if job is array (has _N entries) or single
_is_array() {
  sacct -j "$1" --format=JobID -n -P 2>/dev/null | grep -q "${1}_[0-9]"
}

# --- Summary ---
if $SUMMARY; then
  if _is_array "$JOBID"; then
    line=$(sacct_summary "$JOBID")
    eval "$line"
    if $VISUAL; then
      printf "${CYAN}Task states for %s${RESET} (total %d):\n" "$JOBID" "${total:-0}"
      {
        echo "completed ${completed:-0} green"
        echo "running   ${running:-0} yellow"
        echo "pending   ${pending:-0} blue"
        echo "failed    ${failed:-0} red"
      } | bar_chart
    else
      printf "${CYAN}Summary for %s:${RESET}\n" "$JOBID"
      printf "  ${GREEN}Completed:${RESET} %d\n" "$completed"
      printf "  ${YELLOW}Running:${RESET}   %d\n" "$running"
      printf "  ${BLUE}Pending:${RESET}   %d\n" "$pending"
      printf "  ${RED}Failed:${RESET}    %d\n" "$failed"
    fi
  else
    # Single/wrap job: just show state
    state=$(sacct -j "$JOBID" --format=State -n -P 2>/dev/null | head -1)
    elapsed=$(sacct -j "$JOBID" --format=Elapsed -n -P 2>/dev/null | head -1)
    node=$(sacct -j "$JOBID" --format=NodeList -n -P 2>/dev/null | head -1)
    name=$(sacct -j "$JOBID" --format=JobName -n -P 2>/dev/null | head -1)
    printf "${CYAN}Job %s:${RESET} %s\n" "$JOBID" "$name"
    printf "  State: %s  Elapsed: %s  Node: %s\n" "$state" "$elapsed" "$node"
  fi
  exit 0
fi

# --- Filter mode ---
STATE_GREP=$(state_filter_regex "$FILTER")

if _is_array "$JOBID"; then
  # Array job: filter tasks
  if ! $VERBOSE; then
    # ID-only mode
    IDS=$(get_task_ids "$JOBID" "$FILTER" || true)
    if [ -z "$IDS" ]; then
      printf "${GREEN}No %s tasks for %s${RESET}\n" "$FILTER" "$JOBID" >&2
    else
      echo "$IDS"
    fi
  else
    SORT_FLAG=""
    case "$SORT_BY" in
      time) SORT_FLAG="| sort -k4" ;;
      node) SORT_FLAG="| sort -k5" ;;
    esac

    printf "${CYAN}%s tasks for %s:${RESET}\n" "${FILTER^}" "$JOBID"

    eval 'sacct -j "$JOBID" --format="JobID%20,State%12,ExitCode,Elapsed,NodeList%15" -n | \
      grep -E "${JOBID}_[0-9]+ " | \
      grep -v "\\." | \
      grep -E "$STATE_GREP" '"$SORT_FLAG" | \
      sed "s/COMPLETED/$(printf "${GREEN}COMPLETED${RESET}")/g" | \
      sed "s/FAILED/$(printf "${RED}FAILED${RESET}")/g" | \
      sed "s/RUNNING/$(printf "${YELLOW}RUNNING${RESET}")/g" | \
      sed "s/PENDING/$(printf "${BLUE}PENDING${RESET}")/g" | \
      sed "s/TIMEOUT/$(printf "${RED}TIMEOUT${RESET}")/g" | \
      sed "s/CANCELLED/$(printf "${RED}CANCELLED${RESET}")/g"
  fi
else
  # Single/wrap job: filter is just a state check
  state=$(sacct -j "$JOBID" --format=State -n -P 2>/dev/null | head -1)

  if [[ "$state" =~ $STATE_GREP ]]; then
    if $VERBOSE; then
      elapsed=$(sacct -j "$JOBID" --format=Elapsed -n -P 2>/dev/null | head -1)
      exitcode=$(sacct -j "$JOBID" --format=ExitCode -n -P 2>/dev/null | head -1)
      node=$(sacct -j "$JOBID" --format=NodeList -n -P 2>/dev/null | head -1)
      printf "%s  %s  exit=%s  %s  %s\n" "$JOBID" "$state" "$exitcode" "$elapsed" "$node"
    else
      echo "$JOBID"
    fi
  else
    printf "${GREEN}Job %s is %s (not %s)${RESET}\n" "$JOBID" "$state" "$FILTER" >&2
  fi
fi
