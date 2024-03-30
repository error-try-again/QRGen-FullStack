#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Globals:
#   auto_install_flag
#   backend_directory
#   backend_dockerfile
#   backend_scheme
#   backend_submodule_url
#   build_certbot_image
#   certbot_dir
#   diffie_hellman_parameters_file
#   disable_docker_build_caching
#   dns_resolver
#   docker_compose_file
#   exposed_nginx_port
#   express_port
#   frontend_dir
#   frontend_dockerfile
#   frontend_dotenv_file
#   frontend_submodule_url
#   google_maps_api_key
#   install_profile
#   mime_types_path
#   nginx_conf_path
#   nginx_configuration_file
#   nginx_mime_types_file
#   nginx_version
#   node_version
#   project_logs_dir
#   project_root_dir
#   release_branch
#   robots_file
#   robots_path
#   service_to_standard_config_map
#   sitemap_path
#   sitemap_xml
#   timeout
#   use_google_api_key
#   use_gzip_flag
#   use_hsts
#   use_letsencrypt
#   use_ocsp_stapling
#   use_self_signed_certs
#   use_ssl_flag
#   use_tls_12_flag
#   use_tls_13_flag
# Arguments:
#  None
#######################################
setup() {
  # Creates a base directory structure for the project
  setup_directory_structure \
  "${frontend_dir}" \
  "${backend_directory}" \
  "${certbot_dir}" \
  "${project_logs_dir}"

  # Initialize the rootless Docker environment if it is not already initialized
  initialize_rootless_docker

  # TODO: patch this to make it effective - supposed to ensure the port is available for each service
#  ensure_port_is_available \
#  "${exposed_nginx_port}" \
#  "auto"

  # Specify the installation procedure
  handle_auto_install \
  "${auto_install_flag}" \
  "${use_letsencrypt}" \
  "${install_profile}" \
  "${project_root_dir}"

  # TODO: fix the following hardcoding
  local domain sitemap_path robots_path frontend_dotenv_file nginx_version
  domain="localhost"
  sitemap_path="frontend/sitemap.xml"
  robots_path="frontend/robots.txt"
  frontend_dotenv_file="frontend/.env"
  nginx_version="stable-alpine3.17-slim"

  # Generates the sitemap.xml file for the website to be indexed by search engines - ${backend_scheme}://${domain} is used as the origin
  generate_sitemap \
  "${backend_scheme}://${domain}" \
  "${sitemap_path}"

  # Generates the robots.txt file for the website to be indexed by search engines
  generate_robots \
  "${robots_file}"

  # Generates the nginx mime.types file for the nginx server
  generate_nginx_mime_types \
  "${nginx_mime_types_file}"

  # Generates the dotenv responsible for passing variables to the frontend
  generate_frontend_dotenv \
  "${frontend_dotenv_file}" \
  "${use_google_api_key}"

  # Generates the backend Dockerfile responsible for building the backend image
  generate_backend_dockerfile \
  "${backend_dockerfile}" \
  "${backend_submodule_url}" \
  "${node_version}" \
  "${release_branch}" \
  "${express_port}" \
  "${use_ssl_flag}" \
  "${google_maps_api_key}" \
  "${backend_scheme}://${domain}" \
  "${domain}"

  # Generates the frontend Dockerfile responsible for building the frontend image
  generate_frontend_dockerfile \
  "${frontend_dockerfile}" \
  "${frontend_submodule_url}" \
  "${node_version}" \
  "${release_branch}" \
  "${use_google_api_key}" \
  "${sitemap_path}" \
  "${robots_path}" \
  "${nginx_conf_path}" \
  "${mime_types_path}" \
  "${nginx_version}"

  [[ ${build_certbot_image} == "true" ]] && generate_certbot_dockerfile

  # Generates the docker-compose file responsible for orchestrating the services
  generate_docker_compose \
  "${docker_compose_file}" \
  "${service_to_standard_config_map[@]}"

  # Generates the nginx configuration file responsible for routing requests to the backend and frontend
  generate_nginx_configuration \
  "${backend_scheme}" \
  "${diffie_hellman_parameters_file}" \
  "${dns_resolver}" \
  "${nginx_configuration_file}" \
  "${release_branch}" \
  "${timeout}" \
  "${use_gzip_flag}" \
  "${use_hsts}" \
  "${use_letsencrypt}" \
  "${use_ocsp_stapling}" \
  "${use_self_signed_certs}" \
  "${use_tls_12_flag}" \
  "${use_tls_13_flag}" \

  # Pools the services and builds the images using docker compose
  build_and_run_docker \
  "${build_certbot_image}" \
  "${docker_compose_file}" \
  "${project_logs_dir}" \
  "${project_root_dir}" \
  "${release_branch}" \
  "${disable_docker_build_caching}"
}