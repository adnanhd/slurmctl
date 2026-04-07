#!/bin/bash
# help — show usage

SCRIPTS=$(find . -type f -name '*.slurm' -not -path '*/.*' 2>/dev/null | sed 's|^\./||' | sort || true)

cat <<EOF

${CYAN}slurmctl${RESET} — SLURM Job Management
===============================================================================

${YELLOW}Global Flags:${RESET}
  -j, --job JOBID         Target a specific job (overrides auto-detection)

${YELLOW}Job Submitting:${RESET}

  ${GREEN}submit${RESET} <script> [--after JOBID] [--wrap="<cmd>"] [--array=RANGE] [sbatch args...]
    Submit a job and track in history. Git metadata captured automatically.
    --after JOBID           Run after JOBID completes (afterok dependency)
    --wrap="<cmd>"          Submit an inline command (no script file needed)
    --array=RANGE           Submit as array job (e.g. 0-99%8)
    Any extra flags are passed directly to sbatch.

${YELLOW}Job Listing:${RESET}

  ${GREEN}list${RESET} [-j JOBID] [--summary] [--failed|--completed|--running|--pending] [-v] [--sort time|node]
    Without filters: your running/pending jobs (squeue).
    With filters: task/step breakdown for a job (sacct). Works for array, single, and wrap jobs.
    --summary               Count tasks by state
    --failed                Failed task IDs (comma-separated)
    --completed             Completed task IDs
    --running               Running task IDs
    --pending               Pending task IDs
    -v, --verbose           Detailed view with exit codes and nodes
    --sort time|node        Sort order for detailed view

${YELLOW}Job Status:${RESET}

  ${GREEN}status${RESET} [-j JOBID] [--acct] [--eff] [--why]
    Deep inspection of a single job. Auto-detects array/single/wrap.
    (default)               Job state, runtime, resources (+ array summary)
    --acct                  Accounting details from sacct
    --eff                   Resource efficiency (avg/max CPU, memory, GPU)
    --why                   Why is this job pending?

${YELLOW}Job Control:${RESET}

  ${GREEN}cancel${RESET} [-j JOBID] [--all] [-n NODE] [-p PARTITION]
    Cancel jobs. Without flags: cancel current/specified job.
    --all                   Cancel all active project jobs from history
    -n, --node NODE         Cancel your jobs on NODE
    -p, --partition PART    Cancel your jobs on PARTITION

  ${GREEN}resubmit${RESET} [-j JOBID] [--all] [-n NODE] [-p PARTITION]
    Resubmit failed tasks. Without flags: resubmit failed tasks of current job.
    --failed                Resubmit failed tasks (default, explicit)
    --all                   Resubmit all failed jobs from history
    -n, --node NODE         Filter to jobs that ran on NODE
    -p, --partition PART    Filter to jobs on PARTITION

${YELLOW}Output Viewing:${RESET}

  ${GREEN}tail${RESET} [-j JOBID] [--no-out] [--no-err] [tail args...]
  ${GREEN}cat${RESET}  [-j JOBID] [--no-out] [--no-err]
  ${GREEN}head${RESET} [-j JOBID] [--no-out] [--no-err] [head args...]
  ${GREEN}less${RESET} [-j JOBID] [--no-out] [--no-err]
  ${GREEN}watch${RESET} [-j JOBID]
  ${GREEN}errors${RESET}
    View job stdout/stderr. Defaults to current job.
    --no-out                Show only stderr
    --no-err                Show only stdout

${YELLOW}Cluster Info:${RESET}

  ${GREEN}nodes${RESET} [-p PARTITION] [-v] [--group-by=MODE]
    Cluster node status. Without --group-by: flat node list.
    -v, --verbose           Detailed view with CPU/GPU/state per node
    -p, --partition PART    Filter to PARTITION
    --group-by=MODE         Group output:
      gpu                   Nodes grouped by free GPU count
      cpu                   Nodes grouped by idle CPU count
      mem                   Nodes grouped by total memory (GiB)
      job                   Your jobs grouped by node
    All modes support -v for per-node detail within each group.

${YELLOW}History:${RESET}

  ${GREEN}history${RESET} [-n N] [--all] [--oneline] [--script] [--state STATE]
    Show submission history (newest first).
    -n N                    Show last N entries
    --all                   Include archived entries
    --oneline               Compact one-line format
    --script                Show script paths
    --state STATE           Filter by state

  ${GREEN}update${RESET}                  Refresh job states from sacct
  ${GREEN}pop${RESET}                     Archive current job from active history
  ${GREEN}clear${RESET}                   Clear all history
  ${GREEN}clean${RESET}                   Remove SLURM output files

${YELLOW}Other:${RESET}
  ${GREEN}health${RESET}                  Version, install path, project, cluster status

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
      printf "  ./%s/\n", dir
      prev_dir = dir
    }
    printf "    %s\n", file
  }'
fi
