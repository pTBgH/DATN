#!/usr/bin/env bash
# =============================================================================
# zta-diag-cnp2.sh — READ-ONLY: vì sao app->identity vẫn 000 dù đã add CNP L7.
# Phân biệt 3 khả năng:
#   (a) candidate EGRESS hỏng       -> tới job-service:80 cũng 000
#   (b) identity L7 proxy blackhole -> tới service KHÁC (L4) OK, identity 000 hết
#   (c) rule L7 không match path    -> health 000 nhưng path-được-allow != 000
# Chạy trên baosrc. KHÔNG sửa cluster.
#   bash zta-diag-cnp2.sh
# =============================================================================
set -uo pipefail
NS="${NS:-job7189-apps}"
ex(){ # ex <app> <desc> <curl-args...>
  local app="$1" desc="$2"; shift 2
  local pod; pod="$(kubectl -n "$NS" get pod -l app="$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  [ -z "$pod" ] && { printf '    %-55s : (no pod)\n' "$desc"; return; }
  local code; code="$(kubectl -n "$NS" exec "$pod" -c app -- sh -lc "$*" 2>/dev/null)"
  printf '    %-55s : %s\n' "$desc" "$code"
}
line(){ printf '%.0s─' {1..78}; echo; }; hdr(){ echo; line; echo "  $1"; line; }

hdr "1) CONTROL — candidate egress tới service KHÁC (L4, không L7 ingress)"
ex candidate-service "GET job-service/api/health"     "curl -s -m5 -o /dev/null -w '%{http_code}' http://job-service/api/health"
ex candidate-service "GET storage-service/api/health" "curl -s -m5 -o /dev/null -w '%{http_code}' http://storage-service/api/health"
ex candidate-service "GET workspace-service/api/health" "curl -s -m5 -o /dev/null -w '%{http_code}' http://workspace-service/api/health"

hdr "2) candidate -> identity (health KHÔNG allow vs path ĐÃ allow)"
ex candidate-service "GET identity/api/health           (mong 000)"        "curl -s -m5 -o /dev/null -w '%{http_code}' http://identity-service/api/health"
ex candidate-service "GET identity/api/internal/users/1 (allow→mong !=000)" "curl -s -m5 -o /dev/null -w '%{http_code}' http://identity-service/api/internal/users/1"
ex candidate-service "POST identity/.../sync-user       (allow→mong !=000)" "curl -s -m5 -o /dev/null -w '%{http_code}' -X POST http://identity-service/api/internal/auth/sync-user -H 'Content-Type: application/json' -d '{\"keycloak_id\":\"x\",\"type\":\"candidate\"}'"

hdr "3) hiring -> identity (hiring là source ĐÃ allow L7 từ trước)"
ex hiring-service "GET identity/api/health             (mong 000 nếu L7 chặt)" "curl -s -m5 -o /dev/null -w '%{http_code}' http://identity-service/api/health"
ex hiring-service "GET identity/api/internal/users/1   (allow→mong !=000)"     "curl -s -m5 -o /dev/null -w '%{http_code}' http://identity-service/api/internal/users/1"

hdr "4) DNS + ClusterIP nhìn từ candidate (loại trừ DNS)"
POD="$(kubectl -n "$NS" get pod -l app=candidate-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
[ -n "$POD" ] && kubectl -n "$NS" exec "$POD" -c app -- sh -lc 'getent hosts identity-service || nslookup identity-service 2>/dev/null | tail -3' 2>/dev/null
echo "  identity-service ClusterIP/endpoints:"
kubectl -n "$NS" get svc identity-service -o wide 2>/dev/null | sed 's/^/    /'
kubectl -n "$NS" get endpoints identity-service 2>/dev/null | sed 's/^/    /'

hdr "5) CNP đang select identity-service (xem L7 vs L4)"
kubectl -n "$NS" get cnp 2>/dev/null | sed 's/^/    /'

hdr "XONG — copy toàn bộ output gửi lại."
