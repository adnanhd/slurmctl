#!/bin/bash
# info — partition/node info

printf "${CYAN}Cluster Info:${RESET}\n"
sinfo --all -o "%12P %36N %8t %6c %8m %14G" | \
  sed "1s/^/$(printf "${YELLOW}")/" | sed "1s/$/$(printf "${RESET}")/"
