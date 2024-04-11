#!/usr/bin/env bash

set -euo pipefail

#######################################
# Generates the Nginx configuration file for mime types
# Arguments:
#   1
#######################################
generate_nginx_mime_types() {
  local nginx_mime_types_file="${1}"

  if [[ ! -f ${nginx_mime_types_file}   ]]; then
    mkdir -p "$(dirname "${nginx_mime_types_file}")"
    touch "${nginx_mime_types_file}"
  fi

  # Restrict the mime types to the ones that might actually be used by the application
  cat << EOF > "${nginx_mime_types_file}"
types {
    text/html                                        html htm shtml;
    text/css                                         css;
    text/xml                                         xml;
    image/gif                                        gif;
    image/jpeg                                       jpeg jpg;
    application/javascript                           js;

    image/png                                        png;
    image/svg+xml                                    svg svgz;
    image/tiff                                       tif tiff;
    image/webp                                       webp;
    image/x-icon                                     ico;
    image/x-jng                                      jng;
    image/x-ms-bmp                                   bmp;

    font/woff                                        woff;
    font/woff2                                       woff2;

    application/zip                                  zip;
}
EOF
}