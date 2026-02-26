#!/bin/bash
# list — show your running jobs

printf "${CYAN}Your Jobs:${RESET}\n"
squeue -u "$USER" -o '%.20i %.12P %.40j %.8u %.2t %.10M %.6D %R' | \
  sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
