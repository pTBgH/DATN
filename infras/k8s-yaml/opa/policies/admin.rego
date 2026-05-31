# =============================================================================
# admin.rego — authorization cho /api/admin/users (quản trị người dùng)
# Chỉ role 'admin'. (/api/admin/jobs & /api/admin/categories đã do jobs.rego lo.)
# =============================================================================
package zta.authz.admin

import future.keywords.if

default allow := false

allow if {
	startswith(input.path, "/api/admin/users")
	data.zta.authz.has_any_role({"admin"})
}
