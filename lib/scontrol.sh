#!/bin/bash
# scontrol.sh — thin API over the `scontrol` CLI.
#
# scontrol is the live-job source of truth (running/pending jobs that sacct may
# not have fully accounted yet). Wrappers keep the `show job` parsing in one
# place instead of scattered grep -oP across endpoints.

# Full `scontrol show job` blob for a job. Empty when the job has left the queue
# (already completed/failed); never aborts under `set -e`.
scontrol_show_job() {
  scontrol show job "$1" 2>/dev/null || true
}

# Extract a single whitespace-delimited Field=VALUE token from a show-job blob
# passed on stdin.  Usage: echo "$blob" | scontrol_field JobState
scontrol_field() {
  grep -oP "$1=\K\S+" | head -1
}

# Extract a to-end-of-line Field=VALUE from a show-job blob on stdin, for fields
# whose value may contain spaces (e.g. Reason). Usage: ... | scontrol_field_line Reason
scontrol_field_line() {
  grep -oP "$1=\K.*" | head -1
}
