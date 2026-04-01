#!/bin/bash
# failed — alias for tasks --failed
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/tasks.sh" --failed "$@"
