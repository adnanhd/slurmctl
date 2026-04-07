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
  slurmctl list [-j JOBID] --failed -v   Failed tasks with details
  slurmctl list [-j JOBID] --sort time|node

${YELLOW}Options:${RESET}
  --summary               Count tasks/steps by state
  --failed                Filter to failed/timeout tasks
  --completed             Filter to completed tasks
  --running               Filter to running tasks
  --pending               Filter to pending tasks
  -v, --verbose           Detailed view with exit codes and nodes
  --sort time|node        Sort order for detailed view

Without filters, shows your squeue. With filters, shows task/step
breakdown for the current job (auto-detected or -j). Works for
array jobs, single jobs, and --wrap jobs." "$@"

FILTER=""
VERBOSE=false
SUMMARY=false
SORT_BY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --summary)    SUMMARY=true; shift ;;
    --failed)     FILTER="failed"; shift ;;
    --completed)  FILTER="completed"; shift ;;
    --running)    FILTER="running"; shift ;;
    --pending)    FILTER="pending"; shift ;;
    -v|--verbose|--list) VERBOSE=true; shift ;;
    --sort)       [ $# -lt 2 ] && { echo "error: --sort requires an argument (time|node)" >&2; exit 1; }; SORT_BY="$2"; shift 2 ;;
    *) break ;;
  esac
done

# --- No filter: squeue listing ---
if ! $SUMMARY && [ -z "$FILTER" ]; then
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
    printf "${CYAN}Summary for %s:${RESET}\n" "$JOBID"
    printf "  ${GREEN}Completed:${RESET} %d\n" "$completed"
    printf "  ${YELLOW}Running:${RESET}   %d\n" "$running"
    printf "  ${BLUE}Pending:${RESET}   %d\n" "$pending"
    printf "  ${RED}Failed:${RESET}    %d\n" "$failed"
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
    # Detailed list
    case "$FILTER" in
      failed)    STATE_GREP='FAILED|TIMEOUT|CANCELLED|NODE_FAIL' ;;
      completed) STATE_GREP='COMPLETED' ;;
      running)   STATE_GREP='RUNNING' ;;
      pending)   STATE_GREP='PENDING' ;;
      *)         STATE_GREP='.' ;;
    esac

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

  match=false
  case "$FILTER" in
    failed)    [[ "$state" =~ FAILED|TIMEOUT|CANCELLED|NODE_FAIL ]] && match=true ;;
    completed) [ "$state" = "COMPLETED" ] && match=true ;;
    running)   [ "$state" = "RUNNING" ] && match=true ;;
    pending)   [ "$state" = "PENDING" ] && match=true ;;
  esac

  if $match; then
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
