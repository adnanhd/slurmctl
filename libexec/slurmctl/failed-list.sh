#!/bin/bash
# failed-list — alias for tasks --failed --list
source "$SLURMCTL_SRC_DIR/libexec/slurmctl/tasks.sh" --failed --list "$@"
