DB_USER=$1
DB_PASSWORD=$2
DB_HOST=$3
ADMIN_PASSWORD=$(pwgen 10 1)
MYSQL=$(which mysql)
JEM=$(which jem)
cmd="CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION; GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
unset resp;
resp=$($MYSQL -u${DB_USER} -p${DB_PASSWORD} -h ${DB_HOST} --execute="SHOW DATABASES;")
[ -z "$resp" ] && {
    echo "Creating the DB user for application"
    $JEM passwd set -p ${ADMIN_PASSWORD}
    $MYSQL -uroot -p${ADMIN_PASSWORD} -h ${DB_HOST} --execute="$cmd"
} || {
    echo "[Info] User ${DB_USER} already exists."
}
