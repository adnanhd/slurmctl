# Fish completions for slurmctl

# Disable file completions by default
complete -c slurmctl -f

# Subcommands
complete -c slurmctl -n __fish_use_subcommand -a submit      -d 'Submit a .slurm script'
complete -c slurmctl -n __fish_use_subcommand -a list         -d 'List your running jobs'
complete -c slurmctl -n __fish_use_subcommand -a status       -d 'Detailed status of current job'
complete -c slurmctl -n __fish_use_subcommand -a acct         -d 'Job accounting details'
complete -c slurmctl -n __fish_use_subcommand -a tasks        -d 'Show status of all array tasks'
complete -c slurmctl -n __fish_use_subcommand -a running      -d 'Count running/pending/failed'
complete -c slurmctl -n __fish_use_subcommand -a failed       -d 'List failed array task IDs'
complete -c slurmctl -n __fish_use_subcommand -a 'failed-list' -d 'Failed tasks with details'
complete -c slurmctl -n __fish_use_subcommand -a resubmit     -d 'Resubmit failed tasks'
complete -c slurmctl -n __fish_use_subcommand -a resubmitall  -d 'Resubmit all failed jobs'
complete -c slurmctl -n __fish_use_subcommand -a tail         -d 'View job output (tail)'
complete -c slurmctl -n __fish_use_subcommand -a cat          -d 'View job output (cat)'
complete -c slurmctl -n __fish_use_subcommand -a head         -d 'View job output (head)'
complete -c slurmctl -n __fish_use_subcommand -a less         -d 'View job output (less)'
complete -c slurmctl -n __fish_use_subcommand -a watch        -d 'Live tail of job output'
complete -c slurmctl -n __fish_use_subcommand -a errors       -d 'Recent errors'
complete -c slurmctl -n __fish_use_subcommand -a cancel       -d 'Cancel current job'
complete -c slurmctl -n __fish_use_subcommand -a cancelall    -d 'Cancel all project jobs'
complete -c slurmctl -n __fish_use_subcommand -a nodes        -d 'Node status and resources'
complete -c slurmctl -n __fish_use_subcommand -a users        -d 'Your jobs by node'
complete -c slurmctl -n __fish_use_subcommand -a info         -d 'Partition/node info'
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

# history
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l all -d 'Show all entries (including archived)'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l oneline -d 'One-line compact format'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l script -d 'Show script paths'
complete -c slurmctl -n '__fish_seen_subcommand_from history' -l state -d 'Filter by state' -x

# tail/cat/head/less/watch
complete -c slurmctl -n '__fish_seen_subcommand_from tail cat head less watch' -l no-out -d 'View only stderr'
complete -c slurmctl -n '__fish_seen_subcommand_from tail cat head less watch' -l no-err -d 'View only stdout'

# nodes
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l partition -s p -d 'Filter by partition' -x
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l raw -d 'Raw sinfo output'
complete -c slurmctl -n '__fish_seen_subcommand_from nodes' -l all -d 'Show all nodes'

# users
complete -c slurmctl -n '__fish_seen_subcommand_from users' -l partition -s p -d 'Filter by partition' -x

# info
complete -c slurmctl -n '__fish_seen_subcommand_from info' -l raw -d 'Raw output'

# acct/tasks/failed-list
complete -c slurmctl -n '__fish_seen_subcommand_from acct tasks failed-list' -l format -d 'Custom sacct format' -x

# resubmit
complete -c slurmctl -n '__fish_seen_subcommand_from resubmit' -l array -d 'Override array range' -x
