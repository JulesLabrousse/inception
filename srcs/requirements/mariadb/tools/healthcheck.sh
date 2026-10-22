#!/bin/sh
set -eu
export MYSQL_PWD="$(cat /run/secrets/db_password)"
exec mariadb --protocol=tcp -h127.0.0.1 -u"$MYSQL_USER" "$MYSQL_DATABASE" --batch --skip-column-names -e 'SELECT 1'
