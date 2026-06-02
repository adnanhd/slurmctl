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

VERBOSE=false
SUMMARY=false
VISUAL=false
SORT_BY=""
FILTER_STATES=()
FILTER_SINCE=""
FILTER_UNTIL=""

while [ $# -gt 0 ]; do
  # Shared state/window flags (--failed/--timeout/.../--since/--until)
  if filter_consume "$@"; then shift "$FILTER_CONSUMED"; continue; fi
  case "$1" in
    --summary)            SUMMARY=true; shift ;;
    --visual|--graphical) VISUAL=true; shift ;;
    -v|--verbose|--list)  VERBOSE=true; shift ;;
    --sort)               [ $# -lt 2 ] && { echo "error: --sort requires an argument (time|node)" >&2; exit 1; }; SORT_BY="$2"; shift 2 ;;
    *) break ;;
  esac
done

FILTER=$(filter_states_csv)

# --- Global sacct mode: --since/--until without a specific -j ---
if [ -n "$FILTER_SINCE" ] || [ -n "$FILTER_UNTIL" ]; then
  if [ -z "${SLURMCTL_JOBID:-}" ]; then
    state_grep='.'
    [ -n "$FILTER" ] && state_grep=$(state_filter_regex "$FILTER")

    printf "${CYAN}Your jobs"
    [ -n "$FILTER_SINCE" ] && printf " since %s" "$FILTER_SINCE"
    [ -n "$FILTER_UNTIL" ] && printf " until %s" "$FILTER_UNTIL"
    printf ":${RESET}\n"

    sacct_user_window "$FILTER_SINCE" "$FILTER_UNTIL" | \
      awk -F'|' -v re="$state_grep" '$4 ~ re {printf "%s  %-25s  %-15s  %-12s  %-10s  %-19s  %s\n", $1, $2, $3, $4, $5, $6, $7}' | \
      colorize_states
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
  squeue_user_jobs | \
    sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
  exit 0
fi

# --- Filter/summary mode: need a job ID ---
JOBID=$(require_jobid)

# --- Summary ---
if $SUMMARY; then
  if is_array_job "$JOBID"; then
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
    printf "${CYAN}Job %s:${RESET} %s\n" "$JOBID" "$(sacct_job_field "$JOBID" JobName)"
    printf "  State: %s  Elapsed: %s  Node: %s\n" \
      "$(sacct_job_field "$JOBID" State)" \
      "$(sacct_job_field "$JOBID" Elapsed)" \
      "$(sacct_job_field "$JOBID" NodeList)"
  fi
  exit 0
fi

# --- Filter mode ---
STATE_GREP=$(state_filter_regex "$FILTER")

if is_array_job "$JOBID"; then
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
    printf "${CYAN}%s tasks for %s:${RESET}\n" "${FILTER^}" "$JOBID"
    sacct_task_table "$JOBID" "$STATE_GREP" "$SORT_BY"
  fi
else
  # Single/wrap job: filter is just a state check
  state=$(sacct_job_state "$JOBID")

  if [[ "$state" =~ $STATE_GREP ]]; then
    if $VERBOSE; then
      printf "%s  %s  exit=%s  %s  %s\n" "$JOBID" "$state" \
        "$(sacct_job_field "$JOBID" ExitCode)" \
        "$(sacct_job_field "$JOBID" Elapsed)" \
        "$(sacct_job_field "$JOBID" NodeList)"
    else
      echo "$JOBID"
    fi
  else
    printf "${GREEN}Job %s is %s (not %s)${RESET}\n" "$JOBID" "$state" "$FILTER" >&2
  fi
fi
