R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
NC='\033[0m'

apt_get() {
  apt-get -qq install $* >/dev/null
}

certbot_apply() {
  certbot --agree-tos \
    --domains $2 \
    --email $3 \
    --keep \
    --redirect \
    --$1 \
    --quiet
  certbot renew \
    --dry-run \
    --no-random-sleep-on-renew \
    --quiet
}

composer_get() {
  if [ ! $(hash composer &>/dev/null) ]; then
    local DOWNLOAD_URL="https://getcomposer.org/installer"
    local DOWNLOAD_FILE="$(mktemp)"
    local INSTALL_DIR="/usr/local/bin"
    wget -q -O "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
    php "$DOWNLOAD_FILE" --quiet --install-dir="$INSTALL_DIR"
    mv "$INSTALL_DIR/composer.phar" "$INSTALL_DIR/composer"
    rm "$DOWNLOAD_FILE"
  else
    composer self-update
  fi
}

env_from_file() {
  # https://gist.github.com/judy2k/7656bfe3b322d669ef75364a46327836#gistcomment-3239799
  local envFile=${1:-.env}
  while IFS='=' read -r key temp || [ -n "$key" ]; do
    local isComment='^[[:space:]]*#'
    local isBlank='^[[:space:]]*$'
    [[ $key =~ $isComment ]] && continue
    [[ $key =~ $isBlank ]] && continue
    value=$(eval echo "$temp")
    eval export "$key='$value'"
  done <$envFile
}

hostname_get_domain() {
  echo -n "$(regexp_match "$1" '^(.*\.)?\K([^.]+)(\.[^.]+?)$')"
}

log_colorize() {
  echo -e "${1}${2}${NC}"
}

log() {
  log_colorize "$G" "$1"
}

log_error() {
  log_colorize >&2 "$R" "$1"
}

log_info() {
  log_colorize "$Y" "$1"
}

mysql_db_import() {
  mysql $1 <"$2"
}

mysql_db_drop() {
  mysql -e \
    "DROP DATABASE IF EXISTS $1;"
}

mysql_db_create() {
  mysql -e \
    "CREATE DATABASE IF NOT EXISTS $1
      CHARACTER SET utf8
      COLLATE utf8_unicode_ci;"
}

mysql_get() {
  apt-get -qq update >/dev/null
  apt-get -qq install mysql-server >/dev/null
}

mysql_user_add() {
  mysql -e \
    "CREATE USER IF NOT EXISTS '$1'@'localhost'
      IDENTIFIED BY '$2';"
}

mysql_user_grant() {
  mysql -e \
    "GRANT ALL ON $2.*
      TO '$1'@'localhost';"
}

nginx_config_disable_default() {
  local default="/etc/nginx/sites-enabled/default"
  if [ -f $default ]; then
    rm $default
    systemctl restart nginx
  fi
}

nginx_config_add() {
  cp "$2" "/etc/nginx/sites-available/${1}.conf"
  chmod 644 "/etc/nginx/sites-available/${1}.conf"
}

nginx_config_enable() {
  ln --symbolic --force \
    "/etc/nginx/sites-available/${1}.conf" \
    "/etc/nginx/sites-enabled/"
  systemctl restart nginx
}

nginx_get() {
  apt-get -qq update >/dev/null
  apt-get -qq install certbot nginx python3-certbot-nginx >/dev/null
}

php_get() {
  apt-get -qq update >/dev/null
  apt-get -qq install \
    php${1}-curl \
    php${1}-dom \
    php${1}-fpm \
    php${1}-intl \
    php${1}-mbstring \
    php${1}-mysql \
    php${1}-zip \
    php${1}-xml \
    php-imagick \
    >/dev/null
}

php_mod_add() {
  local PHP_VERSION=$1
  local MOD_NAME="$2"
  local MOD_FILE="$3"
  cp "$MOD_FILE" "/etc/php/$PHP_VERSION/mods-available/${MOD_NAME}.ini"
  chmod 644 "/etc/php/$PHP_VERSION/mods-available/${MOD_NAME}.ini"
}

php_mod_enable() {
  local PHP_VERSION=$1
  local MOD_NAME="$2"
  phpenmod -v $PHP_VERSION -s fpm "$MOD_NAME"
  systemctl restart php${PHP_VERSION}-fpm
}

makeswap() {
  if [ ! -f /swapfile ]; then
    fallocate -l "$1" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null && swapon /swapfile
    sysctl vm.swappiness=10 >/dev/null
    sysctl vm.vfs_cache_pressure=50 >/dev/null
    echo '/swapfile   none    swap    sw    0   0' >>/etc/fstab
    echo 'vm.swappiness=10' >>/etc/sysctl.conf
    echo 'vm.vfs_cache_pressure=50' >>/etc/sysctl.conf
  fi
}

makeswap_auto() {
  local quarter_mem="$(free --mega | awk '$1 == "Mem:" { print(int($2/4)) }')"
  makeswap "${quarter_mem}M"
}

postfix_get() {
  apt-get -qq update >/dev/null
  apt-get -qq install postfix >/dev/null
}

postfix_relay_to_gsuite() {
  local origin=$1
  local relayhost="smtp-relay.gmail.com"
  local relayport="587"
  local virtualmap="/etc/postfix/virtual"
  # SEE: http://www.postfix.org/STANDARD_CONFIGURATION_README.html#null_client
  # SEE: http://www.postfix.org/STANDARD_CONFIGURATION_README.html#some_local
  postconf -e "myorigin = $origin"
  postconf -e "relayhost = $relayhost:$relayport"
  postconf -e 'inet_interfaces = loopback-only'
  postconf -e 'mydestination ='
  postconf -e 'virtual_alias_maps = hash:/etc/postfix/virtual'
  printf "" >$virtualmap &&
    echo "root   root@localhost" >>$virtualmap &&
    echo "ubuntu ubuntu@localhost" >>$virtualmap &&
    postmap /etc/postfix/virtual
  systemctl restart postfix
}

random_password() {
  local charSet='A-Za-z0-9-_'
  head /dev/urandom | tr --delete --complement $charSet |
    head --bytes=${1:-12}
}

random_uuid() {
  local prefix=${1:-}
  local uuid=$(cat /proc/sys/kernel/random/uuid)
  echo "${prefix}--${uuid}"
}

regexp_match() {
  echo "$1" | grep --perl-regexp --only-matching "$2"
}

set_permissions() {
  local owner=$1
  local mode=$2
  shift 2
  for file in "$@"; do
    if [ -d "$file" ]; then
      chown --recursive $owner $file
      chmod --recursive $mode $file
      find "$file" -type d -exec chmod +x {} \;
    elif [ -f "$file" ]; then
      chown $owner $file
      chmod $mode $file
    fi
  done
}
