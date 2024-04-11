#!/usr/bin/env bash

set -euo pipefail

#######################################
# Cleans the Docker Compose file before generating a new one
# Arguments:
#   1
#######################################
clean_compose_file() {
    local compose_file="${1}"
    rm -f "${compose_file}"
}

#######################################
# Appends a service configuration to the Docker Compose file
# Arguments:
#   1
#   2
#######################################
append_service_to_compose() {
    local service_config_json="${1}"
    local compose_file="${2}"

    # Generates service configuration from JSON with conditional build or image specification
    # and supports optional user and entrypoint fields.
    jq -r --argjson defaultPorts '[]' --argjson defaultVolumes '{}' --argjson defaultNetworks '[]' '
        "  \(.name):",
        (if .context and .dockerfile then
            "    build:\n      context: \(.context)\n      dockerfile: \(.dockerfile)"
        else
            "    image: \(.image // empty)"
        end),
        "    container_name: \(.container_name // empty)",
        (if (.ports // $defaultPorts) | length > 0 then "    ports:" else empty end),
        (.ports // $defaultPorts | .[] | "      - \"\(.)\""),
        (if (.volumes // $defaultVolumes) | keys | length > 0 then "    volumes:" else empty end),
        (.volumes // $defaultVolumes | to_entries[] | "      - \"\(.key):\(.value)\""),
        (if (.networks // $defaultNetworks) | length > 0 then "    networks:" else empty end),
        (.networks // $defaultNetworks | .[] | "      - \(.)"),
        (if (.depends_on // empty) | length > 0 then "    depends_on:" else empty end),
        (.depends_on // empty | .[] | "      - \(.)"),
        "    restart: \(.restart // "no")",
        (if (.command // empty) | length > 0 then "    command: \(.command)" else empty end),
        (if .user? then "    user: \(.user)" else empty end),
        (if .entrypoint? then "    entrypoint: \(.entrypoint)" else empty end)
    ' <<< "${service_config_json}" >> "${compose_file}"
}

#######################################
# Appends global networks and volumes configurations only once
# Arguments:
#   1
#   2
#   3
#######################################
append_global_configurations() {
  local networks_json="${1}"
  local volumes_json="${2}"
  local compose_file="${3}"

  # Check and append global networks if not empty
  if [ "$(jq -r 'keys | length' <<< "${networks_json}")" -gt 0 ]; then
    echo "networks:" >> "${compose_file}"
    jq -r '. | to_entries[] | "  \(.key):\n    driver: \(.value.driver)"' <<< "${networks_json}" >> "${compose_file}"
  fi

  # Check and append global volumes if not empty
  if [ "$(jq -r 'keys | length' <<< "${volumes_json}")" -gt 0 ]; then
    echo "volumes:" >> "${compose_file}"
    jq -r '. | to_entries[] | "  \(.key):" + (if .value.driver then "\n    driver: \(.value.driver)" else empty end)' <<< "${volumes_json}" >> "${compose_file}"
  fi
}

#######################################
# Generate the Docker Compose file from the given service configurations
# Globals:
#   global_networks_json
#   global_volumes_json
# Arguments:
#  None
#######################################
generate_docker_compose() {
  local compose_file="${1}"
  shift
  local service_configs=("$@")

  clean_compose_file "${compose_file}"
  echo "services:" >> "${compose_file}"

  local service_config
  for service_config in "${service_configs[@]}"; do
    append_service_to_compose "${service_config}" "${compose_file}"
  done

  append_global_configurations "${global_networks_json}" "${global_volumes_json}" "${compose_file}"
}