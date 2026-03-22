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

# Split array task ID: 1153579_0 → base=1153579, array=0
BASE_JOBID="${JOBID%%_*}"
if [[ "$JOBID" == *_* ]]; then
  ARRAY_INDEX="${JOBID#*_}"
else
  ARRAY_INDEX=""
fi

# Try to resolve paths from history log (lookup by base job ID)
OUT_FILE=""
ERR_FILE=""

hist_line=$(grep "\"job_id\":\"$BASE_JOBID\"" "$HIST_FILE" 2>/dev/null | tail -1)
if [ -n "$hist_line" ]; then
  logged_out=$(json_get_or_empty "$hist_line" out_path)
  logged_err=$(json_get_or_empty "$hist_line" err_path)

  # Strip inline comments (e.g. "/path/%A_%a.out # some comment" → "/path/%A_%a.out")
  logged_out="${logged_out%% #*}"
  logged_err="${logged_err%% #*}"

  if [ -n "$logged_out" ]; then
    pattern=$(resolve_output_pattern "$logged_out" "$BASE_JOBID" "${ARRAY_INDEX:-*}")
    OUT_FILE=$(ls -t $pattern 2>/dev/null | head -1 || true)
  fi
  if [ -n "$logged_err" ]; then
    pattern=$(resolve_output_pattern "$logged_err" "$BASE_JOBID" "${ARRAY_INDEX:-*}")
    ERR_FILE=$(ls -t $pattern 2>/dev/null | head -1 || true)
  fi
fi

# Fallback: search SLURMCTL_LOG_DIR
if [ -z "$OUT_FILE" ]; then
  OUT_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".out "$SLURMCTL_LOG_DIR/${JOBID}"_*.out 2>/dev/null | head -1 || true)
fi
if [ -z "$ERR_FILE" ]; then
  ERR_FILE=$(ls -t "$SLURMCTL_LOG_DIR/${JOBID}".err "$SLURMCTL_LOG_DIR/${JOBID}"_*.err 2>/dev/null | head -1 || true)
fi

# Fallback: search ~/.slurm/ (legacy SBATCH --output/--error location)
LEGACY_DIR="$HOME/.slurm"
if [ -z "$OUT_FILE" ] && [ -d "$LEGACY_DIR" ]; then
  OUT_FILE=$(ls -t "$LEGACY_DIR/${JOBID}".out "$LEGACY_DIR/${JOBID}"_*.out 2>/dev/null | head -1 || true)
fi
if [ -z "$ERR_FILE" ] && [ -d "$LEGACY_DIR" ]; then
  ERR_FILE=$(ls -t "$LEGACY_DIR/${JOBID}".err "$LEGACY_DIR/${JOBID}"_*.err 2>/dev/null | head -1 || true)
fi

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
