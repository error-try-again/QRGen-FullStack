#!/usr/bin/env bash

#######################################
# Ensures that no conflicting containers or networks exist and removes them
# before starting services
# Arguments:
#  None
#######################################
pre_flight() {
  remove_conflicting_containers
  handle_ambiguous_networks
}

#######################################
# Waits for the Certbot container to complete its process.
# Arguments: None
# Returns:
#   0 if Certbot successfully exited.
#   1 if Certbot is in an unexpected state or timeout occurs.
#######################################
wait_for_certbot_completion() {
  local attempt_count=0
  local max_attempts=12
  local sleep_duration=5
  local certbot_container_id certbot_status

  while ((attempt_count++ < max_attempts)); do
    certbot_container_id=$(docker compose ps -q certbot)
    if [[ -n $certbot_container_id ]]; then
      certbot_status=$(docker inspect -f '{{.State.Status}}' "$certbot_container_id")
      print_message "Attempt ${attempt_count}: Certbot container status - ${certbot_status}"

      case $certbot_status in
        "exited")
          return 0 ;;
        "running")
          ;; # continue waiting
        *)
          print_message "Certbot container is in an unexpected state: ${certbot_status}"
          return 1 ;;
      esac
    else
      print_message "Certbot container is not running."
      break
    fi
    sleep $sleep_duration
  done

  if ((attempt_count > max_attempts)); then
    print_message "Certbot process timed out."
    return 1
  fi
}


#######################################
# Build and run docker services with conditional certbot handling
# Globals:
#   None
# Arguments:
#######################################
build_and_run_docker() {
  local docker_compose_file="${1}"
  local project_logs_dir="${2}"
  local project_root_dir="${3}"
  local release_branch="${4}"
  local disable_docker_build_caching="${5}"

  # Change to project root directory
  cd "${project_root_dir}" || exit 1

  # Run pre-flight procedures
  pre_flight

  # Handle certificates
  handle_certs

  print_message "Building and running docker services for ${release_branch} from $(pwd)"

  # Now build and run the rest of the services
  if [[ ${disable_docker_build_caching} == "true" ]]; then
    docker compose build --no-cache
  else
    docker compose build
  fi

  docker compose up -d --force-recreate --renew-anon-volumes

  if wait_for_certbot_completion; then
    print_message "Certbot has completed. Restarting other services."
    restart_services
  else
    print_message "An error occurred with Certbot. Please check logs."
    exit 1
  fi

}

#######################################
# List and inspect the networks and containers and disconnect and remove them if they are ambiguous
# Globals:
#   service_to_standard_config_map
# Arguments:
#  None
#######################################
handle_ambiguous_networks() {
  print_message "Handling ambiguous networks..."
  local network_name
  for network_name in $(docker network ls --format '{{.Name}}'); do
    if [[ ${network_name} =~ ^(${!service_to_standard_config_map[*]}|default)$   ]]; then
      local containers_in_network
      containers_in_network=$(docker network inspect "${network_name}" --format '{{range .Containers}}{{.Name}} {{end}}')
      local container
      for container in ${containers_in_network}; do
        docker network disconnect -f "${network_name}" "${container}"
      done
      docker network rm "${network_name}" || exit 1
    fi
  done
}

#######################################
#
# Globals:
#   PWD
# Arguments:
#  None
#######################################
remove_conflicting_containers() {
  print_message "Removing conflicting containers..."
  local service
  for service in $(docker compose config --services); do
    local container_name
    docker ps -a --format '{{.Names}}' | grep -E "${service}.*" | while read -r container_name; do
      echo "Removing container: ${container_name}"
      docker rm -f "${container_name}" &> /dev/null
    done
  done
}

#######################################
#
# Globals:
#   service_to_standard_config_map
# Arguments:
#  None
# Returns:
#   1 ...
#######################################
restart_services() {
  print_message "Restarting services..."
  # Restart services dynamically based on unique service names
  local service
  for service in "${!service_to_standard_config_map[@]}"; do
    if [[ ${service} == "certbot" ]]; then
      continue
    fi
    docker compose restart "${service}" || {
      echo "Failed to restart service: ${service}"
      return 1
    }
  done
}