#!/bin/bash
# tail — view job output/error (also handles cat, head, less)

JOBID=$(require_jobid)

# Detect which viewer was requested via argv or symlink name
VIEWER="tail"
NO_OUT=false
NO_ERR=false

while [ $# -gt 0 ]; do
  case "$1" in
    --no-out) NO_OUT=true; shift ;;
    --no-err) NO_ERR=true; shift ;;
    --viewer) VIEWER="$2"; shift 2 ;;
    cat|head|less|more|tail) VIEWER="$1"; shift ;;
    *) shift ;;
  esac
done

# Try to resolve paths from history log
OUT_FILE=""
ERR_FILE=""

hist_line=$(grep "\"job_id\":\"$JOBID\"" "$HIST_FILE" 2>/dev/null | tail -1)
if [ -n "$hist_line" ]; then
  logged_out=$(json_get_or_empty "$hist_line" out_path)
  logged_err=$(json_get_or_empty "$hist_line" err_path)

  if [ -n "$logged_out" ]; then
    pattern=$(resolve_output_pattern "$logged_out" "$JOBID")
    OUT_FILE=$(ls -t $pattern 2>/dev/null | head -1)
  fi
  if [ -n "$logged_err" ]; then
    pattern=$(resolve_output_pattern "$logged_err" "$JOBID")
    ERR_FILE=$(ls -t $pattern 2>/dev/null | head -1)
  fi
fi

# Fallback to legacy glob
if [ -z "$OUT_FILE" ]; then
  OUT_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".out "$SLURMCTL_LOG_DIR/${JOBID}"_*.out 2>/dev/null | head -1)
fi
if [ -z "$ERR_FILE" ]; then
  ERR_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".err "$SLURMCTL_LOG_DIR/${JOBID}"_*.err 2>/dev/null | head -1)
fi

if [ -z "$OUT_FILE" ] && [ -z "$ERR_FILE" ]; then
  printf "${RED}No output files found for job %s${RESET}\n" "$JOBID" >&2
  exit 1
fi

if ! $NO_OUT && [ -n "$OUT_FILE" ]; then
  printf "${CYAN}=== %s ===${RESET}\n" "$OUT_FILE"
  $VIEWER "$OUT_FILE"
fi

if ! $NO_ERR && [ -n "$ERR_FILE" ]; then
  printf "${RED}=== %s ===${RESET}\n" "$ERR_FILE"
  $VIEWER "$ERR_FILE"
fi
