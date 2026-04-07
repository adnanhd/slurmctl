#!/bin/bash
# help — show usage

# Bold escape for options
B=$(printf '\033[1m')
R=$(printf '\033[0m')

cat <<EOF

${CYAN}slurmctl${RESET} — SLURM Job Management
===============================================================================

${YELLOW}Global Flags:${RESET}
  ${B}-j${R}, ${B}--job${R} JOBID         Target a specific job (overrides auto-detection)

${YELLOW}Job Submitting:${RESET}
  ${GREEN}submit${RESET} <script> [${B}--after${R} JOBID] [${B}--wrap${R}="<cmd>"] [${B}--array${R}=RANGE] [sbatch args...]
    Submit a job and track in history. Git metadata captured automatically.
    ${B}--after${R} JOBID           Run after JOBID completes (afterok dependency)
    ${B}--wrap${R}="<cmd>"          Submit an inline command (no script file needed)
    ${B}--array${R}=RANGE           Submit as array job (e.g. 0-99%8)
    Any extra flags are passed directly to sbatch.

${YELLOW}Job Listing:${RESET}
  ${GREEN}list${RESET} [${B}-j${R} JOBID] [${B}--summary${R}] [${B}--failed${R}|${B}--completed${R}|${B}--running${R}|${B}--pending${R}] [${B}-v${R}] [${B}--sort${R} time|node]
    Without filters: your running/pending jobs (squeue).
    With filters: task/step breakdown for a job (sacct). Works for array, single, and wrap jobs.
    ${B}--summary${R}               Count tasks by state
    ${B}--failed${R}                Failed task IDs (comma-separated)
    ${B}--completed${R}             Completed task IDs
    ${B}--running${R}               Running task IDs
    ${B}--pending${R}               Pending task IDs
    ${B}-v${R}, ${B}--verbose${R}           Detailed view with exit codes and nodes
    ${B}--sort${R} time|node        Sort order for detailed view

${YELLOW}Job Status:${RESET}
  ${GREEN}status${RESET} [${B}-j${R} JOBID] [${B}--acct${R}] [${B}--eff${R}] [${B}--why${R}]
    Deep inspection of a single job. Auto-detects array/single/wrap.
    (default)               Job state, runtime, resources (+ array summary)
    ${B}--acct${R}                  Accounting details from sacct
    ${B}--eff${R}                   Resource efficiency (avg/max CPU, memory, GPU)
    ${B}--why${R}                   Why is this job pending?

${YELLOW}Job Control:${RESET}
  ${GREEN}cancel${RESET} [${B}-j${R} JOBID] [${B}--all${R}] [${B}-n${R} NODE] [${B}-p${R} PARTITION]
    Cancel jobs. Without flags: cancel current/specified job.
    ${B}--all${R}                   Cancel all active project jobs from history
    ${B}-n${R}, ${B}--node${R} NODE         Cancel your jobs on NODE
    ${B}-p${R}, ${B}--partition${R} PART    Cancel your jobs on PARTITION

  ${GREEN}resubmit${RESET} [${B}-j${R} JOBID] [${B}--all${R}] [${B}-n${R} NODE] [${B}-p${R} PARTITION]
    Resubmit failed tasks. Without flags: resubmit failed tasks of current job.
    ${B}--failed${R}                Resubmit failed tasks (default, explicit)
    ${B}--all${R}                   Resubmit all failed jobs from history
    ${B}-n${R}, ${B}--node${R} NODE         Filter to jobs that ran on NODE
    ${B}-p${R}, ${B}--partition${R} PART    Filter to jobs on PARTITION

${YELLOW}Output Viewing:${RESET}
  ${GREEN}tail${RESET} [${B}-j${R} JOBID] [${B}--no-out${R}] [${B}--no-err${R}] [tail args...]
  ${GREEN}cat${RESET}  [${B}-j${R} JOBID] [${B}--no-out${R}] [${B}--no-err${R}]
  ${GREEN}head${RESET} [${B}-j${R} JOBID] [${B}--no-out${R}] [${B}--no-err${R}] [head args...]
  ${GREEN}less${RESET} [${B}-j${R} JOBID] [${B}--no-out${R}] [${B}--no-err${R}]
  ${GREEN}watch${RESET} [${B}-j${R} JOBID]
  ${GREEN}errors${RESET}
    View job stdout/stderr. Defaults to current job.
    ${B}--no-out${R}                Show only stderr
    ${B}--no-err${R}                Show only stdout

${YELLOW}Cluster Info:${RESET}
  ${GREEN}nodes${RESET} [${B}-p${R} PARTITION] [${B}-v${R}] [${B}--group-by${R}=MODE]
    Cluster node status. Without --group-by: flat node list.
    ${B}-v${R}, ${B}--verbose${R}           Detailed view with CPU/GPU/state per node
    ${B}-p${R}, ${B}--partition${R} PART    Filter to PARTITION
    ${B}--group-by${R}=MODE         Group output:
      ${B}gpu${R}                   Nodes grouped by free GPU count
      ${B}cpu${R}                   Nodes grouped by idle CPU count
      ${B}mem${R}                   Nodes grouped by total memory (GiB)
      ${B}job${R}                   Your jobs grouped by node
    All modes support ${B}-v${R} for per-node detail within each group.

${YELLOW}History:${RESET}
  ${GREEN}history${RESET} [${B}-n${R} N] [${B}--all${R}] [${B}--oneline${R}] [${B}--script${R}] [${B}--state${R} STATE]
    Show submission history (newest first).
    ${B}-n${R} N                    Show last N entries
    ${B}--all${R}                   Include archived entries
    ${B}--oneline${R}               Compact one-line format
    ${B}--script${R}                Show script paths
    ${B}--state${R} STATE           Filter by state

  ${GREEN}update${RESET}                  Refresh job states from sacct
  ${GREEN}pop${RESET}                     Archive current job from active history
  ${GREEN}clear${RESET}                   Clear all history
  ${GREEN}clean${RESET}                   Remove SLURM output files

${YELLOW}Other:${RESET}
  ${GREEN}health${RESET}                  Version, install path, project, cluster status
EOF
