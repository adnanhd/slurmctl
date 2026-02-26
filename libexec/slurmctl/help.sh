#!/bin/bash
# help — show usage

SCRIPTS=$(cd "$SLURMCTL_PROJECT_ROOT" && ls *.slurm 2>/dev/null | sed 's/\.slurm$//' | tr '\n' ' ')

cat <<EOF

${CYAN}slurmctl${RESET} — SLURM Job Management
===============================================================================

${YELLOW}Submitting Jobs:${RESET}
  slurmctl ${GREEN}submit${RESET} <script>.slurm [sbatch args...]

${YELLOW}Job Monitoring:${RESET}
  slurmctl ${GREEN}list${RESET}                    List your running jobs
  slurmctl ${GREEN}status${RESET}                  Detailed status of current job
  slurmctl ${GREEN}acct${RESET}                    Job accounting details

${YELLOW}Array Jobs:${RESET}
  slurmctl ${GREEN}tasks${RESET}                   Show status of all array tasks
  slurmctl ${GREEN}running${RESET}                 Count running/pending/failed
  slurmctl ${GREEN}failed${RESET}                  List failed array task IDs
  slurmctl ${GREEN}resubmit${RESET}                Resubmit failed tasks

${YELLOW}Output Viewing:${RESET}
  slurmctl ${GREEN}tail${RESET} / ${GREEN}cat${RESET} / ${GREEN}head${RESET} / ${GREEN}less${RESET}   View job output/error
  slurmctl ${GREEN}tail${RESET} --no-out           View only stderr
  slurmctl ${GREEN}tail${RESET} --no-err           View only stdout
  slurmctl ${GREEN}watch${RESET}                   Live tail of job output
  slurmctl ${GREEN}errors${RESET}                  Recent errors

${YELLOW}Job Control:${RESET}
  slurmctl ${GREEN}cancel${RESET}                  Cancel current job
  slurmctl ${GREEN}cancelall${RESET}               Cancel all your jobs

${YELLOW}Cluster Info:${RESET}
  slurmctl ${GREEN}nodes${RESET}                   Jobs per node
  slurmctl ${GREEN}users${RESET}                   Jobs per user
  slurmctl ${GREEN}info${RESET}                    Partition/node info

${YELLOW}History:${RESET}
  slurmctl ${GREEN}update${RESET}                  Refresh job states from sacct
  slurmctl ${GREEN}history${RESET}                 Show submission history
  slurmctl ${GREEN}pop${RESET}                     Archive job from active history
  slurmctl ${GREEN}clear${RESET}                   Clear all history
  slurmctl ${GREEN}clean${RESET}                   Remove SLURM output files

${YELLOW}Global Flags:${RESET}
  --job, -j <JOBID>            Override auto-detected job ID

${YELLOW}Available Scripts:${RESET} ${SCRIPTS:-none}
EOF
