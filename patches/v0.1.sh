#!/bin/bash
# v0.1 → v0.2: Migrate logs from ~/.slurm/ to ~/.slurm/log/

SLURM_DIR="$HOME/.slurm"
LOG_DIR="$SLURM_DIR/log"

mkdir -p "$LOG_DIR"

moved=0
for pattern in "*.slurm.log"; do
  for f in "$SLURM_DIR"/$pattern; do
    [ -f "$f" ] || continue
    mv "$f" "$LOG_DIR/"
    ((++moved))
  done
done

if [ "$moved" -gt 0 ]; then
  printf "  Moved %d file(s) to %s\n" "$moved" "$LOG_DIR"
else
  printf "  No files to migrate\n"
fi

echo "0.2" > "$VERSION_FILE"
