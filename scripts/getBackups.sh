#!/bin/bash

if [ $# -eq 0 ]; then
    ENV_LIST=$(ls -Qm /data);
    OUTPUT_JSON="{\"result\": 0, \"envs\": [${ENV_LIST}"
else
    ENV_NAME=$1
    [ -d "/data/$1" ] && BACKUP_LIST=$(RESTIC_PASSWORD="$1" restic -r /data/$1 snapshots|awk '{print $5}'|grep -o [0-9_-]*|awk '{print "\""$1"\""}'|tr '\n' ',')
    OUTPUT_JSON="{\"result\": 0, \"backups\": [${BACKUP_LIST}"
    [ -n "${BACKUP_LIST}" ] && OUTPUT_JSON=${OUTPUT_JSON::-1}
fi

echo $OUTPUT_JSON]}
