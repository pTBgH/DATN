#!/usr/bin/env bash
# =============================================================================
# fix-opa-recruiters-admin.sh
# Thêm 2 policy OPA còn THIẾU: recruiters.rego + admin.rego, và bổ sung 2 dòng
# aggregation vào default.rego, rồi nạp lại configmap security/opa-policies.
#
# GHI THẲNG vào repo policies dir (để bền vững — lần sau chạy zta-deploy-opa.sh
# vẫn còn). KHÔNG đụng image, KHÔNG rebuild. OPA tự reload từ configmap.
# Chạy trên baosrc. An toàn chạy lại nhiều lần (idempotent).
#
#   bash fix-opa-recruiters-admin.sh
#   (sau khi OK, nếu muốn lưu vĩnh viễn:  cd $REPO && git add infras/k8s-yaml/opa/policies && git commit)
# =============================================================================
set -euo pipefail
REPO="${REPO:-$HOME/projects/DATN}"
POLDIR="${POLDIR:-$REPO/infras/k8s-yaml/opa/policies}"
NS="${OPA_NAMESPACE:-security}"
CM="${CM_NAME:-opa-policies}"
REALM="${REALM:-job7189}"; CLIENT_ID="${CLIENT_ID:-web-frontend}"; PASSWORD="${PASSWORD:-dev1234}"

[ -d "$POLDIR" ] || { echo "ERR: không thấy $POLDIR (đặt REPO=… nếu repo ở chỗ khác)"; exit 1; }
echo "policies dir = $POLDIR"

# --- recruiters.rego ---------------------------------------------------------
cat > "$POLDIR/recruiters.rego" <<'REGO'
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
REGO

# --- admin.rego --------------------------------------------------------------
cat > "$POLDIR/admin.rego" <<'REGO'
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
REGO

# --- aggregation vào default.rego (idempotent) -------------------------------
if ! grep -q "data.zta.authz.recruiters.allow" "$POLDIR/default.rego"; then
cat >> "$POLDIR/default.rego" <<'REGO'

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
REGO
  echo "default.rego: đã thêm 2 dòng aggregation."
else
  echo "default.rego: đã có aggregation (bỏ qua)."
fi

echo "== regos sẽ nạp =="; ls -1 "$POLDIR"/*.rego | xargs -n1 basename

# --- check cú pháp nếu có opa binary ----------------------------------------
if command -v opa >/dev/null 2>&1; then
  echo "== opa check =="; opa check "$POLDIR" && echo "  syntax OK" || { echo "  opa check FAIL — DỪNG (không apply)"; exit 1; }
fi

# --- build & apply configmap (giống logic zta-deploy-opa.sh) -----------------
ARGS=(); for f in "$POLDIR"/*.rego; do ARGS+=(--from-file="$(basename "$f")=$f"); done
kubectl create configmap "$CM" -n "$NS" "${ARGS[@]}" --dry-run=client -o yaml \
  | kubectl label --local -f - openpolicyagent.org/policy=rego --dry-run=client -o yaml \
  | kubectl apply -f -

echo "== chờ opa reload (opa-kube-mgmt watch configmap ~5-10s) =="
sleep 8
echo "configmap keys hiện tại:"
kubectl -n "$NS" get configmap "$CM" -o jsonpath='{.data}' 2>/dev/null \
  | grep -oE '"[a-z]+\.rego"' | sort -u | sed 's/^/  /'

# --- verify qua Kong ---------------------------------------------------------
KONG_URL="${KONG_URL:-$(journalctl -u cloudflared-kong --no-pager -b 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)}"
KONG_URL="${KONG_URL%/}"
echo "== verify OPA qua Kong ($KONG_URL) =="
get_tok(){ curl -s --max-time 15 -X POST "$KONG_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=password -d "client_id=$CLIENT_ID" -d "username=$1" -d "password=$PASSWORD" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null; }
TR="$(get_tok recruiter1)"; TA="$(get_tok admin1)"; TM="$(get_tok member1)"
hb(){ curl -s -o /dev/null -w '%{http_code}' --max-time 15 -H "Authorization: Bearer $2" "$KONG_URL$1"; }
echo "recruiter1 /api/recruiters/profile : HTTP $(hb /api/recruiters/profile "$TR")  (mong: HẾT 403. 401 'Unauthorized Client' = OPA OK, còn lỗi azp ở identity — sẽ fix bước sau)"
echo "member1    /api/recruiters/profile : HTTP $(hb /api/recruiters/profile "$TM")  (mong: VẪN 403 — chặn đúng role)"
echo "admin1     /api/admin/users        : HTTP $(hb /api/admin/users "$TA")  (mong: HẾT 403. 404 = OPA OK nhưng identity chưa có route /api/admin/users)"
echo "DONE."
