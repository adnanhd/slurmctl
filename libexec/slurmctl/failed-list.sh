#!/bin/bash
# failed-list — alias for tasks --failed --list
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/tasks.sh" --failed --list "$@"
