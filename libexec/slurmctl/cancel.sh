#!/bin/bash
# cancel — cancel job and mark as cancelled in history

JOBID=$(require_jobid)

printf "${RED}Cancelling${RESET} job %s\n" "$JOBID"
scancel "$JOBID"

if [ -f "$HIST_FILE" ]; then
  sed -i "/${JOBID}/{s/ *,\? *\"state\":\"[^\"]*\"//g;s/}$/, \"state\":\"cancelled\"}/;}" "$HIST_FILE"
fi
