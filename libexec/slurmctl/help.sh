#!/bin/bash
# help — show usage

SCRIPTS=$(find . -type f -name '*.slurm' -not -path '*/.*' 2>/dev/null | sed 's|^\./||' | sort || true)

cat <<EOF

${CYAN}slurmctl${RESET} — SLURM Job Management
===============================================================================

${YELLOW}Job Submitting:${RESET}
  slurmctl ${GREEN}submit${RESET} <script>.slurm [sbatch args...]
  slurmctl ${GREEN}submit${RESET} --wrap="<cmd>" [sbatch args...]
  slurmctl ${GREEN}submit${RESET} --after <jobid> <script>.slurm

${YELLOW}Job Listing:${RESET}
  slurmctl ${GREEN}list${RESET}                    Your running/pending jobs (squeue)
  slurmctl ${GREEN}list${RESET} --summary          Task/step count by state
  slurmctl ${GREEN}list${RESET} --failed            Failed task IDs (comma-separated)
  slurmctl ${GREEN}list${RESET} --failed -v         Failed tasks with details

${YELLOW}Job Status:${RESET}
  slurmctl ${GREEN}status${RESET}                  Job state, runtime, resources
  slurmctl ${GREEN}status${RESET} --acct            Accounting details (sacct)
  slurmctl ${GREEN}status${RESET} --eff             Resource efficiency (CPU, memory, GPU)
  slurmctl ${GREEN}status${RESET} --why             Why is this job pending?

${YELLOW}Job Control:${RESET}
  slurmctl ${GREEN}cancel${RESET}                  Cancel current job
  slurmctl ${GREEN}cancel${RESET} --all             Cancel all active project jobs
  slurmctl ${GREEN}cancel${RESET} --node=NODE       Cancel jobs on a specific node
  slurmctl ${GREEN}cancel${RESET} -p PARTITION      Cancel jobs on a partition
  slurmctl ${GREEN}resubmit${RESET}                Resubmit failed tasks of current job
  slurmctl ${GREEN}resubmit${RESET} --all           Resubmit all failed jobs from history
  slurmctl ${GREEN}resubmit${RESET} --all -p PART   Resubmit failed jobs on a partition
  slurmctl ${GREEN}resubmit${RESET} --all --node=N  Resubmit failed jobs on a node

${YELLOW}Output Viewing:${RESET}
  slurmctl ${GREEN}tail${RESET} [ARGS...]           Tail stdout + stderr (pass args to tail)
  slurmctl ${GREEN}cat${RESET}                     Full stdout + stderr
  slurmctl ${GREEN}head${RESET} [ARGS...]           Head of stdout + stderr
  slurmctl ${GREEN}less${RESET}                    Pager view of stdout + stderr
  slurmctl ${GREEN}watch${RESET}                   Live tail -f of job output
  slurmctl ${GREEN}errors${RESET}                  Last 5 lines of recent stderr files
    --no-out             Show only stderr
    --no-err             Show only stdout

${YELLOW}Cluster Info:${RESET}
  slurmctl ${GREEN}nodes${RESET} [-p PART]                   Per-node one-liner (sinfo)
  slurmctl ${GREEN}nodes${RESET} -v                          Per-node with CPU/GPU detail
  slurmctl ${GREEN}nodes${RESET} --group-by=gpu              Nodes grouped by free GPU count
  slurmctl ${GREEN}nodes${RESET} --group-by=cpu              Nodes grouped by idle CPU count
  slurmctl ${GREEN}nodes${RESET} --group-by=mem              Nodes grouped by total memory
  slurmctl ${GREEN}nodes${RESET} --group-by=job              Your jobs grouped by node
  Any --group-by mode supports ${GREEN}-v${RESET} for per-node detail within each group.

${YELLOW}History:${RESET}
  slurmctl ${GREEN}update${RESET}                  Refresh job states from sacct
  slurmctl ${GREEN}history${RESET} [-n N] [--all]   Submission log (newest first)
  slurmctl ${GREEN}pop${RESET}                     Archive job (remove from active stack)
  slurmctl ${GREEN}clear${RESET}                   Clear all history
  slurmctl ${GREEN}clean${RESET}                   Remove SLURM output files

${YELLOW}Other:${RESET}
  slurmctl ${GREEN}health${RESET}                  Version, environment, connectivity

${YELLOW}Global Flags:${RESET}
  --job, -j <JOBID>     Target a specific job (overrides auto-detection)

${YELLOW}Examples:${RESET}
  slurmctl submit train.slurm                     Submit a job
  slurmctl submit train.slurm --array=0-99%8      Submit array job
  slurmctl submit eval.slurm --after 12345        Submit with dependency
  slurmctl submit --wrap="python train.py"       Inline command
  slurmctl list --summary                         Check array job progress
  slurmctl list --failed                          Get failed task IDs
  slurmctl tail --no-out                          View only stderr
  slurmctl resubmit                               Resubmit failed tasks

${YELLOW}Available Scripts:${RESET}
EOF

if [ -z "$SCRIPTS" ]; then
  echo "  (none)"
else
  echo "$SCRIPTS" | awk -F/ '
  {
    dir = ""
    for (i = 1; i < NF; i++) dir = (dir ? dir "/" : "") $i
    file = $NF
    if (dir != prev_dir) {
      if (prev_dir != "") printf "\n"
      printf "  %s/\n", dir
      prev_dir = dir
    }
    printf "    %s\n", file
  }'
fi
