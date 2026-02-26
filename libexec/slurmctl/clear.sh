#!/bin/bash
# clear — clear all history

> "$HIST_FILE"
printf "${GREEN}History cleared${RESET}\n"
