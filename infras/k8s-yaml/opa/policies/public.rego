# =============================================================================
# public.rego — anonymous-ok routes
#
# Paths matched here bypass the authenticated check in default.rego. All
# other paths require a valid JWT (verified by Kong's `jwt` plugin; OPA
# only checks `input.jwt.sub` is present).
# =============================================================================
package zta.authz.public

import future.keywords.if
import future.keywords.in

default allow := false

# ---------------------------------------------------------------------------
# Exact whitelist (see `public_paths` in default.rego).
# ---------------------------------------------------------------------------
allow if {
	input.path in data.zta.authz.public_paths
}

# ---------------------------------------------------------------------------
# /api/jobs — public job browse. Listing and detail are both anonymous-ok;
# they only return data the recruiter has explicitly published.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	input.path == "/api/jobs"
}

# ---------------------------------------------------------------------------
# Job detail and apply endpoints under /api/jobs/<id-or-slug>/...
#   GET  /api/jobs/<id>            — public detail
#   POST /api/jobs/<slug>/apply    — anyone with a session OR no session can
#                                    submit (Laravel will require a candidate
#                                    JWT before persisting if it needs to
#                                    attribute the application).
# We do NOT match write methods on /api/jobs/<id> here — those are
# recruiter-only, gated by the authenticated branch of default.rego plus
# Laravel middleware.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	startswith(input.path, "/api/jobs/")
}

allow if {
	input.method == "POST"
	startswith(input.path, "/api/jobs/")
	endswith(input.path, "/apply")
}

# ---------------------------------------------------------------------------
# Company profile read — recruiter brand page is part of the public job
# detail experience. Writes still hit the authenticated branch.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	startswith(input.path, "/api/companies/")
}

# ---------------------------------------------------------------------------
# Geolocation / category metadata — pure reference data, no PII.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/metadata/")
}

allow if {
	startswith(input.path, "/api/public/")
}

# ---------------------------------------------------------------------------
# Health probes — every service exposes `/api/health`.
# ---------------------------------------------------------------------------
allow if {
	endswith(input.path, "/api/health")
}

# ---------------------------------------------------------------------------
# Keycloak OIDC surfaces — token / auth / certs / .well-known / userinfo /
# logout… FE needs these to obtain a token in the first place. Keycloak
# enforces its own auth on each sub-path.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/realms/")
}
