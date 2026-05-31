# =============================================================================
# candidates.rego — authorization for /api/candidates/* and /api/resumes
#
# Resource map (mirrors infras/kong/kong.yml lines 220–227):
#   GET /api/candidates/profile          candidate owns their own profile
#                                         → identity-service decides via JWT sub;
#                                           OPA just allows any signed-in caller
#   *   /api/resumes                     recruiter, sourcer, coordinator,
#                                         hiring_manager, rec_ops, admin
#                                         (sees candidate resumes pool)
#   POST /api/applications               candidate, member  (applies to a job)
#   GET  /api/applications               recruiter, rec_ops, admin
#                                         (lists incoming applications)
#
# Note: the candidate's own profile route under identity-service
# (/api/candidates/profile) goes through identity-service which already
# has middleware checking jwt.sub == route.user_id. OPA only adds the role
# fence — anyone with a valid JWT can hit GET /api/candidates/profile,
# but the back-end ensures they only see THEIR data.
# =============================================================================
package zta.authz.candidates

import future.keywords.if
import future.keywords.in

default allow := false

# ---------------------------------------------------------------------------
# Candidate's own profile — any signed-in user (back-end enforces ownership).
# ---------------------------------------------------------------------------
allow if {
	input.path == "/api/candidates/profile"
	count(data.zta.authz.user_roles) > 0
}

# ---------------------------------------------------------------------------
# Candidate's own application history (candidate-service GET /api/my-applications)
# — any signed-in user; back-end (role:candidate + ownership) enforces scope.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	input.path == "/api/my-applications"
	count(data.zta.authz.user_roles) > 0
}

# ---------------------------------------------------------------------------
# Resume pool — sourcer / recruiter / coordinator / hiring_manager / rec_ops /
# admin can view; only those roles can upload/delete (no candidates here).
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/resumes")
	data.zta.authz.has_any_role({
		"sourcer", "recruiter", "coordinator",
		"hiring_manager", "rec_ops", "admin"
	})
}

# ---------------------------------------------------------------------------
# Submitting an application to a job — anyone signed in (including 'member',
# which is the catch-all role for a logged-in candidate).
# ---------------------------------------------------------------------------
allow if {
	input.method == "POST"
	input.path == "/api/applications"
	data.zta.authz.has_any_role({"member", "recruiter", "rec_ops", "sourcer",
		"coordinator", "hiring_manager", "interviewer", "admin"})
}

# ---------------------------------------------------------------------------
# Application board / list — internal staff only.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	input.path == "/api/applications"
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "coordinator", "admin"})
}

allow if {
	startswith(input.path, "/api/applications/")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "coordinator",
		"hiring_manager", "admin"})
}

# ---------------------------------------------------------------------------
# Hiring board (pipelines, cards) — recruiter team + hiring_manager.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/board")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "coordinator",
		"hiring_manager", "admin"})
}
