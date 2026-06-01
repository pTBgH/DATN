# =============================================================================
# default.rego — OPA user-authz entrypoint (simplified)
#
# Single decision point exposed to Kong:
#   POST /v1/data/zta/authz/allow
#
# Request body shape (Kong pre-function Lua sends — unchanged from previous
# revision, just less of it is used now):
#   {
#     "input": {
#       "method": "GET" | "POST" | ...,
#       "path":   "/api/jobs",
#       "path_segments": ["api", "jobs"],
#       "jwt": {
#         "sub": "<keycloak-user-id>",
#         "preferred_username": "recruiter1",
#         "azp": "recruiter-app-dev",
#         "exp": 1733...
#       }
#     }
#   }
#
# Response: { "result": true | false }
#
# Decision model (post-refactor — see PR description for context):
#
#   1. Default DENY.
#   2. ALLOW if the path is public (see public.rego — health, public job
#      listings, OIDC surfaces, /api/jobs/{slug}/apply, ...).
#   3. ALLOW if the JWT carries a `sub` claim (i.e. it is a valid
#      authenticated session — Kong's `jwt` plugin has already verified the
#      signature against the Keycloak realm public key by the time we get
#      here; we only need to confirm a subject is present).
#
# What this layer no longer does (intentionally):
#   - Maps roles like `recruiter`, `rec_ops`, `coordinator`, `interviewer`, ...
#     to specific endpoints. ATS business roles live in the application layer
#     (Laravel + `workspace_members` bitmask perms). Keeping them in Keycloak
#     realm-roles + Rego was a leaky abstraction: the JWT carries a single
#     global role list, but the business model assigns roles per (user,
#     workspace), so the global view could never be correct.
#   - Gates `/api/admin/*`. Platform-admin identity is established by
#     Laravel's `super.admin` middleware (membership of
#     `SUPER_ADMIN_WORKSPACE_ID`), not by a realm-role claim.
#
# OPA still adds value over plain Kong JWT verification:
#   - Centralized, version-controlled public-path whitelist (1 file, easy
#     to grep — vs. spreading `plugins: [{ name: jwt }]` toggles across
#     dozens of Kong routes).
#   - Decision log (allow/deny per request) — shipped to Elasticsearch by
#     the Filebeat sidecar; useful audit trail for the thesis.
#   - Future-proof for richer policy (per-claim, per-IP, time-of-day, ABAC)
#     without re-deploying Kong config.
# =============================================================================
package zta.authz

import future.keywords.if

default allow := false

# ---------------------------------------------------------------------------
# Public routes — anonymous OK. (See public.rego.)
# ---------------------------------------------------------------------------
allow if {
	data.zta.authz.public.allow
}

# ---------------------------------------------------------------------------
# Authenticated routes — any valid session passes the gate. The application
# layer (Laravel middleware + `workspace_members` bitmask) does the fine-
# grained authorization (e.g. "can user X create a job in workspace Y?").
# ---------------------------------------------------------------------------
allow if {
	input.jwt.sub
	input.jwt.sub != ""
}

# ---------------------------------------------------------------------------
# Public-paths data block — referenced by public.rego. Keeping it on the
# top-level `zta.authz` package preserves the previous contract for callers
# that read `data.zta.authz.public_paths` directly.
# ---------------------------------------------------------------------------
public_paths := {
	"/api/health",
	"/api/options/company-types",
	"/api/options/general",
	"/api/public/jobs",
	"/api/metadata/common",
	"/api/public/metadata/common",
}
