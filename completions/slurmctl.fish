# Fish completions for slurmctl

complete -c slurmctl -f

# Dynamic partition list (cached for session via fish's own memoization is N/A; sinfo is cheap)
function __slurmctl_partitions
    sinfo -h -o '%R' 2>/dev/null | sort -u
end

# Subcommands
complete -c slurmctl -n __fish_use_subcommand -a submit      -d 'Submit a job'
complete -c slurmctl -n __fish_use_subcommand -a list         -d 'List jobs and tasks'
complete -c slurmctl -n __fish_use_subcommand -a status       -d 'Job status and inspection'
complete -c slurmctl -n __fish_use_subcommand -a util         -d 'Per-job GPU/CPU/mem/io utilization'
complete -c slurmctl -n __fish_use_subcommand -a resubmit     -d 'Resubmit failed tasks or jobs'
complete -c slurmctl -n __fish_use_subcommand -a cancel       -d 'Cancel jobs'
complete -c slurmctl -n __fish_use_subcommand -a throttle     -d 'Set running array job max concurrent tasks'
complete -c slurmctl -n __fish_use_subcommand -a tail         -d 'View job output (tail)'
complete -c slurmctl -n __fish_use_subcommand -a cat          -d 'View job output (cat)'
complete -c slurmctl -n __fish_use_subcommand -a head         -d 'View job output (head)'
complete -c slurmctl -n __fish_use_subcommand -a less         -d 'View job output (less)'
complete -c slurmctl -n __fish_use_subcommand -a watch        -d 'Live tail of job output'
complete -c slurmctl -n __fish_use_subcommand -a errors       -d 'Recent errors'
complete -c slurmctl -n __fish_use_subcommand -a nodes        -d 'Cluster node status'
complete -c slurmctl -n __fish_use_subcommand -a health       -d 'Version and cluster connectivity'
complete -c slurmctl -n __fish_use_subcommand -a history      -d 'Show submission history'
complete -c slurmctl -n __fish_use_subcommand -a update       -d 'Refresh job states from sacct'
complete -c slurmctl -n __fish_use_subcommand -a pop          -d 'Archive job from active history'
complete -c slurmctl -n __fish_use_subcommand -a clear        -d 'Clear all history'
complete -c slurmctl -n __fish_use_subcommand -a clean        -d 'Remove SLURM output files'
complete -c slurmctl -n __fish_use_subcommand -a help         -d 'Show usage'

# Global flags
complete -c slurmctl -l job -s j -d 'Override auto-detected job ID' -x

# submit
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -xa '(find . -type f -name "*.slurm" -not -path "*/.*" 2>/dev/null | sed "s|^\./||")'
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l after -d 'Run after job completes (afterok)' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l wrap -d 'Submit inline command' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l array -d 'Array task range' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l output -d 'Override stdout path' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l error -d 'Override stderr path' -x

# list
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l summary -d 'Count by state'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l failed -d 'Failed tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l completed -d 'Completed tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l running -d 'Running tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l pending -d 'Pending tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l cancelled -d 'Cancelled tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l timeout -d 'Timed-out tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l since -d 'Only jobs on/after DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l until -d 'Only jobs before DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l verbose -s v -d 'Detailed view'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l sort -d 'Sort by time|node' -xa 'time node'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l visual -d 'TUI bar chart of states'
complete -c slurmctl -n '__fish_seen_subcommand_from list' -l graphical -d 'TUI bar chart of states'

# status
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l acct -d 'Accounting details (sacct)'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l eff -d 'Resource efficiency'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l why -d 'Why is job pending'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l failed -d 'Failed tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l completed -d 'Completed tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l running -d 'Running tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l pending -d 'Pending tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l cancelled -d 'Cancelled tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l timeout -d 'Timed-out tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l node-fail -d 'Node-failed tasks table'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l sort -d 'Sort by time|node' -xa 'time node'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l visual -d 'TUI GPU util line graph (with --eff)'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l graphical -d 'TUI GPU util line graph (with --eff)'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l task -d 'GPU-csv task id for --visual' -x

# cancel
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l all -d 'Cancel all project jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l pending -d 'Only pending jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l running -d 'Only running jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l since -d 'Only jobs on/after DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l until -d 'Only jobs before DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l node -s n -d 'Cancel jobs on node' -x
complete -c slurmctl -n '__fish_seen_subcommand_from cancel' -l partition -s p -d 'Cancel jobs on partition' -xa '(__slurmctl_partitions)'

# resubmit
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l failed -d 'Resubmit FAILED jobs (default)'
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l cancelled -d 'Include CANCELLED jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l timeout -d 'Include TIMEOUT jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l node-fail -d 'Include NODE_FAIL jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l all -d 'Iterate history'
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l since -d 'Only jobs on/after DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l until -d 'Only jobs before DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l node -s n -d 'Filter by node' -x
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l partition -s p -d 'Filter by partition' -xa '(__slurmctl_partitions)'

# tail/cat/head/less/watch
complete -c slurmctl -n '__fish_seen_subcommand_from tail cat head less watch' -l no-out -d 'Show only stderr'
complete -c slurmctl -n '__fish_seen_subcommand_from tail cat head less watch' -l no-err -d 'Show only stdout'

# nodes
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l partition -s p -d 'Filter by partition' -xa '(__slurmctl_partitions)'
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l verbose -s v -d 'Detailed view'
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l group-by -d 'Group mode' -xa 'gpu cpu mem job'

# history
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l all -d 'Include archived'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l oneline -d 'Compact format'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l script -d 'Show script paths'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l failed -d 'Only FAILED jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l completed -d 'Only COMPLETED jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l running -d 'Only RUNNING jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l pending -d 'Only PENDING jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l cancelled -d 'Only CANCELLED jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l timeout -d 'Only TIMEOUT jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l node-fail -d 'Only NODE_FAIL jobs'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l since -d 'Only jobs on/after DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l until -d 'Only jobs before DATETIME' -x
complete -c slurmctl -n '__fish_seen_subcommand_from history' -s n -d 'Show last N entries' -x
