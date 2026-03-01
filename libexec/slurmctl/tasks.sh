#!/bin/bash
# tasks — show status of all array tasks
cmd_help "${CYAN}slurmctl tasks${RESET} — Show status of all array tasks

${YELLOW}Usage:${RESET}  slurmctl tasks [-j JOBID]

Lists every array task with state, exit code, elapsed time, and start time." "$@"

JOBID=$(require_jobid)
printf "${CYAN}Array Tasks for %s:${RESET}\n" "$JOBID"
sacct -j "$JOBID" --format="JobID%15,State%10,ExitCode,Elapsed,Start" | \
  grep -E "^${JOBID}(_[0-9]+)? " | \
  sed "s/COMPLETED/$(printf "${GREEN}COMPLETED${RESET}")/" | \
  sed "s/FAILED/$(printf "${RED}FAILED${RESET}")/" | \
  sed "s/RUNNING/$(printf "${YELLOW}RUNNING${RESET}")/" | \
  sed "s/PENDING/$(printf "${BLUE}PENDING${RESET}")/"
