#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Arguments:
#   1
#   2
#######################################
set_env_var() {
    local var_name="${1}"
    local default_value="${2}"
    eval "if [[ -z \${${var_name}:-} ]]; then export ${var_name}='${default_value}'; fi"
}

#######################################
# description
# Arguments:
#  None
#######################################
verify_docker() {
    set_env_var "DOCKER_HOST" "unix:///run/user/$(id -u)/docker.sock"
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
check_command_exists() {
  local command="${1}"
  local message="${2}"
  if ! command -v "${command}" &> /dev/null; then
    print_multiple_messages "${message}"
    exit 1
  fi
}

#######################################
# description
# Globals:
#   PATH
# Arguments:
#  None
# Returns:
#   1 ...
#######################################
initialize_rootless_docker() {
  print_multiple_messages "Setting up Docker in rootless mode..."

  # Ensure rootless setup tool is available before attempting setup.
  if ! command -v dockerd-rootless-setuptool.sh > /dev/null 2>&1; then
    print_multiple_messages "dockerd-rootless-setuptool.sh not found. Exiting."
    return 1
  else
    dockerd-rootless-setuptool.sh install
  fi

  # Ensure Docker environment variables are set.
  verify_docker

  local uid
  uid=$(id -u)

  local bashrc_path="$HOME/.bashrc"
  local backup_path="${bashrc_path}.backup"
  # Create a backup of .bashrc
  cp "$bashrc_path" "$backup_path"
  echo "Backup of .bashrc created at ${backup_path}."

  insert_into_bashrc "export XDG_RUNTIME_DIR=/run/user/${uid}"
  insert_into_bashrc "export DOCKER_HOST=unix:///run/user/${uid}/docker.sock"

  # Manage Docker's systemd services.
  systemctl --user start docker.service
  systemctl --user enable docker.service
}