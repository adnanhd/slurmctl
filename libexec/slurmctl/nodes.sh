#!/bin/bash
# nodes — alias for info --list
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/info.sh" --list "$@"
