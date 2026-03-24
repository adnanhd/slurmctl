#!/bin/bash
# nodes — node status overview
cmd_help "${CYAN}slurmctl nodes${RESET} — Node status overview

${YELLOW}Usage:${RESET}  slurmctl nodes [-p PARTITION] [--raw]

Shows all nodes with their state and resource allocation [used/total].

${YELLOW}Options:${RESET}
  -p, --partition PART  Filter to a specific partition
  --raw                 Raw sinfo output (partition, nodes, state, CPUs, mem, GPUs)

${YELLOW}Examples:${RESET}
  slurmctl nodes                        All nodes
  slurmctl nodes -p kolyoz-cuda         Only kolyoz-cuda partition
  slurmctl nodes --raw                  Raw sinfo table" "$@"

PARTITION=""
RAW=false
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--partition) PARTITION="$2"; shift 2 ;;
    --partition=*)  PARTITION="${1#*=}"; shift ;;
    --raw)          RAW=true; shift ;;
    *) shift ;;
  esac
done

if $RAW; then
  SINFO_RAW=(-o "%12P %36N %8t %6c %8m %14G")
  [ -n "$PARTITION" ] && SINFO_RAW+=(-p "$PARTITION") || SINFO_RAW+=(--all)
  printf "${CYAN}Cluster Info:${RESET}\n"
  sinfo "${SINFO_RAW[@]}" | \
    sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
  exit 0
fi

SINFO_ARGS=(-h -N --Format "NodeHost:20,Partition:14,StateLong:12,CPUsState:14,Gres:24,GresUsed:24")
if [ -n "$PARTITION" ]; then
  SINFO_ARGS+=(-p "$PARTITION")
fi

output=$(sinfo "${SINFO_ARGS[@]}" 2>/dev/null)

if [ -z "$output" ]; then
  printf "${YELLOW}No nodes found${RESET}\n"
  exit 0
fi

printf "${CYAN}Nodes:${RESET}\n"
echo "$output" | awk -v g="$GREEN" -v y="$YELLOW" -v r="$RED" -v b="$BLUE" -v c="$CYAN" -v rs="$RESET" '
{
  node=$1; part=$2; state=$3; cpus=$4; gres=$5; gres_used=$6

  # Parse A/I/O/T cpu format
  split(cpus, cpu, "/")
  cpu_alloc = cpu[1]; cpu_total = cpu[4]

  # Color state (pad manually — ANSI codes break %-Ns)
  sw = 12
  pad = ""
  for (i = length(state); i < sw; i++) pad = pad " "
  if (state == "idle")           sc = g state rs pad
  else if (state == "mixed")     sc = y state rs pad
  else if (state == "allocated") sc = b state rs pad
  else if (state ~ /drain/)      sc = r state rs pad
  else if (state ~ /down/)       sc = r state rs pad
  else                           sc = c state rs pad

  # GPU info: parse total from gres (gpu:a100:4) and used from gres_used (gpu:a100:2)
  gpu_str = ""
  if (gres != "(null)" && gres != "" && gres ~ /gpu/) {
    gpu_total = gres;    gsub(/.*:/, "", gpu_total)
    gpu_used = 0
    if (gres_used ~ /gpu/) { gpu_used = gres_used; gsub(/.*:/, "", gpu_used) }
    gpu_type = gres;     sub(/^gpu:/, "", gpu_type); sub(/:[0-9]+$/, "", gpu_type)
    gpu_str = sprintf("  [%s/%s %s]", gpu_used, gpu_total, gpu_type)
  }

  # CPU column: pad to fixed width so GPU column aligns
  cpu_str = sprintf("[%s/%s CPUs]", cpu_alloc, cpu_total)
  cpu_pad = ""
  for (i = length(cpu_str); i < 14; i++) cpu_pad = cpu_pad " "

  printf "  %-20s %-14s %s%s%s%s\n", node, part, sc, cpu_str, cpu_pad, gpu_str
}'
