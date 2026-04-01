#!/bin/bash
# running — alias for tasks --summary
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/tasks.sh" --summary "$@"
