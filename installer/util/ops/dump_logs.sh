#!/usr/bin/env bash

set -euo pipefail

dump_logs() {
  local docker_compose_file="${1}"
  local output_dir="${2}"
  if ! command -v docker compose &> /dev/null; then
    print_multiple_messages "Docker Compose is not installed." "Please install Docker Compose and try again."
    exit 1
  fi
  if [[ ! -f ${docker_compose_file} ]]; then
    print_multiple_messages "Docker Compose file not found: ${docker_compose_file}" "Please provide a valid Docker Compose file."
    exit 1
  fi
  mkdir -p "${output_dir}"
  local datetime
  datetime=$(date +"%Y-%m-%d %H:%M:%S")
  local log_file="${output_dir}/docker-compose-logs-${datetime}.log"
  docker compose logs | tee "${log_file}"
  print_message "Logs saved to ${log_file}"
}