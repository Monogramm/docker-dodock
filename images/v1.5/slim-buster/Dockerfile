##
##    Docker image for Dodock applications.
##    Copyright (C) 2021 Monogramm
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
FROM python:3.7-slim-buster

ARG VERSION=v1.5.3

ENV DODOCK_BRANCH=${VERSION} \
    NODE_VERSION=12.20.0 \
    WKHTMLTOX_VERSION=0.12.6-1 \
    DOCKERIZE_VERSION=0.6.1

ENV DEBIAN_FRONTEND="noninteractive"

# Dodock base environment
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        gnupg2 \
        locales \
        curl; \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    dpkg-reconfigure --frontend=noninteractive locales; \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list; \
    curl -sL "https://dl.yarnpkg.com/debian/pubkey.gpg" | apt-key add -; \
    curl -sL "https://deb.nodesource.com/setup_${NODE_VERSION%%.*}.x" | bash -; \
    apt-get install -y --no-install-recommends \
        cron \
        sudo \
        wget \
        nodejs \
        yarn \
        git \
        ntp \
        build-essential \
        mariadb-client \
        postgresql-client \
        redis-tools \
        libffi-dev \
        liblcms2-dev \
        libldap2-dev \
        libmariadbclient-dev \
        libpq-dev \
        libsasl2-dev \
        libssl-dev  \
        libxslt1-dev \
        libcrypto++-dev \
        python-dev \
        python-mysqldb \
        python-openssl \
        python-ldap3 \
        python-psycopg2 \
        python-pip \
        python-setuptools \
        libtiff5-dev \
        libjpeg62-turbo-dev \
        liblcms2-dev \
        libwebp-dev \
        tcl8.6-dev \
        tk8.6-dev \
        python-tk \
        zlib1g-dev \
        libfreetype6-dev \
        fontconfig \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        fonts-cantarell \
        xfonts-75dpi \
        xfonts-base \
    ; \
    if [ `uname -m` = 'aarch64' ]; then export ARCH=arm64; fi; \
    if [ `uname -m` = 'x86_64' ]; then export ARCH=amd64; fi; \
    wget "https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOX_VERSION}/wkhtmltox_${WKHTMLTOX_VERSION}.buster_${ARCH}.deb"; \
    dpkg -i "wkhtmltox_${WKHTMLTOX_VERSION}.buster_${ARCH}.deb"; \
    rm "wkhtmltox_${WKHTMLTOX_VERSION}.buster_${ARCH}.deb"; \
    if [ `uname -m` = 'aarch64' ]; then export ARCH=armhf; fi; \
    wget "https://github.com/jwilder/dockerize/releases/download/v${DOCKERIZE_VERSION}/dockerize-linux-${ARCH}-v${DOCKERIZE_VERSION}.tar.gz"; \
    tar -C /usr/local/bin -xzvf "dockerize-linux-${ARCH}-v${DOCKERIZE_VERSION}.tar.gz"; \
    rm "dockerize-linux-${ARCH}-v${DOCKERIZE_VERSION}.tar.gz"; \
    apt-get autoremove --purge -f -y; \
    apt-get clean; \
    groupadd -g 1000 dodock; \
    useradd --no-log-init -r -m -s /bin/bash -u 1000 -g 1000 dodock; \
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
COPY bin/healthcheck.sh /usr/local/bin/healthcheck
COPY bin/bench /usr/local/bin/bench

USER dodock
WORKDIR /home/dodock

ENV PATH=/home/dodock/.local/bin:$PATH

# Setup Bench and Dodock
RUN set -ex; \
    echo "export PATH=/home/dodock/.local/bin:\$PATH" >> .bashrc; \
    git clone 'https://gitlab.com/dokos/docli.git' .bench; \
    sed -i -e 's/urllib3==.*/urllib3/' .bench/requirements.txt; \
    pip install --user urllib3==1.25.11; \
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
    mkdir -p config apps logs sites/assets/css sites/assets/frappe sites/error; \
    cp /home/dodock/.bench/bench/config/templates/502.html sites/error/; \
    install_app frappe 'https://gitlab.com/dokos/dodock' "${DODOCK_BRANCH}"; \
    cp -R apps/frappe/frappe/public/* sites/assets/frappe/; \
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
