#!/usr/bin/env bash

set -euo pipefail


#######################################
# Stop containers using docker-compose
# Arguments:
#   1
#######################################
stop_containers() {
  verify_docker
  if [[ -f "${docker_compose_file}" ]]; then
    print_message "Stopping containers using docker-compose..."
    docker compose -f "${docker_compose_file}" down --remove-orphans
  fi
}