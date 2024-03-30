#!/usr/bin/env bash

set -euo pipefail

docker exec -it nginx /bin/sh -c "curl --location 'express_service:3001/' \
--header 'Content-Type: application/json' \
--data '{
    \"customData\": {
        \"colors\": {
            \"dark\": \"#000000\",
            \"light\": \"#ffffff\"
        },
        \"isLoading\": false,
        \"qrCodeURL\": \"\",
        \"size\": \"150\",
        \"precision\": \"H\",
        \"text\": \"t\"
    },
    \"type\": \"Text\"
}'" &> /dev/null && echo "Inter-container communication Success" || echo "Inter-container communication Failed"

docker exec -it nginx /bin/sh -c "curl --location 'localhost:3001/' \
--header 'Content-Type: application/json' \
--data '{
    \"customData\": {
        \"colors\": {
            \"dark\": \"#000000\",
            \"light\": \"#ffffff\"
        },
        \"isLoading\": false,
        \"qrCodeURL\": \"\",
        \"size\": \"150\",
        \"precision\": \"H\",
        \"text\": \"t\"
    },
    \"type\": \"Text\"
}'" &> /dev/null && echo "Inter-container communication Success" || echo "Inter-container communication Failed"

curl localhost &> /dev/null && echo "Host communication Success" || echo "Host communication Failed"

curl --location 'localhost:3001/qr/generate' \
  --header 'Content-Type: application/json' \
  --data '{
    "customData": {
        "colors": {
            "dark": "#000000",
            "light": "#ffffff"
        },
        "isLoading": false,
        "qrCodeURL": "",
        "size": "150",
        "precision": "H",
        "text": "t"
    },
    "type": "Text"
}' &> /dev/null && echo "Host communication Success" || echo "Host communication Failed"

docker exec -it nginx /bin/sh -c "cat /etc/nginx/html/sitemap.xml"
docker exec -it nginx /bin/sh -c "cat /etc/nginx/html/html/robots.txt"
docker exec -it nginx /bin/sh -c "cat /etc/nginx/nginx.conf"
docker exec -it nginx /bin/sh -c "cat /etc/nginx/mime.types"
docker exec -it nginx /bin/sh -c "ls -la /etc/nginx/html"
docker exec -it nginx /bin/sh -c "ls -la /etc/nginx/html/.well-known"