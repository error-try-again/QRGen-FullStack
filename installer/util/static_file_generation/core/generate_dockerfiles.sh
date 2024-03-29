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

  local dockerfile_template="FROM ${base_image}

RUN mkdir -p src \\
 && wget -O certbot-master.zip ${certbot_repo} \\
 && unzip certbot-master.zip \\
 && cp certbot-master/CHANGELOG.md certbot-master/README.rst src/ \\
 && cp -r certbot-master/tools tools \\
 && cp -r certbot-master/acme src/acme \\
 && cp -r certbot-master/certbot src/certbot \\
 && rm -rf certbot-master.tar.gz certbot-master

RUN apk add --no-cache --virtual .certbot-deps \\
        libffi \\
        libssl1.1 \\
        openssl \\
        ca-certificates \\
        binutils

ARG CARGO_NET_GIT_FETCH_WITH_CLI=${cargo_net_git_fetch_with_cli}

RUN apk add --no-cache --virtual .build-deps \\
        gcc \\
        linux-headers \\
        openssl-dev \\
        musl-dev \\
        libffi-dev \\
        python3-dev \\
        cargo \\
        git \\
        pkgconfig \\
    && python tools/pip_install.py --no-cache-dir \\
            --editable src/acme \\
            --editable src/certbot \\
    && apk del .build-deps \\
    && rm -rf \"${HOME}\"/.cargo

WORKDIR ${workdir}
VOLUME ${volumes}
EXPOSE ${expose}
ENTRYPOINT ${entrypoint}
"

  backup_existing_file "${certbot_dockerfile}"
  echo -e "${dockerfile_template}" > "${certbot_dockerfile}"
  print_multiple_messages "Dockerfile configured successfully at ${certbot_dockerfile}"
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
#   9
#######################################
generate_backend_dockerfile() {
  local backend_dockerfile="${1}"
  local backend_submodule_url="${2}"
  local node_version="${3}"
  local release_branch="${4}"
  local port="${5}"
  local use_ssl_flag="${6}"
  local google_maps_api_key="${7}"
  local origin="${8}"

  print_multiple_messages "Configuring the Docker Backend at ${backend_dockerfile}"
  local origin
  origin="origin"/"${release_branch}"
  backup_existing_file "${backend_dockerfile}"
  cat << EOF > "${backend_dockerfile}"
FROM node:${node_version}

WORKDIR /usr/app

RUN git init

RUN git submodule add --force "${backend_submodule_url}" backend
RUN git submodule update --init --recursive

RUN cd backend \
    && git fetch --all \
    && git reset --hard "${origin}" \
    && git checkout "${release_branch}" \
    && npm install \
    && cd ..

ENV ORIGIN=${origin}
ENV USE_SSL=${use_ssl_flag}
ENV GOOGLE_MAPS_API_KEY=${google_maps_api_key}

EXPOSE ${port}

CMD ["npx", "ts-node", "/usr/app/backend/src/server.ts"]

EOF
  print_message "Successfully generated Dockerfile at ${backend_dockerfile}"
}

#######################################
# description
# Globals:
#   exposed_nginx_port
# Arguments:
#   1
#   2
#   3
#   4
#   5
#######################################
generate_frontend_dockerfile() {
  local frontend_dockerfile="${1}"
  local frontend_submodule_url="${2}"
  local node_version="${3}"
  local release_branch="${4}"
  local use_google_api_key="${5}"
  local sitemap_path="${6}"
  local robots_path="${7}"
  local nginx_conf_path="${8}"
  local mime_types_path="${9}"
  local nginx_version="${10}"

  print_message "Configuring the frontend Docker environment..."
  local origin="origin/${release_branch}"
  backup_existing_file "${frontend_dockerfile}"
  print_message "Configuring Dockerfile at ${frontend_dockerfile}"
  cat << EOF > "${frontend_dockerfile}"
FROM node:${node_version} as build

WORKDIR /usr/app

RUN git init && \
    (if [ -d "frontend" ]; then \
        echo "Removing existing frontend directory"; \
        rm -rf frontend; \
    fi) && \
    git submodule add --force "$frontend_submodule_url" frontend && \
    git submodule update --init --recursive && \
    cd frontend && \
    git fetch --all && \
    git reset --hard "${origin}" && \
    git checkout "${release_branch}" && \
    npm install && \
    (if [ "${use_google_api_key}" = "true" ]; then \
        sed -i'' -e 's/export const googleSdkEnabled = false;/export const googleSdkEnabled = true;/' src/config.tsx; \
    fi)

WORKDIR /usr/app/frontend
RUN npm run build

FROM nginx:$nginx_version
COPY $sitemap_path /usr/share/nginx/html/sitemap.xml
COPY $robots_path /usr/share/nginx/html/robots.txt
COPY --from=build /usr/app/frontend/dist /usr/share/nginx/html
COPY $nginx_conf_path /usr/share/nginx/nginx.conf
COPY $mime_types_path /usr/share/nginx/mime.types

# Create logs directory
RUN mkdir -p /usr/share/nginx/logs && \
    touch /usr/share/nginx/logs/error.log && \
    touch /usr/share/nginx/logs/access.log

RUN mkdir -p /usr/share/nginx/html/.well-known/acme-challenge && \
    chmod -R 777 /usr/share/nginx/html/.well-known

EXPOSE ${exposed_nginx_port}
CMD ["nginx", "-g", "daemon off;"]
EOF

  print_message "Successfully configured Dockerfile at ${frontend_dockerfile}"
}