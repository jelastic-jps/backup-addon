DB_USER=$1
DB_PASSWORD=$2
DB_HOST=$3
DB_PORT=$4
DB_SOCKET=$5
ADMIN_PASSWORD=$(pwgen 10 1)
MYSQL=$(which mysql)
JEM=$(which jem)
WP_DB_CLIENT_ARGS=()
[ -n "$DB_SOCKET" ] && WP_DB_CLIENT_ARGS+=(-S "$DB_SOCKET")
[ -n "$DB_HOST" ] && WP_DB_CLIENT_ARGS+=(-h "$DB_HOST")
[ -n "$DB_PORT" ] && WP_DB_CLIENT_ARGS+=(-P "$DB_PORT")
cmd="CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION; GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
unset resp;
resp=$($MYSQL -u${DB_USER} -p${DB_PASSWORD} "${WP_DB_CLIENT_ARGS[@]}" --execute="SHOW DATABASES;")
[ -z "$resp" ] && {
    echo "Creating the DB user for application"
    $JEM passwd set -p ${ADMIN_PASSWORD}
    $MYSQL -uroot -p${ADMIN_PASSWORD} "${WP_DB_CLIENT_ARGS[@]}" --execute="$cmd"
} || {
    echo "[Info] User ${DB_USER} already exists."
}
