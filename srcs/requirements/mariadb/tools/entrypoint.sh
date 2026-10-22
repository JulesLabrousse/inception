#!/bin/sh
set -eu
# Identifier validation and hex-only generated secrets avoid SQL injection.
case "${MYSQL_DATABASE:-}" in ''|*[!a-zA-Z0-9_]*) echo 'Invalid database name' >&2; exit 1;; esac
case "${MYSQL_USER:-}" in ''|root|mysql|*[!a-zA-Z0-9_]*) echo 'Invalid database user' >&2; exit 1;; esac
for secret in db_password db_root_password; do
    value=$(cat "/run/secrets/$secret")
    case "$value" in ''|*[!a-f0-9]*) echo 'Secrets must be hex strings' >&2; exit 1;; esac
    [ "${#value}" -ge 32 ] || exit 1
done
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
if [ ! -f /var/lib/mysql/.inception-ready ]; then
    # Do not accept an interrupted or foreign datadir as a completed installation.
    if [ -d /var/lib/mysql/mysql ]; then
        echo 'Incomplete/foreign datadir: restore a backup or explicitly reset it.' >&2
        exit 1
    fi
    chown -R mysql:mysql /var/lib/mysql
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal --skip-test-db > /dev/null
    mariadbd --user=mysql --skip-networking --socket=/run/mysqld/init.sock &
    pid=$!
    trap 'kill -TERM "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :' EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT
    ready=0
    for attempt in $(seq 1 60); do
        if mariadb-admin --socket=/run/mysqld/init.sock ping --silent >/dev/null 2>&1; then ready=1; break; fi
        kill -0 "$pid" 2>/dev/null || exit 1
        sleep 1
    done
    [ "$ready" -eq 1 ] || { echo 'MariaDB init timed out' >&2; exit 1; }
    db_password=$(cat /run/secrets/db_password)
    root_password=$(cat /run/secrets/db_root_password)
    mariadb --socket=/run/mysqld/init.sock -uroot <<SQL
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.global_priv WHERE User = '' OR (User = 'root' AND Host <> 'localhost');
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_password';
FLUSH PRIVILEGES;
SQL
    kill -TERM "$pid"
    wait "$pid"
    trap - EXIT INT TERM
    touch /var/lib/mysql/.inception-ready
fi
exec "$@"
