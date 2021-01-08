##
##    Docker image for Dodock applications.
##    Copyright (C) 2020  Monogramm
##
##    This program is free software: you can redistribute it and/or modify
##    it under the terms of the GNU Affero General Public License as published
##    by the Free Software Foundation, either version 3 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU Affero General Public License for more details.
##
##    You should have received a copy of the GNU Affero General Public License
##    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##
FROM madnight/alpine-wkhtmltopdf-builder:0.12.5-alpine3.10-745686742 AS wkhtmltopdf-builder

FROM python:3.7-alpine3.12

ARG VERSION=v1.4.9

ENV DODOCK_BRANCH=${VERSION} \
    NODE_VERSION=12.18.3 \
    WKHTMLTOX_VERSION=0.12.5 \
    DOCKERIZE_VERSION=0.6.1

COPY --from=wkhtmltopdf-builder /bin/wkhtmltopdf /bin/wkhtmltopdf

# Dodock base environment
RUN set -ex; \
    apk add --update \
        alpine-sdk \
        bash \
        sudo \
        gnupg \
        curl \
        busybox-suid \
        dbus \
        git \
        glib \
        linux-headers \
        libgcc \
        libintl \
        libstdc++ \
        libxslt \
        libxslt-dev \
        nodejs \
        nodejs-npm \
        cython \
        openntpd \
        py-setuptools \
        py-openssl \
        py-ldap3 \
        python3-dev \
        wget \
        zlib-dev \
        mariadb-client \
        mariadb-common \
        mariadb-dev \
        postgresql-client \
        postgresql-dev \
        postgresql-libs \
        jpeg-dev \
        lcms2-dev \
        libffi-dev \
        libwebp-dev \
        tiff-dev \
        freetype-dev \
        fontconfig \
        libx11 \
        libxext \
        libxrender \
        screen \
        ttf-freefont \
        ttf-dejavu \
        ttf-droid \
        ttf-liberation \
        ttf-ubuntu-font-family \
        xvfb \
    ; \
#pip install Cython==0.29.10; \ 0.29.19 provided by Alpine
#pip install numpy==1.17.4; \ but Collecting numpy>=1.13.3 after
#pip install pandas==0.24.2; \ but Collecting pandas==0.25.3 after
    wget "https://github.com/jwilder/dockerize/releases/download/v${DOCKERIZE_VERSION}/dockerize-linux-amd64-v${DOCKERIZE_VERSION}.tar.gz"; \
    tar -C /usr/local/bin -xzvf "dockerize-linux-amd64-v${DOCKERIZE_VERSION}.tar.gz"; \
    rm "dockerize-linux-amd64-v${DOCKERIZE_VERSION}.tar.gz"; \
    npm install -g --unsafe-perm yarn; \
    rm -rf /var/cache/apk/*; \
    addgroup -g 1000 dodock; \
    adduser -D -s /bin/bash -G dodock -u 1000 dodock; \
    echo "dodock ALL=(root) NOPASSWD: /bin/chown" > /etc/sudoers.d/dodock; \
    mkdir /tmp/.X11-unix; \
    chmod 777 /tmp/.X11-unix; \
    node --version; \
    npm --version; \
    yarn --version; \
    pip --version; \
    wkhtmltopdf --version

# Copy config scripts
COPY bin/install_app.sh /usr/local/bin/install_app
COPY bin/bench /usr/local/bin/bench

USER dodock
WORKDIR /home/dodock

ENV PATH=/home/dodock/.local/bin:$PATH

# Setup Bench and Dodock
RUN set -ex; \
    echo "export PATH=/home/dodock/.local/bin:\$PATH" >> .bashrc; \
    git clone https://gitlab.com/dokos/docli.git .bench; \
    pip install --user -e .bench; \
    npm install \
        express \
        socket.io \
        superagent \
        redis \
    ; \
    mkdir dodock-bench; \
    cd dodock-bench; \
    python -m venv env; \
    mkdir -p config apps logs sites/assets sites/error; \
    cp /home/dodock/.bench/bench/config/templates/502.html sites/error/; \
    touch logs/bench.log; \
    echo "frappe" > sites/apps.txt; \
    install_app frappe https://gitlab.com/dokos/dodock ${DODOCK_BRANCH}; \
    (cd apps/frappe && yarn && yarn run production && rm -rf node_modules); \
    (cd apps/frappe && yarn install --production=true && yarn add node-sass); \
    cp -R apps/frappe/frappe/public sites/assets/frappe; \
    cp -R apps/frappe/node_modules sites/assets/frappe/; \
    tar zcf sites-base.tgz sites; \
    rm -rf sites/* ~/.cache

# Copy dokos commands
COPY --chown=dodock:dodock commands /home/dodock/dodock-bench/commands/
COPY --chown=dodock:dodock socketio/* /home/dodock/dodock-bench/apps/frappe/
#ADD "https://gitlab.com/dokos/dodock/-/raw/$DODOCK_BRANCH/socketio.js" /home/dodock/dodock-bench/apps/frappe/socketio.js
#ADD "https://gitlab.com/dokos/dodock/-/raw/$DODOCK_BRANCH/node_utils.js" /home/dodock/dodock-bench/apps/frappe/node_utils.js

# Runtime environment variables
ENV DOCKER_DB_TIMEOUT=240 \
    DOCKER_DB_ALLOWED_HOSTS= \
    DOCKER_SITES_TIMEOUT=600 \
    DOCKER_APPS_TIMEOUT=720 \
    DOCKER_INIT_TIMEOUT=300 \
    DOCKER_DEBUG= \
    DOCKER_GUNICORN_BIND_ADDRESS=0.0.0.0 \
    DOCKER_GUNICORN_PORT=8000 \
    DOCKER_GUNICORN_WORKERS=4 \
    DOCKER_GUNICORN_TIMEOUT=240 \
    DOCKER_GUNICORN_LOGLEVEL=info \
    DODOCK_APP_INIT= \
    DODOCK_APP_RESET= \
    DODOCK_APP_PROTECTED=frappe \
    DODOCK_DEFAULT_PROTOCOL=http \
    DODOCK_DEFAULT_SITE= \
    DODOCK_HTTP_PORT=80 \
    DODOCK_WEBSERVER_PORT=80 \
    DODOCK_SOCKETIO_PORT=3000 \
    DODOCK_RESET_SITES= \
    DODOCK_REINSTALL_DATABASE= \
    DODOCK_BUILD_OPTIONS= \
    DODOCK_LOGGING=1 \
    GOOGLE_ANALYTICS_ID= \
    SERVER_SCRIPT_ENABLED=0 \
    ALLOW_TESTS=0 \
    DEVELOPER_MODE=0 \
    ADMIN_PASSWORD=admin \
    ENCRYPTION_KEY= \
    DB_TYPE=mariadb \
    DB_HOST=db \
    DB_PORT=3306 \
    DB_NAME=dodock \
    DB_PASSWORD=youshouldoverwritethis \
    DB_ROOT_USER=root \
    DB_ROOT_PASSWORD=mariadb_root_password \
    MAIL_MUTED=false \
    MAIL_HOST=mail \
    MAIL_PORT=587 \
    MAIL_USE_SSL=1 \
    MAIL_LOGIN=dodock-mail \
    MAIL_PASSWORD=youshouldoverwritethis \
    MAIL_EMAIL_ID= \
    MAIL_SENDER_NAME=Notifications \
    MAIL_ALWAYS_EMAIL_ID_AS_SENDER=0 \
    MAIL_ALWAYS_NAME_AS_SENDER_NAME=0 \
    REDIS_CACHE_HOST=redis_cache \
    REDIS_CACHE_PORT=6379 \
    REDIS_QUEUE_HOST=redis_queue \
    REDIS_QUEUE_PORT=6379 \
    REDIS_SOCKETIO_HOST=redis_socketio \
    REDIS_SOCKETIO_PORT=6379

VOLUME /home/dodock/.bench \
       /home/dodock/dodock-bench/logs \
       /home/dodock/dodock-bench/sites \
       /home/dodock/dodock-bench/apps/frappe/frappe/public

WORKDIR /home/dodock/dodock-bench

# Copy entrypoint
COPY ./entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["app"]

ARG TAG
ARG VCS_REF
ARG BUILD_DATE

EXPOSE 8000-8005 9000-9005 6787

LABEL maintainer="Monogramm Maintainers <opensource at monogramm dot io>" \
      product="Dokos Dodock" \
      version=$VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Monogramm/docker-dodock" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Dodock" \
      org.label-schema.description="Python + JS based metadata driven, full-stack web-application framework." \
      org.label-schema.url="https://dokos.io/" \
      org.label-schema.vendor="DOKOS SAS" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

# Docker built environment variables
ENV DOCKER_TAG=${TAG} \
    DOCKER_VCS_REF=${VCS_REF} \
    DOCKER_BUILD_DATE=${BUILD_DATE}
