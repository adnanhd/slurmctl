#!/bin/bash
# status — detailed job status
cmd_help "${CYAN}slurmctl status${RESET} — Detailed job status and resource efficiency

${YELLOW}Usage:${RESET}
  slurmctl status [-j JOBID]         Job state, runtime, resources
  slurmctl status [-j JOBID] --eff   Resource efficiency (avg/max CPU, memory, GPU across tasks)
  slurmctl status [-j JOBID] --why   Why is this job pending?

${YELLOW}Examples:${RESET}
  slurmctl status                 Current job status
  slurmctl status --eff           Resource efficiency for array job
  slurmctl status --why 1175620   Why is this job pending?" "$@"

EFF=false
WHY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --eff)  EFF=true; shift ;;
    --why)  WHY=true; shift ;;
    *) break ;;
  esac
done

JOBID=$(require_jobid)

# --- Why pending ---
if $WHY; then
  reason=$(scontrol show job "$JOBID" 2>/dev/null | grep -oP 'Reason=\K.*')
  state=$(scontrol show job "$JOBID" 2>/dev/null | grep -oP 'JobState=\K\S+')
  name=$(scontrol show job "$JOBID" 2>/dev/null | grep -oP 'JobName=\K\S+')
  if [ "$state" != "PENDING" ]; then
    printf "Job %s (%s): %s (not pending)\n" "$JOBID" "$name" "$state"
  else
    dep=$(scontrol show job "$JOBID" 2>/dev/null | grep -oP 'Dependency=\K\S+')
    printf "Job %s (%s): ${YELLOW}%s${RESET}\n" "$JOBID" "$name" "$reason"
    [ -n "$dep" ] && printf "  Dependency: %s\n" "$dep"
  fi
  exit 0
fi

# --- Resource efficiency ---
if $EFF; then
  printf "${CYAN}Resource Usage for %s:${RESET}\n" "$JOBID"

  sacct_data=$(sacct -j "$JOBID" --format=JobID%20,State%12,Elapsed,TotalCPU,MaxRSS,ReqMem,AllocCPUS,TimelimitRaw -n -P 2>/dev/null \
    | grep '\.batch|')

  if [ -z "$sacct_data" ]; then
    printf "  ${YELLOW}No accounting data available yet${RESET}\n"
    exit 0
  fi

  echo "$sacct_data" | awk -F'|' '
  function parse_time(s,    parts, d) {
    d = 0
    if (index(s, "-")) { split(s, parts, "-"); d = parts[1]; s = parts[2] }
    split(s, parts, ":")
    return (d * 24 + parts[1]) * 3600 + parts[2] * 60 + parts[3]
  }
  function fmt_time(secs,    d, h, m) {
    d = int(secs / 86400); h = int((secs % 86400) / 3600); m = int((secs % 3600) / 60)
    if (d > 0) return sprintf("%dd %dh%02dm", d, h, m)
    if (h > 0) return sprintf("%dh%02dm", h, m)
    return sprintf("%dm", m)
  }
  function parse_mem_mib(s) {
    if (s ~ /K$/) return substr(s, 1, length(s)-1) / 1024
    if (s ~ /M$/) return substr(s, 1, length(s)-1)
    if (s ~ /G$/) return substr(s, 1, length(s)-1) * 1024
    if (s ~ /T$/) return substr(s, 1, length(s)-1) * 1024 * 1024
    if (s+0 > 0) return s / 1048576
    return 0
  }
  {
    n++
    elapsed = parse_time($3); cputime = parse_time($4)
    maxrss = parse_mem_mib($5); reqmem = parse_mem_mib($6)
    ncpus = $7 + 0; tlimit = $8 * 60

    sum_elapsed += elapsed; if (elapsed > max_elapsed) max_elapsed = elapsed
    sum_rss += maxrss; if (maxrss > max_rss) max_rss = maxrss

    if (elapsed > 0 && ncpus > 0) {
      eff = (cputime / (elapsed * ncpus)) * 100
      sum_eff += eff; if (eff > max_eff) max_eff = eff
    }
    last_reqmem = reqmem; last_ncpus = ncpus; last_tlimit = tlimit
  }
  END {
    if (n == 0) exit
    printf "  Tasks:     %d completed\n", n
    printf "  Wall time: avg %s, max %s", fmt_time(sum_elapsed/n), fmt_time(max_elapsed)
    if (last_tlimit > 0) printf " (limit %s)", fmt_time(last_tlimit)
    printf "\n"
    printf "  CPU:       avg %.1f%%, max %.1f%% of %d cores\n", sum_eff/n, max_eff, last_ncpus
    printf "  Memory:    avg %.1f GiB, max %.1f GiB", sum_rss/n/1024, max_rss/1024
    if (last_reqmem > 0) printf " (of %.0f GiB, %.0f%% peak)", last_reqmem/1024, (max_rss/last_reqmem)*100
    printf "\n"
  }'

  # GPU stats from slurmctl monitoring
  gpu_summaries=$(ls "$SLURMCTL_LOG_DIR/${JOBID}"_*_gpu.summary 2>/dev/null)
  if [ -n "$gpu_summaries" ]; then
    awk -F= '
    /^gpu_util_avg/    { sum_u += $2; nu++ }
    /^gpu_util_max/    { if ($2+0 > mu) mu = $2 }
    /^gpu_mem_avg_mib/ { sum_m += $2; nm++ }
    /^gpu_mem_max_mib/ { if ($2+0 > mm) mm = $2 }
    /^gpu_mem_total/   { mt = $2 }
    /^gpu_temp_max/    { if ($2+0 > mtemp) mtemp = $2 }
    /^gpu_power_avg/   { sum_p += $2; np++ }
    END {
      if (nu > 0) printf "  GPU util:  avg %.1f%%, max %.0f%%\n", sum_u/nu, mu
      if (nm > 0) {
        printf "  GPU mem:   avg %.1f GiB, max %.1f GiB", sum_m/nm/1024, mm/1024
        if (mt > 0) printf " (of %.0f GiB, %.0f%% peak)", mt/1024, (mm/mt)*100
        printf "\n"
      }
      if (mtemp > 0) printf "  GPU temp:  max %d C\n", mtemp
      if (np > 0) printf "  GPU power: avg %.0f W\n", sum_p/np
    }' $gpu_summaries
  else
    printf "  ${DIM}GPU: no monitoring data (submit via slurmctl for GPU tracking)${RESET}\n"
  fi
  exit 0
fi

# --- Default: basic job status from scontrol ---
JOB_NAME=$(squeue --job "$JOBID" -o %j 2>/dev/null | tail -1)

printf "${CYAN}Job %s:${RESET} %s\n" "$JOBID" "$JOB_NAME"
scontrol show job "$JOBID" 2>/dev/null | \
  grep -E "JobState=|Reason=|RunTime=|TimeLimit=|NumCPUs=|MinMemory|NodeList=" | \
  sed 's/^/  /'
