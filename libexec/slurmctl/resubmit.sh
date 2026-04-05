#!/bin/bash
# resubmit — alias for tasks --resubmit
source "$SLURMCTL_SRC_DIR/libexec/slurmctl/tasks.sh" --resubmit "$@"
