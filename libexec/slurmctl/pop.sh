#!/bin/bash
# pop — archive job from active history (mark as cancelled)

JOBID=$(require_jobid)

printf "${YELLOW}Archiving${RESET} %s in history\n" "$JOBID"

if [ -f "$HIST_FILE" ]; then
  sed -i "/${JOBID}/{s/ *,\? *\"state\":\"[^\"]*\"//g;s/}$/, \"state\":\"cancelled\"}/;}" "$HIST_FILE"
fi
