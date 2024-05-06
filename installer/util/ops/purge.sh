#!/usr/bin/env bash

set -euo pipefail

#######################################
# Purge resources for all services in the install profile
# Globals:
#   install_profile
# Arguments:
#  None
#######################################
purge() {
  local service_name
  verify_docker
  print_message "Identifying and purging associated resources..."

  # Dynamically get service names
  local service_names
  mapfile -t service_names < <(read_service_names "${install_profile}")
  for service_name in "${service_names[@]}"; do
    purge_resources "${service_name}"
  done
}

#######################################
# Read service names from the JSON file
# Arguments:
#   1
#######################################
read_service_names() {
  local install_profile=${1}
  jq -r '.services | keys | .[]' "${install_profile}"
}


#######################################
# Stop and remove containers, images, volumes, and networks for a given service
# Arguments:
#   1
#######################################
purge_resources() {
  local name="${1}"

  # Stop all containers, remove images, volumes, and networks for the service
  stop_containers

  # Containers
  print_message "Stopping and removing containers for service ${name}..."
  docker ps -a --format '{{.Names}}' | grep -E "${name}" | xargs -r -I{} docker stop {}
  docker ps -a --format '{{.Names}}' | grep -E "${name}" | xargs -r -I{} docker rm {}

  # Images
  print_message "Removing images for service ${name}..."

  # Specifically handle '<none>:<none>' images if 'name' matches '<none>' or swallow if there are no '<none>:<none>' images
  docker images -a | grep none | awk '{ print $3; }' | xargs -r -I{} docker rmi --force {}

  # Remove images with the service name
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "${name}" | xargs -r -I{} docker rmi --force {}

  # Remove images with the service name
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "${name}" | xargs -r -I{} docker rmi --force {}

  # Volumes
  print_message "Removing volumes for service ${name}..."
  docker volume ls --format '{{.Name}}' | grep -E "${name}" | xargs -r -I{} docker volume rm --force {}
  print_message "Removing dangling volumes..."
  docker volume ls -qf dangling=true | xargs -r docker volume rm

  # Networks
  print_message "Removing networks for service ${name}..."
  docker network ls --format '{{.Name}}' | grep -E "${name}" | xargs -r -I{} docker network rm --force {}
  print_message "Removing dangling networks..."
  docker network ls -qf dangling=true | xargs -r docker network rm
}