#!/bin/bash
set -o errexit -o noclobber -o nounset -o pipefail
export DEBIAN_FRONTEND="noninteractive"


# Parse args ###########################################################
# SEE: https://stackoverflow.com/a/29754866/13037463
OPTIONS=
LONG_OPTIONS=config-path:,craft-admin-password:,craft-path:,domain-name:,drop,php:
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
PROVISION_PHP_VER=7.4
PROVISION_DOMAIN=localhost

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
    --domain-name)
      PROVISION_DOMAIN="$2"
      shift 2; ;;
    --drop)
      PROVISION_DROP_DB=true
      shift; ;;
    --php)
      PROVISION_PHP_VER="$2"
      shift 2; ;;
    --)
      shift; break; ;;
    *)
      echo "Invalid args"; exit 3; ;;
  esac
done


# Change PWD & load utils ##############################################
cd "$PROVISION_CONFIG_PATH"


# Load utilities #######################################################
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
export PROVISION_PHP_VER # -------------------------------- START EXPORT
CONFIG="$(mktemp)" # ======================================== START FILE
envsubst '$PROVISION_PHP_VER:$PROVISION_CRAFT_PATH' \
  < "nginx/local.conf" > "$CONFIG"
nginx_config_add "$PROVISION_DOMAIN" "$CONFIG"
rm "$CONFIG" && unset CONFIG # ================================ END FILE
export -n PROVISION_PHP_VER # ------------------------------- END EXPORT
nginx_config_disable_default
nginx_config_enable "$PROVISION_DOMAIN"


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
mkdir --mode 777 --parents "/usr/local/lib/craft"
sudo --user=vagrant --set-home \
  composer --quiet --working-dir="cms" \
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
