#!/bin/bash
# health — show slurmctl version, environment, and connectivity

printf "${CYAN}slurmctl health${RESET}\n"
echo "==============================="

# Version info (stamped at install time by Makefile)
VERSION=$(cat "$SLURMCTL_SRC_DIR/VERSION" 2>/dev/null || echo "unknown")
printf "  %-16s %s\n" "Version:" "$VERSION"
printf "  %-16s %s\n" "Install:" "$SLURMCTL_SRC_DIR"
printf "  %-16s %s\n" "Project:" "$SLURMCTL_PROJECT_ROOT"
printf "  %-16s %s\n" "Log dir:" "$SLURMCTL_LOG_DIR"
printf "  %-16s %s\n" "History:" "$HIST_FILE"

# History stats
if [ -f "$HIST_FILE" ]; then
  TOTAL=$(wc -l < "$HIST_FILE")
  printf "  %-16s %d entries\n" "Jobs logged:" "$TOTAL"
else
  printf "  %-16s %s\n" "Jobs logged:" "none"
fi

echo ""

# SLURM connectivity
printf "${CYAN}Cluster${RESET}\n"
echo "==============================="
if command -v squeue &>/dev/null; then
  RUNNING=$(squeue -u "$USER" -h -t RUNNING 2>/dev/null | wc -l)
  PENDING=$(squeue -u "$USER" -h -t PENDING 2>/dev/null | wc -l)
  printf "  %-16s %d running, %d pending\n" "Your jobs:" "$RUNNING" "$PENDING"
else
  printf "  %-16s %s\n" "squeue:" "${RED}not found${RESET}"
fi

if command -v sacct &>/dev/null; then
  printf "  %-16s %s\n" "sacct:" "available"
else
  printf "  %-16s %s\n" "sacct:" "${RED}not found${RESET}"
fi

if command -v sinfo &>/dev/null; then
  NODES_UP=$(sinfo -h -t idle,mixed,alloc -o "%D" 2>/dev/null | awk '{s+=$1}END{print s+0}')
  printf "  %-16s %s nodes up\n" "Cluster:" "$NODES_UP"
else
  printf "  %-16s %s\n" "sinfo:" "${RED}not found${RESET}"
fi
