#!/usr/bin/env bash
# =============================================================================
# add-app-roles.sh — Phase 5.B.2.a (Keycloak business roles for OPA user-authz)
#
# Adds 8 string realm-roles + 3 test users to realm `job7189` running inside
# the Keycloak pod `security/keycloak-*`. Idempotent: rerunning the script
# is safe — kcadm errors on "role/user already exists" are caught and ignored.
#
# Roles (flat, no composites):
#   admin            super user, full CRUD on every resource
#   rec_ops          recruiter ops, manages workspaces + categories
#   recruiter        creates jobs, sees own pipelines
#   sourcer          sees candidate pool, no edit
#   coordinator      schedules interviews, no scorecard
#   hiring_manager   sees scorecards, approves offers
#   interviewer      writes scorecards for assigned interviews
#   member           catch-all logged-in user (read-only public + own profile)
#
# Test users (password = "dev1234", thesis-demo only — DO NOT use in prod):
#   admin1     → roles: [admin]
#   recruiter1 → roles: [recruiter]
#   member1    → roles: [member]
#
# Usage:
#   bash infras/keycloak/scripts/add-app-roles.sh                 # default
#   KEYCLOAK_ADMIN_PASSWORD=xxx bash ....                         # override
#   bash infras/keycloak/scripts/add-app-roles.sh --remove        # tear down
#
# Doc:
#   doc/36-opa-user-authz.md §3.1
# =============================================================================
set -euo pipefail

NAMESPACE="${KC_NAMESPACE:-security}"
REALM="${KC_REALM:-job7189}"
KC_POD_LABEL="${KC_POD_LABEL:-app=keycloak}"
KC_BASE_URL="${KC_BASE_URL:-http://localhost:8080}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-dev1234}"

ROLES=(
  admin
  rec_ops
  recruiter
  sourcer
  coordinator
  hiring_manager
  interviewer
  member
)

# user:role[,role...]   (comma-separated when a user has multiple roles)
USERS=(
  "admin1:admin"
  "recruiter1:recruiter"
  "member1:member"
)

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

REMOVE=0
case "${1:-}" in
  --remove) REMOVE=1 ;;
  -h|--help)
    sed -n '2,30p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  "") : ;;
  *) red "Unknown flag: $1" >&2; exit 1 ;;
esac

# --------------------------------------------------------------------------
# Locate the Keycloak pod + read admin password from Kubernetes Secret.
# --------------------------------------------------------------------------
KC_POD=$(kubectl -n "$NAMESPACE" get pod -l "$KC_POD_LABEL" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$KC_POD" ]; then
  red "ERROR: no pod with label '$KC_POD_LABEL' in namespace '$NAMESPACE'"
  exit 1
fi
blue "Keycloak pod: $NAMESPACE/$KC_POD"

if [ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ]; then
  KEYCLOAK_ADMIN_PASSWORD=$(kubectl -n "$NAMESPACE" get secret app-secrets \
    -o jsonpath='{.data.keycloak-admin-password}' 2>/dev/null | base64 -d || true)
  if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    red "ERROR: cannot read keycloak admin password from Secret '$NAMESPACE/app-secrets'"
    red "       (key: keycloak-admin-password). Pass KEYCLOAK_ADMIN_PASSWORD env var instead."
    exit 1
  fi
fi

# --------------------------------------------------------------------------
# Wrapper: run kcadm.sh inside the pod and squash benign "already exists"
# errors so the script stays idempotent.
# --------------------------------------------------------------------------
kcadm() {
  kubectl -n "$NAMESPACE" exec "$KC_POD" -- \
    /opt/keycloak/bin/kcadm.sh "$@"
}

login_kcadm() {
  blue "Logging in to kcadm as admin..."
  kcadm config credentials \
    --server "$KC_BASE_URL" \
    --realm master \
    --user admin \
    --password "$KEYCLOAK_ADMIN_PASSWORD" \
    >/dev/null
}

role_exists() {
  kcadm get "roles/$1" -r "$REALM" >/dev/null 2>&1
}

user_exists() {
  local username="$1"
  local count
  count=$(kcadm get users -r "$REALM" -q "username=$username" --fields id 2>/dev/null \
    | grep -c '"id"' || true)
  [ "$count" -gt 0 ]
}

get_user_id() {
  kcadm get users -r "$REALM" -q "username=$1" --fields id 2>/dev/null \
    | python3 -c 'import sys,json; arr=json.load(sys.stdin); print(arr[0]["id"]) if arr else None'
}

# ==========================================================================
# REMOVAL PATH
# ==========================================================================
if [ "$REMOVE" -eq 1 ]; then
  yellow "Removing test users + business roles from realm '$REALM'..."
  login_kcadm
  for entry in "${USERS[@]}"; do
    username="${entry%%:*}"
    if user_exists "$username"; then
      uid=$(get_user_id "$username")
      [ -n "$uid" ] && kcadm delete "users/$uid" -r "$REALM" \
        && green "  removed user $username" \
        || yellow "  user $username delete failed (ignored)"
    fi
  done
  for role in "${ROLES[@]}"; do
    if role_exists "$role"; then
      kcadm delete "roles/$role" -r "$REALM" \
        && green "  removed role $role" \
        || yellow "  role $role delete failed (ignored)"
    fi
  done
  green "✓ test users and business roles removed"
  exit 0
fi

# ==========================================================================
# INSTALL PATH
# ==========================================================================
blue "=========================================================="
blue " Adding $((${#ROLES[@]})) business roles + ${#USERS[@]} test users"
blue " Realm:    $REALM"
blue " Pod:      $NAMESPACE/$KC_POD"
blue " Password: \"$TEST_USER_PASSWORD\" (thesis-demo only)"
blue "=========================================================="
login_kcadm

# --------------------------------------------------------------------------
# 1. Create realm roles.
# --------------------------------------------------------------------------
blue "[1/3] Creating realm roles..."
for role in "${ROLES[@]}"; do
  if role_exists "$role"; then
    yellow "  role $role already exists — skipping"
  else
    kcadm create roles -r "$REALM" \
      -s "name=$role" \
      -s "description=Phase 5.B.2 business role: $role" \
      >/dev/null
    green "  created role $role"
  fi
done

# --------------------------------------------------------------------------
# 2. Create test users + set password.
# --------------------------------------------------------------------------
blue "[2/3] Creating test users..."
for entry in "${USERS[@]}"; do
  username="${entry%%:*}"
  if user_exists "$username"; then
    yellow "  user $username already exists — skipping create"
  else
    kcadm create users -r "$REALM" \
      -s "username=$username" \
      -s "enabled=true" \
      -s "emailVerified=true" \
      -s "email=${username}@thesis.local" \
      -s "firstName=${username}" \
      -s "lastName=Test" \
      >/dev/null
    green "  created user $username"
  fi
  # Always (re)set the password — useful when re-running on existing user
  # (kcadm set-password is idempotent — overwrites).
  kcadm set-password -r "$REALM" \
    --username "$username" \
    --new-password "$TEST_USER_PASSWORD" \
    >/dev/null
  green "    set password for $username"
done

# --------------------------------------------------------------------------
# 3. Map roles to users.
# --------------------------------------------------------------------------
blue "[3/3] Assigning roles to users..."
for entry in "${USERS[@]}"; do
  username="${entry%%:*}"
  roles_csv="${entry#*:}"
  IFS=',' read -ra wanted_roles <<<"$roles_csv"
  for role in "${wanted_roles[@]}"; do
    role=$(echo "$role" | tr -d ' ')
    # 'kcadm add-roles' is idempotent — re-adding an already-mapped role
    # is a no-op (returns 0). We don't need to query first.
    kcadm add-roles -r "$REALM" \
      --uusername "$username" \
      --rolename "$role" \
      >/dev/null
    green "  $username -> $role"
  done
done

blue "=========================================================="
green " ✓ done"
blue "=========================================================="
echo
echo "Test login:"
echo "  TOKEN=\$(curl -s -X POST \\"
echo "    -d 'client_id=candidate-app-dev' \\"
echo "    -d 'username=admin1' -d 'password=$TEST_USER_PASSWORD' \\"
echo "    -d 'grant_type=password' \\"
echo "    http://<keycloak>/realms/$REALM/protocol/openid-connect/token \\"
echo "    | jq -r .access_token)"
echo "  echo \$TOKEN | cut -d. -f2 | base64 -d | jq .realm_access.roles"
echo
echo "Expected output: [\"admin\", \"default-roles-$REALM\"]"
