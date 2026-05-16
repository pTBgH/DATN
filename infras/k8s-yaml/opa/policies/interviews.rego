# =============================================================================
# interviews.rego — authorization for /api/interviews/* and /api/scorecards/*
#
# Resource map (mirrors infras/kong/kong.yml hiring-service routes 198–219):
#   POST /api/interviews             coordinator, recruiter, rec_ops, admin
#                                     (schedules an interview)
#   GET  /api/interviews             coordinator, recruiter, rec_ops,
#                                     hiring_manager, interviewer, admin
#   PUT  /api/interviews/{id}        coordinator, recruiter, rec_ops, admin
#   POST /api/pipelines              recruiter, rec_ops, admin
#   GET  /api/pipelines              recruiter, rec_ops, hiring_manager,
#                                     interviewer, admin
#   POST /api/scorecards             interviewer, hiring_manager, admin
#                                     (write scorecard for assigned interview)
#   GET  /api/scorecards             recruiter, rec_ops, hiring_manager, admin
# =============================================================================
package zta.authz.interviews

import future.keywords.if
import future.keywords.in

default allow := false

# ---------------------------------------------------------------------------
# Schedule / update interviews — recruiter team + coordinator + admin.
# ---------------------------------------------------------------------------
allow if {
	input.method in {"POST", "PUT", "PATCH", "DELETE"}
	startswith(input.path, "/api/interviews")
	data.zta.authz.has_any_role({"coordinator", "recruiter", "rec_ops", "admin"})
}

# Reading interview list / detail — also the interviewer + hiring_manager
# (they need to see what they're assigned to).
allow if {
	input.method == "GET"
	startswith(input.path, "/api/interviews")
	data.zta.authz.has_any_role({"coordinator", "recruiter", "rec_ops",
		"hiring_manager", "interviewer", "admin"})
}

# ---------------------------------------------------------------------------
# Pipelines (the hiring board).
# ---------------------------------------------------------------------------
allow if {
	input.method in {"POST", "PUT", "PATCH", "DELETE"}
	startswith(input.path, "/api/pipelines")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "admin"})
}

allow if {
	input.method == "GET"
	startswith(input.path, "/api/pipelines")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "hiring_manager",
		"interviewer", "admin"})
}

# ---------------------------------------------------------------------------
# Scorecards — only interviewer/hiring_manager/admin can write; recruiter
# team can read.
# ---------------------------------------------------------------------------
allow if {
	input.method in {"POST", "PUT", "PATCH"}
	startswith(input.path, "/api/scorecards")
	data.zta.authz.has_any_role({"interviewer", "hiring_manager", "admin"})
}

allow if {
	input.method == "GET"
	startswith(input.path, "/api/scorecards")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "hiring_manager",
		"admin"})
}
