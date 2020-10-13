#!/bin/bash

CLR_BLACK="30m"
CLR_RED="31m"
CLR_GREEN="32m"
CLR_YELLOW="33m"
CLR_BLUE="34m"
CLR_MAGENTA="35m"
CLR_CYAN="36m"
CLR_WHITE="37m"

CLR_BRIGHT_BLACK="30;1m"
CLR_BRIGHT_RED="31;1m"
CLR_BRIGHT_GREEN="32;1m"
CLR_BRIGHT_YELLOW="33;1m"
CLR_BRIGHT_BLUE="34;1m"
CLR_BRIGHT_MAGENTA="35;1m"
CLR_BRIGHT_CYAN="36;1m"
CLR_BRIGHT_WHITE="37;1m"

echocolor() {
  local C="\u001b[$1" && shift
  local C_END="\u001b[0m"
  if [ "$1" != "-n" ]; then
    echo -e "${C}${@}${C_END}"
  else
    shift
    printf "${C}${@}${C_END}"
  fi
}

echoblue() {
  echocolor "$CLR_BLUE" "$@"
}

echogreen() {
  echocolor "$CLR_GREEN" "$@"
}

echored() {
  echocolor "$CLR_RED" "$@"
}
