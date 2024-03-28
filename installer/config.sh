#!/usr/bin/env bash

set -euo pipefail

#######################################
# Source defaults for global configuration variables.
# Globals:
#   auto_install_flag
#   backend_directory
#   backend_dockerfile
#   backend_dotenv_file
#   backend_scheme
#   backend_submodule_url
#   backend_upstream_name
#   build_certbot_image
#   certbot_base_image
#   certbot_dir
#   certbot_dockerfile
#   certbot_repo
#   certificates_diffie_hellman_directory
#   certs_diffie_hellman_volume_mapping
#   certs_dir
#   challenge_port
#   diffie_hellman_parameter_bit_size
#   diffie_hellman_parameters_file
#   disable_docker_build_caching
#   dns_resolver
#   docker_compose_file
#   domain_name
#   exposed_nginx_port
#   express_port
#   frontend_dir
#   frontend_dockerfile
#   frontend_dotenv_file
#   frontend_submodule_url
#   google_maps_api_key
#   install_profile
#   internal_certificates_diffie_hellman_directory
#   internal_nginx_port
#   internal_webroot_dir
#   letsencrypt_automatic_profile
#   letsencrypt_email
#   letsencrypt_logs_volume_mapping
#   letsencrypt_volume_mapping
#   nginx_configuration_file
#   nginx_ssl_port
#   no_eff_email_flag
#   node_version
#   non_interactive_flag
#   origin
#   origin_port
#   origin_url
#   project_logs_dir
#   project_root_dir
#   regenerate_diffie_hellman_parameters
#   regenerate_ssl_certificates
#   release_branch
#   robots_file
#   rsa_key_size
#   rsa_key_size_flag
#   sitemap_xml
#   subdomain
#   terms_of_service_flag
#   timeout
#   use_auto_renew_ssl
#   use_custom_domain
#   use_dry_run
#   use_force_renew
#   use_google_api_key
#   use_gzip_flag
#   use_hsts
#   use_letsencrypt
#   use_must_staple
#   use_ocsp_stapling
#   use_overwrite_self_signed_certificates
#   use_production_ssl
#   use_self_signed_certs
#   use_ssl_flag
#   use_strict_file_permissions
#   use_tls_12_flag
#   use_tls_13_flag
#   use_uir
#   webroot_dir
# Arguments:
#  None
#######################################
source_global_configurations() {
  # ------------------
  # Local Configurations
  # ------------------
  local internal_certificates_diffie_hellman_directory="/etc/ssl/certs/dhparam"

  # ---------------
  # Server Configs
  # ---------------
  export express_port=3001
  export exposed_nginx_port=8080
  export internal_nginx_port=80
  export nginx_ssl_port=443
  export challenge_port=80
  export dns_resolver=8.8.8.8
  export node_version=latest
  export timeout=5

  # -------------------------------
  # Domain and Origin Configuration
  # -------------------------------
  export domain_name=localhost
  export subdomain=www
  export backend_scheme=http
  export origin_url="${backend_scheme}://${domain_name}"
  export origin_port="${exposed_nginx_port}"
  export origin="${origin_url}:${origin_port}"
  export auto_install_flag=false

  # ------------------------
  # General SSL Configuration
  # ------------------------
  export use_ssl_flag=false
  export use_self_signed_certs=false
  export regenerate_ssl_certificates=false
  export regenerate_diffie_hellman_parameters=false

  # LetsEncrypt Configurations
  export letsencrypt_email=""
  export use_auto_renew_ssl=false
  export use_overwrite_self_signed_certificates=false
  export use_force_renew=false
  export use_letsencrypt=false
  export use_production_ssl=false
  export use_hsts=false
  export use_ocsp_stapling=false
  export use_must_staple=false
  export use_uir=false
  export use_dry_run=false
  export use_custom_domain=false
  export use_strict_file_permissions=false

  # LetsEncrypt Flags
  export terms_of_service_flag=--agree-tos
  export no_eff_email_flag=--no-eff-email
  export non_interactive_flag=--non-interactive
  export rsa_key_size=4096
  export rsa_key_size_flag="--rsa-key-size $rsa_key_size"

  # TLS version usage
  export use_tls_13_flag=false
  export use_tls_12_flag=false

  # Nginx Configurations
  export use_gzip_flag=false

  # ------------------
  # Certbot Image Configs
  # ------------------
  export build_certbot_image=false
  export certbot_base_image=python:3.10-alpine3.16
  export certbot_repo=https://github.com/error-try-again/certbot/archive/refs/heads/master.zip

  # ------------------
  # Directory Structure
  # ------------------
  export project_root_dir
  project_root_dir="$(pwd)"
  export project_logs_dir="${project_root_dir}/logs"
  export backend_directory="${project_root_dir}/backend"
  export frontend_dir="${project_root_dir}/frontend"
  export certbot_dir="${project_root_dir}/certbot"
  export internal_webroot_dir="/usr/share/nginx/html"

  # ------------------
  # File Configurations
  # ------------------
  export nginx_configuration_file="${project_root_dir}/nginx/nginx.conf"
  export nginx_mime_types_file="${project_root_dir}/nginx/mime.types"
  export docker_compose_file="${project_root_dir}/docker-compose.yml"
  export backend_dotenv_file="${backend_directory}/.env"
  export backend_dockerfile="${backend_directory}/Dockerfile"
  export frontend_dockerfile="${frontend_dir}/Dockerfile"
  export frontend_dotenv_file="${frontend_dir}/.env"
  export certbot_dockerfile="${certbot_dir}/Dockerfile"
  export robots_file="${frontend_dir}/robots.txt"
  export sitemap_xml="${frontend_dir}/sitemap.xml"

  # ------------------
  # Docker Specific
  # ------------------
  export disable_docker_build_caching=false

  # ------------------
  # Google API Configs
  # ------------------
  export use_google_api_key=false
  export google_maps_api_key=""

  # ------------------
  # Submodule Configs
  # ------------------
  export release_branch=full-release
  export frontend_submodule_url=https://github.com/error-try-again/QRGen-frontend.git
  export backend_submodule_url=https://github.com/error-try-again/QRGen-backend.git

  # ------------------
  # Volume Mappings
  # ------------------
  export certs_dir="${project_root_dir}/certs/live"
  export certificates_diffie_hellman_directory="${certs_dir}/dhparam"
  export letsencrypt_volume_mapping="${certs_dir}:/etc/letsencrypt"
  export letsencrypt_logs_volume_mapping="${certbot_dir}/logs:/var/log/letsencrypt"
  export diffie_hellman_parameters_file="${internal_certificates_diffie_hellman_directory}/dhparam.pem"
  export certs_diffie_hellman_volume_mapping="${certificates_diffie_hellman_directory}:${internal_certificates_diffie_hellman_directory}"

  # ------------------
  # JSON Install Configs
  # ------------------
  export install_profile=profiles/main_install_profiles.json
  export letsencrypt_automatic_profile=profiles/le_auto_profiles.json

  export diffie_hellman_parameter_bit_size=
}