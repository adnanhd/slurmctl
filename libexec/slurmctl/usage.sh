#!/bin/bash
# usage — cluster CPU/GPU-hour consumption by account and user (sreport)
cmd_help "${CYAN}slurmctl usage${RESET} — Account/user utilization report (sreport)

${YELLOW}Usage:${RESET}
  slurmctl usage                       Your account's usage by user (CPU hours, today)
  slurmctl usage --gpu                 Same, in GPU hours
  slurmctl usage --all                 Every account on the cluster
  slurmctl usage -a proj29             A specific account
  slurmctl usage --start 2026-06-01    From a date
  slurmctl usage --start now-7days --gpu

${YELLOW}Options:${RESET}
  -a, --account ACCT   Report this account (default: your default account)
  --all, --cluster     All accounts on the cluster (no account filter)
  --gpu                Report GPU hours (--tres=gres/gpu) instead of CPU
  --tres TRES          Report an arbitrary TRES (e.g. gres/gpu, mem, cpu)
  -t UNIT              Time unit: hours (default), minutes, seconds, percent
  --start DATETIME     Window start (default: today)
  --end DATETIME       Window end (default: now)

DATETIME uses sreport's own format: today, now, YYYY-MM-DD, MM/DD-HH:MM,
now-7days. Account totals are the bold rows; your own row is highlighted." "$@"

ACCOUNT=""
ALL=false
TRES=""
TRES_LABEL="CPU"
UNIT="hours"
START="today"
END=""

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--account)   [ $# -lt 2 ] && { echo "error: --account requires an argument" >&2; exit 1; }; ACCOUNT="$2"; shift 2 ;;
    --account=*)    ACCOUNT="${1#*=}"; shift ;;
    --all|--cluster) ALL=true; shift ;;
    --gpu)          TRES="gres/gpu"; TRES_LABEL="GPU"; shift ;;
    --tres)         [ $# -lt 2 ] && { echo "error: --tres requires an argument" >&2; exit 1; }; TRES="$2"; TRES_LABEL="$2"; shift 2 ;;
    --tres=*)       TRES="${1#*=}"; TRES_LABEL="$TRES"; shift ;;
    -t)             [ $# -lt 2 ] && { echo "error: -t requires an argument" >&2; exit 1; }; UNIT="$2"; shift 2 ;;
    -t=*|--unit=*)  UNIT="${1#*=}"; shift ;;
    --start)        [ $# -lt 2 ] && { echo "error: --start requires an argument" >&2; exit 1; }; START="$2"; shift 2 ;;
    --start=*)      START="${1#*=}"; shift ;;
    --end)          [ $# -lt 2 ] && { echo "error: --end requires an argument" >&2; exit 1; }; END="$2"; shift 2 ;;
    --end=*)        END="${1#*=}"; shift ;;
    -*) printf "${RED}Unknown option: %s${RESET}\n" "$1" >&2; exit 1 ;;
    *)  printf "${RED}Unexpected argument: %s${RESET}\n" "$1" >&2; exit 1 ;;
  esac
done

# Resolve account scope: default to your own account unless --all/-a says otherwise.
if ! $ALL && [ -z "$ACCOUNT" ]; then
  ACCOUNT=$(sreport_my_account)
  if [ -z "$ACCOUNT" ]; then
    printf "${YELLOW}No default account found; showing all accounts (use -a ACCT to pick one).${RESET}\n" >&2
    ALL=true
  fi
fi

acct_arg=""
$ALL || acct_arg="$ACCOUNT"

# Header
scope_desc="all accounts"
$ALL || scope_desc="$ACCOUNT"
win="since $START"
[ -n "$END" ] && win="$START -> $END"
printf "${CYAN}Cluster usage — %s${RESET} (%s %s, %s)\n" "$scope_desc" "$TRES_LABEL" "$UNIT" "$win"

rows=$(sreport_account_usage "$START" "$END" "$UNIT" "$TRES" "$acct_arg")

if [ -z "$rows" ]; then
  printf "  ${YELLOW}No usage in this window${RESET}\n"
  exit 0
fi

printf "%s\n" "$rows" | awk -F'|' \
  -v me="$USER" -v bold="$BOLD" -v green="$GREEN" -v dim="$DIM" -v reset="$RESET" '
  BEGIN { printf "%s%-12s %-11s %-22s %12s%s\n", dim, "ACCOUNT", "USER", "NAME", "USED", reset }
  {
    acct=$1; login=$2; name=$3; used=$4
    if (login == "")        printf "%s%-12s %-11s %-22s %12s%s\n",       bold,  acct, "(total)", "",   used, reset
    else if (login == me)   printf "%s%-12s %-11s %-22s %12s  <- you%s\n", green, acct, login, name, used, reset
    else                    printf "%-12s %-11s %-22s %12s\n",                  acct, login, name, used
  }'
