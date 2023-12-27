#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Arguments:
#   1
#   2
#######################################
numeric_prompt() {
  local prompt_message=$1
  local var_name=$2
  local input
  read -rp "$prompt_message" input
  while ! [[ $input =~ ^[0-9]+$ ]]; do
    echo "Please enter a valid number."
    read -rp "$prompt_message" input
  done
  eval "$var_name"="'$input'"
}
