#!/bin/bash

if [ -e /var/www/webroot/ROOT/wp-config.php ]; then
    echo "$(date) trying to install the backup add-on" >> /var/log/backup_addon.log
    if [ -e /home/jelastic/bin/wp ]; then
        /home/jelastic/bin/wp --info >> /var/log/backup_addon.log
    fi
else
    echo "$(date) The application deployed to WEBROOT cannot be backuped by Jelastic backup add-on" >> /var/log/backup_addon.log
    echo "Non-supported"
fi
