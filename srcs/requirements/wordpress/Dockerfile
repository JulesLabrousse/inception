FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-cli php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring \
    php8.2-xml php8.2-zip curl ca-certificates mariadb-client libfcgi-bin \
    && sed -i 's|^error_log =.*|error_log = /proc/self/fd/2|' /etc/php/8.2/fpm/php-fpm.conf \
    && rm -rf /var/lib/apt/lists/*
ARG WP_VERSION=7.1.3
ARG WP_CLI_VERSION=2.12.0
RUN curl -fsSL "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" -o /usr/local/bin/wp \
    && chmod 755 /usr/local/bin/wp \
    && mkdir -p /usr/src/wordpress \
    && wp core download --allow-root --version="${WP_VERSION}" --path=/usr/src/wordpress \
    && wp core verify-checksums --allow-root --version="${WP_VERSION}" --path=/usr/src/wordpress
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY conf/uploads.ini /etc/php/8.2/fpm/conf.d/99-inception.ini
COPY tools/entrypoint.sh /usr/local/bin/entrypoint
COPY tools/healthcheck.sh /usr/local/bin/wp-healthcheck
RUN chmod 755 /usr/local/bin/entrypoint /usr/local/bin/wp-healthcheck
WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["php-fpm8.2", "-F"]
