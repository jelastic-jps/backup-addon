#!/bin/bash

BASE_URL=$2
BACKUP_TYPE=$3
NODE_ID=$4
BACKUP_LOG_FILE=$5
ENV_NAME=$6
BACKUP_COUNT=$7
APP_PATH=$8

function check_backup_repo(){
    [ -d /opt/backup/${ENV_NAME} ] || mkdir -p /opt/backup/${ENV_NAME}
    export FILES_COUNT=$(ls -n /opt/backup/${ENV_NAME}|awk '{print $2}');
    if [ "${FILES_COUNT}" != "0" ]; then 
        echo $(date) ${ENV_NAME}  "Checking the backup repository integrity and consistency" | tee -a $BACKUP_LOG_FILE;
        GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic -q -r /opt/backup/${ENV_NAME} check --read-data-subset=1/10 || { echo "Backup repository integrity check failed."; exit 1; }
    else
        echo $(date) ${ENV_NAME}  "Initializing the new backup repo" | tee -a $BACKUP_LOG_FILE;
        GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic init -r /opt/backup/${ENV_NAME}
    fi
}

function rotate_snapshots(){
    echo $(date) ${ENV_NAME} "Rotating snapshots by keeping the last ${BACKUP_COUNT}" | tee -a ${BACKUP_LOG_FILE}
    { GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic forget -q -r /opt/backup/${ENV_NAME} --keep-last ${BACKUP_COUNT} --prune | tee -a $BACKUP_LOG_FILE; } || { echo "Backup rotation failed."; exit 1; }
}

function create_snapshot(){
    echo $(date) ${ENV_NAME} "Uploading the snapshot to backup storage" | tee -a ${BACKUP_LOG_FILE}
    DUMP_NAME=$(date "+%F_%H%M%S")
    { GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic -q -r /opt/backup/${ENV_NAME} backup --tag "${DUMP_NAME} ${BACKUP_ADDON_COMMIT_ID} ${BACKUP_TYPE}" ${APP_PATH} ~/wp_db_backup.sql | tee -a $BACKUP_LOG_FILE; } || { echo "Backup snapshot creation failed."; exit 1; }
}

function backup(){
    echo $$ > /var/run/${ENV_NAME}_backup.pid
    BACKUP_ADDON_REPO=$(echo ${BASE_URL}|sed 's|https:\/\/raw.githubusercontent.com\/||'|awk -F / '{print $1"/"$2}')
    BACKUP_ADDON_BRANCH=$(echo ${BASE_URL}|sed 's|https:\/\/raw.githubusercontent.com\/||'|awk -F / '{print $3}')
    BACKUP_ADDON_COMMIT_ID=$(git ls-remote https://github.com/${BACKUP_ADDON_REPO}.git | grep "/${BACKUP_ADDON_BRANCH}$" | awk '{print $1}')
    echo $(date) ${ENV_NAME} "Creating the ${BACKUP_TYPE} backup (using the backup addon with commit id ${BACKUP_ADDON_COMMIT_ID}) on storage node ${NODE_ID}" | tee -a ${BACKUP_LOG_FILE}
    for i in DB_USER DB_PASSWORD DB_NAME; do declare "${i}"=$(cat /var/www/webroot/ROOT/wp-config.php|grep ${i}|grep -v '^[[:space:]]*#'|tr -d '[[:blank:]]'|awk -F ',' '{print $2}'|tr -d "\"');"|tr -d '\r'|tail -n 1); done
    DB_HOST=$(cat /var/www/webroot/ROOT/wp-config.php|grep DB_HOST|grep -v '^[[:space:]]*#'|tr -d '[[:blank:]]'|awk -F ',' '{print $2}'|tr -d "\"');"|tr -d '\r'|tail -n 1|awk -F ':' '{print $1}');
    DB_PORT=$(cat /var/www/webroot/ROOT/wp-config.php|grep DB_HOST|grep -v '^[[:space:]]*#'|tr -d '[[:blank:]]'|awk -F ',' '{print $2}'|tr -d "\"');"|tr -d '\r'|tail -n 1|awk -F ':' '{print $2}');
    if [ -n "${DB_PORT}" ]; then 
        MYSQLDUMP_DB_PORT_OPTION="-P ${DB_PORT}"
    else
        MYSQLDUMP_DB_PORT_OPTION=""
    fi
    SERVER_VERSION_STRING=$(mysql -h ${DB_HOST} -u ${DB_USER} ${MYSQLDUMP_DB_PORT_OPTION} -p${DB_PASSWORD} -e 'status'|grep 'Server version')
    WP_DB_STACK_NAME=$(echo $SERVER_VERSION_STRING|awk '{print $4}')
    WP_DB_STACK_NAME=${WP_DB_STACK_NAME^^}
    WP_DB_STACK_VERSION=$(echo ${SERVER_VERSION_STRING}|awk '{print $3}'|awk -F '-' '{print $1}')
    source /.jelenv ; if [[ ${MARIADB_VERSION//.*} -eq 10 && ${MARIADB_VERSION:3:1} -le 6 ]]; then COL_STAT=""; else COL_STAT="--column-statistics=0"; fi
    if [ "x${WP_DB_STACK_NAME}" == "xMARIADB" ]; then
        if [[ ${WP_DB_STACK_VERSION//.*} -eq 10 && ${WP_DB_STACK_VERSION:3:1} -le 6 ]]; then COL_STAT=""; else COL_STAT="--column-statistics=0"; fi
    fi
    echo $(date) ${ENV_NAME} "Creating the DB dump" | tee -a ${BACKUP_LOG_FILE}
    source /etc/jelastic/metainf.conf ; if [ "${COMPUTE_TYPE}" == "lemp" -o "${COMPUTE_TYPE}" == "llsmp" ]; then service mysql status 2>&1 || service mysql start 2>&1; fi
    mysqldump -h ${DB_HOST} -u ${DB_USER} ${MYSQLDUMP_DB_PORT_OPTION} -p${DB_PASSWORD} ${DB_NAME} --force --single-transaction --quote-names --opt --databases ${COL_STAT} > wp_db_backup.sql || { echo "DB backup process failed."; exit 1; }
    rm -f /var/run/${ENV_NAME}_backup.pid
}

case "$1" in
    backup)
        $1
        ;;
    check_backup_repo)
        $1
        ;;
    rotate_snapshots)
        $1
        ;;
    create_snapshot)
	$1
        ;;
    *)
        echo "Usage: $0 {backup|check_backup_repo|rotate_snapshots|create_snapshot}"
        exit 2
esac

exit $?
