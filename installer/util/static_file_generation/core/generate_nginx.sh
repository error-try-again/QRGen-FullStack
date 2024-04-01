#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Arguments:
#   1
#   2
#######################################
echo_indented() {
  local level=$1
  local message=$2

  printf '%*s%s\n' "${level}" '' "${message}"
}

#######################################
# description
# Arguments:
#   1
#######################################
configure_server_name() {
  local domain="${1}"
  echo_indented 8 "server_name ${domain};"
}

#######################################
# description
# Arguments:
#   1
#   2
#   3
#   4
#   5
#######################################
configure_https() {
  local nginx_ssl_port="${1:-443}"
  local dns_resolver="${2:-1.1.1.1}"
  local timeout="${3:-5}"
  local use_letsencrypt="${4:-false}"
  local use_self_signed_certs="${5:-false}"

  echo_indented 8 "listen ${nginx_ssl_port} ssl;"
  echo_indented 8 "listen [::]:${nginx_ssl_port} ssl;"

  if [[ ${use_letsencrypt} == "true" || ${use_self_signed_certs} == "true"     ]]; then
    echo_indented 8 "resolver ${dns_resolver} valid=${timeout}s;"
    echo_indented 8 "resolver_timeout ${timeout}s;"
  fi
}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
configure_ssl_mode() {
  local use_tls_12="${1:-false}"
  local use_tls_13="${2:-true}"
  local protocols=()

  [[ ${use_tls_12} == "true"   ]] && protocols+=("TLSv1.2")
  [[ ${use_tls_13} == "true"   ]] && protocols+=("TLSv1.3")

  if [[ ${#protocols[@]} -gt 0 ]]; then
    echo_indented 8 "ssl_protocols ${protocols[*]};"
  fi
}

#######################################
# description
# Arguments:
#   1
#######################################
get_gzip() {
  local use_gzip_flag="${1:-false}"

  if [[ ${use_gzip_flag} == "true" ]]; then
    echo_indented 4 "gzip on;"
    echo_indented 4 "gzip_comp_level 6;"
    echo_indented 4 "gzip_vary on;"
    echo_indented 4 "gzip_min_length 256;"
    echo_indented 4 "gzip_proxied any;"
    echo_indented 4 "gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;"
  else
    echo_indented 4 "gzip off;"
  fi
}

#######################################
# description
# Arguments:
#   1
#   2
#   3
#   4
#######################################
configure_ssl_settings() {
  local diffie_hellman_parameters_file="${1:-}"
  local use_letsencrypt="${2:-false}"
  local use_ocsp_stapling="${3:-false}"
  local use_self_signed_certs="${4:-false}"

  if [[ ${use_letsencrypt:-false} == "true" ]] || [[ ${use_self_signed_certs:-false} == "true"  ]]; then
    echo_indented 8 "ssl_prefer_server_ciphers on;"
    echo_indented 8 "ssl_ciphers 'ECDH+AESGCM:ECDH+AES256:!DH+3DES:!ADH:!AECDH:!MD5:!ECDHE-RSA-AES256-SHA384:!ECDHE-RSA-AES256-SHA:!ECDHE-RSA-AES128-SHA256:!ECDHE-RSA-AES128-SHA:!RC2:!RC4:!DES:!EXPORT:!NULL:!SHA1';"
    echo_indented 8 "ssl_buffer_size 8k;"
    echo_indented 8 "ssl_ecdh_curve secp384r1;"
    echo_indented 8 "ssl_session_cache shared:SSL:10m;"
    echo_indented 8 "ssl_session_timeout 10m;"

    if [[ -n ${diffie_hellman_parameters_file:-}   ]]; then
      echo_indented 8 "ssl_dhparam ${diffie_hellman_parameters_file};"
    fi

    if [[ ${use_ocsp_stapling:-false} == "true"   ]]; then
      echo_indented 8 "ssl_stapling on;"
      echo_indented 8 "ssl_stapling_verify on;"
    fi
  fi
}

#######################################
# description
# Arguments:
#   1
#######################################
configure_certs() {
  local domain="${1}"
  echo_indented 8 "ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;"
  echo_indented 8 "ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;"
  echo_indented 8 "ssl_trusted_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;"
}

#######################################
# description
# Arguments:
#   1
#######################################
configure_security_headers() {
  local use_hsts="${1}"

  echo_indented 8 "add_header X-Frame-Options 'DENY' always;"
  echo_indented 8 "add_header X-Content-Type-Options nosniff always;"
  echo_indented 8 "add_header X-XSS-Protection '1; mode=block' always;"
  echo_indented 8 "add_header Referrer-Policy 'strict-origin-when-cross-origin' always;"
  echo_indented 8 "add_header Content-Security-Policy \"default-src 'self'; object-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://*.tile.openstreetmap.org; media-src 'none'; frame-src 'none'; font-src 'self'; connect-src 'self';\";"
  if [[ ${use_hsts} == "true"   ]]; then
    echo_indented 8 "add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains' always;"
  fi
}

#######################################
# description
# Arguments:
#   1
#######################################
configure_acme_location_block() {
  local use_letsencrypt="${1}"

  if [[ ${use_letsencrypt} == "true"   ]]; then
    echo_indented 8 "location ^~ /.well-known/acme-challenge/ {"
    echo_indented 12 "allow all;"
    echo_indented 12 "root /usr/share/nginx/html;"
    echo_indented 12 "try_files \$uri =404;"
    echo_indented 8 "}"
  fi

}

#######################################
# description
# Arguments:
#   1
#   2
#######################################
configure_local_redirect() {
  local use_letsencrypt="${1}"
  local domain="${2}"

  if [[ ${use_letsencrypt:-false} == "true" ]] || [[ ${use_self_signed_certs:-false} == "true"   ]]; then
    echo_indented 4 "server {"
    echo_indented 8 "listen 80;"
    echo_indented 8 "listen [::]:80;"
    echo_indented 8 "server_name ${domain};"
    configure_acme_location_block "${use_letsencrypt}"
    echo_indented 8 "location / {"
    echo_indented 12 "return 301 https://\$host\$request_uri;"
    echo_indented 8 "}"
    echo_indented 4 "}"
  fi
}

#######################################
# description
# Arguments:
#  None
#######################################
generate_listen_directives() {
  local ports=("$@") # Expand passed ports into an array

  local port_mapping
  for port_mapping in "${ports[@]}"; do
    local host_port container_port
    host_port=$(echo "$port_mapping" | cut -d ":" -f1)
    container_port=$(echo "$port_mapping" | cut -d ":" -f2)

    if [[ ${container_port} == "80" ]] || [[ ${container_port} == "443" ]]; then
      echo_indented 8 "listen $host_port;"
      echo_indented 8 "listen [::]:$host_port;"
    fi
  done
}

#######################################
# description
# Arguments:
#   1
#   2
#   3
#   4
#   5
#   6
#   7
#   8
#######################################
configure_additional_ssl_settings() {
  local dns_resolver="${1:-}"
  local timeout="${2:-5}"
  local use_hsts="${3:-false}"
  local use_letsencrypt="${4:-false}"
  local use_self_signed_certs="${5:-false}"
  local use_tls_12_flag="${6:-false}"
  local use_tls_13_flag="${7:-true}"
  local domain="${8}"

  local nginx_ssl_port="443"

  if [[ ${use_letsencrypt:-false} == "true" ]] || [[ ${use_self_signed_certs:-false} == "true"   ]]; then
    configure_https "${nginx_ssl_port:-443}" "${dns_resolver:-1.1.1.1}" "${timeout:-5}" "${use_letsencrypt:-false}" "${use_self_signed_certs:-false}"
    configure_ssl_mode "${use_tls_12_flag:-false}" "${use_tls_13_flag:-true}"
    configure_certs "${domain}"
    configure_security_headers "${use_hsts:-false}"
  fi
}

#######################################
# description
# Arguments:
#  None
#######################################
generate_default_location_block() {
  # Location block for static content
  echo_indented 8 "location / {"
  echo_indented 12 "root /usr/share/nginx/html;"
  echo_indented 12 "index index.html index.htm;"
  echo_indented 12 "try_files \$uri \$uri/ /index.html;"
  echo_indented 12 "expires 1y;"
  echo_indented 12 "add_header Cache-Control public;"
  echo_indented 12 "access_log /usr/share/nginx/logs/access.log;"
  echo_indented 12 "error_log /usr/share/nginx/logs/error.log warn;"
  echo_indented 8 "}"
}

#######################################
# description
# Arguments:
#  None
#######################################
generate_default_file_location() {
  echo_indented 8 "location /robots.txt {"
  echo_indented 12 "root /usr/share/nginx/html;"
  echo_indented 8 "}"

  echo_indented 8 "location /sitemap.xml {"
  echo_indented 12 "root /usr/share/nginx/html;"
  echo_indented 8 "}"
}

#######################################
# description
# Arguments:
#   1
#   2
#   3
#   4
#   5
#   6
#######################################
write_endpoints() {
  local service_name="${1}"
  local port="${2}"
  local backend_scheme="${3}"
  local release_branch="${4}"
  local location="${5}"
  local service_name="${6}"

  if [[ ${release_branch} == "full-release" && ${service_name} != "nginx" ]]; then
     echo_indented 8 "location ${location:-/} {"
     echo_indented 12 "proxy_pass ${backend_scheme}://${service_name}:${port};"
     echo_indented 12 "proxy_set_header Host \$host;"
     echo_indented 12 "proxy_set_header X-Real-IP \$remote_addr;"
     echo_indented 12 "proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
     echo_indented 8 "}"
  fi
}

#######################################
# description
# Arguments:
#  None
#######################################
write_nginx_workers() {
    echo "worker_processes auto;"
    echo "events { worker_connections 1024; }"
    echo ""
}

#######################################
# description
# Arguments:
#   1
#######################################
write_include_directive() {
  local include_file="${1}"

  echo_indented 4 "include ${include_file};"
}

#######################################
# description
# Arguments:
#   1
#######################################
write_default_type() {
   local default_type="${1}"
   echo_indented 4 "default_type ${default_type};"
}

#######################################
# description
# Arguments:
#  None
#######################################
write_nginx_server_opening_configuration() {
  echo_indented 4 "server {"
}

#######################################
# description
# Arguments:
#  None
#######################################
write_nginx_server_close_configuration() {
  echo_indented 4 "}"
}

#######################################
# description
# Arguments:
#  None
#######################################
write_nginx_http_opening_configuration() {
  echo_indented 0 "http {"
}

#######################################
# description
# Arguments:
#  None
#######################################
write_nginx_http_closing_configuration() {
  echo_indented 0 "}"
}

#######################################
# description
# Arguments:
#   1
#######################################
prepare_nginx_configuration_file() {
  local nginx_configuration_file="${1}"

  if [[ ! -f ${nginx_configuration_file} ]]; then
    echo "Creating NGINX configuration file at ${nginx_configuration_file}"
    mkdir -p "$(dirname "${nginx_configuration_file}")"
    touch "${nginx_configuration_file}"
  fi
}

#######################################
# description
# Globals:
#   use_gzip_flag
# Arguments:
#   1
#######################################
initialize_http_block() {
  local nginx_configuration_file="${1}"

  # Initialize HTTP block
  {
    write_nginx_workers
    write_nginx_http_opening_configuration
    write_include_directive "/etc/nginx/mime.types"
    write_default_type "application/octet-stream"
    get_gzip "${use_gzip_flag:-false}"
  } > "${nginx_configuration_file}"
}

#######################################
# description
# Arguments:
#   1
#   10
#   11
#   12
#   13
#   14
#   2
#   3
#   4
#   5
#   6
#   7
#   8
#   9
#######################################
generate_nginx_configuration() {
  local backend_scheme="${1}"
  local diffie_hellman_parameters_file="${2}"
  local dns_resolver="${3}"
  local nginx_configuration_file="${4}"
  local release_branch="${5}"
  local timeout="${6}"
  local use_gzip_flag="${7}"
  local use_hsts="${8}"
  local use_letsencrypt="${9}"
  local use_ocsp_stapling="${10}"
  local use_self_signed_certs="${11}"
  local use_tls_12_flag="${12}"
  local use_tls_13_flag="${13}"

  # Initialize and backup the NGINX config file
  prepare_nginx_configuration_file "${nginx_configuration_file}"
  backup_existing_file "${nginx_configuration_file}"

  # Start writing out the HTTP block of the NGINX configuration
  initialize_http_block "${nginx_configuration_file}"

  # Prepare an associative array to map domains to their services
  declare -A domain_to_services_map

  # Loop through service configurations to populate domain to service map
  local service_config
  for service_config in "${service_to_standard_config_map[@]}"; do
    local domains=$(echo "${service_config}" | jq -r '.domains[]')
    local name=$(echo "${service_config}" | jq -r '.name')

    for domain in $domains; do
      domain_to_services_map["$domain"]+="$name "
    done
  done

  # Configure server blocks for each domain
  for domain in "${!domain_to_services_map[@]}"; do
    local service_names=(${domain_to_services_map[${domain}]})

    {
      write_nginx_server_opening_configuration

      # Configure server name and SSL settings
      configure_server_name \
        "${domain}"

      # Configure server-specific SSL settings and security headers
      configure_additional_ssl_settings \
        "${dns_resolver}" \
        "${timeout}" \
        "${use_hsts}" \
        "${use_letsencrypt}" \
        "${use_self_signed_certs}" \
        "${use_tls_12_flag}" \
        "${use_tls_13_flag}" \
        "${domain}"

      # Configure SSL certificate paths and OCSP stapling
      configure_ssl_settings \
        "${diffie_hellman_parameters_file}" \
        "${use_letsencrypt}" \
        "${use_ocsp_stapling}" \
        "${use_self_signed_certs}"

      # Generate default and file-specific location blocks
      generate_default_location_block
      generate_default_file_location

      # Handle unique service locations within the same domain
      local locations_seen=()
      local service_name
      for service_name in "${service_names[@]}"; do

        local service_config="${service_to_standard_config_map[${service_name}]}"
        local locations=$(echo "${service_config}" | jq -r '.locations[] // empty')

        local port ports
        # Extract port mappings for the service
        mapfile -t ports < <(echo "${service_config}" | jq -r '.ports[]')

        # Extract the external port for the service
        port=$(echo "${ports[0]}" | cut -d ":" -f1)

        local location
        for location in ${locations}; do
          if [[ ! " ${locations_seen[*]} " =~ " ${location} " ]]; then
            locations_seen+=("${location}")

            # Write endpoint configuration for each service location
            write_endpoints \
              "${service_name}" \
              "${port}" \
              "${backend_scheme}" \
              "${release_branch}" \
              "${location}" \
              "${service_name}"
          fi
        done
      done

      # Configure ACME challenge location for LetsEncrypt
      configure_acme_location_block "${use_letsencrypt}"

      # Close the HTTP block of the NGINX configuration
      write_nginx_server_close_configuration

    } >> "${nginx_configuration_file}"
  done

  # Finalize the HTTP block of the configuration
  {
    write_nginx_http_closing_configuration
  } >> "${nginx_configuration_file}"

  echo "NGINX configuration successfully written to ${nginx_configuration_file}"
}