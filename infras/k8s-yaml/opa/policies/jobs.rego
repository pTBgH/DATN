# =============================================================================
# jobs.rego — authorization for /api/jobs and /api/admin/jobs
#
# Resource map (mirrors infras/kong/kong.yml lines 163–197):
#   GET  /api/jobs                       any signed-in user
#   GET  /api/public/jobs                public (handled in public.rego)
#   POST /api/jobs                       recruiter, rec_ops, admin
#   *    /api/admin/jobs                 rec_ops, admin
#   *    /api/admin/categories           rec_ops, admin
#   GET  /api/jobs/{id}/workspace        member, recruiter, rec_ops, admin
#                                        (just identifies the workspace —
#                                        full workspace mgmt is in workspace.rego)
# =============================================================================
package zta.authz.jobs

import future.keywords.if
import future.keywords.in

default allow := false

# ---------------------------------------------------------------------------
# Read access to job listings — any authenticated user.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	input.path == "/api/jobs"
	data.zta.authz.has_any_role({"member", "recruiter", "rec_ops", "sourcer",
		"coordinator", "hiring_manager", "interviewer", "admin"})
}

# ---------------------------------------------------------------------------
# Create / update / delete a job — recruiter, rec_ops, admin.
# ---------------------------------------------------------------------------
allow if {
	input.method in {"POST", "PUT", "PATCH", "DELETE"}
	input.path == "/api/jobs"
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "admin"})
}

allow if {
	input.method in {"POST", "PUT", "PATCH", "DELETE"}
	startswith(input.path, "/api/jobs/")
	not endswith(input.path, "/apply")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "admin"})
}

# ---------------------------------------------------------------------------
# Admin board (/api/admin/jobs, /api/admin/categories) — rec_ops + admin only.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/admin/jobs")
	data.zta.authz.has_any_role({"rec_ops", "admin"})
}

allow if {
	startswith(input.path, "/api/admin/categories")
	data.zta.authz.has_any_role({"rec_ops", "admin"})
}

# ---------------------------------------------------------------------------
# Job → workspace lookup endpoint — any signed-in user can read it (just
# returns the workspace_id; sensitive workspace data still gated by
# workspace.rego).
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	startswith(input.path, "/api/jobs/")
	endswith(input.path, "/workspace")
	count(data.zta.authz.user_roles) > 0
}
