# =============================================================================
# workspace.rego — authorization for /api/workspaces and /api/invitations
#
# Resource map (mirrors infras/kong/kong.yml lines 153–158):
#   GET  /api/workspaces             member, recruiter, rec_ops, sourcer,
#                                     coordinator, hiring_manager, interviewer,
#                                     admin (any signed-in user lists own)
#   POST /api/workspaces             rec_ops, admin only (create new workspace)
#   *    /api/workspaces/{id}        rec_ops, admin (manage workspace mgmt)
#   POST /api/invitations            recruiter, rec_ops, admin (invite into ws)
#   GET  /api/invitations            any signed-in user (sees own invites)
#   GET  /api/options/company-types  public (handled in public.rego)
# =============================================================================
package zta.authz.workspace

import future.keywords.if
import future.keywords.in

default allow := false

# ---------------------------------------------------------------------------
# Listing the workspaces a user belongs to — any signed-in caller.
# ---------------------------------------------------------------------------
allow if {
	input.method == "GET"
	input.path == "/api/workspaces"
	count(data.zta.authz.user_roles) > 0
}

# workspace-service GET /api/my-workspaces — any signed-in caller lists own.
allow if {
	input.method == "GET"
	input.path == "/api/my-workspaces"
	count(data.zta.authz.user_roles) > 0
}

allow if {
	input.method == "GET"
	startswith(input.path, "/api/workspaces/")
	count(data.zta.authz.user_roles) > 0
}

# ---------------------------------------------------------------------------
# Creating / editing / deleting a workspace — rec_ops + admin only.
# ---------------------------------------------------------------------------
allow if {
	input.method == "POST"
	input.path == "/api/workspaces"
	data.zta.authz.has_any_role({"rec_ops", "admin"})
}

allow if {
	input.method in {"PUT", "PATCH", "DELETE"}
	startswith(input.path, "/api/workspaces/")
	data.zta.authz.has_any_role({"rec_ops", "admin"})
}

# ---------------------------------------------------------------------------
# Invitations.
# ---------------------------------------------------------------------------
allow if {
	input.method == "POST"
	input.path == "/api/invitations"
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "admin"})
}

allow if {
	input.method in {"PUT", "PATCH", "DELETE"}
	startswith(input.path, "/api/invitations/")
	data.zta.authz.has_any_role({"recruiter", "rec_ops", "admin"})
}

allow if {
	input.method == "GET"
	startswith(input.path, "/api/invitations")
	count(data.zta.authz.user_roles) > 0
}
