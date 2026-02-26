#!/bin/bash
# submit — sbatch a .slurm script and log to history

script="${1:?Usage: slurmctl submit <script>.slurm [sbatch args...]}"
shift

if [ ! -f "$script" ] && [ -f "$SLURMCTL_ROOT/$script" ]; then
  script="$SLURMCTL_ROOT/$script"
fi

if [ ! -f "$script" ]; then
  printf "${RED}Script not found: %s${RESET}\n" "$script" >&2
  exit 1
fi

mkdir -p "$SLURM_PREFIX"

printf "${CYAN}Submitting${RESET} %s %s\n" "$script" "$*" >&2

JID=$(sbatch -o "$SLURM_PREFIX/%A_%a.out" \
             -e "$SLURM_PREFIX/%A_%a.err" \
             --parsable "$@" "$script")

if [ -z "$JID" ]; then
  printf "${RED}Submission failed${RESET}\n" >&2
  exit 1
fi

REPO=$(git remote get-url origin 2>/dev/null || echo "")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
BRANCH=$(git branch --show-current 2>/dev/null || echo "")

printf '{"job_id":"%s","script":"%s","args":"%s","repo":"%s","commit":"%s","branch":"%s","created":"%s"}\n' \
  "$JID" "$(basename "$script")" "$*" "$REPO" "$COMMIT" "$BRANCH" "$(date -Iseconds)" >> "$HIST_FILE"

printf "${GREEN}Submitted${RESET} job %s\n" "$JID" >&2
echo "$JID"
