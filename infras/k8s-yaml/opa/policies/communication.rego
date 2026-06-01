# =============================================================================
# communication.rego — authorization for /api/conversations, /api/messages,
#                       /api/notifications
#
# Resource map (mirrors infras/kong/kong.yml lines 231–242):
#   GET  /api/conversations              any signed-in user (sees own)
#   POST /api/conversations              any signed-in user (starts a thread)
#   GET  /api/conversations/{id}/messages any signed-in user (back-end ownership)
#   POST /api/messages                   any signed-in user (sends a message)
#   GET  /api/notifications              any signed-in user (sees own)
#
# Back-end enforces ownership: users only see conversations/messages they
# participate in. OPA provides the role fence — any authenticated caller
# is allowed through.
# =============================================================================
package zta.authz.communication

import future.keywords.if

default allow := false

# ---------------------------------------------------------------------------
# Conversations — any signed-in user.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/conversations")
	count(data.zta.authz.user_roles) > 0
}

# ---------------------------------------------------------------------------
# Messages — any signed-in user.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/messages")
	count(data.zta.authz.user_roles) > 0
}

# ---------------------------------------------------------------------------
# Notifications — any signed-in user.
# ---------------------------------------------------------------------------
allow if {
	startswith(input.path, "/api/notifications")
	count(data.zta.authz.user_roles) > 0
}
