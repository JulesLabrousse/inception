FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends mariadb-server mariadb-client \
    && rm -rf /var/lib/apt/lists/* /var/lib/mysql/*
COPY conf/inception.cnf /etc/mysql/mariadb.conf.d/60-inception.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint
COPY tools/healthcheck.sh /usr/local/bin/db-healthcheck
RUN chmod 755 /usr/local/bin/entrypoint /usr/local/bin/db-healthcheck
EXPOSE 3306
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["mariadbd", "--user=mysql", "--console"]
