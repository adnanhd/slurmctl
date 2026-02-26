#!/bin/bash
exec bash "$SLURMCTL_SRC_DIR/libexec/slurmctl/tail.sh" --viewer cat "$@"
