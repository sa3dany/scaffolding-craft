#!/bin/bash
set -o errexit -o noclobber -o nounset -o pipefail
export DEBIAN_FRONTEND="noninteractive"


# Parse args ###########################################################
# SEE: https://stackoverflow.com/a/29754866/13037463
OPTIONS=
LONG_OPTIONS="config-path:,craft-admin-password:,craft-path:,drop,php:,\
email-hostname:,hostname:,staging"

! PARSED=$(getopt --name "$0" \
    --options="$OPTIONS" \
    --longoptions=$LONG_OPTIONS \
    -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then exit 2; fi
set -- $PARSED

PROVISION_CONFIG_PATH="$(dirname "$0")"
PROVISION_CRAFT_ADMIN_PASSWORD=
PROVISION_CRAFT_PATH=
PROVISION_DROP_DB=false
PROVISION_EMAIL_HOSTNAME=
PROVISION_ENV=
PROVISION_HOSTNAME=localhost
PROVISION_PHP_VER=7.4

while true; do
  case "$1" in
    --config-path)
      if [ ! -f "$2/utils.sh" ]; then
        echo "$1 is invalid"; exit 3
      fi
      PROVISION_CONFIG_PATH="$2"
      shift 2; ;;
    --craft-admin-password)
      PROVISION_CRAFT_ADMIN_PASSWORD="$2"
      shift 2; ;;
    --craft-path)
      PROVISION_CRAFT_PATH="$2"
      shift 2; ;;
    --email-hostname)
      PROVISION_EMAIL_HOSTNAME="$2"
      shift 2; ;;
    --hostname)
      PROVISION_HOSTNAME="$2"
      shift 2; ;;
    --drop)
      PROVISION_DROP_DB=true
      shift; ;;
    --php)
      PROVISION_PHP_VER="$2"
      shift 2; ;;
    --staging)
      if [ ! -z "$PROVISION_ENV" ]; then
        echo "only one env modifier is allowed at a time"; exit 3
      fi
      PROVISION_ENV=staging
      shift; ;;
    --)
      shift; break; ;;
    *)
      echo "Invalid args"; exit 3; ;;
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
php_mod_add $PROVISION_PHP_VER "provisioner" "php/php.ini"
php_mod_enable $PROVISION_PHP_VER "provisioner"


# Web server setup #####################################################
log 1 "Configuring NGINX"
nginx_get
if [ ! -d "/etc/nginx/nginx-partials" ]; then
  mkdir "/etc/nginx/nginx-partials"
fi
cp "nginx/partials/"* "/etc/nginx/nginx-partials"
export PROVISION_PHP_VER PROVISION_HOSTNAME PROVISION_CRAFT_PATH
  CONFIG="$(mktemp)"
    if [ "$PROVISION_ENV" = "staging" ]; then
      envsubst '$PROVISION_PHP_VER:$PROVISION_CRAFT_PATH' \
        < "nginx/local.conf" > "$CONFIG"
    else
      envsubst '$PROVISION_PHP_VER:$PROVISION_HOSTNAME:$PROVISION_CRAFT_PATH' \
        < "nginx/live.conf" > "$CONFIG"
    fi
    nginx_config_add "$PROVISION_HOSTNAME" "$CONFIG"
  rm "$CONFIG" && unset CONFIG
export -n PROVISION_PHP_VER PROVISION_HOSTNAME PROVISION_CRAFT_PATH
nginx_config_disable_default
nginx_config_enable "$PROVISION_HOSTNAME"


# Database setup #######################################################
log 1 "MySQL setup"
mysql_get
if [ "$PROVISION_DROP_DB" = true ]; then
  echo "Dropping existing database (if any)..."
  mysql_db_drop "cms"
fi
mysql_db_create "cms"
mysql_user_add "cms_user" "cms_password"
mysql_user_grant "cms_user" "cms"


# Setup Craft CMS ######################################################
# Composer install
log 1 "Performing composer install"
composer_get
if [ ! -d "/usr/local/lib/craft" ]; then
  mkdir --mode 774 --parents "/usr/local/lib/craft"
fi
chown www-data:www-data "/usr/local/lib/craft"
sudo --user=www-data --set-home \
  composer --quiet --no-cache --working-dir="$PROVISION_CRAFT_PATH" \
    install --no-dev

# Copy .env file
log 1 'Importing .env file'
cp "cms/local.env" "$PROVISION_CRAFT_PATH/.env"

# Set permissions
set_permissions vagrant:www-data 774 "$PROVISION_CRAFT_PATH/.env"
set_permissions vagrant:www-data 774 "$PROVISION_CRAFT_PATH/composer".*
set_permissions vagrant:www-data 774 "$PROVISION_CRAFT_PATH/config/license.key"
set_permissions vagrant:www-data 774 "$PROVISION_CRAFT_PATH/config/project/"*
set_permissions vagrant:www-data 774 "$PROVISION_CRAFT_PATH/storage/"*
set_permissions vagrant:www-data 774 "/usr/local/lib/craft" # <--Vendor
set_permissions vagrant:www-data 774 "$PROVISION_CRAFT_PATH/web/cpresources/"*

# Install Craft CMS if not installed. Otherwise, clear cache
if ! cms/craft install/check; then

  # Install Craft CMS
  log 1 "Installing Craft CMS"
  sudo --user=www-data \
    cms/craft install \
      --interactive=0 \
      --email="$SCAFFOLDING_CRAFT_EMAIL" \
      --username="$SCAFFOLDING_CRAFT_EMAIL" \
      --siteName="$SCAFFOLDING_CRAFT_SITE_NAME" \
      --siteUrl="$SCAFFOLDING_CRAFT_SITE_URL" \
      --password="${PROVISION_CRAFT_ADMIN_PASSWORD:-(password_gen)}" \
    > /dev/null

  echo "USERNAME: $SCAFFOLDING_CRAFT_EMAIL"
  echo "PASSWORD: $PROVISION_CRAFT_ADMIN_PASSWORD"

else

  # Clear craft caches
  log 1 'Clearing Craft CMS caches'
  cd "$PROVISION_CRAFT_PATH"
    ./craft install/check > /dev/null
    ./craft clear-caches/all > /dev/null
  cd - > /dev/null

fi


# Email setup ##########################################################
# Make sure to setup SMTP relay in G Suite with the website's static IP
# SEE: https://support.google.com/a/answer/176600?hl=en
if [ "$PROVISION_ENV" = "staging" ]; then
  log 1 "POSTFIX setup through G Suite relay"

  # validate if --email-hostname was set
  if [ -z "$PROVISION_EMAIL_HOSTNAME" ]; then
    echo "--email-hostname is required in non-local env"
    exit 2
  fi

  # setup POSTFIX
  postfix_get && postfix_relay_to_gsuite "meltblown.sa"

  # test mail sending
  cd "$PROVISION_CRAFT_PATH"
    ./craft mailer/test \
      --interactive=0 \
      --to msaadany@iceweb.co \
    > /dev/null
  cd - > /dev/null
fi
