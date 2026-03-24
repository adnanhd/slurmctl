#!/bin/bash
# users — your jobs and which nodes they're on
cmd_help "${CYAN}slurmctl users${RESET} — Your jobs per node

${YELLOW}Usage:${RESET}  slurmctl users [-p PARTITION]

Lists your running/pending jobs grouped by node.

${YELLOW}Options:${RESET}
  -p, --partition PART  Filter to a specific partition" "$@"

PARTITION=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--partition) PARTITION="$2"; shift 2 ;;
    --partition=*)  PARTITION="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

SQUEUE_ARGS=(-u "$USER" -h -o "%i %t %P %N %j")
if [ -n "$PARTITION" ]; then
  SQUEUE_ARGS+=(-p "$PARTITION")
fi

output=$(squeue "${SQUEUE_ARGS[@]}" 2>/dev/null)

if [ -z "$output" ]; then
  printf "${YELLOW}No jobs in queue${RESET}\n"
  exit 0
fi

printf "${CYAN}Your jobs by node:${RESET}\n"
echo "$output" | awk -v g="$GREEN" -v y="$YELLOW" -v b="$BLUE" -v r="$RESET" -v c="$CYAN" '
{
  jobid=$1; state=$2; part=$3; node=$4; name=$5
  for(i=6;i<=NF;i++) name=name" "$i

  if (state == "R") sc = g "R" r
  else if (state == "PD") sc = b "PD" r
  else sc = y state r

  if (node == "" || node == "(None)") node = "(pending)"

  key = node
  if (!(key in nodes)) { order[++n] = key }
  nodes[key] = nodes[key] sprintf("    %s%-10s%s %s %-4s %s%s%s\n", c, jobid, r, sc, part, y, name, r)
  counts[key]++
}
END {
  for (i = 1; i <= n; i++) {
    k = order[i]
    printf "  %s%s%s (%d job%s)\n", g, k, r, counts[k], (counts[k]==1?"":"s")
    printf "%s", nodes[k]
  }
}'
