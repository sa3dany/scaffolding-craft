#!/bin/bash
set -o errexit -o noclobber -o nounset -o pipefail
export DEBIAN_FRONTEND="noninteractive"

# Variables ############################################################
PROVISION_CONFIG_PATH="$(dirname "$0")"
PROVISION_CRAFT_PATH=
PROVISION_DROP_DB=false
PROVISION_EMAIL_HOSTNAME=
PROVISION_ENV=
PROVISION_HOSTNAME=localhost
PROVISION_PHP_VER=7.4

# Parse args ###########################################################
# SEE: https://stackoverflow.com/a/29754866/13037463
OPTIONS="config-path:,craft-path:,drop,php:,email-hostname:,hostname:,staging"

! PARSED=$(getopt --name="$0" --options="" --longoptions=$OPTIONS -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then exit 2; fi

eval set -- "$PARSED"
while true; do
  case "$1" in
  --config-path)
    if [ ! -f "$2/utils.sh" ]; then
      echo "$1 is invalid"
      exit 3
    fi
    PROVISION_CONFIG_PATH="$2"
    shift 2
    ;;
  --craft-path)
    PROVISION_CRAFT_PATH="$2"
    shift 2
    ;;
  --email-hostname)
    PROVISION_EMAIL_HOSTNAME="$2"
    shift 2
    ;;
  --hostname)
    PROVISION_HOSTNAME="$2"
    shift 2
    ;;
  --drop)
    PROVISION_DROP_DB=true
    shift
    ;;
  --php)
    PROVISION_PHP_VER="$2"
    shift 2
    ;;
  --staging)
    if [ ! -z "$PROVISION_ENV" ]; then
      echo "only one env modifier is allowed at a time"
      exit 3
    fi
    PROVISION_ENV=staging
    shift
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Invalid args"
    exit 3
    ;;
  esac
done

# Change PWD & load utils ##############################################
cd "$PROVISION_CONFIG_PATH"
source "utils.sh"

# General system setup #################################################
# Set timezone
timedatectl set-timezone Asia/Riyadh
# Add some swap (1/4 of total memory)
makeswap_auto
# Common dependencies
log 1 "Installing curl, wget & unzip"
apt_get "curl" "wget" "unzip"

# Update PHP config ####################################################
log 1 "Updating php configuration..."
php_get $PROVISION_PHP_VER
php_mod_add $PROVISION_PHP_VER "cms" "php/php.ini"
php_mod_enable $PROVISION_PHP_VER "cms"

# Email setup ##########################################################
# Make sure to setup SMTP relay in G Suite with the website's static IP
# SEE: https://support.google.com/a/answer/176600?hl=en
if [ "$PROVISION_ENV" = "staging" ] ||
  [ "$PROVISION_ENV" = "production" ]; then
  log 1 "POSTFIX setup through G Suite relay"
  if [ -z "$PROVISION_EMAIL_HOSTNAME" ]; then
    echo "--email-hostname is required in non-local env"
    exit 2
  fi
  postfix_get && postfix_relay_to_gsuite "$PROVISION_EMAIL_HOSTNAME"
fi

# Main Tasks ###########################################################
download_craft() {
  if [ ! -d "/usr/local/lib/craft" ]; then
    mkdir --mode 774 --parents "/usr/local/lib/craft"
  fi
  set_permissions www-data:www-data 774 "/usr/local/lib/craft"
  log 1 "Performing composer install"
  composer_get
  cd "$PROVISION_CRAFT_PATH"
  sudo --user=www-data \
    composer --no-cache --quiet install --no-dev
  cd - >/dev/null
}

set_the_file_permissions() {
  local owner=www-data:www-data
  local mode=774
  local path="$PROVISION_CRAFT_PATH"
  set_permissions $owner $mode "$path/.env"
  set_permissions $owner $mode "$path/composer".*
  set_permissions $owner $mode "$path/config/license.key"
  set_permissions $owner $mode "$path/config/project/"*
  set_permissions $owner $mode "$path/storage/"*
  set_permissions $owner $mode "$path/vendor"
  set_permissions $owner $mode "$path/web/cpresources/"*
}

create_a_database() {
  log 1 "MySQL setup"
  mysql_get
  if [ "$PROVISION_DROP_DB" = true ]; then
    echo "Dropping existing database (if any)..."
    mysql_db_drop "cms"
  fi
  mysql_db_create "cms"
  mysql_user_add "cms_user" "cms_password"
  mysql_user_grant "cms_user" "cms"
}

setup_the_web_server() {
  log 1 "Configuring NGINX"

  nginx_get

  if [ ! -d /etc/nginx/nginx-partials ]; then
    mkdir /etc/nginx/nginx-partials
  fi
  cp nginx/partials/* /etc/nginx/nginx-partials

  export PROVISION_PHP_VER PROVISION_HOSTNAME PROVISION_CRAFT_PATH
  CONFIG="$(mktemp)"

  if [ "$PROVISION_ENV" = staging ]; then
    envsubst '$PROVISION_PHP_VER:$PROVISION_HOSTNAME:$PROVISION_CRAFT_PATH' \
      <nginx/live.conf >|"$CONFIG"
  else
    envsubst '$PROVISION_PHP_VER:$PROVISION_CRAFT_PATH' \
      <nginx/local.conf >|"$CONFIG"
  fi

  nginx_config_add "$PROVISION_HOSTNAME" "$CONFIG"
  rm "$CONFIG" && unset CONFIG
  export -n PROVISION_PHP_VER PROVISION_HOSTNAME PROVISION_CRAFT_PATH

  nginx_config_disable_default
  nginx_config_enable "$PROVISION_HOSTNAME"

  if [ "$PROVISION_ENV" = staging ]; then
    certbot_apply nginx "$PROVISION_HOSTNAME" "msaadany@iceweb.co"
  fi
}

run_the_setup() {
  log 1 "Installing Craft CMS"
  local password="$(password_gen)"
  cd "$PROVISION_CRAFT_PATH"
  sudo --user=www-data \
    ./craft install \
    --interactive=0 \
    --email="msaadany@iceweb.co" \
    --password="$password" \
    >/dev/null
  cd - >/dev/null
  echo "Craft login details:"
  echo "  username: msaadany@iceweb.co"
  echo "  password: $password"
}

clear_all_caches() {
  log 1 'Clearing Craft CMS caches'
  cd "$PROVISION_CRAFT_PATH"
  sudo --user=www-data \
    ./craft clear-caches/all >/dev/null
  cd - >/dev/null
}

project_config_apply() {
  cd "$PROVISION_CRAFT_PATH"
  sudo --user=www-data \
    ./craft project-config/apply
  cd - >/dev/null
}

mailer_test() {
  if [ "$PROVISION_ENV" = "staging" ] ||
    [ "$PROVISION_ENV" = "production" ]; then
    log 1 'Test mail sending'
    cd "$PROVISION_CRAFT_PATH"
    sudo --user=www-data \
      ./craft mailer/test --interactive=0 --to msaadany@iceweb.co >/dev/null
    cd - >/dev/null
  fi
}

# Check if Craft CMS is already installed ##############################
if ! sudo --user=www-data \
  "$PROVISION_CRAFT_PATH"/craft install/check; then

  # Copy .env file
  log 1 'Importing .env file'
  cp "cms/.local.env" "$PROVISION_CRAFT_PATH/.env"

  download_craft
  set_the_file_permissions
  create_a_database
  setup_the_web_server
  run_the_setup
  project_config_apply
  clear_all_caches
  mailer_test

else

  download_craft
  set_the_file_permissions
  create_a_database
  setup_the_web_server
  run_the_setup
  project_config_apply
  clear_all_caches
  mailer_test

fi
