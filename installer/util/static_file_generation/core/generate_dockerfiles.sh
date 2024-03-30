#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Globals:
#   HOME
#   certbot_base_image
#   certbot_dockerfile
#   certbot_repo
# Arguments:
#  None
#######################################
generate_certbot_dockerfile() {
  print_multiple_messages "Configuring the Docker Certbot Image..."

  local base_image="python:3.10-alpine3.16 as certbot"
  local entrypoint='[ "certbot" ]'
  local expose="80 443"
  local volumes="/etc/letsencrypt /var/lib/letsencrypt"
  local workdir="/opt/certbot"
  local cargo_net_git_fetch_with_cli="true"
  local certbot_repo=https://github.com/error-try-again/certbot/archive/refs/heads/master.zip

  backup_existing_file "${certbot_dockerfile}"

cat << EOF > "${certbot_dockerfile}"
FROM ${base_image}

WORKDIR ${workdir}
VOLUME ${volumes}
EXPOSE ${expose}
ENTRYPOINT ${entrypoint}

RUN apk update && apk add --no-cache wget unzip

RUN mkdir -p src

RUN wget -O certbot-master.zip ${certbot_repo} \
 && unzip certbot-master.zip \
 && cp certbot-master/CHANGELOG.md certbot-master/README.rst src/ \
 && cp -r certbot-master/tools tools \
 && cp -r certbot-master/acme src/acme \
 && cp -r certbot-master/certbot src/certbot \
 && rm -rf certbot-master.zip certbot-master

# Additional dependencies may be required for certbot
RUN apk add --no-cache --virtual .certbot-deps \
        libffi \
        libssl1.1 \
        openssl \
        ca-certificates \
        binutils

ARG CARGO_NET_GIT_FETCH_WITH_CLI=${cargo_net_git_fetch_with_cli}

# Assuming you need to compile Python dependencies with native extensions
RUN apk add --no-cache --virtual .build-deps \
        gcc \
        linux-headers \
        openssl-dev \
        musl-dev \
        libffi-dev \
        python3-dev \
        cargo \
        git \
        pkgconfig \
 && python3 -m pip install --upgrade pip \
 && pip install --no-cache-dir --editable ./src/acme --editable ./src/certbot \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/* /root/.cache
EOF

  print_multiple_messages "Dockerfile configured successfully at ${certbot_dockerfile}"
}

#######################################
# Take the variable value and the variable name and validate that the variable is not empty
# Arguments:
#   $1 - The variable value
#   $2 - The variable name
#######################################
validate_argument_exists() {
  if [[ -z ${1} ]]; then
    print_message "${2} is not initialized"
    exit 1
  fi
}

#######################################
# description
# Globals:
#   arg_name
#   backend_dockerfile
#   backend_submodule_url
#   google_maps_api_key
#   node_version
#   origin
#   port
#   release_branch
#   use_ssl_flag
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
generate_backend_dockerfile() {
  declare -A args=(
      [backend_dockerfile]="${1}"
      [backend_submodule_url]="${2}"
      [node_version]="${3}"
      [release_branch]="${4}"
      [port]="${5}"
      [use_ssl_flag]="${6}"
      [google_maps_api_key]="${7}"
      [origin]="${8}"
  )

  for arg_name in "${!args[@]}"; do
    if [[ ${arg_name} == "google_maps_api_key"   ]]; then
      continue
    fi
    validate_argument_exists "${args[$arg_name]}" "$arg_name"
  done


  # Git origin for the release branch is the release branch itself, not the origin used for CORS requests. Naming is hard
  local git_origin
  git_origin="origin"/"${release_branch}"

  print_message "Configuring the Docker Backend at ${args[backend_dockerfile]}..."
  backup_existing_file "${args[backend_dockerfile]}"

  cat << EOF > "${args[backend_dockerfile]}"
FROM node:${args[node_version]}

WORKDIR /usr/app

RUN git init && \
    git submodule add --force "${args[backend_submodule_url]}" backend && \
    git submodule update --init --recursive

WORKDIR /usr/app/backend

RUN git fetch --all && \
    git reset --hard "${git_origin}" && \
    git checkout "${args[release_branch]}"

RUN yarn install

ENV ORIGIN=${args[origin]}
ENV USE_SSL=${args[use_ssl_flag]}
ENV GOOGLE_MAPS_API_KEY=${args[google_maps_api_key]}

EXPOSE ${args[port]}

CMD ["npx", "ts-node", "/usr/app/backend/src/server.ts"]

EOF
  print_message "Successfully generated Dockerfile at ${args[backend_dockerfile]}"
}

#######################################
# description
# Globals:
#   arg_name
#   exposed_nginx_port
#   frontend_dockerfile
#   frontend_submodule_url
#   mime_types_path
#   nginx_conf_path
#   node_version
#   release_branch
#   sitemap_path
#   use_google_api_key
# Arguments:
#   1
#   10
#   11
#   2
#   3
#   4
#   5
#   6
#   7
#   8
#   9
#######################################
generate_frontend_dockerfile() {
  declare -A args=(
       [frontend_dockerfile]="${1}"
       [frontend_submodule_url]="${2}"
       [node_version]="${3}"
       [release_branch]="${4}"
       [use_google_api_key]="${5}"
       [sitemap_path]="${6}"
       [robots_path]="${7}"
       [nginx_conf_path]="${8}"
       [mime_types_path]="${9}"
       [nginx_version]="${10}"
  )

  for arg_name in "${!args[@]}"; do
    validate_argument_exists "${args[$arg_name]}" "${arg_name}"
  done

  print_message "Configuring the frontend Docker environment..."
  backup_existing_file "${args[frontend_dockerfile]}"
  print_message "Configuring Dockerfile at ${args[frontend_dockerfile]}"
  cat << EOF > "${args[frontend_dockerfile]}"
FROM node:${args[node_version]} as build

WORKDIR /usr/app

RUN git init && \
    (if [ ! -d "frontend" ]; then \
        git submodule add --force "${args[frontend_submodule_url]}" frontend; \
    fi) && \
    git submodule update --init --recursive

WORKDIR /usr/app/frontend

RUN git fetch --all && \
    git reset --hard "origin/${args[release_branch]}" && \
    git checkout "${args[release_branch]}"

RUN yarn install

RUN (if [ "${args[use_google_api_key]}" = "true" ]; then \
        sed -i'' -e 's/export const googleSdkEnabled = false;/export const googleSdkEnabled = true;/' src/config.tsx; \
    fi)

# Run npm build in the correct directory
RUN npm run build

# Verify the dist directory
RUN ls -la dist

FROM nginx:${args[nginx_version]}

# Install curl for debugging
RUN apk add --no-cache curl

COPY ${args[sitemap_path]} /usr/share/nginx/html/sitemap.xml
COPY ${args[robots_path]} /usr/share/nginx/html/robots.txt

COPY ${args[nginx_conf_path]} /etc/nginx/nginx.conf
COPY ${args[mime_types_path]} /etc/nginx/mime.types

COPY --from=build /usr/app/frontend/dist /usr/share/nginx/html

RUN mkdir -p /usr/share/nginx/logs && \
    touch /usr/share/nginx/logs/error.log && \
    touch /usr/share/nginx/logs/access.log

RUN mkdir -p /usr/share/nginx/html/.well-known/acme-challenge && \
    chmod 755 /usr/share/nginx/html/.well-known/acme-challenge

CMD ["nginx", "-g", "daemon off;"]
EOF

  print_message "Successfully configured Dockerfile at ${args[frontend_dockerfile]}"
}