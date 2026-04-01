#!/bin/bash
# resubmit — alias for tasks --resubmit
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/tasks.sh" --resubmit "$@"
