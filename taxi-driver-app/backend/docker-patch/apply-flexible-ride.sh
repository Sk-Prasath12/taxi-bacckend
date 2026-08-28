#!/bin/sh
# Apply flexible ride patches inside taxi_app_backend container.
set -e
docker cp "$(dirname "$0")/patch-flexible-ride.js" taxi_app_backend:/tmp/patch-flexible-ride.js
docker exec taxi_app_backend node /tmp/patch-flexible-ride.js
docker exec taxi_app_backend sh -c 'cd /app && npm run build 2>/dev/null || npx tsc -p tsconfig.json 2>/dev/null || true'
docker restart taxi_app_backend
echo "Flexible ride patch applied."
