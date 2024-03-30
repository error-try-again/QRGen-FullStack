#!/usr/bin/env bash

set -euo pipefail

#######################################
# Create the directory structure for the project. This includes the frontend, backend, certbot, and project logs directories.
# Arguments:
#   1
#   2
#   3
#   4
#######################################
setup_directory_structure() {
  local frontend_dir="${1}"
  local backend_directory="${2}"
  local certbot_dir="${3}"
  local project_logs_dir="${4}"

  print_multiple_messages "Staging project directories..."
  local directory
  for directory in "${frontend_dir}" "${backend_directory}" "${certbot_dir}" "${project_logs_dir}"; do
    create_directory_if_not_exist "${directory}"
  done
}