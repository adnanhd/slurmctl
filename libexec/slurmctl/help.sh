#!/bin/bash
# help — show usage

SCRIPTS=$(cd "$SLURMCTL_PROJECT_ROOT" && ls *.slurm 2>/dev/null | sed 's/\.slurm$//' | tr '\n' ' ' || true)

cat <<EOF

${CYAN}slurmctl${RESET} — SLURM Job Management
===============================================================================

${YELLOW}Submitting Jobs:${RESET}
  slurmctl ${GREEN}submit${RESET} <script>.slurm [opts] [sbatch args...]
    Submit a job and track it in history. Git metadata is captured automatically.
    --after <jobid>      Run after <jobid> completes (afterok dependency)
    Any extra flags are passed directly to sbatch.
    Run ${CYAN}slurmctl submit --help${RESET} for full details.

${YELLOW}Job Monitoring:${RESET}
  slurmctl ${GREEN}list${RESET}                    List your running jobs (squeue)
  slurmctl ${GREEN}status${RESET}                  Detailed status + resource usage
  slurmctl ${GREEN}acct${RESET}                    Accounting details (sacct)

${YELLOW}Array Jobs:${RESET}
  slurmctl ${GREEN}tasks${RESET}                   Show status of all array tasks
  slurmctl ${GREEN}running${RESET}                 Count completed/running/pending/failed
  slurmctl ${GREEN}failed${RESET}                  Failed task IDs (comma-separated, for --array)
  slurmctl ${GREEN}failed-list${RESET}             Failed tasks with details
  slurmctl ${GREEN}resubmit${RESET}                Resubmit failed tasks of current job
  slurmctl ${GREEN}resubmitall${RESET}             Resubmit all failed jobs from history

${YELLOW}Output Viewing:${RESET}
  slurmctl ${GREEN}tail${RESET} [N]                Last N lines of stdout + stderr (default: 50)
  slurmctl ${GREEN}cat${RESET}                     Full stdout + stderr
  slurmctl ${GREEN}head${RESET} [N]                First N lines of stdout + stderr
  slurmctl ${GREEN}less${RESET}                    Pager view of stdout + stderr
  slurmctl ${GREEN}watch${RESET}                   Live tail -f of job output
  slurmctl ${GREEN}errors${RESET}                  Recent stderr output
    --no-out             Show only stderr
    --no-err             Show only stdout

${YELLOW}Job Control:${RESET}
  slurmctl ${GREEN}cancel${RESET}                  Cancel current job
  slurmctl ${GREEN}cancelall${RESET}               Cancel all active project jobs

${YELLOW}Cluster Info:${RESET}
  slurmctl ${GREEN}nodes${RESET} [-p PART]          Node status and CPU usage
  slurmctl ${GREEN}users${RESET} [-p PART]          Your jobs grouped by node
  slurmctl ${GREEN}info${RESET}                    Partition/node info (sinfo)

${YELLOW}History:${RESET}
  slurmctl ${GREEN}update${RESET}                  Refresh job states from sacct
  slurmctl ${GREEN}history${RESET} [N]             Show last N submissions (default: 10, 0=all)
  slurmctl ${GREEN}pop${RESET}                     Archive job from active history
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
  slurmctl running                                Check progress
  slurmctl tail --no-out                          View only stderr
  slurmctl -j 12345 tasks                         Check specific job's tasks
  slurmctl resubmit                               Resubmit failed tasks

${YELLOW}Available Scripts:${RESET} ${SCRIPTS:-none}
EOF
