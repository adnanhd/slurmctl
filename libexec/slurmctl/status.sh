#!/bin/bash
# status — detailed job status
cmd_help "${CYAN}slurmctl status${RESET} — Detailed job status

${YELLOW}Usage:${RESET}  slurmctl status [-j JOBID]

Shows job state, reason, runtime, time limit, CPUs, memory, and nodes (scontrol)." "$@"

JOBID=$(require_jobid)
JOB_NAME=$(squeue --job "$JOBID" -o %j 2>/dev/null | tail -1)

printf "${CYAN}Job %s:${RESET} %s\n" "$JOBID" "$JOB_NAME"
scontrol show job "$JOBID" 2>/dev/null | \
  grep -E "JobState=|Reason=|RunTime=|TimeLimit=|NumCPUs=|MinMemory|NodeList=" | \
  sed 's/^/  /'
