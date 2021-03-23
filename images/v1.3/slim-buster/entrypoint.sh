#!/bin/bash
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
set -e

# Container node type. Can be set by command argument or env var
WORKER_TYPE=${WORKER_TYPE:-${1}}

# working directory
DODOCK_WD="/home/dodock/dodock-bench"

# adapt environment to Dokos needs
export WORKERS=${WORKERS:-2}
export DODOCK_PORT=${DODOCK_PORT:-8000}
export SITE_NAME=${DODOCK_SITE:-"localhost"}
export ADMIN_PASSWORD=$DODOCK_ADMIN_PWD
export INSTALL_APPS=$DODOCK_APP_INIT
case "$DB_TYPE" in
  mariadb)
    export MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD
    ;;
  postgres)
    export POSTGRES_HOST=$DB_HOST
    export POSTGRES_USER=$DB_ROOT_USER
    export POSTGRES_PASSWORD=$DB_ROOT_PASSWORD
    ;;
esac

# -------------------------------------------------------------------
# bench management functions

reset_logs() {
  mkdir -p "${DODOCK_WD}/logs/";

  echo "[${WORKER_TYPE}] [$(date +%Y-%m-%dT%H:%M:%S%:z)] Reset docker entrypoint logs" \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
}

log() {
  echo "[${WORKER_TYPE}] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $*" \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
}

display_logs() {
  if [ -d "${DODOCK_WD}/logs/" ]; then
    tail -n 100 "${DODOCK_WD}"/logs/*.log
  else
    log "Logs directory does not exist!"
  fi
}

setup_logs_owner() {
  log "Setup logs folders and files owner to dodock..."
  sudo chown -R "dodock:dodock" \
    "${DODOCK_WD}/logs" \
  ;
}

setup_sites_owner() {
  # FIXME New bug with Debian where owners is not set properly??!
  log "Setup sites folders and files owner to dodock..."
  sudo chown -R "dodock:dodock" \
    "${DODOCK_WD}/sites" \
  ;
}

# TODO Function to escape double quotes for variables inserted in JSON


pip_install() {
  log "Install apps python packages..."

  cd "${DODOCK_WD}"
  ls apps/ | while read -r file; do
    # Install python packages of installed or protected frappe apps
    if grep -q "^${file}$" "${DODOCK_WD}/sites/apps.txt"; then
      log "Install requested app '$file' python packages..."
      pip_install_package "$file"
    elif echo "${DODOCK_APP_PROTECTED}" | grep -qE "(^| )${file}( |$)"; then
      log "Install protected app '$file' python packages..."
      pip_install_package "$file"
    fi
  done

  log "Apps python packages installed"
}

pip_install_package() {
  local package=$1

  if [ "$package" != "frappe" ] && [ -f "apps/$package/setup.py" ]; then
    pip install -q -e "apps/$package" --no-cache-dir \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
  fi;

  log "Apps python package '$package' installed"
}

wait_db() {
  log "Waiting for DB at ${DB_HOST}:${DB_PORT} to start up..."
  dockerize -wait \
    "tcp://${DB_HOST}:${DB_PORT}" \
    -timeout "${DOCKER_DB_TIMEOUT}s"
}

wait_apps() {
  log "Waiting for frappe apps to be set..."

  i=0
  s=10
  l=${DOCKER_APPS_TIMEOUT}
  while [ ! -f "${DODOCK_WD}/sites/apps.txt" ] && [ ! -f "${DODOCK_WD}/sites/.docker-app-init" ]; do
      log "Waiting apps..."
      sleep "$s"

      i="$((i+s))"
      if [ "$i" = "$l" ]; then
          log 'Apps were not set in time!'
          if [[ "${DOCKER_DEBUG}" = "1" ]]; then
            log 'Check the following logs for details:'
            display_logs
          fi
          exit 1
      fi
  done
  log "Apps were set at $(cat "${DODOCK_WD}/sites/.docker-app-init")"
}

wait_sites() {
  log "Waiting for frappe current site to be set..."

  i=0
  s=10
  l=${DOCKER_SITES_TIMEOUT}
  while [ ! -f "${DODOCK_WD}/sites/currentsite.txt" ] || [ ! -f "${DODOCK_WD}/sites/.docker-site-init" ]; do
      log "Waiting site..."
      sleep "$s"

      i="$((i+s))"
      if [ "$i" = "$l" ]; then
          log 'Site was not set in time!'
          if [[ "${DOCKER_DEBUG}" = "1" ]]; then
            log 'Check the following logs for details:'
            display_logs
          fi
          exit 1
      fi
  done
  log "Site was set at $(cat "${DODOCK_WD}/sites/.docker-site-init")"
}

wait_container() {
  log "Waiting for docker container init..."

  i=0
  s=10
  l=${DOCKER_INIT_TIMEOUT}
  while [ ! -f "${DODOCK_WD}/sites/.docker-init" ]; do
      log "Waiting init..."
      sleep "$s"

      i="$((i+s))"
      if [ "$i" = "$l" ]; then
          log 'Container was not initialized in time!'
          if [[ "${DOCKER_DEBUG}" = "1" ]]; then
            log 'Check the following logs for details:'
            display_logs
          fi
          exit 1
      fi
  done
  log "Container was set at $(cat "${DODOCK_WD}/sites/.docker-init")"
}

bench_doctor() {
  setup_logs_owner

  log "Checking diagnostic info..."

  if bench doctor; then

    log "Everything seems to be good with your Dodock environment and background workers."
    # bench Doctor might return successfully but display in logs scheduler is disabled/inactive:
    # -----Checking scheduler status-----
    # Scheduler disabled for localhost
    # Scheduler inactive for localhost
    # Workers online: 3
    # -----localhost Jobs-----

    # TODO Only enable if doctor says the scheduler is disabled/inactive
    log "Enabling schedulers for current site..."
    bench enable-scheduler \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"

  else

    log "Error(s) detected in your Dodock environment and background workers!!!"
    bench doctor \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"

    # Remove any module not found from bench installed apps
    for app in $(bench doctor 3>&1 1>&2 2>&3 | grep 'ModuleNotFoundError: ' | cut -d"'" -f 2); do
      if ! echo "${DODOCK_APP_PROTECTED}" | grep -qE "(^| )${app}( |$)"; then
        log "Removing '$app' from bench..."
        bench remove-from-installed-apps "$app" \
          | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
          | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
      else
        log "The application '$app' was not found but cannot be removed because it is protected!!"
      fi
    done

  fi
}

bench_build_apps() {
  log "Building apps assets..."
  bench build --restore ${DODOCK_BUILD_OPTIONS} \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
  log "Apps assets build Finished"
}

bench_setup_database() {
  log "Setup database..."

  if [ "${DB_TYPE}" = "mariadb" ] && [ -n "${DOCKER_DB_ALLOWED_HOSTS}" ]; then
    log "Updating MariaDB users allowed hosts..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" \
          -u "${DB_ROOT_USER}" "-p${DB_ROOT_PASSWORD}" \
          "${DB_NAME}" \
          -e "UPDATE mysql.user SET host = '${DOCKER_DB_ALLOWED_HOSTS}' WHERE host LIKE '%.%.%.%' AND user != 'root';"

    log "Updating MariaDB databases allowed hosts..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" \
          -u "${DB_ROOT_USER}" "-p${DB_ROOT_PASSWORD}" \
          "${DB_NAME}" \
          -e "UPDATE mysql.db SET host = '${DOCKER_DB_ALLOWED_HOSTS}' WHERE host LIKE '%.%.%.%' AND user != 'root';"

    log "Flushing MariaDB privileges..."
    mysql -h "${DB_HOST}" -P "${DB_PORT}" \
          -u "${DB_ROOT_USER}" "-p${DB_ROOT_PASSWORD}" \
          "${DB_NAME}" \
          -e "FLUSH PRIVILEGES;"
  fi

  log "Database setup Finished"
}

bench_install_apps() {
  IFS=',' read -ra APPS <<< "$@"
  for app in "${APPS[@]}"; do
    if ! grep -q "^${app}$" "${DODOCK_WD}/sites/apps.txt"; then
      log "Adding '$app' to apps.txt..."
      echo "$app" >> "${DODOCK_WD}/sites/apps.txt"

      pip_install_package "$app"

      log "Installing app '$app'..."
      bench install-app "$app" \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
    fi
  done
}

bench_setup() {
  # Expecting parameters to be a list of apps to (re)install
  if [ "$#" -ne 0 ] || [[ "${DODOCK_REINSTALL_DATABASE}" = "1" ]]; then
    wait_db

    log "Reinstalling with fresh database..."
    bench reinstall --yes \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
      | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"

    bench_install_apps "$@"
  else
    log "No app specified to reinstall"
  fi

  bench_build_apps
  bench_setup_database
}

bench_update() {
  setup_logs_owner
  log "Starting update..."
  bench update "$@" \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
  log "Update Finished"
}

list_backups() {
  if [ -z "${DODOCK_DEFAULT_SITE}" ]; then
    if [ -f "${DODOCK_WD}/sites/currentsite.txt" ]; then
      DODOCK_DEFAULT_SITE=$(cat "${DODOCK_WD}/sites/currentsite.txt")
    else
      log "Could not define the Dodock current site!"
      exit 1
    fi
  fi

  if [ -d "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups" ]; then
    log "Available backups for site ${DODOCK_DEFAULT_SITE}:"
    i=1
    for file in "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}"/private/backups/*
    do
      log "    $i. $file"
      i="$((i + 1))"
    done
  else
    log "No available backups."
  fi
}

bench_backup() {
  setup_logs_owner
  log "Starting backup..."
  bench backup "$@" \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
  log "Backup Finished."
  list_backups

  # Call bench doctor after backup
  bench_doctor
}

bench_restore() {
  setup_logs_owner

  if [ "$#" -eq 0 ]; then
    list_backups
    # Choose file name
    read -r -p "Enter the SQL file name which you want to restore: " file

    # Allow to set the private and public files archive as well
    read -r -p "Enter the public files archive name which you want to restore (or press enter for none): " public
    read -r -p "Enter the private files archive name which you want to restore (or press enter for none): " private
  else

    case ${1} in
      (*[!0-9]*|'') # Not a number: assume all args are file names
        file=$1
        public=$2
        private=$3
        ;;
      (*) # A number: assume all args are numbers
        i=1
        for f in "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}"/private/backups/*
        do
          if [ "$1" = "$i" ]; then
            file=$f
          elif [ "$2" = "$i" ]; then
            public=$f
          elif [ "$3" = "$i" ]; then
            private=$f
          fi
          i="$((i+1))"
        done
        ;;
    esac

  fi

  # Little helpers to allow to only set the name of the files instead of path
  if [ -f "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups/${file}" ]; then
    file="${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups/${file}"
  fi
  if [ -f "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups/${public}" ]; then
    public="${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups/${public}"
  fi
  if [ -f "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups/${private}" ]; then
    private="${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups/${private}"
  fi

  log "You have chosen to restore backup file '$file'"
  if [ -f "$file" ]; then
      RESTORE_ARGS=
      if [ -f "$public" ]; then
        log "Public files backup will also be restored: '$public'"
        RESTORE_ARGS="${RESTORE_ARGS} --with-public-files $public"
      elif [ -n "$public" ]; then
        log "Requested public files backup '$public' was not found!"
      fi
      if [ -f "$private" ]; then
        log "Private files backup will also be restored: '$private'"
        RESTORE_ARGS="${RESTORE_ARGS} --with-private-files $private"
      elif [ -n "$private" ]; then
        log "Requested private files backup '$private' was not found!"
      fi

      bench --force restore ${RESTORE_ARGS} "$file" \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"

    log "Backup successfully restored."
    # Call bench doctor after backup
    bench_doctor
  else
    log "Requested backup was not found!"
    exit 1
  fi
}

bench_setup_requirements() {
  setup_logs_owner
  log "Starting setup of requirements..."
  bench setup requirements "$@" \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
  log "Requirements setup Finished"
}

bench_migrate() {
  setup_logs_owner
  log "Starting migration..."
  bench migrate "$@" \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
  log "Migrate Finished"

  # Call bench doctor after migrate
  bench_doctor
}


# -------------------------------------------------------------------
# Dodock bench service functions

bench_cmd() {
  module=${DODOCK_WD}/commands/$1.py
  shift
  if [ -f "$module" ]; then
    . "${DODOCK_WD}/env/bin/activate"
    cd "${DODOCK_WD}/sites"
    python "$module" "$@"
  else
    return 255
  fi
}

bench_app() {
  bench_doctor

  log "Starting app on port ${DOCKER_GUNICORN_PORT}..."
  cd "${DODOCK_WD}/sites"

  GUNICORN_ARGS="-t ${DOCKER_GUNICORN_TIMEOUT} --workers ${DOCKER_GUNICORN_WORKERS} --bind ${DOCKER_GUNICORN_BIND_ADDRESS}:${DOCKER_GUNICORN_PORT} --log-level ${DOCKER_GUNICORN_LOGLEVEL}"

  if [ -n "${DOCKER_GUNICORN_CERTFILE}" ]; then
    GUNICORN_ARGS="${DOCKER_GUNICORN_ARGS} --certfile=${DOCKER_GUNICORN_CERTFILE}"
  fi

  if [ -n "${DOCKER_GUNICORN_KEYFILE}" ]; then
    GUNICORN_ARGS="${DOCKER_GUNICORN_ARGS} --keyfile=${DOCKER_GUNICORN_KEYFILE}"
  fi

  "${DODOCK_WD}/env/bin/gunicorn" \
    $GUNICORN_ARGS \
    frappe.app:application --preload \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.err.log"
}

bench_scheduler() {
  log "Starting scheduler..."
  bench schedule \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.err.log"
}

bench_worker() {
  log "Starting $1 worker..."
  bench worker --queue "$1" \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.err.log"
}

bench_socketio() {
  log "Starting socketio..."
  node "${DODOCK_WD}/apps/frappe/socketio.js" \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.err.log"
}

bench_socketio_doctor() {
  log "Checking socketio diagnostic info..."
  node "${DODOCK_WD}/apps/frappe/health.js" \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.log" 3>&1 1>&2 2>&3 \
    | tee "${DODOCK_WD}/logs/${WORKER_TYPE}.err.log"
}


# -------------------------------------------------------------------
# Runtime

reset_logs
setup_logs_owner

if [ -f "/before_${WORKER_TYPE}_init.sh" ]; then
  log "Executin custom script before '${WORKER_TYPE}' init..."
  "/before_${WORKER_TYPE}_init.sh"
fi

if [[ "${DODOCK_RESET_SITES}" = "1" ]]; then
  log "Removing all sites!"
  (cd "${DODOCK_WD}"
   rm -rf sites/*
   rm sites/.docker*)
fi

if [ ! -d "${DODOCK_WD}/sites/assets/frappe" ]; then
  log "Restoring apps assets to site from archive..."
  (cd "${DODOCK_WD}"
   tar zxf sites-base.tgz)
fi

# Dodock automatic app init
if [ -n "${DODOCK_APP_INIT}" ]; then

  setup_sites_owner

  # Remove anything from apps.txt which is not in requested through docker
  if [ -f "${DODOCK_WD}/sites/apps.txt" ]; then
    log "Checking bench apps to remove before init..."

    for app in $(cat ${DODOCK_WD}/sites/apps.txt); do
      if ! echo "${DODOCK_APP_PROTECTED}" | grep -qE "(^|,)${app}(,|$)" && ! echo "${DODOCK_APP_INIT}" | grep -qE "(^|,)${app}(,|$)"; then
        log "Removing '$app' from bench..."
        bench remove-from-installed-apps "$app" \
          | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
          | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
      fi
    done
  fi

  # Reset apps
  if [ ! -f "${DODOCK_WD}/sites/apps.txt" ] || [[ "${DODOCK_APP_RESET}" = "1" ]]; then
    log "Adding frappe to apps.txt..."
    touch "${DODOCK_WD}/sites/apps.txt"
    sudo chown "dodock:dodock" \
      "${DODOCK_WD}/sites/apps.txt" \
    ;
    echo "frappe" > "${DODOCK_WD}/sites/apps.txt"
  fi

else
  log 'Wait for another node to setup apps and sites...'
  wait_sites
  wait_apps
  wait_container
fi



# Dodock automatic site setup
if [ -z "${DODOCK_DEFAULT_SITE}" ]; then
  log 'Wait for another node to setup sites...'
  wait_sites

  log 'Always install pip packages...'
  pip_install
elif [ ! -f "${DODOCK_WD}/sites/.docker-site-init" ]; then
  log "Creating default directories for sites/${DODOCK_DEFAULT_SITE}..."
  mkdir -p \
    "${DODOCK_WD}/sites/assets" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/error-snapshots" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/locks" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/files" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/public/files" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/tasks-logs" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/task-logs" \
  ;
  sudo chown -R "dodock:dodock" \
    "${DODOCK_WD}/sites/assets" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/error-snapshots" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/locks" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/backups" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/private/files" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/public/files" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/tasks-logs" \
    "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/task-logs" \
  ;

  # Init common site config
  if [ ! -f "${DODOCK_WD}/sites/common_site_config.json" ]; then
    log "Creating common site config..."
    touch "${DODOCK_WD}/sites/common_site_config.json"
    sudo chown "dodock:dodock" \
      "${DODOCK_WD}/sites/common_site_config.json" \
    ;
    cat <<EOF > "${DODOCK_WD}/sites/common_site_config.json"
{
  "allow_tests": ${ALLOW_TESTS:-0},
  "server_script_enabled": ${SERVER_SCRIPT_ENABLED:-0},
  "deny_multiple_logins": false,
  "disable_website_cache": false,
  "dns_multitenant": false,
  "serve_default_site": true,
  "frappe_user": "dodock",
  "auto_update": false,
  "update_bench_on_update": true,
  "shallow_clone": true,
  "rebase_on_pull": false,
  "redis_cache": "redis://${REDIS_CACHE_HOST}:${REDIS_CACHE_PORT}",
  "redis_queue": "redis://${REDIS_QUEUE_HOST}:${REDIS_QUEUE_PORT}",
  "redis_socketio": "redis://${REDIS_SOCKETIO_HOST}:${REDIS_SOCKETIO_PORT}",
  "logging": "${DODOCK_LOGGING:-1}",
  "root_login": "${DB_ROOT_USER}",
  "root_password": "${DB_ROOT_PASSWORD}",
  "db_type": "${DB_TYPE}",
  "db_host": "${DB_HOST}",
  "db_port": ${DB_PORT},
  "db_name": "${DB_NAME}",
  "db_user": "${DB_NAME}",
  "db_password": "${DB_PASSWORD}",
  "host_name": "${DODOCK_DEFAULT_PROTOCOL:-http}://${DODOCK_DEFAULT_SITE}:${DODOCK_HTTP_PORT:-80}",
  "http_port": ${DODOCK_HTTP_PORT:-80},
  "webserver_port": ${DODOCK_WEBSERVER_PORT:-80},
  "socketio_port": ${DODOCK_SOCKETIO_PORT:-3000},
  "google_analytics_id": "${GOOGLE_ANALYTICS_ID}",
  "developer_mode": ${DEVELOPER_MODE:-0},
  "admin_password": "${ADMIN_PASSWORD:-admin}",
  "encryption_key": "${ENCRYPTION_KEY:-$(openssl rand -base64 32)}",
  "mail_server": "${MAIL_HOST}",
  "mail_port": ${MAIL_PORT},
  "use_ssl": "${MAIL_USE_SSL}",
  "mail_login": "${MAIL_LOGIN}",
  "mail_password": "${MAIL_PASSWORD}",
  "auto_email_id": "${MAIL_EMAIL_ID}",
  "email_sender_name": "${MAIL_SENDER_NAME}",
  "always_use_account_email_id_as_sender": ${MAIL_ALWAYS_EMAIL_ID_AS_SENDER:-0},
  "always_use_account_name_as_sender_name": ${MAIL_ALWAYS_NAME_AS_SENDER_NAME:-0},
  "mute_emails": ${MAIL_MUTED:-1}
}
EOF
  fi

  # Check default site config
  if [ ! -f "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/site_config.json" ]; then
    # TODO Not really clean to copy common config to site... better to create specific properties
    log "Creating ${DODOCK_DEFAULT_SITE} site config from common config..."
    cp \
      "${DODOCK_WD}/sites/common_site_config.json" \
      "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/site_config.json"
    sudo chown "dodock:dodock" \
      "${DODOCK_WD}/sites/${DODOCK_DEFAULT_SITE}/site_config.json" \
    ;
  fi

  # Init current site
  if [ ! -f "${DODOCK_WD}/sites/currentsite.txt" ]; then
    wait_db

    setup_sites_owner

    log "Creating new site at ${DODOCK_DEFAULT_SITE} with ${DB_TYPE} database..."
    if [ "${DB_TYPE}" = "mariadb" ]; then
      bench new-site "${DODOCK_DEFAULT_SITE}" \
        --force \
        --db-name "${DB_NAME}" \
        --admin-password "${ADMIN_PASSWORD}" \
        --mariadb-root-username "${DB_ROOT_USER}" \
        --mariadb-root-password "${DB_ROOT_PASSWORD}" \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
    else
      bench new-site "${DODOCK_DEFAULT_SITE}" \
        --force \
        --db-name "${DB_NAME}" \
        --admin-password "${ADMIN_PASSWORD}" \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
        | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"
    fi

    log "Setting ${DODOCK_DEFAULT_SITE} as current site..."
    touch "${DODOCK_WD}/sites/currentsite.txt"
    sudo chown "dodock:dodock" \
      "${DODOCK_WD}/sites/currentsite.txt" \
    ;
    echo "${DODOCK_DEFAULT_SITE}" > "${DODOCK_WD}/sites/currentsite.txt"
  fi

  log "Using site at ${DODOCK_DEFAULT_SITE}..."
  bench use "${DODOCK_DEFAULT_SITE}" \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.log" 3>&1 1>&2 2>&3 \
    | tee -a "${DODOCK_WD}/logs/${WORKER_TYPE}-docker.err.log"

  echo "[${WORKER_TYPE}] $(date +%Y-%m-%dT%H:%M:%S%:z)" > "${DODOCK_WD}/sites/.docker-site-init"
  log "Docker Dodock automatic site setup ended"
fi


if [ -n "${DODOCK_APP_INIT}" ]; then

  # Dodock automatic app setup
  if [ ! -f "${DODOCK_WD}/sites/.docker-app-init" ] || [[ "${DODOCK_REINSTALL_DATABASE}" = "1" ]]; then

    # Call bench setup for app
    log "Docker Dodock automatic app setup..."
    bench_setup "${DODOCK_APP_INIT}"

    echo "[${WORKER_TYPE}] $(date +%Y-%m-%dT%H:%M:%S%:z)" > "${DODOCK_WD}/sites/.docker-app-init"
    log "Docker Dodock automatic app setup ended"

  else

    # Add any missing app to init in apps.txt
    log "Docker Dodock automatic app update..."
    bench_install_apps "${DODOCK_APP_INIT}"

    echo "[${WORKER_TYPE}] $(date +%Y-%m-%dT%H:%M:%S%:z)" > "${DODOCK_WD}/sites/.docker-app-init"
    log "Docker Dodock automatic app update ended"

  fi

  # Dodock automatic app migration (based on container build properties)
  if [ -f "${DODOCK_WD}/sites/.docker-init" ] && ! grep -q "${DOCKER_TAG} ${DOCKER_VCS_REF} ${DOCKER_BUILD_DATE}" "${DODOCK_WD}/sites/.docker-init"; then
    bench_setup_requirements
    bench_build_apps
    bench_migrate
  fi
  echo "[${WORKER_TYPE}] ${DOCKER_TAG} ${DOCKER_VCS_REF} ${DOCKER_BUILD_DATE}" > "${DODOCK_WD}/sites/.docker-init"

fi

if [ -f "/after_${WORKER_TYPE}_init.sh" ]; then
  log "Executin custom script after '${WORKER_TYPE}' init..."
  "/after_${WORKER_TYPE}_init.sh"
fi


# Execute requested task
case "${1}" in
  # Management tasks
  doctor) bench_cmd doctor ;;
  setup) pip_install; shift; bench_setup "$@" ;;
  install-apps) bench_install_apps ;;
  build-apps) pip_install; bench_build_apps ;;
  update) shift; bench_update "$@" ;;
  #push-backup) bench_cmd push_backup ;;
  backup) bench_cmd backup ;;
  restore) bench_cmd restore_backup ;;
  migrate) bench_cmd migrate ;;
  # Service tasks
  start|app)
    log "Check Dodock app connection..."
    bench_cmd check_connection
    if [[ -n "$AUTO_MIGRATE" ]]; then
      log "Dodock auto-migrate..."
      bench_cmd auto_migrate
    fi
    log "Starting Gunicorn server..."
    gunicorn -b "0.0.0.0:$DODOCK_PORT" \
      --worker-tmp-dir /dev/shm \
      --threads=4 \
      --workers "$WORKERS" \
      --worker-class=gthread \
      --log-file=- \
      -t 120 frappe.app:application --preload
    ;;
  new)
    log "Check Dodock new database connection..."
    bench_cmd check_connection
    log "Dodock new database..."
    bench_cmd new "${@:2}"
    ;;
  drop)
    log "Check Dodock new database connection..."
    bench_cmd check_connection
    log "Dodock drop site..."
    bench_cmd drop "${@:2}"
    ;;
  worker*)
    log "Check Dodock worker connection..."
    bench_cmd check_connection
    log "Starting worker..."
    bench_cmd worker
    ;;
  schedule|scheduler)
    log "Check Dodock scheduler connection..."
    bench_cmd check_connection
    log "Starting background job scheduler..."
    bench_cmd background
    ;;
  node-socketio) bench_socketio ;;
  node-socketio-doctor) bench_socketio_doctor ;;
  console)
    if [[ -z "$2" ]]; then
      echo "Need to specify a sitename with the command:"
      echo "console <sitename>"
      exit 1
    fi
    bench_cmd console "$2"
    ;;
  *) exec "$@" ;;
esac
