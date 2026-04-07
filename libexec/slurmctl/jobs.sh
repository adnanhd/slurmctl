#!/bin/bash
# jobs — alias for nodes --jobs
source "$SLURMCTL_SRC_DIR/libexec/slurmctl/info.sh" --jobs "$@"
