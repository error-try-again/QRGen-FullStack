#!/usr/bin/env bash
# bashsupport disable=BP5006

set -euo pipefail

#######################################
# Configures Docker Compose services for HTTP (non-SSL).
# This function sets up necessary port mappings and service definitions
# for running without any SSL certificates.
# Globals:
#   BACKEND_PORT
#   EXPOSED_NGINX_PORT
#   INTERNAL_NGINX_PORT
#   RELEASE_BRANCH
# Arguments:
#  None
#######################################
configure_http() {
  echo "Configuring Docker Compose for HTTP..."

  if [[ ${RELEASE_BRANCH} == "full-release" ]]; then
    backend_ports=$(join_with_commas \
      "ports" \
      "${BACKEND_PORT}:${BACKEND_PORT}")
  fi

  frontend_ports=$(join_with_commas \
      "ports" \
      "${EXPOSED_NGINX_PORT}:${INTERNAL_NGINX_PORT}")
}
