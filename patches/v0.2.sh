#!/bin/bash
# v0.2 → v0.3: Remove standalone *_gpu.summary files
# Summary is now prepended as `# key=value` comments to *_gpu.csv.

LOG_DIR="$HOME/.slurm/log"

removed=0
for f in "$LOG_DIR"/*_gpu.summary; do
  [ -f "$f" ] || continue
  rm -f "$f"
  ((++removed))
done

if [ "$removed" -gt 0 ]; then
  printf "  Removed %d stale *_gpu.summary file(s)\n" "$removed"
else
  printf "  No *_gpu.summary files to remove\n"
fi

echo "0.3" > "$VERSION_FILE"
