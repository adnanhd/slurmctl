#!/bin/bash
# common.sh — shared config, colors, and JSON helpers for slurmctl

# Colors (only when stdout is a terminal)
if [ -t 1 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
fi

# Config — single directory for all slurm output, error, and log files
SLURMCTL_LOG_DIR="${SLURMCTL_LOG_DIR:-$HOME/.slurm/log}"
export SLURMCTL_LOG_DIR
mkdir -p "$SLURMCTL_LOG_DIR"

# Per-project history file: encode project path into filename.
# Exported so libexec scripts invoked via subshell (e.g. resubmit → submit)
# inherit the computed path.
_project_key=$(echo "${SLURMCTL_PROJECT_ROOT:-$PWD}" | tr '/' '-')
HIST_FILE="${SLURMCTL_LOG_DIR}/${_project_key}.slurm.log"
export HIST_FILE

# Extract a JSON string field: json_get '{"k":"v"}' k → v
json_get() {
  echo "$1" | sed 's/.*"'"$2"'":"\([^"]*\)".*/\1/'
}

# Extract a JSON string field, returning "" if field is missing
json_get_or_empty() {
  local val
  val=$(echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | sed 's/"'"$2"'"://;s/"//g')
  echo "$val"
}

# Extract state field from a JSON line
json_get_state() {
  echo "$1" | grep -o '"state":"[^"]*"' | sed 's/"state":"//;s/"//g'
}

# Set/replace state field in a JSON line
json_set_state() {
  local line="$1" state="$2"
  local clean
  clean=$(echo "$line" | sed 's/ *,\? *"state":"[^"]*"//g')
  echo "${clean%\}}, \"state\":\"$state\"}"
}

# Update state for a job ID in the history file
# Usage: mark_job_state <jobid> <new_state>
mark_job_state() {
  local jobid="$1" new_state="$2"
  [ -f "$HIST_FILE" ] || return 0
  local tmpfile="${HIST_FILE}.tmp"
  while IFS= read -r line; do
    if echo "$line" | grep -q "\"job_id\":\"$jobid\""; then
      json_set_state "$line" "$new_state"
    else
      echo "$line"
    fi
  done < "$HIST_FILE" > "$tmpfile" && mv "$tmpfile" "$HIST_FILE"
}

# Get the history entry for a job ID
# Usage: get_history_entry <jobid>
get_history_entry() {
  grep "\"job_id\":\"$1\"" "$HIST_FILE" 2>/dev/null | tail -1
}

# Parse a user datetime string into ISO-8601 for lexicographic comparison
# against the "created" field in history entries. Accepts anything `date -d`
# understands: "2026-04-14", "yesterday", "1 hour ago", "now-3days" (→ 3 days ago).
# Usage: parse_datetime <string>
parse_datetime() {
  local s="$1"
  # Normalize sacct-style "now-3days" / "1h" into something date(1) accepts
  if [[ "$s" =~ ^now-(.+)$ ]]; then
    s="${BASH_REMATCH[1]} ago"
  elif [[ "$s" =~ ^([0-9]+)([smhd])$ ]]; then
    local n="${BASH_REMATCH[1]}" u="${BASH_REMATCH[2]}"
    case "$u" in
      s) s="$n seconds ago" ;;
      m) s="$n minutes ago" ;;
      h) s="$n hours ago" ;;
      d) s="$n days ago" ;;
    esac
  fi
  date -d "$s" -Iseconds 2>/dev/null || {
    printf "error: invalid datetime: %s\n" "$1" >&2
    return 1
  }
}

# Resolve output pattern: expand %A→jobid, %a→task_id|*, %j→jobid
# Usage: resolve_output_pattern <pattern> <jobid> [array_index]
resolve_output_pattern() {
  local pattern="$1" jobid="$2" array_index="${3:-*}"
  pattern="${pattern//%A/$jobid}"
  pattern="${pattern//%j/$jobid}"
  pattern="${pattern//%a/$array_index}"
  # Resolve %x (job name) via sacct if present in pattern
  if [[ "$pattern" == *%x* ]]; then
    local job_name
    job_name=$(sacct -j "$jobid" --format=JobName%50 --noheader -P 2>/dev/null | head -1 | xargs)
    if [ -n "$job_name" ]; then
      pattern="${pattern//%x/$job_name}"
    fi
  fi
  echo "$pattern"
}

# Resolve output files for a job, sets OUT_FILE and ERR_FILE
# Usage: resolve_job_output_files <jobid> [array_index]
resolve_job_output_files() {
  local jobid="$1" array_index="${2:-}"
  local base_jobid="${jobid%%_*}"
  if [ -z "$array_index" ] && [[ "$jobid" == *_* ]]; then
    array_index="${jobid#*_}"
  fi

  OUT_FILE=""
  ERR_FILE=""

  # 1) Try history log
  local hist_line
  hist_line=$(get_history_entry "$base_jobid")
  if [ -n "$hist_line" ]; then
    local logged_out logged_err pattern
    logged_out=$(json_get_or_empty "$hist_line" out_path)
    logged_err=$(json_get_or_empty "$hist_line" err_path)
    logged_out="${logged_out%% #*}"
    logged_err="${logged_err%% #*}"

    if [ -n "$logged_out" ]; then
      pattern=$(resolve_output_pattern "$logged_out" "$base_jobid" "${array_index:-*}")
      OUT_FILE=$(ls -t $pattern 2>/dev/null | head -1 || true)
    fi
    if [ -n "$logged_err" ]; then
      pattern=$(resolve_output_pattern "$logged_err" "$base_jobid" "${array_index:-*}")
      ERR_FILE=$(ls -t $pattern 2>/dev/null | head -1 || true)
    fi
  fi

  # 2) Fallback: SLURMCTL_LOG_DIR
  if [ -z "$OUT_FILE" ]; then
    OUT_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${jobid}".out "$SLURMCTL_LOG_DIR/${jobid}"_*.out 2>/dev/null | head -1 || true)
  fi
  if [ -z "$ERR_FILE" ]; then
    ERR_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${jobid}".err "$SLURMCTL_LOG_DIR/${jobid}"_*.err 2>/dev/null | head -1 || true)
  fi

  # 3) Fallback: ~/.slurm/ (legacy)
  local legacy_dir="$HOME/.slurm"
  if [ -z "$OUT_FILE" ] && [ -d "$legacy_dir" ]; then
    OUT_FILE=$(ls -t "$legacy_dir/${jobid}".out "$legacy_dir/${jobid}"_*.out 2>/dev/null | head -1 || true)
  fi
  if [ -z "$ERR_FILE" ] && [ -d "$legacy_dir" ]; then
    ERR_FILE=$(ls -t "$legacy_dir/${jobid}".err "$legacy_dir/${jobid}"_*.err 2>/dev/null | head -1 || true)
  fi
}

# Resolve the active job ID (most recent non-cancelled, non-resubmitted from history)
resolve_jobid() {
  if [ -n "${SLURMCTL_JOBID:-}" ]; then
    echo "$SLURMCTL_JOBID"
    return
  fi
  if [ ! -f "$HIST_FILE" ]; then
    return 1
  fi
  grep -v '"state":"cancelled"' "$HIST_FILE" 2>/dev/null \
    | grep -v '"state":"resubmitted"' \
    | grep -v '"state":"archived"' \
    | tail -1 | sed 's/.*"job_id":"\([^"]*\)".*/\1/'
}

# Require a job ID or exit
require_jobid() {
  local jid
  jid=$(resolve_jobid)
  if [ -z "$jid" ]; then
    printf "${RED}No active job ID found${RESET}\n" >&2
    exit 1
  fi
  echo "$jid"
}

# Show help and exit if --help/-h is in args
# Usage: cmd_help "help text" "$@"
cmd_help() {
  local text="$1"; shift
  for arg in "$@"; do
    case "$arg" in --help|-h) printf "\n%b\n" "$text"; exit 0 ;; esac
  done
}

# Color a state string for display
color_state() {
  local state="$1"
  case "$state" in
    cancelled|resubmitted|archived) printf "${RED}%s${RESET}" "$state" ;;
    COMPLETED)             printf "${GREEN}%s${RESET}" "$state" ;;
    RUNNING)               printf "${YELLOW}%s${RESET}" "$state" ;;
    PENDING)               printf "${BLUE}%s${RESET}" "$state" ;;
    DEPENDING*)            printf "${CYAN}%s${RESET}" "$state" ;;
    FAILED*|TIMEOUT*)      printf "${RED}%s${RESET}" "$state" ;;
    *)                     printf "${CYAN}%s${RESET}" "$state" ;;
  esac
}
