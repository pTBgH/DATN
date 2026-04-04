#!/bin/sh

# ======================================================
# Add extra routes for job-service
# Kong Admin đang port-forward tại 9001
# ======================================================

KONG_ADMIN="http://localhost:19001"
SERVICE_NAME="job-service"

echo "🚀 Adding extra routes for job-service..."

# --- Helper ---
create_route() {
    local name=$1
    local path=$2
    echo "   ➕ Route: $name ($path)"
    curl -s -X POST "$KONG_ADMIN/services/$SERVICE_NAME/routes" \
        -d "name=$name" \
        -d "paths[]=$path" \
        -d "strip_path=false" \
        -o /dev/null
}

# ======================
# Job Metadata APIs
# ======================

create_route "job-metadata-common" "/api/metadata/common"
create_route "job-metadata-districts" "~/api/metadata/districts/[^/]+"

# ======================
# Job Company APIs
# ======================

create_route "job-company-detail" "~/api/companies/[^/]+"

echo "✅ Done! Job extra routes added."
