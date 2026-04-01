#!/bin/bash
# info — cluster resource overview
cmd_help "${CYAN}slurmctl info${RESET} — Cluster resource overview

${YELLOW}Usage:${RESET}
  slurmctl info [-p PARTITION]          Compact view: nodes grouped by free GPUs
  slurmctl info [-p PARTITION] --list   Detailed per-node list with summary
  slurmctl info [-p PARTITION] --raw    Raw sinfo output

${YELLOW}Options:${RESET}
  -p, --partition PART  Filter to a specific partition
  --list, -l            Show per-node detailed list
  --raw                 Raw sinfo table

${YELLOW}Examples:${RESET}
  slurmctl info                    Free GPUs grouped by count
  slurmctl info -p kolyoz-cuda     Filter to kolyoz-cuda
  slurmctl info --list              Per-node status with summary" "$@"

PARTITION=""
LIST=false
RAW=false
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--partition) [ $# -lt 2 ] && { echo "error: --partition requires an argument" >&2; exit 1; }; PARTITION="$2"; shift 2 ;;
    --partition=*)  PARTITION="${1#*=}"; shift ;;
    -l|--list)      LIST=true; shift ;;
    --raw)          RAW=true; shift ;;
    *) shift ;;
  esac
done

# --- Raw mode ---
if $RAW; then
  SINFO_RAW=(-o "%12P %36N %8t %6c %8m %14G")
  [ -n "$PARTITION" ] && SINFO_RAW+=(-p "$PARTITION") || SINFO_RAW+=(--all)
  printf "${CYAN}Cluster Info:${RESET}\n"
  sinfo "${SINFO_RAW[@]}" | \
    sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
  exit 0
fi

# --- Common: build sinfo args ---
SINFO_ARGS=(-h -N --Format "NodeHost:20,Partition:14,StateLong:12,CPUsState:14,Gres:24,GresUsed:24")
[ -n "$PARTITION" ] && SINFO_ARGS+=(-p "$PARTITION")

if [ -n "$PARTITION" ]; then
  printf "${CYAN}Cluster Resources (%s):${RESET}\n" "$PARTITION"
else
  printf "${CYAN}Cluster Resources:${RESET}\n"
fi

# --- List mode: per-node details + summary footer ---
if $LIST; then
  sinfo "${SINFO_ARGS[@]}" 2>/dev/null | awk -v g="$GREEN" -v y="$YELLOW" -v r="$RED" -v b="$BLUE" -v c="$CYAN" -v rs="$RESET" '
  {
    node=$1; part=$2; state=$3; cpus=$4; gres=$5; gres_used=$6

    split(cpus, cpu, "/")
    cpu_alloc = cpu[1]; cpu_total = cpu[4]

    sw = 12; pad = ""
    for (i = length(state); i < sw; i++) pad = pad " "
    if (state == "idle")           sc = g state rs pad
    else if (state == "mixed")     sc = y state rs pad
    else if (state == "allocated") sc = b state rs pad
    else if (state ~ /drain/)      sc = r state rs pad
    else if (state ~ /down/)       sc = r state rs pad
    else                           sc = c state rs pad

    gpu_str = ""
    if (gres != "(null)" && gres != "" && gres ~ /gpu/) {
      gpu_total = gres;    gsub(/.*:/, "", gpu_total)
      gpu_used = 0
      if (gres_used ~ /gpu/) { gpu_used = gres_used; gsub(/.*:/, "", gpu_used) }
      n_gp = split(gres, gp, ":")
      if (n_gp >= 3) gpu_type = gp[2]
      else            gpu_type = "GPUs"
      gpu_str = sprintf("  [%s/%s %s]", gpu_used, gpu_total, gpu_type)
      total_gpu_used += gpu_used + 0
      total_gpu += gpu_total + 0
    }

    cpu_str = sprintf("[%s/%s CPUs]", cpu_alloc, cpu_total)
    cpu_pad = ""
    for (i = length(cpu_str); i < 16; i++) cpu_pad = cpu_pad " "

    total_cpu_alloc += cpu_alloc + 0
    total_cpu += cpu_total + 0
    total_nodes++

    printf "  %-20s %-14s %s%s%s%s\n", node, part, sc, cpu_str, cpu_pad, gpu_str
  }
  END {
    if (total_nodes > 0) {
      cpu_idle = total_cpu - total_cpu_alloc
      gpu_free = total_gpu - total_gpu_used
      cpu_pct = (total_cpu > 0) ? (cpu_idle / total_cpu) * 100 : 0
      gpu_pct = (total_gpu > 0) ? (gpu_free / total_gpu) * 100 : 0
      printf "\n  CPUs: %d/%d idle (%.0f%%)   GPUs: %d/%d free (%.0f%%)   Nodes: %d\n", \
        cpu_idle, total_cpu, cpu_pct, gpu_free, total_gpu, gpu_pct, total_nodes
    }
  }'
  exit 0
fi

# --- Default: compact table grouped by free GPUs ---

# Compress node list into SLURM range notation: kolyoz1,kolyoz2,kolyoz3 -> kolyoz[1-3]
_compress_nodes() {
  echo "$1" | tr ', ' '\n' | sort -V | awk '
  {
    match($0, /^([a-zA-Z]+)([0-9]+)$/, m)
    if (RSTART == 0) { lone[++nl] = $0; next }
    prefix = m[1]; num = m[2] + 0
    if (prefix != prev_prefix && prev_prefix != "") flush()
    prev_prefix = prefix
    nums[++nn] = num
  }
  function flush(    i, v, j, range_start, range_end, parts, np) {
    if (nn == 0) return
    for (i = 2; i <= nn; i++) {
      v = nums[i]; j = i - 1
      while (j >= 1 && nums[j] > v) { nums[j+1] = nums[j]; j-- }
      nums[j+1] = v
    }
    np = 0; range_start = nums[1]; range_end = nums[1]
    for (i = 2; i <= nn; i++) {
      if (nums[i] == range_end + 1) { range_end = nums[i] }
      else {
        np++; parts[np] = (range_start == range_end) ? range_start : range_start "-" range_end
        range_start = range_end = nums[i]
      }
    }
    np++; parts[np] = (range_start == range_end) ? range_start : range_start "-" range_end
    result = prev_prefix "["
    for (i = 1; i <= np; i++) result = result (i>1 ? "," : "") parts[i]
    result = result "]"
    if (np == 1 && parts[1] !~ /-/) result = prev_prefix parts[1]
    out = out (out ? ", " : "") result
    nn = 0; delete nums
  }
  END {
    flush()
    for (i = 1; i <= nl; i++) out = out (out ? ", " : "") lone[i]
    print out
  }'
}

_info_tmp=$(mktemp)
sinfo "${SINFO_ARGS[@]}" | awk '
{
  node=$1; state=$3; cpus=$4; gres=$5; gres_used=$6
  split(cpus, c, "/")
  cpu_idle = c[2]
  gpu_total = gres; gsub(/.*:/, "", gpu_total); gpu_total += 0
  gpu_used = gres_used; gsub(/.*:/, "", gpu_used); gpu_used += 0
  gpu_free = gpu_total - gpu_used
  total_cpu_idle += cpu_idle; total_cpu += c[4]
  total_gpu_free += gpu_free; total_gpu += gpu_total

  if (state ~ /down|drain/) key = "down"
  else key = gpu_free + 0

  print key "\t" node
}
END {
  print "SUMMARY\t" total_cpu_idle "\t" total_cpu "\t" total_gpu_free "\t" total_gpu
}' > "$_info_tmp"

eval "$(awk -F'\t' '$1=="SUMMARY"{printf "S_CPU_IDLE=%s S_CPU_TOTAL=%s S_GPU_FREE=%s S_GPU_TOTAL=%s", $2, $3, $4, $5}' "$_info_tmp")"
S_CPU_IDLE=${S_CPU_IDLE:-0}; S_CPU_TOTAL=${S_CPU_TOTAL:-0}
S_GPU_FREE=${S_GPU_FREE:-0}; S_GPU_TOTAL=${S_GPU_TOTAL:-0}
cpu_pct=0; [ "$S_CPU_TOTAL" -gt 0 ] && cpu_pct=$((S_CPU_IDLE * 100 / S_CPU_TOTAL))
gpu_pct=0; [ "$S_GPU_TOTAL" -gt 0 ] && gpu_pct=$((S_GPU_FREE * 100 / S_GPU_TOTAL))
printf "  CPUs: %s/%s idle (%d%%)   GPUs: %s/%s free (%d%%)\n\n" \
  "$S_CPU_IDLE" "$S_CPU_TOTAL" "$cpu_pct" \
  "$S_GPU_FREE" "$S_GPU_TOTAL" "$gpu_pct"

printf "  %-11s %-55s %s\n" "Free GPUs" "Nodes" "Count"
printf "  %-11s %-55s %s\n" "---------" "-----" "-----"

keys=$(awk -F'\t' '$1!="SUMMARY"{print $1}' "$_info_tmp" | sort -u)
numeric_keys=$(echo "$keys" | grep -v 'down' | sort -rn)
has_down=$(echo "$keys" | grep -c 'down')

for k in $numeric_keys; do
  node_list=$(awk -F'\t' -v k="$k" '$1==k{print $2}' "$_info_tmp" | tr '\n' ',' | sed 's/,$//')
  count=$(awk -F'\t' -v k="$k" '$1==k{n++}END{print n}' "$_info_tmp")
  compressed=$(_compress_nodes "$node_list")
  printf "  %-11s %-55s %s\n" "$k" "$compressed" "$count"
done

if [ "$has_down" -gt 0 ]; then
  node_list=$(awk -F'\t' '$1=="down"{print $2}' "$_info_tmp" | tr '\n' ',' | sed 's/,$//')
  count=$(awk -F'\t' '$1=="down"{n++}END{print n}' "$_info_tmp")
  compressed=$(_compress_nodes "$node_list")
  printf "  %-11s %-55s %s\n" "down" "$compressed" "$count"
fi

rm -f "$_info_tmp"
