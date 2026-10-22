#!/bin/sh
set -eu
case "${DOMAIN_NAME:-}" in ''|*[!a-zA-Z0-9.-]*) echo 'Invalid DOMAIN_NAME' >&2; exit 1;; esac
mkdir -p /etc/nginx/templates /etc/nginx/tls
umask 077
if [ ! -s /etc/nginx/tls/key.pem ] || ! openssl x509 -in /etc/nginx/tls/cert.pem -noout -checkend 86400 >/dev/null 2>&1; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -keyout /etc/nginx/tls/key.pem -out /etc/nginx/tls/cert.pem \
        -subj "/CN=$DOMAIN_NAME" -addext "subjectAltName=DNS:$DOMAIN_NAME"
fi
envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/inception.conf.template > /etc/nginx/conf.d/inception.conf
nginx -t
exec "$@"
