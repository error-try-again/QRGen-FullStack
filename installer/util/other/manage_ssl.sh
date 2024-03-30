#!/usr/bin/env bash

set -euo pipefail

# Generate self-signed certificates for services if needed.
# Globals:
#   use_letsencrypt
#   use_self_signed_certs
handle_certs() {
  if [[ ${use_letsencrypt:-false} == "true" || ${use_self_signed_certs:-false} == "true" ]]; then
    generate_self_signed_certificates_for_services
  fi
}

# Handle SSL configuration based on whether a custom domain is used.
# Globals:
#   use_custom_domain
handle_ssl_types() {
  if [[ ${use_custom_domain:-false} == "true" ]]; then
    prompt_for_ssl
    prompt_for_letsencrypt
    construct_certbot_flags
  else
    prompt_for_self_signed_certificates
  fi
}

# Generate self-signed certificates for services, if needed.
# Globals:
#   certs_dir
#   regenerate_ssl_certificates
#   rsa_key_size
#   service_to_standard_config_map
generate_self_signed_certificates_for_services() {
  generate_dh_params
  local regenerate_needed=false

  # Check if regeneration is needed
  local service_name
  for service_name in "${!service_to_standard_config_map[@]}"; do
    local service_config="${service_to_standard_config_map[$service_name]}"
    local domains

    mapfile -t domains < <(echo "$service_config" | jq -r 'if .domains then .domains[] else empty end')

    # Skip if no domains are found
    if [[ ${#domains[@]} -eq 0 ]]; then
      continue
    fi

    for domain in "${domains[@]}"; do
      local certs_path="${certs_dir}/${domain}"
      local fullchain_path="${certs_path}/fullchain.pem"
      local privkey_path="${certs_path}/privkey.pem"
      if [[ ${regenerate_ssl_certificates} == "true" ]] || [[ ! -f ${fullchain_path} ]] || [[ ! -f ${privkey_path} ]]; then
        regenerate_needed=true
        break 2
      fi
    done
    if [[ $regenerate_needed == true ]]; then
      break
    fi
  done

  # Regenerate certificates if needed
  if [[ $regenerate_needed == true ]]; then
    for service_name in "${!service_to_standard_config_map[@]}"; do
      local service_config="${service_to_standard_config_map[$service_name]}"
      local domains

        mapfile -t domains < <(echo "$service_config" | jq -r '.domains[]')
        for domain in "${domains[@]}"; do
          generate_certificate_if_needed "${domain}" "${certs_dir}" "${rsa_key_size}" "${regenerate_ssl_certificates}"
        done
    done
  else
    echo "All certificates are up to date; skipping regeneration."
  fi
}

# Generate a self-signed certificate for a domain if needed.
# Arguments:
#   domain, certs_dir, rsa_key_size, regenerate
generate_certificate_if_needed() {
  local domain="${1}"
  local certs_dir="${2}"
  local rsa_key_size="${3}"
  local regenerate="${4}"

  local certs_path="${certs_dir}/${domain}"
  local fullchain_path="${certs_path}/fullchain.pem"
  local privkey_path="${certs_path}/privkey.pem"

  mkdir -p "${certs_path}"

  if [[ ${regenerate} == "true" ]] || [[ ! -f ${fullchain_path} ]] || [[ ! -f ${privkey_path} ]]; then
    echo "Generating self-signed certificates for ${domain}..."
    if ! openssl req -x509 -nodes -days 365 -newkey rsa:"${rsa_key_size}" -keyout "${privkey_path}" -out "${fullchain_path}" -subj "/CN=${domain}"; then
      echo "Error generating certificates for ${domain}."
      return 1
    fi
    echo "Certificates generated at ${fullchain_path} and ${privkey_path}."
  else
    echo "Certificates already exist at ${fullchain_path} and ${privkey_path}, skipping."
  fi
}

# Generate Diffie-Hellman parameters if needed.
# Globals:
# certificates_diffie_hellman_directory
# diffie_hellman_parameter_bit_size
generate_dh_params() {
  local dh_param_path="${certificates_diffie_hellman_directory}/dhparam.pem"
  mkdir -p "${certificates_diffie_hellman_directory}"

  if [[ ${regenerate_diffie_hellman_parameters:-false} == "true" ]] || [[ ! -f ${dh_param_path} ]]; then
    echo "Generating Diffie-Hellman parameters..."
    if ! openssl dhparam -out "${dh_param_path}" "${diffie_hellman_parameter_bit_size}"; then
      echo "Failed to generate DH parameters."
      return 1
    fi
    echo "DH parameters generated at ${dh_param_path}."
  else
    echo "DH parameters already exist at ${dh_param_path}, skipping."
  fi
}

# Interactive prompt for deciding on certificate regeneration.
# Globals:
# auto_install_flag
prompt_for_certificate_regeneration() {
  regenerate_ssl_certificates="false"
  if [[ ${auto_install_flag:-false} != "true" ]]; then
    read -rp "Do you want to regenerate the self-signed certificates? [y/N]: " response
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
      regenerate_ssl_certificates="true"
    else
      echo "Skipping self-signed certificates generation."
    fi
  fi
}

# Prompt for selecting the strength of DH parameters.
# Globals:
# diffie_hellman_parameter_bit_size
prompt_for_dhparam_strength() {

  local diffie_hellman_parameter_choice

  echo "1: Use 2048-bit DH parameters (Faster)"
  echo "2: Use 4096-bit DH parameters (More secure)"
  read -rp "Please enter your choice (1/2): " diffie_hellman_parameter_choice

  case ${diffie_hellman_parameter_choice} in
    1) diffie_hellman_parameter_bit_size=2048 ;;
    2) diffie_hellman_parameter_bit_size=4096 ;;
    *)
      echo "Invalid choice. Please enter 1 or 2."
      prompt_for_dhparam_strength
                                 ;;
  esac
}