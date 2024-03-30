#!/usr/bin/env bash

set -euo pipefail

#######################################
# Create a directory if it does not exist and print a message.
# Arguments:
#   1
#######################################
create_directory_if_not_exist() {
  local directory="$1"
  if [[ ! -d ${directory} ]]; then
    mkdir -p "${directory}"
    echo "${directory} created."
  else
    echo "${directory} already exists."
  fi
}