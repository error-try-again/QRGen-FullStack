#!/usr/bin/env bash

set -euo pipefail

#######################################
# Exports environment flags as variables for the given profile.
# Globals:
#   None
# Arguments:
#   1 - Path to the JSON file
#   2 - Profile name
#######################################
export_environment_flags() {
  local json_file="${1}"
  local profile="${2}"

  echo "Exporting environment flags for profile: ${profile}"

  # Extract flags as a JSON string
  local flags_json
  flags_json=$(jq -r --arg profile "${profile}" '.environments[$profile].flags | tojson' "${json_file}")

  # Convert JSON string to "key=value" pairs
  local key_value_pairs
  key_value_pairs=$(echo "${flags_json}" | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]')

  # Use process substitution to avoid creating a subshell for the while loop
  while IFS= read -r line; do
    # Extract key and value from the line
    local key value
    key=$(echo "${line}" | cut -d'=' -f1)
    value=$(echo "${line}" | cut -d'=' -f2)

    print_message "Exporting flag: ${key}=${value}"

    # Declare variables globally to make them available in the environment
    declare -g "${key}"="${value}"
  done < <(echo "${key_value_pairs}")

  print_message "Environment flags exported successfully."
}

#######################################
# Validate that a file exists
# Arguments:
#   1
#######################################
validate_file_exists() {
  local file
  file="${1}"

  if [[ ! -f ${file}   ]]; then
    print_multiple_messages "Configuration file ${file} does not exist." "Please create the file and try again."
    exit 1
  else
    print_multiple_messages "Configuration file ${file} exists." "Proceeding with the installation."
    return 0
  fi
}

#######################################
# Take the JSON file as input and apply the configurations for the selected profile.
# The configurations are applied by merging the default configurations with the profile overrides.
# Values are stored in the service_to_standard_config_map, global_networks_json, and global_volumes_json.
# The global_networks_json and global_volumes_json are used to store the global networks and volumes.
# The service_to_standard_config_map is used to store the service configurations with the service name as the key.
# Globals:
#   global_networks_json
#   global_volumes_json
#   service_name
#   service_to_standard_config_map
# Arguments:
#   1
#   2
#######################################
apply_profile() {
  local json_file="$1"
  local profile="$2"

  declare -gA service_to_standard_config_map
  declare -g global_networks_json global_volumes_json


  validate_file_exists "${json_file}"

  print_message "Applying configurations for profile: ${profile}"

  # Read the services for the selected profile
  local services
  readarray -t services < <(jq -r ".environments[\"${profile}\"].services[]" "${json_file}")

  local global_networks_override global_volumes_override
  global_networks_override=$(jq -r --arg profile "${profile}" '.environments[$profile].networks // {} | tojson' "${json_file}")
  global_volumes_override=$(jq -r --arg profile "${profile}" '.environments[$profile].volumes // {} | tojson' "${json_file}")

  # Fetch and merge global networks and volumes with overrides
  global_networks_json=$(jq -s '.[0] * .[1]' <(jq -r '.networks | tojson' "${json_file}") <(echo "${global_networks_override}"))
  global_volumes_json=$(jq -s '.[0] * .[1]' <(jq -r '.volumes | tojson' "${json_file}") <(echo "${global_volumes_override}"))

  # Iterate over each service to configure it based on the base and overridden properties
  local service_name
  for service_name in "${services[@]}"; do
    echo "Configuring service: ${service_name}"

    # Merge the base service configuration with its overrides for the selected profile
    local service_config
    # Merge the base service configuration with its overrides for the selected profile
    service_config=$(jq -r --arg service_name "${service_name}" --arg profile "${profile}" '
      .services[$service_name] as $default
      | .environments[$profile].overrides[$service_name] // {}
      | $default + .' "${json_file}")

    service_to_standard_config_map["$service_name"]="$service_config"
  done

  # Display the configurations applied for the selected profile
  export_environment_flags "${json_file}" "${profile}"
  print_message "Configurations applied for profile: ${profile}"
}

#######################################
# Take a profile name as input and apply the configurations for that profile from the JSON file.
# Iterates over each entry in the environments object and applies the configurations for the selected environment.
# The configurations are applied by merging the default configurations with the profile overrides.
# Globals:
#   profile
# Arguments:
#   1
#######################################
select_and_apply_profile() {
  local json_file="${1}"

  # Fetch and display available profiles
  local profiles
  readarray -t profiles < <(jq -r '.environments | keys | .[]' "$json_file")

  # Display the available profiles to the user from the JSON file
  echo "Available profiles:"
  local idx=1
  for profile in "${profiles[@]}"; do
    echo "${idx}) ${profile}"
    ((idx++))
  done

  # Prompt user from the list of profiles and validate the
  # selected profile is within the range of 0-9
  local selection
  read -rp "Please enter your choice (1-${#profiles[@]}): " selection
  if ! [[ ${selection} =~ ^[0-9]+$ ]] || ((selection < 1 || selection > ${#profiles[@]})); then
    echo "Invalid selection."
    exit 1
  fi

  # Retrieve the selection from the 0-indexed array and apply the profile
  local selected_profile=${profiles[selection - 1]}
  apply_profile "${json_file}" "${selected_profile}"
}