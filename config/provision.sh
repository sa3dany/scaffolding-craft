#!/bin/bash
set -o errexit -o noclobber -o nounset -o pipefail
# set -0 xtrace # uncomment to debug
export DEBIAN_FRONTEND="noninteractive"
function usage() {
  cat <<"EOF"
Required environment variables:
  CONFIG_PATH          Provisioning script config path
  CRAFT_HOSTNAME       hostname of the website
  CRAFT_PATH           Craft CMS base path

Optional environment variables:
  CRAFT_ENV=local      Craft CMS environment: local, staging or production
  CRAFT_DROP_DB=false  Set to 'true' to drop the Craft CMS database
  CRAFT_RESTORE_DB     Restore db from backup. File path
  PHP_VERSION=7.4      PHP version to install
EOF
}

# Validate CONFIG_PATH, then load utils.sh =============================
CONFIG_PATH="${CONFIG_PATH:-$(dirname "$0")}"
[ ! -f "$CONFIG_PATH/utils.sh" ] && usage && exit 1
source "$CONFIG_PATH/utils.sh"

# Validate remaining environment variables =============================
CRAFT_ENV="${CRAFT_ENV:-local}"
CRAFT_DROP_DB="${CRAFT_DROP_DB:-false}"
CRAFT_RESTORE_DB="${CRAFT_RESTORE_DB:-}"
CRAFT_HOSTNAME="${CRAFT_HOSTNAME:-}"
CRAFT_PATH="${CRAFT_PATH:-}"
PHP_VERSION="${PHP_VERSION:-7.4}"

if [ -z "$CRAFT_PATH" ] || [ -z "$CRAFT_HOSTNAME" ]; then
  usage && exit 1
fi

if [ -z $(hostname_get_domain "$CRAFT_HOSTNAME") ]; then
  log_error "$CRAFT_HOSTNAME is not a valid domain name"
  exit 1
fi

if [ "$CRAFT_ENV" != "local" ] &&
  [ "$CRAFT_ENV" != "staging" ] &&
  [ "$CRAFT_ENV" != "production" ]; then
  usage && exit 1
fi

if [ "$CRAFT_DROP_DB" = true ] &&
  [ "$CRAFT_ENV" = "production" ]; then
  log_error "CRAFT_DROP_DB=true is not allowed on production"
  exit 1
fi

if [ ! -z "$CRAFT_RESTORE_DB" ] && [ "$CRAFT_DROP_DB" = true ]; then
  log_error "CRAFT_RESTORE_DB & CRAFT_DROP_DB are mutually exclusive"
  exit 1
fi

if [ ! -z "$CRAFT_RESTORE_DB" ]; then
  if [ ! -f "$CRAFT_RESTORE_DB" ]; then
    log_error "CRAFT_RESTORE_DB is not a file: $CRAFT_RESTORE_DB"
    exit 1
  fi
  if [[ $CRAFT_RESTORE_DB != *.sql ]]; then
    log_error "CRAFT_RESTORE_DB is not an SQL file: $CRAFT_RESTORE_DB"
    exit 1
  fi
fi

# General system setup =================================================
timedatectl set-timezone Asia/Riyadh
makeswap_auto # (1/4 of total memory)
log "Installing [curl, wget, unzip]"
apt_get curl wget unzip

# Update PHP config ====================================================
log "Configuring PHP $PHP_VERSION"
php_get $PHP_VERSION
php_mod_add $PHP_VERSION craftcms "$CONFIG_PATH/php/php.ini"
php_mod_enable $PHP_VERSION craftcms

# Email setup ==========================================================
# Make sure to setup SMTP relay in G Suite with the website's static IP
# SEE: https://support.google.com/a/answer/176600?hl=en
if [ "$CRAFT_ENV" != "local" ]; then
  log "POSTFIX setup through G Suite relay"
  postfix_get
  postfix_relay_to_gsuite "$(hostname_get_domain "$CRAFT_HOSTNAME")"
fi

# Units of work ========================================================
is_installed() {
  if "$CRAFT_PATH/craft" install/check >/dev/null 2>&1; then
    return true
  else
    return false
  fi
}

# Unused
remove_existing_dotenv() {
  if [ -f "$CRAFT_PATH/.env" ]; then
    log "Removing existing .env file"
    rm "$CRAFT_PATH/.env"
  fi
}

download_craft() {
  log "Downloading Craft CMS [Composer]"
  local vendorPath="/usr/local/lib/craft"
  [ ! -d "$vendorPath" ] && mkdir "$vendorPath"
  set_permissions www-data:www-data 774 "$vendorPath"
  composer_get
  sudo --user=www-data \
    composer --working-dir="$CRAFT_PATH" --no-cache --quiet install
}

restore_db() {
  sudo --user=www-data \
    "$CRAFT_PATH/craft" restore/db "$1" --interactive=0 \
    >/dev/null
}

generate_app_id() {
  # https://github.com/craftcms/cms/blob/
  #   23610e02030e21de0183399bf4e8df052295831c/
  #     src/console/controllers/SetupController.php#L173
  # Also: `craft setup/app-id --interactive=0`
  # Which saves the output in the `.env` file
  random_password 32
}

generate_security_key() {
  # https://github.com/craftcms/cms/blob/
  #   23610e02030e21de0183399bf4e8df052295831c/
  #     src/console/controllers/SetupController.php#L189
  # Also: `craft setup/security-key --interactive=0`
  # Which saves the output in the `.env` file
  random_uuid "CraftCMS"
}

save_setup_keys() {
  log "Saving APP_ID & SECURITY_KEY"
  local appId="$1"
  local securityKey="$2"
  local setupFile="$CONFIG_PATH/cms/setup"
  touch "$setupFile" && echo -n >|"$setupFile"
  echo "APP_ID=$appId" >>"$setupFile"
  echo "SECURITY_KEY=$securityKey" >>"$setupFile"
}

generate_dotenv() {
  log 'Generating .env file'
  if [ "$CRAFT_ENV" = "local" ]; then
    export SITE_URL="http://$CRAFT_HOSTNAME"
  else
    export SITE_URL="https://$CRAFT_HOSTNAME"
  fi
  export ASSETS_URL="$SITE_URL"
  local envList='$APP_ID:$ASSETS_URL:$SECURITY_KEY:$SITE_URL'
  env_from_file "$CONFIG_PATH/cms/setup"
  envsubst $envList \
    <"$CONFIG_PATH/cms/.env.$CRAFT_ENV" >|"$CRAFT_PATH/.env"
  export -n APP_ID ASSETS_URL SECURITY_KEY SITE_URL
}

set_the_file_permissions() {
  log "Setting file permissions"
  local owner=www-data:www-data
  local mode=774
  local path="$CRAFT_PATH"
  set_permissions $owner $mode "$path/.env"
  set_permissions $owner $mode "$path/composer".*
  set_permissions $owner $mode "$path/config/license.key"
  set_permissions $owner $mode "$path/config/project"
  set_permissions $owner $mode "$path/storage"
  set_permissions $owner $mode "$path/vendor"
  set_permissions $owner $mode "$path/web/cpresources"
}

create_a_database() {
  log "Creating database"
  mysql_get
  mysql_db_create "cms"
  mysql_user_add "cms_user" "cms_password"
  mysql_user_grant "cms_user" "cms"
}

setup_the_web_server() {
  log "Configuring NGINX"
  export PHP_VERSION CRAFT_HOSTNAME CRAFT_PATH
  local config="$(mktemp)"
  local certEmail="msaadany@iceweb.co"
  local partialsPath="/etc/nginx/nginx-partials"
  local envList='$PHP_VERSION:$CRAFT_HOSTNAME:$CRAFT_PATH'
  nginx_get
  [ ! -d "$partialsPath" ] && mkdir "$partialsPath"
  cp "$CONFIG_PATH/nginx/partials"/* "$partialsPath"
  if [ "$CRAFT_ENV" = "local" ]; then
    envsubst $envList <"$CONFIG_PATH/nginx/local.conf" >|"$config"
  else
    envsubst $envList <"$CONFIG_PATH/nginx/production.conf" >|"$config"
  fi
  nginx_config_add "$CRAFT_HOSTNAME" "$config"
  nginx_config_disable_default
  nginx_config_enable "$CRAFT_HOSTNAME"
  if [ "$CRAFT_ENV" != "local" ]; then
    certbot_apply nginx $CRAFT_HOSTNAME $certEmail
  fi
  rm "$config"
  export -n PHP_VERSION CRAFT_HOSTNAME CRAFT_PATH
}

run_the_setup() {
  log "Installing Craft CMS"
  local password="$(password_gen)"
  local email="msaadany@iceweb.co"
  sudo --user=www-data \
    "$CRAFT_PATH/craft" install --interactive=0 \
    --email=$email --password="$password" \
    >/dev/null
  printf "  %-10s %-30s\n" Email: $email
  printf "  %-10s %-30s\n" Password: $password
}

clear_all_caches() {
  log 'Clearing Craft CMS caches'
  sudo --user=www-data \
    "$CRAFT_PATH/craft" clear-caches/all \
    >/dev/null 2>&1
}

project_config_apply() {
  log 'Applying Craft CMS project config'
  sudo --user=www-data \
    "$CRAFT_PATH/craft" project-config/apply \
    >/dev/null
}

mailer_test() {
  [ "$CRAFT_ENV" = "local" ] && return 0
  log 'Testing mail sending from Craft CMS'
  local to="msaadany@iceweb.co"
  sudo --user=www-data \
    "$CRAFT_PATH/craft" mailer/test --interactive=0 --to $to \
    >/dev/null
}

# Craft CMS Setup ======================================================
download_craft

if [ "$CRAFT_DROP_DB" = true ]; then
  log "Dropping existing database (if any)"
  mysql_db_drop "cms"
fi

if [ ! is_installed ]; then
  if [ "$CRAFT_ENV" != "local" ] && [ -z "$CRAFT_RESTORE_DB" ]; then
    log_error "First non-local provision requires CRAFT_RESTORE_DB to be set"
    exit 2
  fi
fi

if [ ! -z "$CRAFT_RESTORE_DB" ]; then
  log "Restoring database from backup"
  restore_db "$CRAFT_RESTORE_DB"
fi

if [ ! is_installed ]; then
  appId=$(generate_app_id)
  securityKey=$(generate_security_key)
  save_setup_keys $appId $securityKey
  generate_dotenv
  set_the_file_permissions
  create_a_database
  setup_the_web_server
  run_the_setup
  mailer_test
else
  generate_dotenv
  set_the_file_permissions
  setup_the_web_server
  project_config_apply
  clear_all_caches
  mailer_test
fi
