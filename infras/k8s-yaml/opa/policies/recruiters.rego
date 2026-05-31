# =============================================================================
# recruiters.rego — authorization cho /api/recruiters/profile
# Nhà tuyển dụng (và admin) xem/sửa hồ sơ recruiter của chính họ. Back-end
# (identity-service) vẫn enforce ownership theo jwt.sub; OPA chỉ chặn role.
# =============================================================================
package zta.authz.recruiters

import future.keywords.if

default allow := false

allow if {
	startswith(input.path, "/api/recruiters/profile")
	data.zta.authz.has_any_role({
		"recruiter", "rec_ops", "coordinator",
		"hiring_manager", "sourcer", "interviewer", "admin",
	})
}
