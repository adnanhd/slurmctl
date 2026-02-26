#!/bin/bash
# watch — live tail of job output

JOBID=$(require_jobid)

OUT_FILE=$(ls -t "$SLURM_PREFIX/${JOBID}".out "$SLURM_PREFIX/${JOBID}"_*.out 2>/dev/null | head -1)
ERR_FILE=$(ls -t "$SLURM_PREFIX/${JOBID}".err "$SLURM_PREFIX/${JOBID}"_*.err 2>/dev/null | head -1)

FILES=""
[ -n "$OUT_FILE" ] && FILES="$OUT_FILE"
[ -n "$ERR_FILE" ] && FILES="$FILES $ERR_FILE"

if [ -z "$FILES" ]; then
  printf "${RED}No output files found for job %s${RESET}\n" "$JOBID" >&2
  exit 1
fi

printf "${CYAN}Watching${RESET} %s\n" "$FILES"
exec tail -f $FILES
