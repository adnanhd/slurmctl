#!/bin/bash
# util — per-job resource utilization (GPU from slurmctl CSVs, CPU/mem/io from sacct)
cmd_help "${CYAN}slurmctl util${RESET} — Per-job resource utilization (avg + peak)

${YELLOW}Usage:${RESET}
  slurmctl util [-j JOBID]             GPU/CPU/mem/io utilization for a job

${YELLOW}Options:${RESET}
  -j, --job JOBID         Target job (default: current job from history)

GPU stats are parsed from the per-task GPU CSVs slurmctl writes during
submission; CPU, memory, and disk I/O come from sacct. Works for both
running and completed jobs." "$@"

while [ $# -gt 0 ]; do
  case "$1" in
    -*) printf "${RED}Unknown option: %s${RESET}\n" "$1" >&2; exit 1 ;;
    *)  printf "${RED}Unexpected argument: %s${RESET}\n" "$1" >&2; exit 1 ;;
  esac
done

JOBID=$(require_jobid)
BASE_JOBID="${JOBID%%_*}"

printf "${CYAN}Resource utilization for %s:${RESET}\n" "$BASE_JOBID"

# --- GPU: parse the per-task GPU CSVs (bounded glob — never a full ~/.slurm scan) ---
# CSV columns (sep ", "): timestamp, gpu_idx, util%, mem_used_MiB, mem_total_MiB, temp_C, power_W
gpu_csvs=$(ls "$SLURMCTL_LOG_DIR/${BASE_JOBID}"_*_gpu.csv 2>/dev/null || true)
if [ -n "$gpu_csvs" ]; then
  ntasks=$(echo "$gpu_csvs" | grep -c .)
  awk -F", " -v ntasks="$ntasks" '
  NF >= 5 {
    n++
    u += $3;            if ($3+0 > mu) mu = $3
    m += $4;            if ($4+0 > mm) mm = $4
    mt = $5
    if (NF >= 6) { t += $6; if ($6+0 > tmax) tmax = $6 }
    if (NF >= 7) { p += $7; if ($7+0 > pmax) pmax = $7 }
  }
  END {
    if (n == 0) { printf "  GPU:    no samples recorded\n"; exit }
    printf "  GPU util:  avg %.1f%%, max %.0f%%  (%d tasks, %d samples)\n", u/n, mu, ntasks, n
    printf "  GPU mem:   avg %.1f GiB, max %.1f GiB", m/n/1024, mm/1024
    if (mt+0 > 0) printf " (of %.0f GiB, %.0f%% peak)", mt/1024, (mm/mt)*100
    printf "\n"
    if (tmax+0 > 0) printf "  GPU temp:  avg %.0f C, max %.0f C\n", t/n, tmax
    if (pmax+0 > 0) printf "  GPU power: avg %.0f W, max %.0f W\n", p/n, pmax
  }' $gpu_csvs
else
  printf "  ${DIM}GPU: no monitoring CSVs found (job not GPU-monitored by slurmctl)${RESET}\n"
fi

# --- CPU / memory / disk I/O from sacct (.batch step) ---
sacct_data=$(sacct -j "$BASE_JOBID" --format=JobID%24,State%12,Elapsed,TotalCPU,MaxRSS,AllocCPUS,MaxDiskRead,MaxDiskWrite -n -P 2>/dev/null \
  | grep "\.batch|")

if [ -z "$sacct_data" ]; then
  printf "  ${YELLOW}CPU/mem/io: no sacct accounting data yet${RESET}\n"
  exit 0
fi

echo "$sacct_data" | awk -F"|" '
function parse_time(s,    parts, d) {
  d = 0
  if (index(s, "-")) { split(s, parts, "-"); d = parts[1]; s = parts[2] }
  split(s, parts, ":")
  return (d * 24 + parts[1]) * 3600 + parts[2] * 60 + parts[3]
}
function parse_mem_mib(s) {
  if (s ~ /K$/) return substr(s, 1, length(s)-1) / 1024
  if (s ~ /M$/) return substr(s, 1, length(s)-1)
  if (s ~ /G$/) return substr(s, 1, length(s)-1) * 1024
  if (s ~ /T$/) return substr(s, 1, length(s)-1) * 1024 * 1024
  if (s+0 > 0)  return s / 1048576
  return 0
}
{
  n++
  elapsed = parse_time($3); cputime = parse_time($4)
  rss = parse_mem_mib($5); ncpus = $6 + 0
  dr = parse_mem_mib($7); dw = parse_mem_mib($8)

  sum_rss += rss;  if (rss > max_rss) max_rss = rss
  sum_dr += dr;    if (dr > max_dr) max_dr = dr
  sum_dw += dw;    if (dw > max_dw) max_dw = dw
  if (elapsed > 0 && ncpus > 0) {
    eff = (cputime / (elapsed * ncpus)) * 100
    sum_eff += eff; neff++; if (eff > max_eff) max_eff = eff
  }
  last_ncpus = ncpus
}
END {
  if (n == 0) exit
  printf "  Tasks:     %d with accounting\n", n
  if (neff > 0)
    printf "  CPU:       avg %.1f%%, max %.1f%% of %d cores\n", sum_eff/neff, max_eff, last_ncpus
  printf "  Memory:    avg %.2f GiB, max %.2f GiB (MaxRSS)\n", sum_rss/n/1024, max_rss/1024
  printf "  Disk read: avg %.2f GiB, max %.2f GiB\n", sum_dr/n/1024, max_dr/1024
  printf "  Disk write:avg %.2f GiB, max %.2f GiB\n", sum_dw/n/1024, max_dw/1024
}'
