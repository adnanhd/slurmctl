#!/bin/bash
# throttle — change a running array job's max concurrent tasks (ArrayTaskThrottle)
cmd_help "${CYAN}slurmctl throttle${RESET} — Change a running array job's max concurrent tasks

${YELLOW}Usage:${RESET}
  slurmctl throttle [-j JOBID] <N>     Set ArrayTaskThrottle to N

${YELLOW}Options:${RESET}
  -j, --job JOBID         Target job (default: current job from history)

Runs: scontrol update jobid=<JOBID> ArrayTaskThrottle=<N>

${YELLOW}Examples:${RESET}
  slurmctl throttle -j 1279233 2        Allow 2 concurrent tasks for job 1279233
  slurmctl throttle 4                   Set throttle to 4 on the current job" "$@"

THROTTLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -*)
      printf "${RED}Unknown option: %s${RESET}\n" "$1" >&2
      exit 1 ;;
    *)
      THROTTLE="$1"; shift ;;
  esac
done

if [ -z "$THROTTLE" ]; then
  printf "${RED}error: missing throttle value${RESET}\n" >&2
  printf "Usage: slurmctl throttle [-j JOBID] <N>\n" >&2
  exit 1
fi
if ! [[ "$THROTTLE" =~ ^[0-9]+$ ]] || [ "$THROTTLE" -lt 1 ]; then
  printf "${RED}error: throttle must be a positive integer, got: %s${RESET}\n" "$THROTTLE" >&2
  exit 1
fi

JOBID=$(require_jobid)
# scontrol wants the base array job ID, not a per-task ID (1279233 not 1279233_4)
BASE_JOBID="${JOBID%%_*}"

_read_throttle() {
  scontrol show job "$1" 2>/dev/null | grep -o "ArrayTaskThrottle=[0-9]*" | head -1 | cut -d= -f2
}

before=$(_read_throttle "$BASE_JOBID")

# scontrol can exit non-zero yet still apply the throttle: on some QOS configs
# it re-validates the (running) tasks' time limit after setting the throttle and
# reports that failure. So the authoritative check is reading ArrayTaskThrottle
# back, not scontrol's exit code.
# Capture output and exit code without tripping the inherited `set -e`
# (scontrol may exit non-zero even when the throttle is applied; see below).
err=$(scontrol update "jobid=${BASE_JOBID}" "ArrayTaskThrottle=${THROTTLE}" 2>&1) && rc=0 || rc=$?

after=$(_read_throttle "$BASE_JOBID")

if [ "$after" = "$THROTTLE" ]; then
  printf "${GREEN}Throttle set${RESET} job %s ArrayTaskThrottle=%s\n" "$BASE_JOBID" "$after"
  # A non-zero scontrol exit despite a successful apply is a benign side effect
  # (e.g. time-limit re-validation on running tasks); surface it dimmed.
  if [ "$rc" -ne 0 ] && [ -n "$err" ]; then
    printf "${DIM}  (scontrol also reported: %s)${RESET}\n" "$(echo "$err" | head -1)"
  fi
  exit 0
fi

printf "${RED}Failed${RESET} to set throttle on job %s" "$BASE_JOBID" >&2
[ -n "$before" ] && printf " (still ArrayTaskThrottle=%s)" "$before" >&2
printf "\n" >&2
[ -n "$err" ] && echo "$err" | sed "s/^/  /" >&2
exit 1
