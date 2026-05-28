# nginx-unprivileged: nginx master + workers all run as a non-root user (uid 101),
# limiting blast radius if a future nginx CVE allows code exec. Listens on 8080
# inside the container (not 80).
FROM nginxinc/nginx-unprivileged:alpine

USER root

COPY index.html /usr/share/nginx/html/index.html
COPY default.conf.tmpl /etc/nginx/conf.d/default.conf.tmpl
COPY docker-entrypoint.d/10-vikunja-config.sh /docker-entrypoint.d/10-vikunja-config.sh

# Make the entrypoint executable and let uid 101 write the rendered config files
# at container start (config.js + default.conf).
RUN chmod +x /docker-entrypoint.d/10-vikunja-config.sh \
 && chown -R 101:0 /usr/share/nginx/html /etc/nginx/conf.d \
 && chmod -R g+w /usr/share/nginx/html /etc/nginx/conf.d

USER 101

EXPOSE 8080
