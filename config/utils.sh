apt_get () {
  apt-get -qq update > /dev/null
  apt-get -qq install $* > /dev/null
}

composer_get () {
  if [ ! $(hash composer &> /dev/null) ]; then
    local DOWNLOAD_URL="https://getcomposer.org/installer"
    local DOWNLOAD_FILE="$(mktemp)" # ======================= START FILE
    local INSTALL_DIR="/usr/local/bin"
    wget -q -O "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
    php "$DOWNLOAD_FILE" --quiet --install-dir="$INSTALL_DIR"
    mv "$INSTALL_DIR/composer.phar" "$INSTALL_DIR/composer"
    rm "$DOWNLOAD_FILE" # ===================================== END FILE
  else
    composer self-update
  fi
}

composer_install () {
  tmpdir="$(mktemp --directory)" # =========================== START DIR
  cd $tmpdir # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ START PWD
  cp "$1/composer".* "$tmpdir/"
  chmod --recursive 777 .
  sudo --user=vagrant --set-home \
    composer --quiet install
  if [ -d "$1/vendor" ]; then
    rm -r "$1/vendor"
  fi
  mv "$tmpdir/vendor" "$1/vendor"
  cp -p "$tmpdir/composer".* "$1/"
  cd - # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ END PWD
  rmdir $tmpdir # ============================================== END DIR
}

craft_download_vendor () {
  local url='https://craftcms.com/latest-v3.tar.gz'
  local tmpfile="$(mktemp)" # =============================== START FILE
  wget -q --output-document="$tmpfile" "$url"
  tar --ungzip --extract --file="$tmpfile" --directory="$1" vendor
  rm "$tmpfile" # ============================================= END FILE
}

craft_create_project () {
  if [ ! -d "$1" ]; then
    sudo --user=vagrant --set-home \
      composer.phar create-project craftcms/craft \
        --no-interaction \
        --no-progress \
        --quiet \
        --remove-vcs \
        "$1"
  fi
}

log () {
  for i in $(seq 1 $1); do
    printf "    "
  done
  shift
  echo "$@"
}

mysql_db_import () {
  sudo mysql $1 < "$2"
}

mysql_db_drop () {
  sudo mysql -e \
    "DROP DATABASE IF EXISTS $1;"
}

mysql_db_create () {
  sudo mysql -e \
    "CREATE DATABASE IF NOT EXISTS $1
      CHARACTER SET utf8
      COLLATE utf8_unicode_ci;"
}

mysql_user_add () {
  sudo mysql -e \
    "CREATE USER IF NOT EXISTS '$1'@'localhost'
      IDENTIFIED BY '$2';"
}

mysql_user_grant () {
  sudo mysql -e \
    "GRANT ALL ON $2.*
      TO '$1'@'localhost';"
}

nginx_config_disable_default () {
  local default="/etc/nginx/sites-enabled/default"
  if [ -f $default ]; then
    rm $default
    systemctl restart nginx
  fi
}

nginx_config_add () {
  cp "$2" "/etc/nginx/sites-available/${1}.conf"
  chmod 644 "/etc/nginx/sites-available/${1}.conf"
}

nginx_config_enable () {
  ln --symbolic --force \
    "/etc/nginx/sites-available/${1}.conf" \
    "/etc/nginx/sites-enabled/"
  systemctl restart nginx
}

php_mod_add () {
  local PHP_VERSION=$1
  local MOD_NAME="$2"
  local MOD_FILE="$3"
  cp "$MOD_FILE" "/etc/php/$PHP_VERSION/mods-available/${MOD_NAME}.ini"
  chmod 644 "/etc/php/$PHP_VERSION/mods-available/${MOD_NAME}.ini"
}

php_mod_enable () {
  local PHP_VERSION=$1
  local MOD_NAME="$2"
  phpenmod -v $PHP_VERSION -s fpm "$MOD_NAME"
  systemctl restart php${PHP_VERSION}-fpm
}

makeswap () {
  if [ ! -f /swapfile ]; then
    fallocate -l "$1" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile && swapon /swapfile
    sysctl vm.swappiness=10 > /dev/null
    sysctl vm.vfs_cache_pressure=50 > /dev/null
    echo '/swapfile   none    swap    sw    0   0' >> /etc/fstab
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
  fi
}

makeswap_auto () {
  local quarter_mem="$(free --mega | awk '$1 == "Mem:" { print(int($2/4)) }')"
  makeswap "${quarter_mem}M"
}

password_gen () {
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c12
}

set_permissions () {
  local owner=$1
  local mode=$2
  local file=$3
  if [ -d "$file" ] || [ -f "$file" ]; then
    chown --recursive $owner $file
    chmod --recursive $mode $file
    find "$file" -type d -exec chmod +x {} \;
  fi
}
