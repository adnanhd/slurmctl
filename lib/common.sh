#!/bin/bash
# common.sh — shared config, colors, and JSON helpers for slurmctl

# Colors (only when stdout is a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

# Config — single directory for all slurm output, error, and log files
SLURMCTL_LOG_DIR="${SLURMCTL_LOG_DIR:-$HOME/.slurm}"
mkdir -p "$SLURMCTL_LOG_DIR"

# Per-project history file: encode project path into filename
_project_key=$(echo "${SLURMCTL_PROJECT_ROOT:-$PWD}" | tr '/' '-')
HIST_FILE="${SLURMCTL_LOG_DIR}/${_project_key}.slurm.log"

# Extract a JSON string field: json_get '{"k":"v"}' k → v
json_get() {
  echo "$1" | sed 's/.*"'"$2"'":"\([^"]*\)".*/\1/'
}

# Set/replace state field in a JSON line
json_set_state() {
  local line="$1" state="$2"
  local clean
  clean=$(echo "$line" | sed 's/ *,\? *"state":"[^"]*"//g')
  echo "${clean%\}}, \"state\":\"$state\"}"
}

# Resolve the active job ID (most recent non-cancelled from history)
resolve_jobid() {
  if [ -n "${SLURMCTL_JOBID:-}" ]; then
    echo "$SLURMCTL_JOBID"
    return
  fi
  if [ ! -f "$HIST_FILE" ]; then
    return 1
  fi
  grep -v '"state":"cancelled"' "$HIST_FILE" 2>/dev/null | tail -1 | sed 's/.*"job_id":"\([^"]*\)".*/\1/'
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

# Color a state string for display
color_state() {
  local state="$1"
  case "$state" in
    cancelled)        printf "${RED}%s${RESET}" "$state" ;;
    COMPLETED)        printf "${GREEN}%s${RESET}" "$state" ;;
    RUNNING)          printf "${YELLOW}%s${RESET}" "$state" ;;
    PENDING)          printf "${BLUE}%s${RESET}" "$state" ;;
    FAILED*|TIMEOUT*) printf "${RED}%s${RESET}" "$state" ;;
    *)                printf "${CYAN}%s${RESET}" "$state" ;;
  esac
}
