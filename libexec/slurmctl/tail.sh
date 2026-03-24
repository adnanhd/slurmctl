#!/bin/bash
# tail — view job output/error (also handles cat, head, less)
cmd_help "${CYAN}slurmctl tail${RESET} / ${CYAN}cat${RESET} / ${CYAN}head${RESET} / ${CYAN}less${RESET} — View job output

${YELLOW}Usage:${RESET}  slurmctl tail [-j JOBID] [--no-out] [--no-err] [VIEWER_ARGS...]
        slurmctl cat  [-j JOBID] [--no-out] [--no-err]
        slurmctl head [-j JOBID] [--no-out] [--no-err] [VIEWER_ARGS...]
        slurmctl less [-j JOBID] [--no-out] [--no-err]

${YELLOW}Options:${RESET}
  --no-out        Show only stderr (skip stdout)
  --no-err        Show only stdout (skip stderr)
  VIEWER_ARGS     Extra arguments passed to the viewer (e.g. -40, -n 20, -f)

Output files are resolved from history, then \$SLURMCTL_LOG_DIR, then ~/.slurm/." "$@"

# Parse args first (--job may override SLURMCTL_JOBID)
VIEWER="tail"
NO_OUT=false
NO_ERR=false
VIEWER_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --no-out) NO_OUT=true; shift ;;
    --no-err) NO_ERR=true; shift ;;
    --viewer) VIEWER="$2"; shift 2 ;;
    cat|head|less|more|tail) VIEWER="$1"; shift ;;
    *) VIEWER_ARGS+=("$1"); shift ;;
  esac
done

# Resolve job ID (after arg parsing so --job takes effect)
JOBID=$(require_jobid)

resolve_job_output_files "$JOBID"

if [ -z "$OUT_FILE" ] && [ -z "$ERR_FILE" ]; then
  printf "${RED}No output files found for job %s${RESET}\n" "$JOBID" >&2
  exit 1
fi

if ! $NO_OUT && [ -n "$OUT_FILE" ]; then
  printf "${CYAN}=== %s ===${RESET}\n" "$OUT_FILE"
  $VIEWER "${VIEWER_ARGS[@]}" "$OUT_FILE"
fi

if ! $NO_ERR && [ -n "$ERR_FILE" ]; then
  printf "${RED}=== %s ===${RESET}\n" "$ERR_FILE"
  $VIEWER "${VIEWER_ARGS[@]}" "$ERR_FILE"
fi
