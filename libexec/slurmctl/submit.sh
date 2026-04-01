#!/bin/bash
# submit — sbatch a .slurm script and log to history

# --- Help ---
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<EOF

${CYAN}slurmctl submit${RESET} — Submit a SLURM job and track it in history

${YELLOW}Usage:${RESET}
  slurmctl submit <script>.slurm [options] [sbatch args...]
  slurmctl submit --wrap="<command>" [options] [sbatch args...]

${YELLOW}Options:${RESET}
  --wrap="<cmd>"        Submit an inline command (no script file needed)
  --after <jobid>       Run after <jobid> completes successfully (afterok dependency)
  -o, --output=<path>   Override stdout path (default: ~/.slurm/log/%A_%a.out)
  -e, --error=<path>    Override stderr path (default: ~/.slurm/log/%A_%a.err)

${YELLOW}Examples:${RESET}
  slurmctl submit train.slurm
  slurmctl submit train.slurm --array=0-99%8
  slurmctl submit eval.slurm --after 12345
  slurmctl submit --wrap="python train.py --lr=0.01" --gres=gpu:1
  slurmctl submit --wrap="hostname && nvidia-smi"

${YELLOW}Notes:${RESET}
  Any extra arguments are passed directly to sbatch.
  Output/error paths from #SBATCH directives in the script are respected.
  Git metadata (commit, branch, remote) is captured automatically.
EOF
  exit 0
fi

mkdir -p "$SLURMCTL_LOG_DIR"

# --- Detect --wrap mode early ---
wrap_cmd=""
script=""
for arg in "$@"; do
  case "$arg" in
    --wrap=*) wrap_cmd="${arg#--wrap=}" ;;
    --wrap)   ;; # handled below with next arg
  esac
done

if [ -z "$wrap_cmd" ]; then
  # Check for --wrap <cmd> (space-separated)
  args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    if [ "${args[$i]}" = "--wrap" ] && [ $((i+1)) -lt ${#args[@]} ]; then
      wrap_cmd="${args[$((i+1))]}"
      break
    fi
  done
fi

if [ -n "$wrap_cmd" ]; then
  # Wrap mode — no script file needed
  script_name="wrap"
else
  script="${1:?Usage: slurmctl submit <script>.slurm [options] [sbatch args...]}"
  shift

  if [ ! -f "$script" ] && [ -f "$SLURMCTL_PROJECT_ROOT/$script" ]; then
    script="$SLURMCTL_PROJECT_ROOT/$script"
  fi

  if [ ! -f "$script" ]; then
    printf "${RED}Script not found: %s${RESET}\n" "$script" >&2
    exit 1
  fi
  script_name="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
fi

# --- Parse slurmctl-specific flags (--after, --wrap), separate from sbatch args ---
depends_on=""
passthrough=()
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  case "${args[$i]}" in
    --after)
      depends_on="${args[$((i+1))]:-}"
      if [ -z "$depends_on" ]; then
        printf "${RED}--after requires a job ID${RESET}\n" >&2
        exit 1
      fi
      i=$((i+2))
      ;;
    --after=*)
      depends_on="${args[$i]#--after=}"
      i=$((i+1))
      ;;
    --wrap=*)
      # Already parsed, skip
      i=$((i+1))
      ;;
    --wrap)
      # Already parsed, skip both --wrap and its argument
      i=$((i+2))
      ;;
    *)
      passthrough+=("${args[$i]}")
      i=$((i+1))
      ;;
  esac
done
set -- "${passthrough[@]+"${passthrough[@]}"}"

# --- Detect user-specified output/error paths ---
user_out=""
user_err=""

# 1) Parse CLI sbatch args for -o/--output and -e/--error
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o)           user_out="${args[$((i+1))]:-}"; i=$((i+1)) ;;
    --output=*)   user_out="${args[$i]#--output=}" ;;
    -e)           user_err="${args[$((i+1))]:-}"; i=$((i+1)) ;;
    --error=*)    user_err="${args[$i]#--error=}" ;;
  esac
done

# 2) Parse the script for #SBATCH --output / #SBATCH --error directives
if [ -z "$user_out" ] && [ -n "$script" ]; then
  user_out=$( (grep -m1 '^#SBATCH\s\+\(-o\s\+\|--output=\)' "$script" || true) \
    | sed 's/^#SBATCH\s\+\(-o\s\+\|--output=\)//' | sed 's/\s*#.*//' | xargs)
fi
if [ -z "$user_err" ] && [ -n "$script" ]; then
  user_err=$( (grep -m1 '^#SBATCH\s\+\(-e\s\+\|--error=\)' "$script" || true) \
    | sed 's/^#SBATCH\s\+\(-e\s\+\|--error=\)//' | sed 's/\s*#.*//' | xargs)
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

# 4) Add dependency if --after was specified
if [ -n "$depends_on" ]; then
  sbatch_extra+=(--dependency="afterok:$depends_on")
fi

# 5) Resolve relative paths to absolute
[[ "$user_out" != /* ]] && user_out="$PWD/$user_out"
[[ "$user_err" != /* ]] && user_err="$PWD/$user_err"

# --- Submit ---
if [ -n "$wrap_cmd" ]; then
  printf "${CYAN}Submitting${RESET} --wrap=%s %s" "$wrap_cmd" "$*" >&2
  [ -n "$depends_on" ] && printf " ${YELLOW}(after %s)${RESET}" "$depends_on" >&2
  printf "\n" >&2
  JID=$(sbatch "${sbatch_extra[@]}" --parsable "$@" --wrap="$wrap_cmd")
else
  printf "${CYAN}Submitting${RESET} %s %s" "$script" "$*" >&2
  [ -n "$depends_on" ] && printf " ${YELLOW}(after %s)${RESET}" "$depends_on" >&2
  printf "\n" >&2
  JID=$(sbatch "${sbatch_extra[@]}" --parsable "$@" "$script")
fi

if [ -z "$JID" ]; then
  printf "${RED}Submission failed${RESET}\n" >&2
  exit 1
fi

REPO=$(git remote get-url origin 2>/dev/null || echo "")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# Build JSON — escape values that may contain quotes/backslashes
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }

dep_field=""
[ -n "$depends_on" ] && dep_field="\"depends_on\":\"$depends_on\","

log_args="$*"
[ -n "$wrap_cmd" ] && log_args="--wrap=$(json_escape "$wrap_cmd") $log_args"

printf '{%s"job_id":"%s","script":"%s","args":"%s","repo":"%s","commit":"%s","branch":"%s","created":"%s","out_path":"%s","err_path":"%s","state":"PENDING"}\n' \
  "$dep_field" "$JID" "$(json_escape "$script_name")" "$(json_escape "$log_args")" "$(json_escape "$REPO")" "$COMMIT" "$BRANCH" "$(date -Iseconds)" "$(json_escape "$user_out")" "$(json_escape "$user_err")" >> "$HIST_FILE"

printf "${GREEN}Submitted${RESET} job %s\n" "$JID" >&2
echo "$JID"
