#!/usr/bin/env bash

set -euo pipefail

source_global_configurations() {
  # ------------------
  # Local Configurations
  # ------------------
  local internal_certificates_diffie_hellman_directory="/etc/ssl/certs/dhparam"

  # -------------------------------
  # Domain and Origin Configuration
  # -------------------------------
  export backend_scheme=http
  export auto_install_flag=false

  # ------------------------
  # General SSL Configuration
  # ------------------------
  export use_ssl_flag=false
  export use_self_signed_certs=false
  export regenerate_ssl_certificates=false
  export regenerate_diffie_hellman_parameters=false

  # LetsEncrypt Configurations
  export use_letsencrypt=false
  export use_hsts=false
  export use_ocsp_stapling=false
  export use_custom_domain=false

  # LetsEncrypt Flags
  export rsa_key_size=4096

  # TLS version usage
  export use_tls_13_flag=false
  export use_tls_12_flag=false

  # Nginx Configurations
  export use_gzip_flag=false

  # ------------------
  # Certbot Image Configs
  # ------------------
  export build_certbot_image=false
  export certbot_repo=https://github.com/error-try-again/certbot/archive/refs/heads/master.zip

  # ------------------
  # Directory Structure
  # ------------------
  export project_root_dir
  project_root_dir="$(pwd)"
  local project_logs_dir="${project_root_dir}/logs"
  local backend_directory="${project_root_dir}/backend"
  local frontend_dir="${project_root_dir}/frontend"
  local certbot_dir="${project_root_dir}/certbot"
  local prometheus_dir="${project_root_dir}/prometheus/config"
  export project_dir_array=("${backend_directory}" "${frontend_dir}" "${certbot_dir}" "${project_logs_dir}" "${prometheus_dir}")

  # ------------------
  # File Configurations
  # ------------------
  export docker_compose_file="${project_root_dir}/docker-compose.yml"
  export nginx_configuration_file="${project_root_dir}/nginx/nginx.conf"
  export nginx_mime_types_file="${project_root_dir}/nginx/mime.types"
  export backend_dockerfile="${backend_directory}/Dockerfile"
  export frontend_dockerfile="${frontend_dir}/Dockerfile"
  export certbot_dockerfile="${certbot_dir}/Dockerfile"
  export robots_file="${frontend_dir}/robots.txt"
  export prometheus_yml_path="${prometheus_dir}/prometheus.yml"

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
  export diffie_hellman_parameters_file="${internal_certificates_diffie_hellman_directory}/dhparam.pem"

  # ------------------
  # JSON Install Configs
  # ------------------
  export install_profile=profiles/main_install_profiles.json

  # ------------------
  # Frontend Dockerfile
  # ------------------
  export nginx_version="latest"
  export sitemap_path="frontend/sitemap.xml"
  export robots_path="frontend/robots.txt"
  export nginx_conf_path="nginx/nginx.conf"
  export mime_types_path="nginx/mime.types"
}