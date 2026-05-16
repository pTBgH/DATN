# =============================================================================
# public.rego — anonymous-ok routes
#
# These paths are reachable without any role (Kong still verifies JWT
# signature on routes that have `plugins: [{ name: jwt }]`, but the OPA layer
# doesn't gate them on a particular role).
# =============================================================================
package zta.authz.public

import future.keywords.if
import future.keywords.in

default allow := false

allow if {
	input.path in data.zta.authz.public_paths
}

# GET /api/jobs/<slug>/apply — anyone with a session can submit a job
# application. Method is forced to POST and the path uses regex on the apply
# segment — but for OPA we only need the prefix check.
allow if {
	input.method == "POST"
	startswith(input.path, "/api/jobs/")
	endswith(input.path, "/apply")
}

# /api/health from any service
allow if {
	endswith(input.path, "/api/health")
}
