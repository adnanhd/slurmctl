# Fish completions for slurmctl

# Disable file completions by default
complete -c slurmctl -f

# Subcommands
complete -c slurmctl -n __fish_use_subcommand -a submit      -d 'Submit a .slurm script'
complete -c slurmctl -n __fish_use_subcommand -a list         -d 'List your running jobs'
complete -c slurmctl -n __fish_use_subcommand -a status       -d 'Job status and efficiency'
complete -c slurmctl -n __fish_use_subcommand -a acct         -d 'Job accounting details'
complete -c slurmctl -n __fish_use_subcommand -a tasks        -d 'Array task management'
complete -c slurmctl -n __fish_use_subcommand -a resubmitall  -d 'Resubmit all failed jobs'
complete -c slurmctl -n __fish_use_subcommand -a tail         -d 'View job output (tail)'
complete -c slurmctl -n __fish_use_subcommand -a cat          -d 'View job output (cat)'
complete -c slurmctl -n __fish_use_subcommand -a head         -d 'View job output (head)'
complete -c slurmctl -n __fish_use_subcommand -a less         -d 'View job output (less)'
complete -c slurmctl -n __fish_use_subcommand -a watch        -d 'Live tail of job output'
complete -c slurmctl -n __fish_use_subcommand -a errors       -d 'Recent errors'
complete -c slurmctl -n __fish_use_subcommand -a cancel       -d 'Cancel current job'
complete -c slurmctl -n __fish_use_subcommand -a cancelall    -d 'Cancel all project jobs'
complete -c slurmctl -n __fish_use_subcommand -a info         -d 'Cluster resource overview'
complete -c slurmctl -n __fish_use_subcommand -a nodes        -d 'Alias: info --list'
complete -c slurmctl -n __fish_use_subcommand -a jobs         -d 'Your jobs by node'
complete -c slurmctl -n __fish_use_subcommand -a update       -d 'Refresh job states from sacct'
complete -c slurmctl -n __fish_use_subcommand -a history      -d 'Show submission history'
complete -c slurmctl -n __fish_use_subcommand -a pop          -d 'Archive job from active history'
complete -c slurmctl -n __fish_use_subcommand -a clear        -d 'Clear all history'
complete -c slurmctl -n __fish_use_subcommand -a clean        -d 'Remove SLURM output files'
complete -c slurmctl -n __fish_use_subcommand -a health       -d 'Cluster health overview'
complete -c slurmctl -n __fish_use_subcommand -a help         -d 'Show usage'

# Global flags
complete -c slurmctl -l job -s j -d 'Override auto-detected job ID' -x

# submit
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -F -a '*.slurm'
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l after -d 'Run after job completes (afterok)' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l wrap -d 'Submit inline command' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l array -d 'Array task range' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l output -d 'Override stdout path' -x
complete -c slurmctl -n '__fish_seen_subcommand_from submit' -l error -d 'Override stderr path' -x

# status
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l eff -d 'Resource efficiency'
complete -c slurmctl -n '__fish_seen_subcommand_from status' -l why -d 'Why is job pending'

# tasks
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l summary -d 'Count by state'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l failed -d 'Failed tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l completed -d 'Completed tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l running -d 'Running tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l pending -d 'Pending tasks'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l list -d 'Detailed view'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l resubmit -d 'Resubmit failed'
complete -c slurmctl -n '__fish_seen_subcommand_from tasks' -l sort -d 'Sort by time|node' -x

# history
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l all -d 'Include archived'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l oneline -d 'Compact format'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l script -d 'Show script paths'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l state -d 'Filter by state' -x

# tail/cat/head/less/watch
complete -c slurmctl -n '__fish_seen_subcommand_from tail cat head less watch' -l no-out -d 'View only stderr'
complete -c slurmctl -n '__fish_seen_subcommand_from tail cat head less watch' -l no-err -d 'View only stdout'

# info
complete -c slurmctl -n '__fish_seen_subcommand_from info' -l partition -s p -d 'Filter by partition' -x
complete -c slurmctl -n '__fish_seen_subcommand_from info' -l list -s l -d 'Per-node detailed list'
complete -c slurmctl -n '__fish_seen_subcommand_from info' -l raw -d 'Raw sinfo output'

# nodes
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l partition -s p -d 'Filter by partition' -x
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l verbose -s v -d 'Per-node detailed list'
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l jobs -d 'Your jobs grouped by node'
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l raw -d 'Raw sinfo output'

# jobs
complete -c slurmctl -n '__fish_seen_subcommand_from jobs' -l partition -s p -d 'Filter by partition' -x

# acct
complete -c slurmctl -n '__fish_seen_subcommand_from acct' -l format -d 'Custom sacct format' -x

