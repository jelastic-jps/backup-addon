#!/bin/bash

BASE_URL=$2
BACKUP_TYPE=$3
NODE_ID=$4
BACKUP_LOG_FILE=$5
ENV_NAME=$6
BACKUP_COUNT=$7
APP_PATH=$8
USER_SESSION=$9
USER_EMAIL=${10}

if which restic 2>&1; then
    true
else
    if which dnf 2>&1; then
          dnf install -y epel-release 2>&1
          dnf install -y restic 2>&1
    else
          yum-config-manager --disable nodesource 2>&1
          yum-config-manager --add-repo https://copr.fedorainfracloud.org/coprs/copart/restic/repo/epel-7/copart-restic-epel-7.repo 2>&1
          yum-config-manager --enable copr:copr.fedorainfracloud.org:copart:restic 2>&1
          yum -y install restic 2>&1
          yum-config-manager --disable copr:copr.fedorainfracloud.org:copart:restic 2>&1
    fi 
fi

function sendEmailNotification(){
    if [ -e "/usr/lib/jelastic/modules/api.module" ]; then
        [ -e "/var/run/jem.pid" ] && return 0;
        CURRENT_PLATFORM_MAJOR_VERSION=$(jem api apicall -s --connect-timeout 3 --max-time 15 [API_DOMAIN]/1.0/statistic/system/rest/getversion 2>/dev/null |jq .version|grep -o [0-9.]*|awk -F . '{print $1}')
        if [ "${CURRENT_PLATFORM_MAJOR_VERSION}" -ge "7" ]; then
            echo $(date) ${ENV_NAME} "Sending e-mail notification about removing the stale lock" | tee -a $BACKUP_LOG_FILE;
            SUBJECT="Stale lock is removed on /opt/backup/${ENV_NAME} backup repo"
            BODY="Please pay attention to /opt/backup/${ENV_NAME} backup repo because the stale lock left from previous operation is removed during the integrity check and backup rotation. Manual check of backup repo integrity and consistency is highly desired."
            jem api apicall -s --connect-timeout 3 --max-time 15 [API_DOMAIN]/1.0/message/email/rest/send --data-urlencode "session=$USER_SESSION" --data-urlencode "to=$USER_EMAIL" --data-urlencode "subject=$SUBJECT" --data-urlencode "body=$BODY"
            if [[ $? != 0 ]]; then
                echo $(date) ${ENV_NAME} "Sending of e-mail notification failed" | tee -a $BACKUP_LOG_FILE;
            else
                echo $(date) ${ENV_NAME} "E-mail notification is sent successfully" | tee -a $BACKUP_LOG_FILE;
            fi
        elif [ -z "${CURRENT_PLATFORM_MAJOR_VERSION}" ]; then #this elif covers the case if the version is not received
            echo $(date) ${ENV_NAME} "Error when checking the platform version" | tee -a $BACKUP_LOG_FILE;
        else
            echo $(date) ${ENV_NAME} "Email notification is not sent because this functionality is unavailable for current platform version." | tee -a $BACKUP_LOG_FILE;
        fi
    else
        echo $(date) ${ENV_NAME} "Email notification is not sent because this functionality is unavailable for current platform version." | tee -a $BACKUP_LOG_FILE;
    fi
}

function update_restic(){
    restic self-update 2>&1;
}

function check_backup_repo(){
    [ -d /opt/backup/${ENV_NAME} ] || mkdir -p /opt/backup/${ENV_NAME}
    export FILES_COUNT=$(ls -n /opt/backup/${ENV_NAME}|awk '{print $2}');
    if [ "${FILES_COUNT}" != "0" ]; then 
        echo $(date) ${ENV_NAME}  "Checking the backup repository integrity and consistency" | tee -a $BACKUP_LOG_FILE;
        if [[ $(ls -A /opt/backup/${ENV_NAME}/locks) ]] ; then
	    echo $(date) ${ENV_NAME}  "Backup repository has a slate lock, removing" | tee -a $BACKUP_LOG_FILE;
            GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic -r /opt/backup/${ENV_NAME} unlock
	    sendEmailNotification
        fi
        GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic -q -r /opt/backup/${ENV_NAME} check --read-data-subset=5% || { echo "Backup repository integrity check failed."; exit 1; }
    else
        GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic init -r /opt/backup/${ENV_NAME}
    fi
}

function rotate_snapshots(){
    echo $(date) ${ENV_NAME} "Rotating snapshots by keeping the last ${BACKUP_COUNT}" | tee -a ${BACKUP_LOG_FILE}
    if [[ $(ls -A /opt/backup/${ENV_NAME}/locks) ]] ; then
        echo $(date) ${ENV_NAME}  "Backup repository has a slate lock, removing" | tee -a $BACKUP_LOG_FILE;
        GOGC=20 RESTIC_PASSWORD=${ENV_NAME} restic -r /opt/backup/${ENV_NAME} unlock
	sendEmailNotification
    fi
    { GOGC=20 RESTIC_COMPRESSION=off RESTIC_PACK_SIZE=8 RESTIC_PASSWORD=${ENV_NAME} restic forget -q -r /opt/backup/${ENV_NAME} --keep-last ${BACKUP_COUNT} --prune | tee -a $BACKUP_LOG_FILE; } || { echo "Backup rotation failed."; exit 1; }
}

function create_snapshot(){
    DUMP_NAME=$(date "+%F_%H%M%S_%Z")
    echo $(date) ${ENV_NAME} "Begin uploading the ${DUMP_NAME} snapshot to backup storage" | tee -a ${BACKUP_LOG_FILE}  
    { GOGC=20 RESTIC_COMPRESSION=off RESTIC_PACK_SIZE=8 RESTIC_READ_CONCURRENCY=8 RESTIC_PASSWORD=${ENV_NAME} restic backup -q -r /opt/backup/${ENV_NAME} --tag "${DUMP_NAME} ${BACKUP_ADDON_COMMIT_ID} ${BACKUP_TYPE}" ${APP_PATH} ~/wp_db_backup.sql | tee -a $BACKUP_LOG_FILE; } || { echo "Backup snapshot creation failed."; exit 1; }
    echo $(date) ${ENV_NAME} "End uploading the ${DUMP_NAME} snapshot to backup storage" | tee -a ${BACKUP_LOG_FILE}
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
    mysqldump -h ${DB_HOST} -u ${DB_USER} ${MYSQLDUMP_DB_PORT_OPTION} -p${DB_PASSWORD} ${DB_NAME} --force --single-transaction --quote-names --opt --databases ${COL_STAT} > wp_db_backup.sql || { echo $(date) ${ENV_NAME} "DB backup process failed." | tee -a ${BACKUP_LOG_FILE}; exit 1; }
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
    update_restic)
	$1
        ;;
    *)
        echo "Usage: $0 {backup|check_backup_repo|rotate_snapshots|create_snapshot}"
        exit 2
esac

exit $?
