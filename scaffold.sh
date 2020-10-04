#!/bin/bash
set -o errexit
set -o nounset

# Utility functions ####################################################
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

# Validate variables ###################################################
# if [ -z "${VAR:-}" ]; then
#   echo >&2 -e "ERROR\tSome variables not set or empty" &&
#     exit 1
# fi
