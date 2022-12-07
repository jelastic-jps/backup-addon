#!/bin/bash

BASE_URL=$2
BACKUP_TYPE=$3
NODE_ID=$4
BACKUP_LOG_FILE=$5
ENV_NAME=$6
BACKUP_COUNT=$7
APP_PATH=$8

function backup(){
    echo $$ > /var/run/${ENV_NAME}_backup.pid
    BACKUP_ADDON_REPO=$(echo ${BASE_URL}|sed 's|https:\/\/raw.githubusercontent.com\/||'|awk -F / '{print $1"/"$2}')
    BACKUP_ADDON_BRANCH=$(echo ${BASE_URL}|sed 's|https:\/\/raw.githubusercontent.com\/||'|awk -F / '{print $3}')
    BACKUP_ADDON_COMMIT_ID=$(git ls-remote https://github.com/${BACKUP_ADDON_REPO}.git | grep "/${BACKUP_ADDON_BRANCH}$" | awk '{print $1}')
    echo $(date) ${ENV_NAME} "Creating the ${BACKUP_TYPE} backup (using the backup addon with commit id ${BACKUP_ADDON_COMMIT_ID}) on storage node ${NODE_ID}" | tee -a ${BACKUP_LOG_FILE}
    [ -d /opt/backup ] || mkdir -p /opt/backup
    export FILES_COUNT=$(ls -n /opt/backup|awk '{print $2}');
    if [ "${FILES_COUNT}" != "0" ]; then 
        echo $(date) ${ENV_NAME}  "Checking the backup repository integrity and consistency before adding the new snapshot" | tee -a $BACKUP_LOG_FILE;
        RESTIC_PASSWORD=${ENV_NAME} restic -q -r /opt/backup check  || { echo "Backup repository integrity check (before backup) failed."; exit 1; }
    else
        RESTIC_PASSWORD=${ENV_NAME} restic init -r /opt/backup
    fi
    DUMP_NAME=$(date "+%F_%H%M%S")
    for i in DB_HOST DB_USER DB_PASSWORD DB_NAME; do declare "${i}"=$(cat /var/www/webroot/ROOT/wp-config.php|grep ${i}|grep -v '^[[:space:]]*#'|tr -d '[[:blank:]]'|awk -F ',' '{print $2}'|tr -d "');"|tr -d '\r'|tail -n 1); done
    source /.jelenv ; if [[ ${MARIADB_VERSION//.*} -eq 10 && ${MARIADB_VERSION:3:1} -le 4 ]]; then COL_STAT=""; else COL_STAT="--column-statistics=0"; fi
    echo $(date) ${ENV_NAME} "Creating the DB dump" | tee -a ${BACKUP_LOG_FILE}
    source /etc/jelastic/metainf.conf ; if [ "${COMPUTE_TYPE}" == "lemp" -o "${COMPUTE_TYPE}" == "llsmp" ]; then service mysql status 2>&1 || service mysql start 2>&1; fi
    mysqldump -h ${DB_HOST} -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} --force --single-transaction --quote-names --opt --databases --compress ${COL_STAT} > wp_db_backup.sql || { echo "DB backup process failed."; exit 1; }
    echo $(date) ${ENV_NAME} "Saving data and DB dump to ${DUMP_NAME} snapshot" | tee -a ${BACKUP_LOG_FILE}
    { RESTIC_PASSWORD=${ENV_NAME} restic -q -r /opt/backup backup --tag "${DUMP_NAME} ${BACKUP_ADDON_COMMIT_ID} ${BACKUP_TYPE}" ${APP_PATH} ~/wp_db_backup.sql | tee -a $BACKUP_LOG_FILE; } || { echo "Backup rotation failed."; exit 1; }
    echo $(date) ${ENV_NAME} "Rotating snapshots by keeping the last ${BACKUP_COUNT}" | tee -a $BACKUP_LOG_FILE
    { RESTIC_PASSWORD=${ENV_NAME} restic forget -q -r /opt/backup --keep-last ${BACKUP_COUNT} --prune | tee -a $BACKUP_LOG_FILE; } || { echo "Backup snapshot creation failed."; exit 1; }
    echo $(date) ${ENV_NAME} "Checking the backup repository integrity and consistency after adding the new snapshot and rotating old ones" | tee -a $BACKUP_LOG_FILE;
    { RESTIC_PASSWORD=${ENV_NAME} restic -q -r /opt/backup check --read-data-subset=1/10 | tee -a $BACKUP_LOG_FILE; } || { echo "Backup repository integrity check (after backup) failed."; exit 1; }
    rm -f /var/run/${ENV_NAME}_backup.pid
}

if [ "x$1" == "xbackup" ]; then
    backup
fi
