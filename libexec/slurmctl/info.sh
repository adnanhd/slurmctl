#!/bin/bash
# info — alias for nodes --raw
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/nodes.sh" --raw "$@"
