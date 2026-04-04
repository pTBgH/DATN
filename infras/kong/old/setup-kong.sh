#!/bin/sh

# QUAN TRỌNG: Dùng localhost:9001 (Vì bạn đang port-forward cổng 9001)
KONG_ADMIN="http://localhost:9001"

# Hàm clean cũ (Dù đang trống nhưng cứ chạy cho chắc)
clean_kong() {
    echo "🧹 Cleaning old configs..."
    SERVICES="identity-service workspace-service job-service hiring-service candidate-service communication-service storage-service"
    for SERVICE in $SERVICES; do
        curl -s -X DELETE "$KONG_ADMIN/services/$SERVICE" > /dev/null
    done
    echo "✅ Cleaned."
}

create_service() {
    local name=$1
    local url=$2
    echo "🛠  Creating Service: $name..."
    curl -s -X POST "$KONG_ADMIN/services" \
        -d "name=$name" \
        -d "url=$url" \
        -o /dev/null
}

create_route() {
    local service=$1
    local name=$2
    local paths=$3
    echo "   ➡️  Adding Route: $name ($paths)"
    curl -s -X POST "$KONG_ADMIN/services/$service/routes" \
        -d "name=$name" \
        -d "paths[]=$paths" \
        -d "strip_path=false" \
        -o /dev/null
}

# --- THỰC THI ---
clean_kong

echo "--- START CONFIGURING KONG (PORT 9001) ---"

# 1. Identity
create_service "identity-service" "http://identity-service:80"
create_route "identity-service" "identity-profiles" "/api/recruiters/profile"
create_route "identity-service" "identity-candidate-profiles" "/api/candidates/profile"
create_route "identity-service" "identity-admin" "/api/admin/users"
create_route "identity-service" "identity-health" "/api/health"

# 2. Workspace
create_service "workspace-service" "http://workspace-service:80"
create_route "workspace-service" "workspace-core" "/api/workspaces"
create_route "workspace-service" "workspace-invitations" "/api/invitations"
create_route "workspace-service" "workspace-options" "/api/options/company-types"

# 3. Job
create_service "job-service" "http://job-service:80"
create_route "job-service" "job-workspace-context" "~/api/workspaces/[^/]+/jobs"
create_route "job-service" "job-admin" "/api/admin/jobs"
create_route "job-service" "job-standalone" "/api/jobs"
create_route "job-service" "job-public" "/api/public/jobs"
create_route "job-service" "job-options" "/api/options/general"

# 4. Hiring
create_service "hiring-service" "http://hiring-service:80"
create_route "hiring-service" "hiring-pipelines" "~/api/workspaces/[^/]+/pipelines"
create_route "hiring-service" "hiring-apply" "~/api/jobs/[^/]+/apply"
create_route "hiring-service" "hiring-applications" "/api/applications"
create_route "hiring-service" "hiring-board" "/api/board"
create_route "hiring-service" "hiring-interviews" "/api/interviews"
create_route "hiring-service" "hiring-scorecards" "/api/scorecards"

# 5. Candidate
create_service "candidate-service" "http://candidate-service:80"
create_route "candidate-service" "candidate-resumes" "/api/resumes"
create_route "candidate-service" "candidate-interactions" "/api/interactions"

# 6. Communication
create_service "communication-service" "http://communication-service:80"
create_route "communication-service" "comm-conversations" "/api/conversations"
create_route "communication-service" "comm-messages" "/api/messages"
create_route "communication-service" "comm-notifications" "/api/notifications"

# 7. Storage
create_service "storage-service" "http://storage-service:80"
create_route "storage-service" "storage-main" "/api/presigned-url"

# 8. CORS Plugin (Global)
echo "🌍 Enabling CORS..."
curl -s -X POST "$KONG_ADMIN/plugins" \
    -d "name=cors" \
    -d "config.origins=*" \
    -d "config.methods=GET,POST,PUT,PATCH,DELETE,OPTIONS" \
    -d "config.headers=Accept,Authorization,Content-Type" \
    -d "config.credentials=true" \
    -o /dev/null

echo "✅ DONE! Configuration loaded into Kong (Port 9001)."