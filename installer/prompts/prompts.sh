#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Globals:
#   google_maps_api_key
#   use_google_api_key
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_google_api_key() {
  if [[ ${use_google_api_key} == "true" ]]; then
    print_multiple_messages "Google API key already set. Skipping prompt."
    return
  fi
  prompt_yes_no "Would you like to use a Google API key? (Will enable google reviews QR Generation)" use_google_api_key
  if [[ ${use_google_api_key} == true ]]; then
    while true; do
      read -rp "Please enter your Google API key (or type 'skip' to skip): " google_maps_api_key
      if [[ -n ${google_maps_api_key} && ${google_maps_api_key} != "skip" ]]; then
        # Proceed with provided API key
        break
      elif [[ ${google_maps_api_key} == "skip" ]]; then
        # User chose to skip entering the API key
        print_multiple_messages "Google API key entry skipped."
        google_maps_api_key="" # Clear the variable if skipping
        break
      else
        # The input was empty, and it's not a skip
        print_multiple_messages "Error: Google API key cannot be empty. Type 'skip' to skip."
      fi
    done
  else
    # User chose not to use a Google API key
    print_multiple_messages "Google API key will not be used."
    google_maps_api_key="" # Ensure variable is empty
  fi
}

readonly welcome_message="QRGen - QR Code Generation Service"
readonly thank_you_message="Task completed!"
readonly select_prompt='Please enter your selection: '
readonly setup_options=("Run Setup" "Uninstall" "Dump logs"
  "Update Project" "Stop Project Docker Containers"
  "Purge Current Builds - Dangerous" "Quit")
readonly invalid_option_message="Invalid option selected."
readonly please_select_option_message="Please select an option from the menu."

#######################################
# description
# Globals:
#   PS3
#   invalid_option_message
#   please_select_option_message
#   select_prompt
#   setup_options
#   thank_you_message
#   welcome_message
# Arguments:
#  None
#######################################
prompt_user() {
  while true; do
    print_multiple_messages "${welcome_message}" "${please_select_option_message}"
    local user_selection
    PS3=${select_prompt}
    select user_selection in "${setup_options[@]}"; do
      if [[ -n ${user_selection} ]]; then
        if prompt_user_selection_switch "${user_selection}"; then
          print_multiple_messages "${thank_you_message}"
        fi
      else
        print_multiple_messages "${invalid_option_message}" "${please_select_option_message}"
      fi
      # Exit the select loop and return to the outer loop, re-displaying the menu
      break
    done
  done
}

#######################################
# description
# Globals:
#   docker_compose_file
#   project_logs_dir
# Arguments:
#   1
#######################################
prompt_user_selection_switch() {
  case $1 in
    "Run Setup") setup ;;
    "Uninstall") uninstall ;;
    "Dump logs") dump_logs "${docker_compose_file}" "${project_logs_dir}" ;;
    "Update Project") update_project ;;
    "Stop Project Docker Containers") stop_containers ;;
    "Purge Current Builds - Dangerous") purge ;;
    "Quit") quit ;;
    *) print_multiple_messages "Invalid selection: $1" ;;
  esac
}

#######################################
# description
# Globals:
#   install_mode_choice
#   release_branch
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_release_install_mode() {
  if [[ ${release_branch} == "minimal-release" ]] || [[ ${release_branch} == "full-release" ]]; then
    return
  fi
  print_multiple_messages "1: Install minimal release (frontend QR generation) (Limited features)"
  print_multiple_messages "2: Install full release (frontend QR generator and backend API/server side generation) (All features)"
  prompt_numeric "Please enter your choice (1/2): " install_mode_choice
  case ${install_mode_choice} in
    1) release_branch="minimal-release" ;;
    2) release_branch="full-release" ;;
    *) print_multiple_messages "Invalid choice. Please enter 1 or 2." ;;
  esac
}

#######################################
# description
# Globals:
#   use_tls_12_flag
#   use_tls_13_flag
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_tls_selection() {
  if [[ ${use_tls_12_flag} == "true" || ${use_tls_13_flag} == "true" ]]; then
    return
  else
    prompt_yes_no "Would you like to enable TLSv1.3? (Recommended): " use_tls_13_flag
    prompt_yes_no "Would you like to enable TLSv1.2?" use_tls_12_flag
  fi
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
prompt_and_validate_input() {
  local prompt_message="$1"
  local error_message="$2"
  local input_value
  while true; do
    read -rp "${prompt_message}" input_value
    if [[ -n ${input_value} ]]; then
      break
    else
      print_multiple_messages "${error_message}"
    fi
  done
}

#######################################
# description
# Globals:
#   auto_install_flag
#   use_letsencrypt
# Arguments:
#  None
# Returns:
#   1 ...
#######################################
prompt_for_letsencrypt() {
  # Guard against auto install
  if [[ ${use_letsencrypt} == "true" ]] || [[ ${auto_install_flag} == "true" ]]; then
    return 1
  fi

  prompt_yes_no "Would you like to use Let's Encrypt?" use_letsencrypt
  if [[ ${use_letsencrypt} == "false" ]]; then
    # Early return here as self-signed certs as managed by another part of the script
    return 1
  else
    prompt_for_letsencrypt_install_type
    prompt_tls_selection
  fi
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
prompt_with_validation() {
  local prompt_message="$1"
  local error_message="$2"
  local user_input=""
  while true; do
    read -rp "${prompt_message}" user_input
    if [[ -n ${user_input} ]]; then
      echo "${user_input}"
      break
    else
      echo "${error_message}"
    fi
  done
}

#######################################
# description
# Globals:
#   auto_install_flag
#   backend_scheme
#   ssl_choice
#   use_ssl_flag
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_ssl() {
  if [[ ${use_ssl_flag} == "true" && ${backend_scheme} == "https" ]]; then
    print_multiple_messages "SSL is already enabled. Skipping SSL prompt."
    return
  elif [[ ${auto_install_flag} == "true" ]]; then
    print_multiple_messages "Auto setup is enabled. Skipping SSL prompt."
    return
  else
    print_multiple_messages "1: Enable SSL"
    print_multiple_messages "2: Do not enable SSL"
    prompt_numeric "Please enter your choice (1/2): " ssl_choice
    case ${ssl_choice} in
      1) enable_ssl ;;
      2) print_multiple_messages "SSL will not be enabled." ;;
      *) print_multiple_messages "Invalid choice, please enter 1 or 2." ;;
    esac
  fi
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
prompt_numeric() {
  local prompt_message=$1
  local var_name=$2
  local input
  read -rp "${prompt_message}" input
  while ! [[ ${input} =~ ^[0-9]+$ ]]; do
    print_multiple_messages "Please enter a valid number."
    read -rp "${prompt_message}" input
  done
  eval "${var_name}"="'${input}'"
}

#######################################
# description
# Globals:
#   disable_docker_build_caching
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_disable_docker_build_cache() {
  if [[ ${disable_docker_build_caching} == "true" ]]; then
    return
  fi
  prompt_yes_no "Would you like to disable Docker build caching for this run?" disable_docker_build_caching
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
prompt_yes_no() {
  local prompt_message="$1"
  local result_var="$2"
  local choice
  while true; do
    read -rp "${prompt_message} [Y/n]: " choice
    case "${choice,,}" in # Convert to lowercase for easier matching
      yes | y)
        eval "${result_var}=true"
        break
        ;;
      no | n)
        eval "${result_var}=false"
        break
        ;;
      "") # Default to 'yes' if the user just presses enter
        eval "${result_var}=true"
        break
        ;;
      *) print_multiple_messages "Invalid input. Please enter 'yes' or 'no'." ;;
    esac
  done
}

#######################################
# description
# Globals:
#   auto_install_flag
#   letsencrypt_automatic_profile
# Arguments:
#  None
#######################################
prompt_for_letsencrypt_install_type() {
  print_multiple_messages "1: Run automatic staging setup for Let's Encrypt SSL (Recommended for testing)"
  print_multiple_messages "2: Run automatic production setup for Let's Encrypt SSL (Recommended for production)"
  print_multiple_messages "3: Run automatic reload of production setup for Let's Encrypt SSL (Keeps existing certificates and reloads server)"
  print_multiple_messages "4: Run custom setup for Let's Encrypt SSL (Advanced)"
  prompt_numeric "Please enter your choice (1/2/3/4): " auto_install_flag
  case ${auto_install_flag} in
    1) automatic_staging_selection "${letsencrypt_automatic_profile}" ;;
    2) automatic_production_selection "${letsencrypt_automatic_profile}" ;;
    3) automatic_production_reload_selection "${letsencrypt_automatic_profile}" ;;
    4) prompt_for_custom_letsencrypt_install ;;
    *) print_multiple_messages "Invalid choice, please enter 1, 2, 3, or 4." ;;
  esac
}

#######################################
# description
# Globals:
#   auto_install_flag
# Arguments:
#  None
#######################################
valid_install_choice() {
  while [[ ${auto_install_flag} -ne 1 && ${auto_install_flag} -ne 2 ]]; do
    print_multiple_messages "Invalid choice, please enter 1 or 2."
    prompt_numeric "Please enter your choice (1/2): " auto_install_flag
  done
}

#######################################
# description
# Globals:
#   auto_install_flag
# Arguments:
#  None
#######################################
prompt_for_auto_install() {
  print_multiple_messages "1: Auto Install" "2: Custom Install"
  prompt_numeric "Please enter your choice (1/2): " auto_install_flag
  valid_install_choice
  if [[ ${auto_install_flag} -eq 1 ]]; then
    enable_auto_install
  elif [[ ${auto_install_flag} -eq 2 ]]; then
    print_multiple_messages "Custom Installation"
  fi
}

#######################################
# description
# Globals:
#   use_gzip_flag
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_gzip() {
  if [[ ${use_gzip_flag} == "true" ]]; then
    return
  fi
  prompt_yes_no "Would you like to enable gzip?" use_gzip_flag
}

#######################################
# description
# Globals:
#   use_self_signed_certs
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_self_signed_certificates() {
  # Guard for automated installs
  if [[ -n ${use_self_signed_certs} && ${use_self_signed_certs} == "true"     ]]; then
    return
  fi
  prompt_yes_no "Would you like to enable self-signed certificates?" use_self_signed_certs
}

#######################################
# description
# Globals:
#   add_another_domain
#   auto_install_flag
#   backend_scheme
#   exposed_nginx_port
#   origin_port
#   use_custom_domain
#   use_subdomain
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_domain_details() {
  # Define an array to hold domain details
  declare -a domain_details=()
  if [[ ${auto_install_flag} == "true" ]]; then
    print_multiple_messages "Skipping domain prompt, auto_install_flag is set to true."
    return
  fi

  #TODO - Modify origin to be specific to the type of service being deployed
  while true; do
    prompt_yes_no "Would you like to specify a domain name other than the default (http://localhost)" use_custom_domain
    if [[ ${use_custom_domain} == "true" ]]; then
      local domain_name
      domain_name=$(prompt_with_validation "Enter your domain name (e.g., example.com): " "Error: Domain name cannot be empty.")
      local origin_url="${backend_scheme}://${domain_name}"
      origin="${origin_url}:${origin_port}"
      prompt_yes_no "Would you like to specify a subdomain for ${domain_name} other than the default (none)" use_subdomain
      if [[ ${use_subdomain} == "true" ]]; then
        local subdomain
        subdomain=$(prompt_with_validation "Enter your subdomain name (e.g., www): " "Error: Subdomain name cannot be empty.")
        origin_url="${backend_scheme}://${subdomain}.${domain_name}"
        origin="${origin_url}:${origin_port}"
      fi
      domain_details+=("${origin}")
      print_multiple_messages "Added domain: ${origin_url}"
    else
      domain_details+=("${backend_scheme}://localhost:${exposed_nginx_port}")
      print_multiple_messages "Added default domain: ${backend_scheme}://localhost:${origin_port}"
    fi
    prompt_yes_no "Would you like to add another domain?" add_another_domain
    if [[ ${add_another_domain} != "true" ]]; then
      break
    fi
  done

  # Display all added domains
  print_multiple_messages "Configured Domains:"
  local domain
  for domain in "${domain_details[@]}"; do
    print_multiple_messages "- ${domain}"
  done
}

#######################################
# description
# Arguments:
#  None
#######################################
prompt_for_custom_letsencrypt_install() {
  prompt_and_validate_input "Please enter your Let's Encrypt email or type 'skip' to skip: " "Error: Email address cannot be empty." letsencrypt_email
  prompt_yes_no "Would you like to use a production SSL certificate?" use_production_ssl
  prompt_yes_no "Would you like to use a dry run?" use_dry_run
  prompt_yes_no "Would you like to force current certificate renewal?" use_force_renew
  prompt_yes_no "Would you like to automatically renew your SSL certificate?" use_auto_renew_ssl
  prompt_yes_no "Would you like to enable HSTS (Recommended)?" use_hsts
  prompt_yes_no "Would you like to enable OCSP Stapling (Recommended)?" use_ocsp_stapling
  prompt_yes_no "Would you like to enable Must Staple (Not Recommended)?" use_must_staple
  prompt_yes_no "Would you like to enable UIR (Unique Identifier for Revocation)?" use_uir
  prompt_yes_no "Would you like to enable Strict Permissions (Not Recommended)?" use_strict_file_permissions
  prompt_yes_no "Would you like to overwrite existing certificates?" use_overwrite_self_signed_certificates
  prompt_yes_no "Would you like to build with Certbot? (Highly Recommended)" build_certbot_image
}

#######################################
# description
# Arguments:
#  None
#######################################
prompt_for_domain_and_letsencrypt() {
  prompt_for_domain_details
  handle_ssl_types
}

#######################################
# description
# Globals:
#   auto_install_flag
#   regenerate_diffie_hellman_parameters
# Arguments:
#  None
# Returns:
#   <unknown> ...
#######################################
prompt_for_dh_param_regeneration() {
  # If auto install is enabled, don't prompt the user.
  if [[ ${auto_install_flag} == "true" ]]; then
    return
  fi
  read -rp "Do you want to regenerate the DH parameters? [y/N]: " response
  if [[ ${response} =~ ^([yY][eE][sS]|[yY])$   ]]; then
    regenerate_diffie_hellman_parameters="true"
  else
    regenerate_diffie_hellman_parameters="false"
    print_multiple_messages "Skipping DH parameters generation."
  fi
}

#######################################
# description
# Globals:
#   backend_scheme
#   use_ssl_flag
# Arguments:
#  None
#######################################
enable_ssl() {
  use_ssl_flag=true
  backend_scheme="https"
}

#######################################
# description
# Globals:
#   auto_install_flag
# Arguments:
#  None
#######################################
enable_auto_install() {
  auto_install_flag=true
}