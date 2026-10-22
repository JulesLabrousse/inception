#!/bin/sh
set -eu
umask 022
case "$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')" in *admin*) echo 'Administrator name must not contain admin' >&2; exit 1;; esac
[ "$WP_ADMIN_USER" != "$WP_USER" ] || { echo 'Two distinct WP users required' >&2; exit 1; }
# credentials: exactly two lines, owner password then regular user password; never source it.
[ "$(wc -l < /run/secrets/credentials)" -eq 2 ] || exit 1
for line in 1 2; do
    value=$(sed -n "${line}p" /run/secrets/credentials)
    case "$value" in ''|*[!a-f0-9]*) echo 'Invalid credentials format' >&2; exit 1;; esac
    [ "${#value}" -ge 32 ] || exit 1
done
mkdir -p /run/php
if [ ! -f wp-includes/version.php ]; then cp -a /usr/src/wordpress/. .; fi
if [ ! -f wp-config.php ]; then
    # --prompt keeps the database password out of process arguments.
    umask 077
    wp config create --allow-root --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" \
        --dbhost=mariadb:3306 --skip-check --prompt=dbpass < /run/secrets/db_password
    wp config set FS_METHOD direct --allow-root
    wp config set DISALLOW_FILE_EDIT true --raw --allow-root
    umask 022
fi
ready=0
for attempt in $(seq 1 60); do
    if wp db query 'SELECT 1' --allow-root >/dev/null 2>&1; then ready=1; break; fi
    sleep 2
done
[ "$ready" -eq 1 ] || { echo 'Database unavailable: check persisted config and secrets' >&2; exit 1; }
if ! wp core is-installed --allow-root; then
    sed -n '1p' /run/secrets/credentials | wp core install --allow-root \
        --url="https://$DOMAIN_NAME" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" \
        --admin_email="$WP_ADMIN_EMAIL" --skip-email --prompt=admin_password
fi
if ! wp user get "$WP_USER" --allow-root >/dev/null 2>&1; then
    sed -n '2p' /run/secrets/credentials | wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --role=subscriber --allow-root --prompt=user_pass
fi
chown -R www-data:www-data /var/www/html
chmod 640 wp-config.php
exec "$@"
