#!/usr/bin/env bash

set -euo pipefail

#######################################
# Checks if the given file exists and exits if it doesn't.
# Arguments:
#   1
#######################################
check_docker_compose() {
  local docker_compose_file="${1}"
  if [[ ! -f ${docker_compose_file} ]]; then
    print_multiple_messages "Docker Compose file not found: ${docker_compose_file}" "Please provide a valid Docker Compose file."
    exit 1
  fi
}

#######################################
# Checks if Docker Compose is installed and running.
# Arguments:
#  None
#######################################
check_docker_compose_installed() {
  if ! command -v docker compose &> /dev/null; then
    print_multiple_messages "Docker Compose is not installed." "Please install Docker Compose and try again."
    exit 1
  fi
}

#######################################
# Takes a Docker Compose file and a directory as arguments and dumps the logs of the services to the directory.
# Arguments:
#   1
#   2
#######################################
dump_compose_logs() {
  local docker_compose_file="${1}"
  local output_dir="${2}"

  check_docker_compose_installed
  check_docker_compose "${docker_compose_file}"

  mkdir -p "${output_dir}"

  local datetime
  datetime=$(date "+%Y-%m-%d_%H-%M-%S")

  local services
  services=$(docker compose -f "${docker_compose_file}" config --services)

  local service
  for service in ${services}; do
    dump_service_logs "${service}" "${datetime}" "${output_dir}"
  done

}

#######################################
# Dumps the logs of a specific service and saves them to a file.
# Arguments:
#   1
#   2
#   3
#######################################
dump_service_logs() {
  local service="${1}"
  local datetime="${2}"
  local docker_compose_file="${3}"

  print_message "Dumping logs for service: ${service}" "${docker_compose_file}"

  local log_file="${docker_compose_file}/${service}_${datetime// /_}.log"
  docker compose logs "${service}" | tee "${log_file}"

  print_message "Logs saved to ${log_file}"
}