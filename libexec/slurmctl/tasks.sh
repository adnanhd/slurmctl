#!/bin/bash
# tasks — array task management (list, filter, resubmit)
cmd_help "${CYAN}slurmctl tasks${RESET} — Array task management

${YELLOW}Usage:${RESET}
  slurmctl tasks [-j JOBID]                    All task statuses (default)
  slurmctl tasks --summary                     Count by state
  slurmctl tasks --failed                      Failed task IDs (comma-separated)
  slurmctl tasks --completed                   Completed task IDs
  slurmctl tasks --running                     Running task IDs
  slurmctl tasks --pending                     Pending task IDs
  slurmctl tasks --failed --list               Detailed failed tasks
  slurmctl tasks --running --list              Detailed running tasks
  slurmctl tasks --resubmit                    Resubmit failed tasks
  slurmctl tasks --sort time|node              Sort detailed list

${YELLOW}Options:${RESET}
  --summary             Show counts per state
  --failed              Filter to failed/timeout/cancelled tasks
  --completed           Filter to completed tasks
  --running             Filter to running tasks
  --pending             Filter to pending tasks
  --list                Show detailed view (with filter)
  --resubmit            Resubmit failed tasks
  --sort time|node      Sort order for list view" "$@"

FILTER=""
LIST=false
SUMMARY=false
RESUBMIT=false
SORT_BY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --summary)    SUMMARY=true; shift ;;
    --failed)     FILTER="failed"; shift ;;
    --completed)  FILTER="completed"; shift ;;
    --running)    FILTER="running"; shift ;;
    --pending)    FILTER="pending"; shift ;;
    --list)       LIST=true; shift ;;
    --resubmit)   RESUBMIT=true; shift ;;
    --sort)       [ $# -lt 2 ] && { echo "error: --sort requires an argument (time|node)" >&2; exit 1; }; SORT_BY="$2"; shift 2 ;;
    *) break ;;
  esac
done

JOBID=$(require_jobid)

# --- Summary mode ---
if $SUMMARY; then
  line=$(sacct_summary "$JOBID")
  eval "$line"
  printf "${CYAN}Summary for %s:${RESET}\n" "$JOBID"
  printf "  ${GREEN}Completed:${RESET} %d\n" "$completed"
  printf "  ${YELLOW}Running:${RESET}   %d\n" "$running"
  printf "  ${BLUE}Pending:${RESET}   %d\n" "$pending"
  printf "  ${RED}Failed:${RESET}    %d\n" "$failed"
  exit 0
fi

# --- Resubmit mode ---
if $RESUBMIT; then
  FAILED=$(get_task_ids "$JOBID" failed)
  if [ -z "$FAILED" ]; then
    printf "${GREEN}No failed tasks to resubmit${RESET}\n"
    exit 0
  fi

  hist_line=$(get_history_entry "$JOBID")
  SCRIPT=$(json_get "$hist_line" script)
  if [ -z "$SCRIPT" ]; then
    printf "${RED}Cannot find script for job %s in history${RESET}\n" "$JOBID" >&2
    exit 1
  fi

  mark_job_state "$JOBID" "resubmitted"

  printf "${CYAN}Resubmitting${RESET} %s ${YELLOW}--array=%s${RESET}\n" "$SCRIPT" "$FAILED"
  bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/submit.sh" "$SCRIPT" --array="$FAILED"
  exit 0
fi

# --- ID-only mode (no --list) ---
if [ -n "$FILTER" ] && ! $LIST; then
  IDS=$(get_task_ids "$JOBID" "$FILTER")
  if [ -z "$IDS" ]; then
    printf "${GREEN}No %s tasks for %s${RESET}\n" "$FILTER" "$JOBID" >&2
  else
    echo "$IDS"
  fi
  exit 0
fi

# --- List mode (default or --list with filter) ---
# Build state filter for grep
case "$FILTER" in
  failed)    STATE_GREP='FAILED|TIMEOUT|CANCELLED|NODE_FAIL' ;;
  completed) STATE_GREP='COMPLETED' ;;
  running)   STATE_GREP='RUNNING' ;;
  pending)   STATE_GREP='PENDING' ;;
  *)         STATE_GREP='.' ;;  # all
esac

# Build sort flag
SORT_FLAG=""
case "$SORT_BY" in
  time) SORT_FLAG="| sort -k4" ;;
  node) SORT_FLAG="| sort -k5" ;;
esac

if [ -n "$FILTER" ]; then
  printf "${CYAN}%s tasks for %s:${RESET}\n" "${FILTER^}" "$JOBID"
else
  printf "${CYAN}Array Tasks for %s:${RESET}\n" "$JOBID"
fi

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
