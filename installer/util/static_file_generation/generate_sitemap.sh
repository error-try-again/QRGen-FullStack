#!/usr/bin/env bash

set -euo pipefail

#######################################
# Generates the sitemap.xml file.
# Arguments:
#   1
#   2
#######################################
generate_sitemap() {
  print_message "Configuring the site map..."
  local origin_url="${1}"
  local sitemap_path="${2}"

  local date regularity priority
  date=$(date +%Y-%m-%d)
  regularity="weekly"
  priority="0.8"

  cat << EOF > "${sitemap_path}"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="https://www.sitemaps.org/schemas/sitemap/0.9">
   <url>
      <loc>${origin_url}</loc>
      <lastmod>${date}</lastmod>
      <changefreq>${regularity}</changeover>
      <priority>${priority}</priority>
   </url>
</urlset>
EOF
}