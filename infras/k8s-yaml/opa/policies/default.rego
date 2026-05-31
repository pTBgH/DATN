# =============================================================================
# default.rego — Phase 5.B.2 OPA user-authz entrypoint
#
# Single decision point exposed to Kong:
#   POST /v1/data/zta/authz/allow
#
# Request body shape (Kong pre-function Lua sends):
#   {
#     "input": {
#       "method": "GET" | "POST" | ...,
#       "path":   "/api/jobs",
#       "path_segments": ["api", "jobs"],
#       "jwt": {
#         "sub": "<keycloak-user-id>",
#         "preferred_username": "recruiter1",
#         "realm_access": { "roles": ["recruiter", "default-roles-job7189"] },
#         "exp": 1733...
#       }
#     }
#   }
#
# Response: { "result": true | false }
#
# Aggregation order (each sub-policy returns `allow` only when its path
# pattern matches):
#   1. default deny
#   2. data.zta.authz.jobs.allow
#   3. data.zta.authz.candidates.allow
#   4. data.zta.authz.workspace.allow
#   5. data.zta.authz.interviews.allow
#   6. data.zta.authz.public.allow  (open routes — health, public/jobs)
#
# Any one rule evaluating true grants access. No policy = deny.
# =============================================================================
package zta.authz

import future.keywords.if
import future.keywords.in

default allow := false

# ---------------------------------------------------------------------------
# Public routes — no role check required (Kong still validates JWT signature
# for authenticated routes; these are explicitly anonymous-ok).
# ---------------------------------------------------------------------------
allow if {
	data.zta.authz.public.allow
}

# ---------------------------------------------------------------------------
# Resource-specific authorization rules — delegated to per-resource Rego files.
# ---------------------------------------------------------------------------
allow if {
	data.zta.authz.jobs.allow
}

allow if {
	data.zta.authz.candidates.allow
}

allow if {
	data.zta.authz.workspace.allow
}

allow if {
	data.zta.authz.interviews.allow
}

# ---------------------------------------------------------------------------
# Helper available to every sub-policy: which Keycloak realm-roles is this
# user holding?
# ---------------------------------------------------------------------------
user_roles := input.jwt.realm_access.roles

# True iff the caller carries at least one of the named roles.
has_any_role(allowed) if {
	some r in user_roles
	r in allowed
}

# Convenience: identity-service /api/health and similar reachable from
# Hubble health probes go through this aggregator.
public_paths := {
	"/api/health",
	"/api/options/company-types",
	"/api/options/general",
	"/api/public/jobs",
	"/api/metadata/common",
	"/api/public/metadata/common",
}

# ---------------------------------------------------------------------------
# Added: recruiters + admin sub-policies (gap fix — 403 trên /api/recruiters/*
# và /api/admin/users do trước đây không có rego tương ứng).
# ---------------------------------------------------------------------------
allow if {
	data.zta.authz.recruiters.allow
}

allow if {
	data.zta.authz.admin.allow
}
