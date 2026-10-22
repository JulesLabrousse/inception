FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends nginx openssl gettext-base curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default
RUN ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
COPY conf/inception.conf.template /etc/nginx/templates/inception.conf.template
COPY tools/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod 755 /usr/local/bin/entrypoint
EXPOSE 443
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["nginx", "-g", "daemon off;"]
