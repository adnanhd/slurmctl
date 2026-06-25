#!/bin/bash
# sreport.sh — thin API over the `sreport` accounting-report CLI.
#
# slurmctl's `usage` endpoint reports cluster CPU/GPU-hour consumption by
# account and user. These wrappers own sreport's report-type + format flag
# soup; callers pick the window, time unit, and TRES, and own presentation.

# Your default Slurm account (from sacctmgr). Empty if none is configured.
sreport_my_account() {
  sacctmgr -n show user "$USER" format=DefaultAccount%30 2>/dev/null \
    | awk 'NF { print $1; exit }'
}

# Account utilization broken down by user.
# Args: <start> <end> <time_unit> <tres> <account>
#   start    sreport date token (today, now-7days, 2026-06-01, ...); required
#   end      sreport date token; optional (defaults to now)
#   unit     hours|minutes|seconds|percent (default hours)
#   tres     optional TRES (e.g. gres/gpu); empty = the cluster's billing TRES
#   account  optional account filter; empty = every account on the cluster
# Emits parsable rows "Account|Login|Proper|Used"; account-total rows have an
# empty Login. Never aborts under `set -e`.
sreport_account_usage() {
  local start="$1" end="$2" unit="${3:-hours}" tres="$4" account="$5"
  local args=(cluster AccountUtilizationByUser -t "$unit" -n -P
              format=Account,Login,Proper,Used)
  [ -n "$start" ]   && args+=("start=$start")
  [ -n "$end" ]     && args+=("end=$end")
  [ -n "$tres" ]    && args+=("--tres=$tres")
  [ -n "$account" ] && args+=("account=$account")
  sreport "${args[@]}" 2>/dev/null || true
}
