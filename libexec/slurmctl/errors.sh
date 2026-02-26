#!/bin/bash
# errors — show recent errors

JOBID=$(require_jobid)

printf "${RED}Recent Errors:${RESET}\n"
for f in $(ls -t "$SLURM_PREFIX/${JOBID}".err "$SLURM_PREFIX/${JOBID}"_*.err 2>/dev/null | head -5); do
  if [ -s "$f" ]; then
    printf "${YELLOW}%s:${RESET}\n" "$f"
    tail -5 "$f"
    echo ""
  fi
done
