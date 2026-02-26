#!/bin/bash
# cancelall — cancel all your jobs

printf "${RED}Cancelling all your jobs${RESET}\n"
scancel -u "$USER"
