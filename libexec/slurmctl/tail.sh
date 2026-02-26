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

OUT_FILE=$(ls -t "$SLURM_PREFIX/${JOBID}".out "$SLURM_PREFIX/${JOBID}"_*.out 2>/dev/null | head -1)
ERR_FILE=$(ls -t "$SLURM_PREFIX/${JOBID}".err "$SLURM_PREFIX/${JOBID}"_*.err 2>/dev/null | head -1)

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
