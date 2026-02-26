#!/bin/bash
# submit — sbatch a .slurm script and log to history

script="${1:?Usage: slurmctl submit <script>.slurm [sbatch args...]}"
shift

if [ ! -f "$script" ] && [ -f "$SLURMCTL_PROJECT_ROOT/$script" ]; then
  script="$SLURMCTL_PROJECT_ROOT/$script"
fi

if [ ! -f "$script" ]; then
  printf "${RED}Script not found: %s${RESET}\n" "$script" >&2
  exit 1
fi

mkdir -p "$SLURMCTL_LOG_DIR"

# --- Detect user-specified output/error paths ---
user_out=""
user_err=""

# 1) Parse CLI sbatch args for -o/--output and -e/--error
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o)           user_out="${args[$((i+1))]:-}"; ((i++)) ;;
    --output=*)   user_out="${args[$i]#--output=}" ;;
    -e)           user_err="${args[$((i+1))]:-}"; ((i++)) ;;
    --error=*)    user_err="${args[$i]#--error=}" ;;
  esac
done

# 2) Parse the script for #SBATCH --output / #SBATCH --error directives
if [ -z "$user_out" ]; then
  user_out=$(grep -m1 '^#SBATCH\s\+\(-o\s\+\|--output=\)' "$script" 2>/dev/null \
    | sed 's/^#SBATCH\s\+\(-o\s\+\|--output=\)//' | xargs)
fi
if [ -z "$user_err" ]; then
  user_err=$(grep -m1 '^#SBATCH\s\+\(-e\s\+\|--error=\)' "$script" 2>/dev/null \
    | sed 's/^#SBATCH\s\+\(-e\s\+\|--error=\)//' | xargs)
fi

# 3) Build sbatch flags — only add defaults if user didn't specify
sbatch_extra=()
if [ -z "$user_out" ]; then
  user_out="$SLURMCTL_LOG_DIR/%A_%a.out"
  sbatch_extra+=(-o "$user_out")
fi
if [ -z "$user_err" ]; then
  user_err="$SLURMCTL_LOG_DIR/%A_%a.err"
  sbatch_extra+=(-e "$user_err")
fi

# 4) Resolve relative paths to absolute
[[ "$user_out" != /* ]] && user_out="$PWD/$user_out"
[[ "$user_err" != /* ]] && user_err="$PWD/$user_err"

printf "${CYAN}Submitting${RESET} %s %s\n" "$script" "$*" >&2

JID=$(sbatch "${sbatch_extra[@]}" --parsable "$@" "$script")

if [ -z "$JID" ]; then
  printf "${RED}Submission failed${RESET}\n" >&2
  exit 1
fi

REPO=$(git remote get-url origin 2>/dev/null || echo "")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
BRANCH=$(git branch --show-current 2>/dev/null || echo "")

printf '{"job_id":"%s","script":"%s","args":"%s","repo":"%s","commit":"%s","branch":"%s","created":"%s","out_path":"%s","err_path":"%s","state":"PENDING"}\n' \
  "$JID" "$(basename "$script")" "$*" "$REPO" "$COMMIT" "$BRANCH" "$(date -Iseconds)" "$user_out" "$user_err" >> "$HIST_FILE"

printf "${GREEN}Submitted${RESET} job %s\n" "$JID" >&2
echo "$JID"
