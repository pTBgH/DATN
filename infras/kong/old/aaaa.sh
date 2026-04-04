#!/bin/sh

# ======================================================
# Update job-service metadata routes
# - Remove old routes
# - Add new /public routes
# ======================================================

KONG_ADMIN="http://localhost:19001"
SERVICE_NAME="job-service"

echo "🚀 Updating job metadata routes for job-service..."

# -----------------------
# Find & delete old routes
# -----------------------
delete_route_by_name() {
    local route_name=$1
    ROUTE_ID=$(curl -s "$KONG_ADMIN/routes" | \
        jq -r ".data[] | select(.name==\"$route_name\") | .id")

    if [ -n "$ROUTE_ID" ]; then
        echo "🗑  Deleting route: $route_name"
        curl -s -X DELETE "$KONG_ADMIN/routes/$ROUTE_ID" -o /dev/null
    else
        echo "ℹ️  Route not found: $route_name (skip)"
    fi
}

delete_route_by_name "job-metadata-common"
delete_route_by_name "job-metadata-districts"

# -----------------------
# Add new routes
# -----------------------
create_route() {
    local name=$1
    local path=$2
    echo "➕ Adding route: $name ($path)"
    curl -s -X POST "$KONG_ADMIN/services/$SERVICE_NAME/routes" \
        -d "name=$name" \
        -d "paths[]=$path" \
        -d "strip_path=false" \
        -o /dev/null
}

create_route "job-public-metadata-common" "/api/public/metadata/common"
create_route "job-public-metadata-districts" "~/api/public/metadata/districts/[^/]+"

echo "✅ Done! Job metadata routes updated."
