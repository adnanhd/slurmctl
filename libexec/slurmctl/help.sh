#!/bin/bash
# help — show usage

SCRIPTS=$(cd "$SLURMCTL_PROJECT_ROOT" && ls *.slurm 2>/dev/null | sed 's/\.slurm$//' | tr '\n' ' ' || true)

cat <<EOF

${CYAN}slurmctl${RESET} — SLURM Job Management
===============================================================================

${YELLOW}Submitting Jobs:${RESET}
  slurmctl ${GREEN}submit${RESET} <script>.slurm [opts] [sbatch args...]
  slurmctl ${GREEN}submit${RESET} --wrap="<cmd>" [opts] [sbatch args...]
    Submit a job and track it in history. Git metadata is captured automatically.
    --wrap="<cmd>"       Submit an inline command (no script needed)
    --after <jobid>      Run after <jobid> completes (afterok dependency)
    Any extra flags are passed directly to sbatch.
    Run ${CYAN}slurmctl submit --help${RESET} for full details.

${YELLOW}Job Monitoring:${RESET}
  slurmctl ${GREEN}list${RESET}                    List your running jobs (squeue)
  slurmctl ${GREEN}status${RESET}                  Detailed status + resource usage
  slurmctl ${GREEN}acct${RESET}                    Accounting details (sacct)

${YELLOW}Array Jobs:${RESET}
  slurmctl ${GREEN}tasks${RESET}                   Show status of all array tasks
  slurmctl ${GREEN}tasks${RESET} --summary         Count completed/running/pending/failed
  slurmctl ${GREEN}tasks${RESET} --failed           Failed task IDs (comma-separated, for --array)
  slurmctl ${GREEN}tasks${RESET} --failed --list    Failed tasks with details
  slurmctl ${GREEN}tasks${RESET} --resubmit         Resubmit failed tasks of current job
  slurmctl ${GREEN}resubmitall${RESET}             Resubmit all failed jobs from history

${YELLOW}Output Viewing:${RESET}
  slurmctl ${GREEN}tail${RESET} [ARGS...]           Tail stdout + stderr (pass args to tail)
  slurmctl ${GREEN}cat${RESET}                     Full stdout + stderr
  slurmctl ${GREEN}head${RESET} [ARGS...]           Head of stdout + stderr
  slurmctl ${GREEN}less${RESET}                    Pager view of stdout + stderr
  slurmctl ${GREEN}watch${RESET}                   Live tail -f of job output
  slurmctl ${GREEN}errors${RESET}                  Last 5 lines of recent stderr files
    --no-out             Show only stderr
    --no-err             Show only stdout

${YELLOW}Job Control:${RESET}
  slurmctl ${GREEN}cancel${RESET}                  Cancel current job
  slurmctl ${GREEN}cancelall${RESET}               Cancel all active project jobs

${YELLOW}Cluster Info:${RESET}
  slurmctl ${GREEN}nodes${RESET} [-p PART]          Free GPUs grouped by count (compact)
  slurmctl ${GREEN}nodes${RESET} --verbose          Per-node detailed list with summary
  slurmctl ${GREEN}nodes${RESET} --raw              Raw sinfo table
  slurmctl ${GREEN}jobs${RESET} [-p PART]            Your jobs grouped by node

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
  slurmctl tasks --summary                        Check progress
  slurmctl tail --no-out                          View only stderr
  slurmctl -j 12345 tasks                         Check specific job's tasks
  slurmctl tasks --resubmit                       Resubmit failed tasks

${YELLOW}Available Scripts:${RESET} ${SCRIPTS:-none}
EOF
