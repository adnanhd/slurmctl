#!/bin/bash
exec bash "$SLURMCTL_ROOT/libexec/slurmctl/tail.sh" --viewer head "$@"
