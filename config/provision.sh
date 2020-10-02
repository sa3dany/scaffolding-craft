#!/bin/bash
set -o errexit
set -o nounset
timedatectl set-timezone Asia/Riyadh
export DEBIAN_FRONTEND="noninteractive"


# change directory to config directory & load utils
cd /vagrant
source config/utils.sh


# Provisioning variables ###############################################
PROVISION_PHP_VER=7.4
PROVISION_DROP_DB=false
PROVISION_CRAFT_PASSWORD="$(password_gen)"


# Add some swap ########################################################
makeswap "512M"


# Dependencies #########################################################
echo "Updating APT repos..."
apt-get -qq update > /dev/null

# General
echo "Installing curl, wget & unzip..."
apt-get -qq install curl wget unzip > /dev/null

# PHP
echo "Installing php$PROVISION_PHP_VER..."
apt-get -qq install \
  php${PROVISION_PHP_VER}-curl \
  php${PROVISION_PHP_VER}-dom \
  php${PROVISION_PHP_VER}-fpm \
  php${PROVISION_PHP_VER}-intl \
  php${PROVISION_PHP_VER}-mbstring \
  php${PROVISION_PHP_VER}-mysql \
  php${PROVISION_PHP_VER}-zip \
  php${PROVISION_PHP_VER}-xml \
  php-imagick \
> /dev/null

# nginx
echo "Installing nginx & certbot..."
apt-get -qq install certbot nginx python3-certbot-nginx > /dev/null

# MySQL
echo "Installing MySQL..."
apt-get -qq install mysql-server > /dev/null

# Composer
echo "Installing Composer..."
composer_get


# Update PHP config ####################################################
echo "Updating php configuration..."
php_mod_add $PROVISION_PHP_VER "vagrant" "config/php/php.ini"
php_mod_enable $PROVISION_PHP_VER "vagrant"


# Nginx config #########################################################
echo "Configuring web server..."
export PROVISION_PHP_VER # -------------------------------- START EXPORT
CONFIG="$(mktemp)" # ======================================== START FILE
envsubst '$PROVISION_PHP_VER' \
  < "config/nginx/default.conf" > "$CONFIG"
nginx_config_add "craft" "$CONFIG"
rm "$CONFIG" && unset CONFIG # ================================ END FILE
export -n PROVISION_PHP_VER # ------------------------------- END EXPORT
nginx_config_disable_default
nginx_config_enable "craft"


# Database setup #######################################################
echo "Database setup..."
if [ "$PROVISION_DROP_DB" = true ]; then
  echo "Dropping existing database (if any)..."
  mysql_db_drop "cms"
fi
mysql_db_create "cms"
mysql_user_add "cms_user" "cms_password"
mysql_user_grant "cms_user" "cms"


# Setup Craft CMS ######################################################
# Composer install
echo "Performing composer install..."
mkdir --mode 777 --parents "/usr/local/lib/craft"
sudo --user=vagrant --set-home \
  composer --quiet --working-dir="cms" \
    install --no-dev

# Copy .env file
echo "Copying .env file..."
cp "config/cms/local.env" "/vagrant/cms/.env"

# Set permissions
set_permissions vagrant:www-data 774 "/vagrant/cms/.env"
set_permissions vagrant:www-data 774 "/vagrant/cms/composer".*
set_permissions vagrant:www-data 774 "/vagrant/cms/config/license.key"
set_permissions vagrant:www-data 774 "/vagrant/cms/config/project/"*
set_permissions vagrant:www-data 774 "/vagrant/cms/storage/"*
set_permissions vagrant:www-data 774 "/usr/local/lib/craft" # <--Vendor
set_permissions vagrant:www-data 774 "/vagrant/cms/web/cpresources/"*

# Install craft
echo "Craft setup..."
if ! cms/craft install/check; then
  sudo --user=vagrant \
    cms/craft install \
      --interactive=0 \
      --email="$SCAFFOLDING_CRAFT_EMAIL" \
      --username="$SCAFFOLDING_CRAFT_EMAIL" \
      --siteName="$SCAFFOLDING_CRAFT_SITE_NAME" \
      --siteUrl="$SCAFFOLDING_CRAFT_SITE_URL" \
      --password="$PROVISION_CRAFT_PASSWORD" \
    > /dev/null

  echo "USERNAME: $SCAFFOLDING_CRAFT_EMAIL"
  echo "PASSWORD: $PROVISION_CRAFT_PASSWORD"
fi
