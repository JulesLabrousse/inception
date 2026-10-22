#!/usr/bin/env bash
# Run on the dedicated Linux VM after make setup and DATA_PATH preparation.
set -euo pipefail
cd "$(dirname "$0")/.."
compose=("${DOCKER:-docker}" compose --env-file srcs/.env -f srcs/docker-compose.yml)
"${compose[@]}" config --quiet
"${compose[@]}" up -d --build --wait --wait-timeout 240
wp() { "${compose[@]}" exec -T wordpress wp --allow-root "$@"; }
domain=$("${compose[@]}" exec -T nginx printenv DOMAIN_NAME | tr -d '\r')
"${compose[@]}" exec -T nginx nginx -t
"${compose[@]}" exec -T wordpress php-fpm8.2 -tt
for item in 'mariadb:mariadbd' 'wordpress:php-fpm' 'nginx:nginx'; do
    service=${item%%:*}; process=${item#*:}
    actual=$("${compose[@]}" exec -T "$service" cat /proc/1/comm)
    [[ "$actual" == "$process"* ]] || { echo "Unexpected PID 1: $service $actual"; exit 1; }
done
[[ $("${compose[@]}" port nginx 443) == *:443 ]]
[[ -z $("${compose[@]}" port wordpress 9000 2>/dev/null || :) ]]
[[ -z $("${compose[@]}" port mariadb 3306 2>/dev/null || :) ]]
for protocol in --tlsv1.2 --tlsv1.3; do
    max=1.2; [[ "$protocol" == --tlsv1.3 ]] && max=1.3
    curl -fkSs --noproxy '*' --resolve "$domain:443:127.0.0.1" "$protocol" --tls-max "$max" "https://$domain/" >/dev/null
done
for version in 1.0 1.1; do
    if curl -fkSs --noproxy '*' --resolve "$domain:443:127.0.0.1" --tlsv1.0 --tls-max "$version" "https://$domain/" >/dev/null 2>&1; then
        echo "Forbidden TLS $version accepted"; exit 1
    fi
done
# A client that disables old TLS itself also rejects this probe; nginx -T is the config evidence.
"${compose[@]}" exec -T nginx nginx -T 2>&1 | grep -q 'ssl_protocols TLSv1.2 TLSv1.3;'
wp core is-installed
[[ $(wp user list --role=administrator --field=user_login | wc -l | tr -d ' ') == 1 ]]
[[ $(wp user list --role=subscriber --field=user_login | wc -l | tr -d ' ') == 1 ]]
"${compose[@]}" exec -T wordpress test ! -e /run/secrets/db_root_password
"${compose[@]}" exec -T nginx test ! -e /run/secrets/db_password
# Preserve an existing test option so the test can safely be repeated.
key=inception_persistence_probe
had=0; old=''
if old=$(wp option get "$key" 2>/dev/null); then had=1; fi
cleanup() {
    if [[ "$had" == 1 ]]; then wp option update "$key" "$old"; else wp option delete "$key"; fi
    "${compose[@]}" exec -T wordpress rm -f /var/www/html/wp-content/inception-test-upload.txt
}
trap cleanup EXIT
probe="probe-$(date +%s)"
wp option update "$key" "$probe"
"${compose[@]}" exec -T wordpress sh -c 'printf persistent > /var/www/html/wp-content/inception-test-upload.txt'
"${compose[@]}" down
"${compose[@]}" up -d --wait --wait-timeout 240
[[ $(wp option get "$key") == "$probe" ]]
[[ $("${compose[@]}" exec -T wordpress cat /var/www/html/wp-content/inception-test-upload.txt) == persistent ]]
curl -fkSs --noproxy '*' --resolve "$domain:443:127.0.0.1" "https://$domain/wp-login.php" >/dev/null
printf 'Integration checks passed (TLS, users, PID 1, ports, secrets, persistence).\n'
