#!/bin/bash
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/patches"
VERSION_FILE="$HOME/.slurm/.version"

# Colors (only when stdout is a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m' YELLOW='\033[0;33m' RESET='\033[0m'
else
  GREEN='' YELLOW='' RESET=''
fi

mkdir -p "$(dirname "$VERSION_FILE")"
[ -f "$VERSION_FILE" ] || echo "0.1" > "$VERSION_FILE"

applied=0
while true; do
  current=$(cat "$VERSION_FILE")
  patch="$PATCH_DIR/v${current}.sh"

  [ -f "$patch" ] || break

  printf "${YELLOW}Applying v%s patch...${RESET}\n" "$current"
  source "$patch"
  ((++applied))
done

if [ "$applied" -eq 0 ]; then
  printf "${GREEN}Already up to date (v%s).${RESET}\n" "$(cat "$VERSION_FILE")"
else
  printf "${GREEN}Applied %d patch(es). Now at v%s${RESET}\n" "$applied" "$(cat "$VERSION_FILE")"
fi
