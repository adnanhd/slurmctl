#!/bin/bash
# info — cluster node status (backend for `nodes` command)
cmd_help "${CYAN}slurmctl nodes${RESET} — Cluster node status

${YELLOW}Usage:${RESET}
  slurmctl nodes [-p PARTITION]                      Per-node one-liner
  slurmctl nodes [-p PARTITION] --verbose            Per-node with CPU/GPU/state detail
  slurmctl nodes [-p PARTITION] --group-by=gpu       Nodes grouped by free GPU count
  slurmctl nodes [-p PARTITION] --group-by=gpu -v    Same + expanded node lists with state
  slurmctl nodes [-p PARTITION] --group-by=job       Your jobs grouped by node
  slurmctl nodes [-p PARTITION] --group-by=job -v    Jobs + node resource info alongside

${YELLOW}Options:${RESET}
  -p, --partition PART     Filter to a specific partition
  -v, --verbose            Show detailed view
  --group-by=MODE          Group output (gpu, cpu, mem, job)

${YELLOW}Examples:${RESET}
  slurmctl nodes                         All nodes, one line each
  slurmctl nodes -v                      All nodes with CPU/GPU detail
  slurmctl nodes --group-by=gpu          Nodes grouped by free GPU count
  slurmctl nodes --group-by=cpu          Nodes grouped by idle CPU count
  slurmctl nodes --group-by=mem          Nodes grouped by total memory
  slurmctl nodes --group-by=job          Your jobs by node
  slurmctl nodes --group-by=job -v       Jobs by node with resource info" "$@"

PARTITION=""
VERBOSE=false
GROUP_BY=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--partition) [ $# -lt 2 ] && { echo "error: --partition requires an argument" >&2; exit 1; }; PARTITION="$2"; shift 2 ;;
    --partition=*)  PARTITION="${1#*=}"; shift ;;
    -v|--verbose|-l|--list) VERBOSE=true; shift ;;
    --group-by=*)   GROUP_BY="${1#*=}"; shift ;;
    --group-by)     [ $# -lt 2 ] && { echo "error: --group-by requires an argument (gpu, job)" >&2; exit 1; }; GROUP_BY="$2"; shift 2 ;;
    --jobs)         GROUP_BY="job"; shift ;;  # backward compat
    --raw)          GROUP_BY="gpu"; shift ;;  # backward compat
    *) shift ;;
  esac
done

# --- Common sinfo args ---
SINFO_ARGS=(-h -N --Format "NodeHost:20,Partition:14,StateLong:12,CPUsState:14,Gres:24,GresUsed:24")
[ -n "$PARTITION" ] && SINFO_ARGS+=(-p "$PARTITION")

_partition_header() {
  if [ -n "$PARTITION" ]; then
    printf "${CYAN}%s (%s):${RESET}\n" "$1" "$PARTITION"
  else
    printf "${CYAN}%s:${RESET}\n" "$1"
  fi
}

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

# Summary footer: CPUs idle / GPUs free
_print_summary() {
  local cpu_idle=$1 cpu_total=$2 gpu_free=$3 gpu_total=$4
  local cpu_pct=0 gpu_pct=0
  [ "$cpu_total" -gt 0 ] && cpu_pct=$((cpu_idle * 100 / cpu_total))
  [ "$gpu_total" -gt 0 ] && gpu_pct=$((gpu_free * 100 / gpu_total))
  printf "\n  CPUs: %s/%s idle (%d%%)   GPUs: %s/%s free (%d%%)\n" \
    "$cpu_idle" "$cpu_total" "$cpu_pct" "$gpu_free" "$gpu_total" "$gpu_pct"
}

# ============================================================================
# group-by=job: your jobs grouped by node
# ============================================================================
if [ "$GROUP_BY" = "job" ]; then
  SQUEUE_ARGS=(-u "$USER" -h -o "%i|%t|%P|%N|%j|%M|%l|%C|%m")
  [ -n "$PARTITION" ] && SQUEUE_ARGS+=(-p "$PARTITION")

  output=$(squeue "${SQUEUE_ARGS[@]}" 2>/dev/null)
  if [ -z "$output" ]; then
    printf "${YELLOW}No jobs in queue${RESET}\n"
    exit 0
  fi

  _partition_header "Your jobs by node"

  if $VERBOSE; then
    # Verbose: jobs with runtime, CPU, memory details
    echo "$output" | awk -F'|' -v g="$GREEN" -v y="$YELLOW" -v b="$BLUE" -v r="$RESET" -v c="$CYAN" '
    {
      for (f = 1; f <= NF; f++) { gsub(/^ +| +$/, "", $f) }
      jobid=$1; state=$2; part=$3; node=$4; name=$5; runtime=$6; timelimit=$7; cpus=$8; mem=$9
      if (state == "R") sc = g "R" r
      else if (state == "PD") sc = b "PD" r
      else sc = y state r
      if (node == "" || node == "(None)") node = "(pending)"
      key = node
      if (!(key in nodes)) { order[++n] = key }
      nodes[key] = nodes[key] sprintf("    %s%-12s%s %s %-14s %-20s %s%s  [%s CPUs, %s]%s\n", \
        c, jobid, r, sc, part, name, y, runtime, cpus, mem, r)
      counts[key]++
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        printf "  %s%s%s (%d job%s)\n", g, k, r, counts[k], (counts[k]==1?"":"s")
        printf "%s", nodes[k]
      }
    }'
  else
    # Default: compact jobs by node
    echo "$output" | awk -F'|' -v g="$GREEN" -v y="$YELLOW" -v b="$BLUE" -v r="$RESET" -v c="$CYAN" '
    {
      for (f = 1; f <= NF; f++) { gsub(/^ +| +$/, "", $f) }
      jobid=$1; state=$2; part=$3; node=$4; name=$5
      if (state == "R") sc = g "R" r
      else if (state == "PD") sc = b "PD" r
      else sc = y state r
      if (node == "" || node == "(None)") node = "(pending)"
      key = node
      if (!(key in nodes)) { order[++n] = key }
      nodes[key] = nodes[key] sprintf("    %s%-10s%s %s %-14s %s%s%s\n", c, jobid, r, sc, part, y, name, r)
      counts[key]++
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        printf "  %s%s%s (%d job%s)\n", g, k, r, counts[k], (counts[k]==1?"":"s")
        printf "%s", nodes[k]
      }
    }'
  fi
  exit 0
fi

# ============================================================================
# group-by=gpu|cpu|mem: nodes grouped by resource availability
# ============================================================================
if [ "$GROUP_BY" = "gpu" ] || [ "$GROUP_BY" = "cpu" ] || [ "$GROUP_BY" = "mem" ]; then
  _partition_header "Cluster Resources"

  # Compute grouping key based on mode
  # Fields in sinfo: node=$1 part=$2 state=$3 cpus=$4 mem=$5 gres=$6 gres_used=$7
  SINFO_RES_ARGS=(-h -N --Format "NodeHost:20,Partition:14,StateLong:12,CPUsState:14,Memory:10,Gres:24,GresUsed:24")
  [ -n "$PARTITION" ] && SINFO_RES_ARGS+=(-p "$PARTITION")

  case "$GROUP_BY" in
    gpu) KEY_LABEL="Free GPUs"; KEY_UNIT="GPU" ;;
    cpu) KEY_LABEL="Idle CPUs"; KEY_UNIT="CPU" ;;
    mem) KEY_LABEL="Free Mem (GiB)"; KEY_UNIT="GiB" ;;
  esac

  _info_tmp=$(mktemp)
  sinfo "${SINFO_RES_ARGS[@]}" | awk -v mode="$GROUP_BY" '
  {
    node=$1; state=$3; cpus=$4; mem=$5; gres=$6; gres_used=$7
    split(cpus, c, "/")
    cpu_alloc = c[1]; cpu_idle = c[2]; cpu_total_v = c[4]
    gpu_total_v = gres; gsub(/.*:/, "", gpu_total_v); gpu_total_v += 0
    gpu_used = gres_used; gsub(/.*:/, "", gpu_used); gpu_used += 0
    gpu_free = gpu_total_v - gpu_used
    # mem from sinfo is in MiB
    mem_total_gib = int(mem / 1024)

    # Count totals, but exclude down/drain nodes from "free/idle"
    # (their resources are unallocatable, not available).
    is_down = (state ~ /down|drain/)
    total_cpu += cpu_total_v; total_gpu += gpu_total_v
    if (!is_down) { total_cpu_idle += cpu_idle; total_gpu_free += gpu_free }

    if (is_down) key = "down"
    else if (mode == "gpu") key = gpu_free + 0
    else if (mode == "cpu") key = cpu_idle + 0
    else if (mode == "mem") key = mem_total_gib + 0

    print key "\t" node "\t" state "\t" cpus "\t" mem "\t" gres "\t" gres_used
  }
  END {
    print "SUMMARY\t" total_cpu_idle "\t" total_cpu "\t" total_gpu_free "\t" total_gpu
  }' > "$_info_tmp"

  eval "$(awk -F'\t' '$1=="SUMMARY"{printf "S_CPU_IDLE=%s S_CPU_TOTAL=%s S_GPU_FREE=%s S_GPU_TOTAL=%s", $2, $3, $4, $5}' "$_info_tmp")"
  S_CPU_IDLE=${S_CPU_IDLE:-0}; S_CPU_TOTAL=${S_CPU_TOTAL:-0}
  S_GPU_FREE=${S_GPU_FREE:-0}; S_GPU_TOTAL=${S_GPU_TOTAL:-0}
  _print_summary "$S_CPU_IDLE" "$S_CPU_TOTAL" "$S_GPU_FREE" "$S_GPU_TOTAL"
  echo ""

  keys=$(awk -F'\t' '$1!="SUMMARY"{print $1}' "$_info_tmp" | sort -u)
  numeric_keys=$(echo "$keys" | grep -v 'down' | sort -rn)
  has_down=$(echo "$keys" | grep -c 'down')

  if $VERBOSE; then
    # Verbose: show per-node detail within each group
    for k in $numeric_keys; do
      count=$(awk -F'\t' -v k="$k" '$1==k{n++}END{print n}' "$_info_tmp")
      printf "  ${GREEN}%s %s${RESET} (%d node%s):\n" "$k" "$KEY_UNIT" "$count" "$([ "$count" = "1" ] && echo "" || echo "s")"
      awk -F'\t' -v k="$k" -v g="$GREEN" -v y="$YELLOW" -v r="$RED" -v b="$BLUE" -v c="$CYAN" -v rs="$RESET" '
      $1==k {
        node=$2; state=$3; cpus=$4; mem=$5; gres=$6; gres_used=$7
        split(cpus, cpu, "/")
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
          n_gp = split(gres, gp, ":"); gpu_total = gp[n_gp]
          gpu_used = 0; if (gres_used ~ /gpu/) { gpu_used = gres_used; gsub(/.*:/, "", gpu_used) }
          gpu_type = (n_gp >= 3) ? gp[2] : "GPUs"
          gpu_str = sprintf("  [%s/%s %s]", gpu_used, gpu_total, gpu_type)
        }
        mem_gib = int(mem / 1024)
        printf "    %-18s %s[%s/%s CPUs] [%s GiB]%s\n", node, sc, cpu[1], cpu[4], mem_gib, gpu_str
      }' "$_info_tmp"
    done
    if [ "$has_down" -gt 0 ]; then
      count=$(awk -F'\t' '$1=="down"{n++}END{print n}' "$_info_tmp")
      printf "  ${RED}down${RESET} (%d node%s):\n" "$count" "$([ "$count" = "1" ] && echo "" || echo "s")"
      awk -F'\t' -v r="$RED" -v rs="$RESET" '
      $1=="down" { printf "    %-18s %s%s%s\n", $2, r, $3, rs }' "$_info_tmp"
    fi
  else
    # Default: compact table
    printf "  %-15s %-55s %s\n" "$KEY_LABEL" "Nodes" "Count"
    printf "  %-15s %-55s %s\n" "---------------" "-----" "-----"

    for k in $numeric_keys; do
      node_list=$(awk -F'\t' -v k="$k" '$1==k{print $2}' "$_info_tmp" | tr '\n' ',' | sed 's/,$//')
      count=$(awk -F'\t' -v k="$k" '$1==k{n++}END{print n}' "$_info_tmp")
      compressed=$(_compress_nodes "$node_list")
      printf "  %-15s %-55s %s\n" "$k" "$compressed" "$count"
    done

    if [ "$has_down" -gt 0 ]; then
      node_list=$(awk -F'\t' '$1=="down"{print $2}' "$_info_tmp" | tr '\n' ',' | sed 's/,$//')
      count=$(awk -F'\t' '$1=="down"{n++}END{print n}' "$_info_tmp")
      compressed=$(_compress_nodes "$node_list")
      printf "  %-15s %-55s %s\n" "down" "$compressed" "$count"
    fi
  fi

  rm -f "$_info_tmp"
  exit 0
fi

# ============================================================================
# No group-by: flat per-node list (default)
# ============================================================================
_partition_header "Cluster Resources"

if $VERBOSE; then
  # Verbose: per-node with CPU/GPU/state detail + summary
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
else
  # Default: one-liner per node (raw sinfo -N)
  SINFO_RAW=(-o "%12P %36N %8t %6c %8m %14G")
  [ -n "$PARTITION" ] && SINFO_RAW+=(-p "$PARTITION") || SINFO_RAW+=(--all)
  sinfo "${SINFO_RAW[@]}" | \
    sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
fi
