#!/usr/bin/env bash
# =============================================================================
# add-test-users.sh — Keycloak test users for realm `job7189`
#
# Creates 3 test users (idempotent) in realm `job7189` running inside the
# Keycloak pod `security/keycloak-*`. User identity is established by which
# Keycloak *client* they log in through (azp claim), so this script no longer
# assigns realm-roles. ATS business roles (recruiter / rec_ops / sourcer /
# coordinator / hiring_manager / interviewer / member) now live entirely in
# Laravel + the `workspace_members` bitmask table — see
# `knowledge-base/36-opa-user-authz.md` for the rationale.
#
# Test users (password = "dev1234", thesis-demo only — DO NOT use in prod):
#   admin1     → use the recruiter Keycloak client; Laravel marks them as a
#                 platform admin by their membership of the workspace whose
#                 ID is set in `SUPER_ADMIN_WORKSPACE_ID` (env var consumed by
#                 each Laravel service's `super.admin` middleware).
#   recruiter1 → use the recruiter Keycloak client; their per-workspace
#                 permissions live in `workspace_members` (job/candidate/
#                 pipeline/workspace bitmasks). Seed those via Laravel.
#   member1    → use either client; Laravel treats them as a recruiter or
#                 candidate based on the client they log in through (azp).
#
# Usage:
#   bash infras/keycloak/scripts/add-test-users.sh               # create users
#   KEYCLOAK_ADMIN_PASSWORD=xxx bash ....                        # override pw
#   bash infras/keycloak/scripts/add-test-users.sh --remove      # delete users
#   bash infras/keycloak/scripts/add-test-users.sh --cleanup-legacy-roles
#                                                                # delete the
#                                                                # 8 legacy
#                                                                # business
#                                                                # roles from
#                                                                # the realm
#                                                                # (no-op if
#                                                                # they don't
#                                                                # exist)
#
# Doc:
#   knowledge-base/36-opa-user-authz.md
# =============================================================================
set -euo pipefail

NAMESPACE="${KC_NAMESPACE:-security}"
REALM="${KC_REALM:-job7189}"
KC_POD_LABEL="${KC_POD_LABEL:-app=keycloak}"
KC_BASE_URL="${KC_BASE_URL:-http://localhost:8080}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-dev1234}"

# Test users — no role-mapping; identity comes from `azp` (Keycloak client).
USERS=(
  "admin1"
  "recruiter1"
  "member1"
)

# Legacy realm-roles from the old role-based OPA design. The current OPA
# policy ignores `realm_access.roles` entirely (see infras/k8s-yaml/opa/
# policies/default.rego), so these roles are dead weight — `--cleanup-legacy-
# roles` deletes them from the realm. Listed here so the script is the single
# place that knows what the legacy names were.
LEGACY_ROLES=(
  admin
  rec_ops
  recruiter
  sourcer
  coordinator
  hiring_manager
  interviewer
  member
)

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

MODE="install"
case "${1:-}" in
  --remove)                 MODE="remove" ;;
  --cleanup-legacy-roles)   MODE="cleanup-legacy-roles" ;;
  -h|--help)
    sed -n '2,42p' "$0" | sed 's/^# \?//'
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
# REMOVAL PATH — delete the 3 test users.
# ==========================================================================
if [ "$MODE" = "remove" ]; then
  yellow "Removing test users from realm '$REALM'..."
  login_kcadm
  for username in "${USERS[@]}"; do
    if user_exists "$username"; then
      uid=$(get_user_id "$username")
      [ -n "$uid" ] && kcadm delete "users/$uid" -r "$REALM" \
        && green "  removed user $username" \
        || yellow "  user $username delete failed (ignored)"
    fi
  done
  green "done — test users removed"
  exit 0
fi

# ==========================================================================
# CLEANUP-LEGACY-ROLES PATH — delete the 8 obsolete business realm-roles.
# ==========================================================================
if [ "$MODE" = "cleanup-legacy-roles" ]; then
  yellow "Removing legacy business roles from realm '$REALM'..."
  yellow "(OPA + Laravel no longer read realm_access.roles for these names.)"
  login_kcadm
  for role in "${LEGACY_ROLES[@]}"; do
    if role_exists "$role"; then
      kcadm delete "roles/$role" -r "$REALM" \
        && green "  removed role $role" \
        || yellow "  role $role delete failed (ignored)"
    else
      yellow "  role $role already absent — skipping"
    fi
  done
  green "done — legacy business roles cleaned up"
  exit 0
fi

# ==========================================================================
# INSTALL PATH — create / refresh the 3 test users (no role mapping).
# ==========================================================================
blue "=========================================================="
blue " Creating ${#USERS[@]} test users"
blue " Realm:    $REALM"
blue " Pod:      $NAMESPACE/$KC_POD"
blue " Password: \"$TEST_USER_PASSWORD\" (thesis-demo only)"
blue " Note:     identity comes from the Keycloak client (azp),"
blue "           not from realm-roles — see knowledge-base/36-opa-user-authz.md"
blue "=========================================================="
login_kcadm

for username in "${USERS[@]}"; do
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
  # Always (re)set the password — useful when re-running on existing user.
  kcadm set-password -r "$REALM" \
    --username "$username" \
    --new-password "$TEST_USER_PASSWORD" \
    >/dev/null
  green "    set password for $username"
done

blue "=========================================================="
green " done"
blue "=========================================================="
echo
echo "Test login (use the recruiter or candidate client id depending on"
echo "which app you want to log in to; Laravel decides recruiter vs"
echo "candidate from the JWT's azp claim):"
echo "  TOKEN=\$(curl -s -X POST \\"
echo "    -d 'client_id=recruiter-app' \\"
echo "    -d 'username=admin1' -d 'password=$TEST_USER_PASSWORD' \\"
echo "    -d 'grant_type=password' \\"
echo "    http://<keycloak>/realms/$REALM/protocol/openid-connect/token \\"
echo "    | jq -r .access_token)"
echo
echo "To grant admin1 platform-admin powers, add them as an active member of"
echo "the workspace whose ID is set in SUPER_ADMIN_WORKSPACE_ID (consumed by"
echo "each Laravel service's 'super.admin' middleware)."
