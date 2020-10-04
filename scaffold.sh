#!/bin/bash
set -o errexit
set -o nounset

# Utility functions ####################################################
function password_gen() {
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c12
}

function get_env_list() {
  set | grep '^SCAFFOLDING_' |
    sed -r 's/(.*)=.*/$\1/' |
    paste -sd ':' -
}

function subst() {
  tmpfile=$(mktemp) &&
    cp $1 $tmpfile &&
    envsubst "$(get_env_list)" <$tmpfile >$1 &&
    rm $tmpfile
}

# Scaffolding variables ################################################
# Please set **all** the varialbes below
export SCAFFOLDING_VAGRANT_IP=""
export SCAFFOLDING_VAGRANT_NAME=""
export SCAFFOLDING_CRAFT_SITE_URL="http://www.site.test"
export SCAFFOLDING_CRAFT_APP_ID="$(password_gen)"
export SCAFFOLDING_CRAFT_SECURITY_KEY="$(password_gen)"

# Validate variables ###################################################
if [ -z "${SCAFFOLDING_VAGRANT_IP:-}" ] ||
  [ -z "${SCAFFOLDING_VAGRANT_NAME:-}" ] ||
  [ -z "${SCAFFOLDING_CRAFT_SITE_URL:-}" ] ||
  [ -z "${SCAFFOLDING_CRAFT_APP_ID:-}" ] ||
  [ -z "${SCAFFOLDING_CRAFT_SECURITY_KEY:-}" ]; then
  echo >&2 -e "ERROR\tSome variables not set or empty" &&
    exit 1
fi

# Set variables into files #############################################
echo "Setting up scaffolding file with your config variables ..."
subst "Vagrantfile"
subst "config/cms/.local.env"
subst "config/cms/.staging.env"
subst "config/cms/.production.env"

# Install npm modules then print info about outdated modules ###########
echo "Installing npm modules ..."
npm install --silent
npm outdated

# Setup git lfs and track common files types
echo "Setting up git lfs"
git lfs install
git lfs track "*.jpg"
git lfs track "*.otf"
git lfs track "*.png"
git lfs track "*.svg"
git lfs track "*.ttf"
git lfs track "*.woff"
git lfs track "*.woff2"

# Remove self
rm "$0"
