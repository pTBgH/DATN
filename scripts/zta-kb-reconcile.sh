#!/usr/bin/env bash
# =============================================================================
# zta-kb-reconcile.sh  —  Knowledge-Base ↔ Running-System Reconciliation Check
# =============================================================================
#
# MỤC ĐÍCH
#   Đối chiếu MỌI claim trong knowledge-base (doc/ — sẽ đổi tên thành
#   knowledge-base/) với TRẠNG THÁI THỰC TẾ của cluster Kubernetes đang chạy.
#   Mỗi điều khẳng định trong KB chỉ được coi là "đúng" nếu cluster trả ra
#   đúng kết quả đó. Script in PASS / FAIL / WARN / SKIP cho từng claim và
#   ghi toàn bộ ra 1 file log để lưu evidence.
#
#   Tài liệu nguồn (source-of-truth precedence):
#     1. doc/40-zta-system-snapshot-20260527.md   (snapshot live mới nhất)
#     2. doc/00-project-overview.md, 03/04/05/06/07/08/19
#     3. doc/architecture/SYSTEM_PORT_MAPPING_ARCHITECTURE.md
#   Khi 2 chương KB mâu thuẫn nhau, script vẫn check theo snapshot 40 và in
#   ra mục "DRIFT WATCH" ở cuối để bạn tự quyết định sửa chương nào.
#
# CHẠY Ở ĐÂU
#   Chạy trên MÁY CỦA BẠN (máy có kubeconfig trỏ tới cluster ZTA srv01).
#   KHÔNG chạy trên máy Devin. Script chỉ READ-ONLY: chỉ `kubectl get` /
#   `describe` / `exec` đọc, KHÔNG apply / patch / delete bất cứ thứ gì.
#
# CÁCH CHẠY
#   bash scripts/zta-kb-reconcile.sh                 # chạy full
#   bash scripts/zta-kb-reconcile.sh --only 7,11     # chỉ chạy section 7 & 11
#   bash scripts/zta-kb-reconcile.sh --list          # liệt kê các section
#   bash scripts/zta-kb-reconcile.sh --no-exec       # bỏ qua các check cần kubectl exec
#   bash scripts/zta-kb-reconcile.sh --static        # chỉ check tĩnh (không cần cluster)
#
# BIẾN MÔI TRƯỜNG (override nếu cluster của bạn khác)
#   KUBECTL=kubectl                      lệnh kubectl (vd: "k3s kubectl")
#   KCTX=<context>                       kube-context muốn dùng (mặc định: hiện tại)
#   K_TIMEOUT=15                         timeout (giây) cho mỗi lệnh kubectl
#   EXEC_TIMEOUT=20                      timeout cho kubectl exec
#   REPO_ROOT=<path>                     gốc repo (mặc định: tự dò từ vị trí script)
#   EXPECT_NODES=4                       số node mong đợi (snapshot: 4)
#   EXPECT_APP_REPLICAS=2                replica mỗi backend service
#   VAULT_ADDR / VAULT_TOKEN             nếu muốn check Vault lease sâu hơn
#
# FALLBACK (yêu cầu của user)
#   Mỗi section chạy trong subshell riêng + timeout. Nếu 1 check lỗi/hang,
#   script LOG cảnh báo rồi NHẢY sang section tiếp theo — không bao giờ chết
#   giữa chừng. Tổng kết PASS/FAIL/WARN/SKIP được in ở cuối.
#
# EXIT CODE
#   0  = không có FAIL (có thể còn WARN)
#   1  = có >=1 FAIL
#   2  = không tới được cluster (mọi check cluster bị SKIP)
# =============================================================================

# Cố ý KHÔNG set -e: ta muốn chạy tiếp khi 1 check lỗi.
set -uo pipefail

# -----------------------------------------------------------------------------
# 0.0  Cấu hình & biến toàn cục
# -----------------------------------------------------------------------------
KUBECTL="${KUBECTL:-kubectl}"
KCTX="${KCTX:-}"
K_TIMEOUT="${K_TIMEOUT:-15}"
EXEC_TIMEOUT="${EXEC_TIMEOUT:-20}"
EXPECT_NODES="${EXPECT_NODES:-4}"
EXPECT_APP_REPLICAS="${EXPECT_APP_REPLICAS:-2}"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
DEFAULT_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "$PWD")"
REPO_ROOT="${REPO_ROOT:-$DEFAULT_REPO_ROOT}"

TS="$(date +%Y%m%d_%H%M%S)"
EVIDENCE_DIR="${REPO_ROOT}/evidence"
mkdir -p "$EVIDENCE_DIR" 2>/dev/null || EVIDENCE_DIR="/tmp"
LOG_FILE="${EVIDENCE_DIR}/kb-reconcile-${TS}.log"
# RESULT_LOG: nơi pass()/fail()/warn() append (đếm được qua subshell).
RESULT_LOG="$(mktemp /tmp/kb-reconcile-results.XXXXXX)"
DRIFT_LOG="$(mktemp /tmp/kb-reconcile-drift.XXXXXX)"

ONLY_SECTIONS=""
NO_EXEC=0
STATIC_ONLY=0
LIST_ONLY=0
CLUSTER_OK=0          # 1 nếu kết nối được cluster

# Màu (tắt nếu không phải TTY)
if [ -t 1 ]; then
  C_RST=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_YEL=$'\033[33m'; C_BLU=$'\033[34m'; C_CYA=$'\033[36m'; C_BLD=$'\033[1m'
else
  C_RST=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_BLD=""
fi

# -----------------------------------------------------------------------------
# 0.1  Parse arguments
# -----------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --only)    ONLY_SECTIONS="${2:-}"; shift 2 ;;
    --only=*)  ONLY_SECTIONS="${1#*=}"; shift ;;
    --no-exec) NO_EXEC=1; shift ;;
    --static)  STATIC_ONLY=1; shift ;;
    --list)    LIST_ONLY=1; shift ;;
    -h|--help) sed -n '1,70p' "$SCRIPT_PATH"; exit 0 ;;
    *) echo "Tham số lạ: $1 (xem --help)"; shift ;;
  esac
done

# -----------------------------------------------------------------------------
# 0.2  Logging helpers — vừa in màn hình, vừa append vào LOG_FILE
# -----------------------------------------------------------------------------
# Toàn bộ stdout/stderr được tee vào LOG_FILE.
exec > >(tee -a "$LOG_FILE") 2>&1

hr()    { printf '%s\n' "------------------------------------------------------------------------------"; }
hr2()   { printf '%s\n' "=============================================================================="; }
section_banner() {
  echo ""
  hr2
  echo "${C_BLD}${C_BLU}### SECTION $1 — $2${C_RST}"
  hr2
}
note()  { echo "    ${C_CYA}·${C_RST} $*"; }
cmd()   { echo "    ${C_CYA}\$ $*${C_RST}"; }

pass()  { echo "    ${C_GRN}✅ PASS${C_RST}  $1"; echo "PASS" >> "$RESULT_LOG"; }
fail()  { echo "    ${C_RED}❌ FAIL${C_RST}  $1${2:+  — $2}"; echo "FAIL|$1${2:+ — $2}" >> "$RESULT_LOG"; }
warn()  { echo "    ${C_YEL}⚠️  WARN${C_RST}  $1${2:+  — $2}"; echo "WARN|$1${2:+ — $2}" >> "$RESULT_LOG"; }
skip()  { echo "    ${C_BLU}⏭️  SKIP${C_RST}  $1${2:+  — $2}"; echo "SKIP|$1${2:+ — $2}" >> "$RESULT_LOG"; }
drift() { echo "    ${C_YEL}🔀 DRIFT${C_RST} $1"; echo "$1" >> "$DRIFT_LOG"; }

# -----------------------------------------------------------------------------
# 0.3  kubectl wrappers (có timeout + context). Không bao giờ làm chết script.
# -----------------------------------------------------------------------------
_kbase() {
  if [ -n "$KCTX" ]; then
    timeout --foreground --kill-after=5s "${K_TIMEOUT}s" "$KUBECTL" --context "$KCTX" "$@"
  else
    timeout --foreground --kill-after=5s "${K_TIMEOUT}s" "$KUBECTL" "$@"
  fi
}
# k: chạy kubectl, trả output; nuốt lỗi để caller tự xử.
k()  { _kbase "$@" 2>/dev/null; }
# kx: kubectl exec có timeout dài hơn.
kx() {
  if [ -n "$KCTX" ]; then
    timeout --foreground --kill-after=5s "${EXEC_TIMEOUT}s" "$KUBECTL" --context "$KCTX" exec "$@" 2>/dev/null
  else
    timeout --foreground --kill-after=5s "${EXEC_TIMEOUT}s" "$KUBECTL" exec "$@" 2>/dev/null
  fi
}

# Tiện ích kiểm tra sự tồn tại của resource.
res_exists() { # kind name ns
  local kind="$1" name="$2" ns="${3:-}"
  if [ -n "$ns" ]; then k get "$kind" "$name" -n "$ns" -o name >/dev/null 2>&1
  else k get "$kind" "$name" -o name >/dev/null 2>&1; fi
}
ns_exists() { k get ns "$1" -o name >/dev/null 2>&1; }

# Đếm số dòng không rỗng. LUÔN in ra đúng 1 số nguyên (tránh "0\n0").
count_lines() { awk 'NF{c++} END{print c+0}'; }

# Lấy số replica ready của 1 deployment/sts/ds.
workload_ready() { # kind name ns
  local kind="$1" name="$2" ns="$3"
  k get "$kind" "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}{" / "}{.status.replicas}' 2>/dev/null
}

# Guard: chỉ chạy check cluster nếu CLUSTER_OK=1, ngược lại SKIP.
need_cluster() {
  if [ "$CLUSTER_OK" -ne 1 ]; then
    skip "$1" "cluster không kết nối được"
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# 0.4  run_section — chạy 1 section trong subshell, có fallback hoàn toàn.
#      Nếu section lỗi/hang/exit!=0, log WARN rồi tiếp tục section sau.
# -----------------------------------------------------------------------------
SECTION_IDS=()
SECTION_TITLES=()
SECTION_FUNCS=()
register() { SECTION_IDS+=("$1"); SECTION_TITLES+=("$2"); SECTION_FUNCS+=("$3"); }

should_run() { # id
  local id="$1"
  [ -z "$ONLY_SECTIONS" ] && return 0
  local IFS=','
  for s in $ONLY_SECTIONS; do [ "$s" = "$id" ] && return 0; done
  return 1
}

run_section() { # id title func
  local id="$1" title="$2" func="$3"
  should_run "$id" || return 0
  section_banner "$id" "$title"
  # Subshell cô lập: lỗi bên trong (kể cả set -u abort) không giết script cha.
  ( "$func" )
  local rc=$?
  if [ $rc -ne 0 ]; then
    warn "Section $id ('$title') kết thúc bất thường (rc=$rc)" "đã bỏ qua, chạy tiếp section sau (fallback)"
  fi
}

# =============================================================================
# SECTION 0 — PREFLIGHT: kết nối cluster, version, node
# =============================================================================
sec_preflight() {
  note "KB nguồn: doc/40-zta-system-snapshot (3+1 node K8s 1.30 kubeadm, Cilium 1.19.4)"

  if ! command -v "$KUBECTL" >/dev/null 2>&1; then
    fail "kubectl ('$KUBECTL') không có trên PATH" "cài kubectl hoặc set KUBECTL=..."
    return 0
  fi
  pass "kubectl binary tồn tại ($($KUBECTL version --client -o json 2>/dev/null | head -c 0; echo "$KUBECTL"))"

  if [ "$STATIC_ONLY" -eq 1 ]; then
    skip "Kết nối cluster" "đang chạy --static"
    return 0
  fi

  # CLUSTER_OK đã được dò ở shell cha (xem MAIN) vì section chạy trong subshell.
  if [ "$CLUSTER_OK" -eq 1 ]; then
    pass "Kết nối được API server"
  else
    fail "Không kết nối được API server" "kiểm tra kubeconfig/context; các section cluster sẽ bị SKIP"
    return 0
  fi

  local ctx; ctx="$(k config current-context 2>/dev/null)"
  note "current-context: ${ctx:-<unknown>}"

  # K8s server version ~ 1.30
  local sv; sv="$(k version -o json 2>/dev/null | grep -oE '"gitVersion":[^,]+' | sed -n '2p')"
  note "server version: ${sv:-<unknown>}"
  if echo "$sv" | grep -q '1\.30'; then pass "K8s server version 1.30.x (đúng snapshot)"
  else warn "K8s server version không phải 1.30.x" "KB snapshot ghi 1.30"; fi

  # Node count
  local nodes; nodes="$(k get nodes --no-headers 2>/dev/null | count_lines)"
  if [ "${nodes:-0}" -eq "$EXPECT_NODES" ]; then
    pass "Số node = $nodes (đúng EXPECT_NODES=$EXPECT_NODES)"
  else
    warn "Số node = ${nodes:-0}, mong đợi $EXPECT_NODES" "snapshot: srv01(cp)+srv02/03/05"
  fi
  k get nodes -o wide 2>/dev/null | sed 's/^/      /'

  # Node Ready?
  local notready; notready="$(k get nodes --no-headers 2>/dev/null | awk '$2!="Ready"{print $1}' | count_lines)"
  if [ "${notready:-0}" -eq 0 ]; then pass "Tất cả node ở trạng thái Ready"
  else fail "Có ${notready} node KHÔNG Ready"; fi

  # Tailscale CGNAT nodeIP 100.64.0.0/10 (snapshot: tất cả node Tailscale)
  local ntot ncgnat
  ntot="$(k get nodes --no-headers 2>/dev/null | count_lines)"
  ncgnat="$(k get nodes -o wide --no-headers 2>/dev/null | awk '{print $6}' | grep -cE '^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.')"
  if [ "${ncgnat:-0}" -ge 1 ]; then
    pass "NodeIP CGNAT 100.64.0.0/10 (Tailscale): ${ncgnat}/${ntot} node"
    if [ "${ncgnat:-0}" -lt "${ntot:-0}" ]; then
      warn "Có $((ntot-ncgnat)) node KHÔNG trên CGNAT (vd srv05 dùng IP LAN 172.16.x)" "snapshot nói toàn bộ Tailscale — ghi chú/chuẩn hóa trong KB"
    fi
  else
    warn "Không node nào có IP CGNAT 100.64.0.0/10" "snapshot ghi Tailscale CGNAT"
  fi
}

# =============================================================================
# SECTION 1 — NAMESPACE INVENTORY (doc/00 + snapshot 40)
# =============================================================================
sec_namespaces() {
  need_cluster "Namespace inventory" || return 0
  # ns -> mô tả (theo doc/00 + snapshot 40)
  local core_ns=(job7189-apps gateway security vault data monitoring management)
  local infra_ns=(ingress-nginx cert-manager kube-system local-path-storage)
  local zta_ns=(spire gatekeeper-system cosign-system trivy-system security-cdm)
  local optional_ns=(registry)

  echo "  Core namespaces (bắt buộc):"
  for ns in "${core_ns[@]}"; do
    if ns_exists "$ns"; then pass "namespace/$ns tồn tại"; else fail "namespace/$ns THIẾU" "doc/00 liệt kê là core tier"; fi
  done
  echo "  Infra namespaces:"
  for ns in "${infra_ns[@]}"; do
    if ns_exists "$ns"; then pass "namespace/$ns tồn tại"; else warn "namespace/$ns thiếu"; fi
  done
  echo "  ZTA add-on namespaces (snapshot 40):"
  for ns in "${zta_ns[@]}"; do
    if ns_exists "$ns"; then pass "namespace/$ns tồn tại"
    else warn "namespace/$ns thiếu" "snapshot ghi (vài cái có thể 0/0 hoặc deferred)"; fi
  done
  echo "  Optional / deferred namespaces:"
  for ns in "${optional_ns[@]}"; do
    if ns_exists "$ns"; then pass "namespace/$ns tồn tại"
    else note "namespace/$ns không có (optional — không trong snapshot 40; có thể dùng registry ngoài)"; fi
  done
  # Orphan ns: có trên cluster nhưng không do manifest nào trong repo tạo.
  if ns_exists pdp-system; then
    warn "namespace/pdp-system TỔN TẠI nhưng không có manifest trong repo" "PDP thật ở ns=security — pdp-system có thể là ns mồ côi; kiểm tra: kubectl get all -n pdp-system"
  fi

  # frontend ns: port-mapping doc claims fe-candidate/fe-recruiter trong ns 'frontend',
  # nhưng doc/19 + cleanup-plan nói frontend ĐÃ tách khỏi cluster ZTA.
  if ns_exists frontend; then
    warn "namespace/frontend TỒN TẠI" "doc/19 + cleanup-plan nói FE đã tách khỏi cluster — kiểm tra lại"
    drift "Port-mapping doc liệt kê ns 'frontend' (fe-candidate/fe-recruiter:3000), nhưng doc/19 nói FE đã gỡ khỏi cluster ZTA. Cluster: ns 'frontend' tồn tại."
  else
    pass "namespace/frontend KHÔNG tồn tại (khớp doc/19: FE tách khỏi cluster ZTA)"
    drift "Port-mapping doc (SYSTEM_PORT_MAPPING_ARCHITECTURE.md mục 3) vẫn liệt kê Frontend Layer ns 'frontend' với fe-candidate/fe-recruiter — thực tế ns không tồn tại. Cần xoá/đánh dấu mục này trong port-mapping doc."
  fi

  note "Danh sách namespace thực tế:"
  k get ns --no-headers 2>/dev/null | awk '{printf "      %-24s %s\n",$1,$2}'
}

# =============================================================================
# SECTION 2 — 7 BACKEND MICROSERVICES (doc/00, doc/03)
# =============================================================================
SERVICES=(identity-service workspace-service job-service hiring-service candidate-service communication-service storage-service)
sec_backend_services() {
  need_cluster "7 backend microservices" || return 0
  local ns=job7189-apps

  echo "  Deployment + readiness (mong đợi mỗi svc $EXPECT_APP_REPLICAS replica):"
  for svc in "${SERVICES[@]}"; do
    if res_exists deployment "$svc" "$ns"; then
      local rr; rr="$(workload_ready deployment "$svc" "$ns")"
      local ready_n; ready_n="$(echo "$rr" | awk -F'/' '{gsub(/ /,"");print $1}')"
      if [ "${ready_n:-0}" -ge 1 ]; then pass "deployment/$svc ready=$rr"
      else fail "deployment/$svc KHÔNG có replica ready ($rr)"; fi
    else
      fail "deployment/$svc THIẾU trong ns=$ns" "doc/00 liệt kê 7 service"
    fi
  done

  # Service object + port 80 (doc port-mapping: backend đều mở port 80)
  echo "  Service object (ClusterIP) + port 80:"
  for svc in "${SERVICES[@]}"; do
    if res_exists service "$svc" "$ns"; then
      local p; p="$(k get svc "$svc" -n "$ns" -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)"
      if echo " $p " | grep -q ' 80 '; then pass "service/$svc expose port 80 (đúng port-mapping)"
      else warn "service/$svc port='$p' (doc nói 80)"; fi
    else
      fail "service/$svc THIẾU"
    fi
  done

  # 4 containers / pod: app, vault-agent, env-loader, env-watcher (doc/00 Pod Structure)
  echo "  Pod structure: mỗi pod backend phải có 4 container (app, vault-agent, env-loader, env-watcher):"
  local expect_ctr=(app vault-agent env-loader env-watcher)
  for svc in "${SERVICES[@]}"; do
    local pod; pod="$(k get pods -n "$ns" -l app="$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    if [ -z "$pod" ]; then warn "Không tìm thấy pod cho app=$svc (thử label khác?)"; continue; fi
    local ctrs; ctrs="$(k get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[*].name}{" "}{.spec.initContainers[*].name}' 2>/dev/null)"
    local miss=""
    for c in "${expect_ctr[@]}"; do echo " $ctrs " | grep -q " $c " || miss="$miss $c"; done
    if [ -z "$miss" ]; then pass "$svc pod có đủ 4 container ($pod)"
    else warn "$svc pod thiếu container:$miss" "containers thực tế: $ctrs"; fi
  done
}

# =============================================================================
# SECTION 3 — PER-SERVICE REDIS CACHE (doc/19, port-mapping)
# =============================================================================
sec_redis() {
  need_cluster "Per-service Redis cache" || return 0
  local ns=job7189-apps
  note "doc port-mapping: mỗi app có 1 Redis riêng (<svc>-redis), port 6379"
  for svc in "${SERVICES[@]}"; do
    local r="${svc}-redis"
    if res_exists deployment "$r" "$ns"; then
      local rr; rr="$(workload_ready deployment "$r" "$ns")"
      pass "deployment/$r tồn tại (ready=$rr)"
    else
      warn "deployment/$r thiếu" "doc/19 nói mỗi service có Redis riêng"
    fi
  done
}

# =============================================================================
# SECTION 4 — IDENTITY LAYER: Keycloak + Vault + SPIRE + PDP (doc/03, snapshot 40)
# =============================================================================
sec_identity() {
  need_cluster "Identity layer" || return 0

  # --- Keycloak (security ns, port 8080) ---
  echo "  Keycloak:"
  if res_exists deployment keycloak security; then
    pass "deployment/keycloak (ns=security) tồn tại — ready=$(workload_ready deployment keycloak security)"
    local kp; kp="$(k get svc keycloak -n security -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)"
    echo " $kp " | grep -q ' 8080 ' && pass "keycloak service port 8080 (đúng doc/03)" || warn "keycloak port='$kp' (doc nói 8080)"
    # Dual realm: 7189_internal + job7189 (cần exec/curl vào keycloak)
    if [ "$NO_EXEC" -eq 0 ]; then
      local kpod; kpod="$(k get pods -n security -l app=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
      if [ -n "$kpod" ]; then
        for realm in 7189_internal job7189; do
          if kx "$kpod" -n security -- sh -c "curl -sf http://localhost:8080/realms/$realm/.well-known/openid-configuration >/dev/null 2>&1"; then
            pass "Keycloak realm '$realm' phản hồi OIDC discovery (đúng dual-realm doc/03)"
          else
            warn "Không xác minh được realm '$realm' qua localhost:8080" "thử endpoint khác / kiểm tra thủ công"
          fi
        done
      else warn "Không thấy pod keycloak để check realm"; fi
    else skip "Keycloak dual-realm check" "--no-exec"; fi
  else
    fail "deployment/keycloak THIẾU (ns=security)"
  fi

  # --- Vault (statefulset vault → vault-0, port 8200) + vault-dev (8300) + injector ---
  echo "  Vault (Dual-Vault):"
  if res_exists statefulset vault vault; then
    pass "statefulset/vault (ns=vault) tồn tại — ready=$(workload_ready statefulset vault vault)"
  else
    fail "statefulset/vault THIẾU (ns=vault)" "doc/03 Dual-Vault: vault-prod StatefulSet"
  fi
  if res_exists deployment vault-dev vault; then pass "deployment/vault-dev (transit auto-unseal, 8300) tồn tại"
  else warn "deployment/vault-dev thiếu" "doc/03: vault-dev transit engine auto-unseal"; fi
  # injector: tên có thể là vault-agent-injector hoặc vault-agent-agent-injector
  if res_exists deployment vault-agent-injector vault || res_exists deployment vault-agent-agent-injector vault; then
    pass "vault-agent-injector (MutatingWebhook) tồn tại"
  else warn "vault-agent-injector thiếu" "doc/00: inject 4-container sidecar"; fi
  # MutatingWebhookConfiguration cho vault
  if k get mutatingwebhookconfiguration 2>/dev/null | grep -qi vault; then
    pass "MutatingWebhookConfiguration cho Vault tồn tại (inject sidecar)"
  else warn "Không thấy MutatingWebhookConfiguration vault"; fi
  # Vault sealed?
  if [ "$NO_EXEC" -eq 0 ]; then
    local vstat; vstat="$(kx vault-0 -n vault -- sh -c 'VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 vault status -format=json 2>/dev/null')"
    if echo "$vstat" | grep -q '"sealed"'; then
      if echo "$vstat" | grep -q '"sealed": *false'; then pass "vault-prod UNSEALED (auto-unseal hoạt động)"
      else fail "vault-prod đang SEALED" "doc/03 Known Limitation: vault-dev restart → mất transit key"; fi
    else warn "Không đọc được vault status (token/exec)" "chạy thủ công: vault status"; fi
  else skip "Vault seal status" "--no-exec"; fi

  # --- SPIRE (snapshot 40: server STS 1/1, agent DS 4/4, trustDomain zta.job7189) ---
  echo "  SPIRE:"
  if ns_exists spire; then
    local sserver; sserver="$(k get statefulset -n spire -o name 2>/dev/null | grep -i server | head -1)"
    [ -n "$sserver" ] && pass "SPIRE server StatefulSet: $sserver (ready=$(k get $sserver -n spire -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null))" || warn "SPIRE server STS không thấy"
    local sds; sds="$(k get daemonset -n spire -o name 2>/dev/null | grep -i agent | head -1)"
    if [ -n "$sds" ]; then
      local dr; dr="$(k get $sds -n spire -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}' 2>/dev/null)"
      pass "SPIRE agent DaemonSet: $sds (ready=$dr — snapshot mong đợi 4/4)"
    else warn "SPIRE agent DS không thấy"; fi
    local spiffeids; spiffeids="$(k get clusterspiffeid --no-headers 2>/dev/null | count_lines)"
    if [ "${spiffeids:-0}" -ge 1 ]; then pass "ClusterSPIFFEID count=$spiffeids (snapshot ~10)"
    else warn "Không thấy ClusterSPIFFEID (CRD chưa cài?)"; fi
  else
    warn "namespace/spire không tồn tại" "snapshot 40: SPIRE deployed"
  fi

  # --- PDP Controller (zta-pdp ns=security) ---
  echo "  PDP Controller:"
  if res_exists deployment zta-pdp security; then
    pass "deployment/zta-pdp (ns=security) tồn tại — ready=$(workload_ready deployment zta-pdp security)"
    # PDP_CVE_INPUT=false (snapshot)
    local cve; cve="$(k get deploy zta-pdp -n security -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PDP_CVE_INPUT")].value}' 2>/dev/null)"
    [ "$cve" = "false" ] && pass "PDP env PDP_CVE_INPUT=false (đúng snapshot)" || warn "PDP_CVE_INPUT='$cve' (snapshot ghi false)"
  else
    warn "deployment/zta-pdp thiếu" "snapshot 40: PDP deployed"
  fi
}

# =============================================================================
# SECTION 5 — SERVICEACCOUNT ↔ VAULT ROLE MAPPING (doc/03)
# =============================================================================
sec_serviceaccounts() {
  need_cluster "ServiceAccount mapping" || return 0
  local ns=job7189-apps
  note "doc/03: mỗi service có 1 SA cùng tên → map 1:1 Vault role"
  for svc in "${SERVICES[@]}"; do
    if res_exists serviceaccount "$svc" "$ns"; then pass "serviceaccount/$svc tồn tại"
    else fail "serviceaccount/$svc THIẾU" "doc/03 SA mapping 1:1"; fi
  done
}

# =============================================================================
# SECTION 6 — KONG GATEWAY + JWT MATRIX (doc/04, kong.yml)
# =============================================================================
sec_kong() {
  need_cluster "Kong Gateway + JWT" || return 0
  echo "  Kong deployment (ns=gateway, DB-less):"
  if res_exists deployment kong-gateway gateway || k get deploy -n gateway -o name 2>/dev/null | grep -qi kong; then
    pass "Kong deployment tồn tại (ns=gateway)"
  else
    fail "Kong deployment THIẾU (ns=gateway)" "doc/04 PEP biên"
  fi

  # NodePort 30000 (port-mapping)
  local knp; knp="$(k get svc -n gateway -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.ports[*].nodePort}{" "}{end}' 2>/dev/null)"
  if echo "$knp" | grep -q '30000'; then pass "kong-proxy NodePort 30000 (đúng port-mapping)"
  else warn "Không thấy NodePort 30000 ở gateway ns" "thực tế: $knp"; fi

  # DB-less mode
  local kpod; kpod="$(k get pods -n gateway -o name 2>/dev/null | grep -i kong | head -1 | sed 's#pod/##')"
  if [ -n "$kpod" ] && [ "$NO_EXEC" -eq 0 ]; then
    local dbmode; dbmode="$(kx "$kpod" -n gateway -- sh -c 'echo "$KONG_DATABASE"' 2>/dev/null)"
    [ "$dbmode" = "off" ] && pass "Kong KONG_DATABASE=off (DB-less — đúng doc/04)" || warn "KONG_DATABASE='$dbmode' (doc nói off/DB-less)"
    # JWT plugin enabled + RS256 + admin API readonly
    if kx "$kpod" -n gateway -- sh -c 'curl -sf http://localhost:8001/plugins 2>/dev/null' | grep -q '"name":"jwt"'; then
      pass "Kong có plugin jwt được enable (RS256)"
    else warn "Không xác minh được plugin jwt qua admin 8001"; fi
  else
    skip "Kong DB-less + jwt plugin (exec)" "${NO_EXEC:+--no-exec}${kpod:+}"
  fi

  # So sánh route trong kong.yml (repo) với route live (nếu admin API đọc được)
  local kongyml="${REPO_ROOT}/infras/kong/kong.yml"
  if [ -f "$kongyml" ]; then
    local routes_file; routes_file="$(grep -cE '^\s*- name: .*-route|^\s*- name: .*-service' "$kongyml" 2>/dev/null)"
    note "kong.yml (repo) khai báo ~$(grep -cE '^\s*- name:' "$kongyml") name entries (service+route+plugin)"
    pass "Tìm thấy infras/kong/kong.yml (declarative config nguồn)"
  else
    warn "Không thấy infras/kong/kong.yml" "doc/04 trỏ config file này"
  fi

  # Kong Prometheus scrape (snapshot: 1 target)
  if k get servicemonitor -A 2>/dev/null | grep -qi kong || k get cm -n gateway 2>/dev/null | grep -qi prometheus; then
    pass "Có dấu hiệu Kong được Prometheus scrape (snapshot: 1 target)"
  else warn "Không xác minh được Kong Prometheus scrape"; fi
}

# =============================================================================
# SECTION 7 — CILIUM MICROSEGMENTATION (doc/04, snapshot 40)
# =============================================================================
sec_cilium() {
  need_cluster "Cilium microsegmentation" || return 0

  if ! k get crd ciliumnetworkpolicies.cilium.io >/dev/null 2>&1; then
    fail "CRD CiliumNetworkPolicy không tồn tại" "Cilium chưa cài? bỏ qua phần CNP"
    return 0
  fi

  # Cilium version 1.19.x
  local cv; cv="$(k -n kube-system get ds cilium -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
  echo "$cv" | grep -qE '1\.19' && pass "Cilium image 1.19.x ($cv)" || warn "Cilium image='$cv' (snapshot: 1.19.4)"

  # CNP trong job7189-apps (snapshot: 11)
  local cnp_apps; cnp_apps="$(k get cnp -n job7189-apps --no-headers 2>/dev/null | count_lines)"
  if [ "${cnp_apps:-0}" -ge 11 ]; then pass "CNP trong job7189-apps = $cnp_apps (snapshot ≥11)"
  elif [ "${cnp_apps:-0}" -gt 0 ]; then warn "CNP trong job7189-apps = $cnp_apps" "snapshot ghi 11"
  else fail "Không có CNP nào trong job7189-apps" "doc/04 microseg"; fi

  # Default-deny coverage (snapshot: 4/7 ns đã có; data/monitoring/management PENDING)
  echo "  Default-deny coverage (snapshot: applied apps/gateway/security/vault; PENDING data/monitoring/management):"
  for ns in job7189-apps gateway security vault; do
    if k get cnp -n "$ns" -o name 2>/dev/null | grep -qiE 'default-deny'; then
      pass "$ns có CNP default-deny (đúng snapshot)"
    else
      warn "$ns KHÔNG thấy CNP default-deny" "snapshot nói đã apply"
    fi
  done
  for ns in data monitoring management; do
    if k get cnp -n "$ns" -o name 2>/dev/null | grep -qiE 'default-deny'; then
      pass "$ns ĐÃ có default-deny (snapshot ghi PENDING → có thể đã rollout thêm)"
      drift "Snapshot 40 ghi default-deny ns '$ns' là PENDING, nhưng cluster đã có. Cập nhật snapshot."
    else
      warn "$ns chưa có default-deny (khớp snapshot: PENDING)" "file: cilium-policies/namespaces/*"
    fi
  done

  # L7 CNP (snapshot: 5 VALID=True): keycloak-oidc, keycloak-jwks, kong-admin, prom-metrics, vault-api
  echo "  L7 CNP (snapshot: 5 policy VALID):"
  local l7; l7="$(k get cnp -A --no-headers 2>/dev/null | grep -iE 'l7|keycloak|jwks|kong-admin|prom|vault-api' | count_lines)"
  if [ "${l7:-0}" -ge 1 ]; then pass "Tìm thấy ~$l7 L7-ish CNP (snapshot: 5 VALID)"
  else warn "Không thấy L7 CNP" "snapshot: 5 L7 policies"; fi

  # CiliumClusterwideNetworkPolicy + CIDRGroup threat-intel
  if k get ccnp --no-headers 2>/dev/null | grep -qi threat-intel; then pass "CCNP threat-intel egress-deny tồn tại (snapshot)"
  else warn "Không thấy CCNP threat-intel" "snapshot: cnp-threat-intel-egress-deny"; fi
  if k get ciliumcidrgroup 2>/dev/null | grep -qi 'threat-intel-firehol'; then pass "CiliumCIDRGroup threat-intel-firehol tồn tại"
  else warn "Không thấy CiliumCIDRGroup threat-intel-firehol"; fi
}

# =============================================================================
# SECTION 8 — ENCRYPTION (doc/04 vs snapshot 40 — DRIFT đã biết)
# =============================================================================
sec_encryption() {
  need_cluster "Encryption (mTLS/WireGuard)" || return 0
  note "doc/04 nói mTLS + WireGuard ĐÃ BẬT (script 08). snapshot 40 nói mesh-auth DISABLED."
  local cfg; cfg="$(k -n kube-system get configmap cilium-config -o json 2>/dev/null)"
  if [ -z "$cfg" ]; then warn "Không đọc được cilium-config"; return 0; fi
  local mesh wg
  mesh="$(echo "$cfg" | grep -oE '"mesh-auth-enabled" *: *"[^"]*"' | grep -oE 'true|false' | head -1)"
  wg="$(echo "$cfg" | grep -oE '"enable-wireguard" *: *"[^"]*"' | grep -oE 'true|false' | head -1)"
  note "mesh-auth-enabled='${mesh:-?}', enable-wireguard='${wg:-?}'"
  if [ "$mesh" = "false" ]; then
    pass "mesh-auth-enabled=false (khớp snapshot 40)"
    drift "doc/04 mục ENCRYPTION ghi 'mTLS sidecarless ĐÃ BẬT'; thực tế mesh-auth-enabled=false (snapshot 40 đúng). Cần sửa doc/04."
  elif [ "$mesh" = "true" ]; then
    pass "mesh-auth-enabled=true (khớp doc/04, KHÁC snapshot 40)"
    drift "snapshot 40 ghi mesh-auth DISABLED; thực tế =true. Cập nhật snapshot 40."
  else warn "Không xác định mesh-auth-enabled"; fi
  [ "$wg" = "true" ] && note "WireGuard enabled" || note "WireGuard disabled (snapshot: Tailscale L3 là baseline)"
}

# =============================================================================
# SECTION 9 — DATA LAYER: MySQL + 7 DB + Kafka + MinIO (doc/00, doc/03, port-map)
# =============================================================================
DATABASES=(job7189_identity_db job7189_workspace_db job7189_job_db job7189_hiring_db job7189_candidate_db job7189_communication_db job7189_storage_db)
sec_data() {
  need_cluster "Data layer" || return 0

  echo "  MySQL (ns=data, port 3306):"
  if res_exists deployment mysql data || k get sts -n data -o name 2>/dev/null | grep -qi mysql; then
    pass "MySQL workload tồn tại (ns=data)"
    local mp; mp="$(k get svc mysql -n data -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)"
    echo " $mp " | grep -q ' 3306 ' && pass "mysql service port 3306" || warn "mysql port='$mp'"
  else
    fail "MySQL THIẾU (ns=data)"
  fi

  echo "  7 logical databases (doc/00):"
  if [ "$NO_EXEC" -eq 0 ]; then
    local mpod; mpod="$(k get pods -n data -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
    [ -z "$mpod" ] && mpod="$(k get pods -n data -o name 2>/dev/null | grep -i mysql | head -1 | sed 's#pod/##')"
    if [ -n "$mpod" ]; then
      # cần root pw — thử lấy từ secret; nếu không có thì WARN.
      local rootpw; rootpw="$(k get secret -n data -o jsonpath='{.items[*].data.mysql-root-password}' 2>/dev/null | head -c 200)"
      local dblist
      dblist="$(kx "$mpod" -n data -- sh -c 'mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-}" -N -e "SHOW DATABASES;" 2>/dev/null')"
      if [ -n "$dblist" ]; then
        for db in "${DATABASES[@]}"; do
          echo "$dblist" | grep -qx "$db" && pass "database '$db' tồn tại" || fail "database '$db' THIẾU"
        done
      else
        warn "Không liệt kê được databases (cần MYSQL_ROOT_PASSWORD)" "chạy thủ công: mysql -uroot -p -e 'SHOW DATABASES;'"
        note "7 DB cần check: ${DATABASES[*]}"
      fi
    else warn "Không thấy pod MySQL"; fi
  else
    skip "Liệt kê 7 databases" "--no-exec"
    note "7 DB cần check thủ công: ${DATABASES[*]}"
  fi

  echo "  Kafka (ns=data, port 9092/9093):"
  if res_exists statefulset kafka data || k get deploy -n data -o name 2>/dev/null | grep -qi kafka; then
    pass "Kafka workload tồn tại (ns=data)"
  else warn "Kafka thiếu (ns=data)" "doc/00: data tier có Kafka"; fi

  echo "  MinIO (storage-service backend — repo: STS ns job7189-infra; label-script: deploy ns data):"
  local minio_found=""
  for q in "deployment minio data" "statefulset minio data" "deployment minio job7189-infra" "statefulset minio job7189-infra"; do
    # shellcheck disable=SC2086
    set -- $q
    if res_exists "$1" "$2" "$3"; then pass "MinIO: $1/$2 tồn tại (ns=$3)"; minio_found=1; break; fi
  done
  [ -z "$minio_found" ] && warn "Không thấy MinIO (deploy/sts 'minio') ở ns data hay job7189-infra" "snapshot 40 không nhắc MinIO — xác nhận: kubectl get sts,deploy -A | grep -i minio"
}

# =============================================================================
# SECTION 10 — VAULT DYNAMIC CREDENTIALS / JIT (doc/03)
# =============================================================================
sec_vault_dynamic() {
  need_cluster "Vault dynamic credentials (JIT)" || return 0
  if [ "$NO_EXEC" -eq 1 ]; then skip "Vault leases + DB engine" "--no-exec"; return 0; fi
  note "doc/03: TTL 1h, secrets trên tmpfs, 7 active leases (snapshot)"
  # Secrets trên tmpfs (emptyDir Memory) — kiểm tra trên 1 backend pod
  local ns=job7189-apps
  local pod; pod="$(k get pods -n "$ns" -l app=identity-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  if [ -n "$pod" ]; then
    if kx "$pod" -n "$ns" -c app -- sh -c 'mount 2>/dev/null | grep -E "/vault/secrets|/app-secrets" | grep -qi tmpfs'; then
      pass "Secrets mount trên tmpfs (RAM-only — đúng doc/03)"
    else warn "Không xác nhận được tmpfs mount cho secrets" "kiểm tra: mount | grep vault"; fi
    if kx "$pod" -n "$ns" -c app -- sh -c 'test -f /app-secrets/.env || test -f /vault/secrets/.env.db'; then
      pass "File .env (merge từ Vault) tồn tại trong pod"
    else warn "Không thấy /app-secrets/.env hay /vault/secrets/.env.db"; fi
  else warn "Không thấy pod identity-service để check tmpfs"; fi

  # Active leases (cần vault token)
  local vstat
  vstat="$(kx vault-0 -n vault -- sh -c 'VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=1 vault list -format=json sys/leases/lookup/database/creds 2>/dev/null')"
  if [ -n "$vstat" ]; then
    pass "Đọc được Vault leases (database/creds)"
  else
    warn "Không liệt kê được Vault leases" "cần auth: VAULT_TOKEN; chạy: vault list sys/leases/lookup/database/creds"
  fi
}

# =============================================================================
# SECTION 11 — OBSERVABILITY: EFK + Prometheus + Grafana + Hubble (doc/05, snapshot)
# =============================================================================
sec_observability() {
  need_cluster "Observability stack" || return 0
  local ns=monitoring

  echo "  Elasticsearch (snapshot: 7.17.18 single-node; doc/05 ghi 8.x — DRIFT):"
  if res_exists statefulset es "$ns" || k get deploy -n "$ns" -o name 2>/dev/null | grep -qiE 'elasticsearch|^deployment/es$'; then
    pass "Elasticsearch workload tồn tại (ns=monitoring)"
    local eimg; eimg="$(k get sts es -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
    note "ES image: ${eimg:-<unknown>}"
    if echo "$eimg" | grep -q '7\.17'; then
      pass "ES version 7.17.x (khớp snapshot 40)"
      drift "doc/05 ghi 'Elasticsearch 8.x' nhưng thực tế 7.17.18 (snapshot 40 đúng). Sửa doc/05."
    elif echo "$eimg" | grep -q ':8\.'; then
      pass "ES version 8.x (khớp doc/05, KHÁC snapshot 40)"
      drift "snapshot 40 ghi ES 7.17.18; thực tế 8.x. Cập nhật snapshot 40."
    else note "Không parse được ES version"; fi
  else
    fail "Elasticsearch THIẾU (ns=monitoring)"
  fi

  echo "  Filebeat DaemonSet (doc/05: 3 pod, chỉ 4 ns: job7189-apps/gateway/security/data):"
  if res_exists daemonset filebeat "$ns"; then
    local dr; dr="$(k get ds filebeat -n "$ns" -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}' 2>/dev/null)"
    pass "daemonset/filebeat ready=$dr"
  else warn "daemonset/filebeat thiếu (ns=monitoring)"; fi

  echo "  Kibana / Prometheus / Grafana / kube-state-metrics / node-exporter:"
  for d in kibana prometheus grafana kube-state-metrics; do
    if res_exists deployment "$d" "$ns"; then pass "deployment/$d tồn tại"
    else warn "deployment/$d thiếu"; fi
  done
  if res_exists daemonset node-exporter "$ns"; then
    pass "daemonset/node-exporter ready=$(k get ds node-exporter -n "$ns" -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}' 2>/dev/null) (snapshot: 4)"
  else warn "daemonset/node-exporter thiếu" "doc/07 deploy exporters"; fi

  echo "  Hubble (relay + UI, port 4245):"
  if k get pods -n kube-system 2>/dev/null | grep -qi hubble-relay; then pass "hubble-relay đang chạy (kube-system)"
  else warn "Không thấy hubble-relay" "doc/05: Hubble Relay bật trong Cilium values"; fi

  echo "  ES indices (snapshot: filebeat-7.17.18-*, threat-intel-feed-*):"
  if [ "$NO_EXEC" -eq 0 ]; then
    local espod; espod="$(k get pods -n "$ns" -o name 2>/dev/null | grep -iE 'es-|elasticsearch' | head -1 | sed 's#pod/##')"
    if [ -n "$espod" ]; then
      local idx; idx="$(kx "$espod" -n "$ns" -- sh -c 'curl -sf http://localhost:9200/_cat/indices?h=index 2>/dev/null')"
      if [ -n "$idx" ]; then
        echo "$idx" | grep -q 'filebeat' && pass "ES index filebeat-* tồn tại" || warn "Không thấy index filebeat-*"
        echo "$idx" | grep -q 'threat-intel-feed' && pass "ES index threat-intel-feed-* tồn tại (snapshot)" || warn "Không thấy threat-intel-feed-*"
      else warn "Không truy vấn được _cat/indices (ES auth?)"; fi
    else warn "Không thấy pod Elasticsearch"; fi
  else skip "ES indices" "--no-exec"; fi

  echo "  PrometheusRule (snapshot: 5 group / 19 alert):"
  if k get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1; then
    local pr; pr="$(k get prometheusrule -A --no-headers 2>/dev/null | count_lines)"
    [ "${pr:-0}" -ge 1 ] && pass "PrometheusRule objects=$pr" || warn "Không thấy PrometheusRule"
  else
    # Prometheus có thể chạy non-operator (rules trong CM)
    if k get cm -n "$ns" 2>/dev/null | grep -qiE 'prometheus.*rule|alert'; then pass "Có ConfigMap chứa Prometheus rules"
    else warn "Không thấy PrometheusRule CRD lẫn rules ConfigMap" "doc/08: 5 alert rules"; fi
  fi
}

# =============================================================================
# SECTION 12 — WORKLOAD LABEL SCHEMA (doc/19) — 6 zta.job7189/* labels
# =============================================================================
sec_labels() {
  need_cluster "Workload label schema (doc/19)" || return 0
  local keys=(role tier env data-classification exposure team)
  # Bảng workload (kind name ns) theo doc/19 + scripts/zta-apply-workload-labels.sh
  local rows=(
    "deployment mysql data"
    "statefulset kafka data"
    "deployment minio data"
    "deployment phpmyadmin management"
    "deployment keycloak security"
    "deployment oauth2-proxy security"
    "deployment zta-pdp security"
    "deployment kong-gateway gateway"
    "statefulset vault vault"
    "deployment vault-dev vault"
    "statefulset es monitoring"
    "daemonset filebeat monitoring"
    "deployment kibana monitoring"
    "deployment prometheus monitoring"
    "deployment grafana monitoring"
    "deployment kube-state-metrics monitoring"
    "daemonset node-exporter monitoring"
    "deployment docker-registry registry"
    "deployment identity-service job7189-apps"
    "deployment workspace-service job7189-apps"
    "deployment job-service job7189-apps"
    "deployment hiring-service job7189-apps"
    "deployment candidate-service job7189-apps"
    "deployment communication-service job7189-apps"
    "deployment storage-service job7189-apps"
    "deployment identity-service-redis job7189-apps"
  )
  local total=0 fully=0 missing_any=0 absent=0
  for row in "${rows[@]}"; do
    set -- $row
    local kind="$1" name="$2" ns="$3"
    total=$((total+1))
    if ! res_exists "$kind" "$name" "$ns"; then
      note "(bỏ qua) $kind/$name ns=$ns không tồn tại trên cluster"
      absent=$((absent+1))
      continue
    fi
    local labels_json; labels_json="$(k get "$kind" "$name" -n "$ns" -o jsonpath='{.metadata.labels}' 2>/dev/null)"
    local miss=""
    for kkey in "${keys[@]}"; do
      echo "$labels_json" | grep -q "zta.job7189/$kkey" || miss="$miss $kkey"
    done
    if [ -z "$miss" ]; then
      fully=$((fully+1))
      pass "$kind/$name ($ns) có đủ 6 ZTA label"
    else
      missing_any=$((missing_any+1))
      warn "$kind/$name ($ns) THIẾU label:$miss" "chạy: bash scripts/zta-apply-workload-labels.sh --apply"
    fi
  done
  hr
  note "Tổng workload trong bảng doc/19: $total | đủ-6-label: $fully | thiếu: $missing_any | không tồn tại: $absent"
  if [ "$missing_any" -gt 0 ]; then
    drift "Có $missing_any workload thiếu ZTA label (doc/19). Snapshot 40 ghi 'zta-labels-required 6 violations'. Khớp nếu =6."
  fi
}

# =============================================================================
# SECTION 13 — OPA GATEKEEPER (doc/24, snapshot 40)
# =============================================================================
sec_gatekeeper() {
  need_cluster "OPA Gatekeeper" || return 0
  if ! ns_exists gatekeeper-system; then warn "namespace/gatekeeper-system thiếu" "snapshot: Gatekeeper deployed"; return 0; fi
  local gkready; gkready="$(k get deploy -n gatekeeper-system -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.status.readyReplicas}{"/"}{.status.replicas}{" "}{end}' 2>/dev/null)"
  note "gatekeeper deploys: ${gkready:-none}"
  [ -n "$gkready" ] && pass "Gatekeeper controller chạy" || warn "Không thấy Gatekeeper deployment"

  # ConstraintTemplates (snapshot: 3 ZTA + 3 image-trust)
  if k get crd constrainttemplates.templates.gatekeeper.sh >/dev/null 2>&1; then
    local ct; ct="$(k get constrainttemplate --no-headers 2>/dev/null | count_lines)"
    pass "ConstraintTemplate count=$ct (snapshot: ZTA 3/3 + image-trust 3/3)"
    # Liệt kê TOÀN BỘ object group constraints.gatekeeper.sh (mỗi constraint là 1 kind riêng).
    local ckinds allcons
    ckinds="$(k api-resources --api-group=constraints.gatekeeper.sh -o name 2>/dev/null | paste -sd, -)"
    allcons="$(k get "${ckinds:-constraints}" -A -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"
    [ -z "$allcons" ] && allcons="$(k get constraints -A --no-headers 2>/dev/null | awk '{print $2}')"
    note "Constraints hiện có: $(echo "$allcons" | tr '\n' ' ')"
    for c in image-digest-required block-latest-tag zta-labels-required; do
      if echo "$allcons" | grep -qx "$c"; then pass "Constraint '$c' tồn tại"
      else warn "Không thấy constraint '$c'" "có trong repo opa-gatekeeper/ nhưng chưa thấy áp trên cluster"; fi
    done
  else
    warn "CRD constrainttemplates không tồn tại"
  fi
}

# =============================================================================
# SECTION 14 — IMAGE PROVENANCE: Cosign policy-controller (doc/26/28, snapshot)
# =============================================================================
sec_image_provenance() {
  need_cluster "Image provenance (Cosign)" || return 0
  if ns_exists cosign-system; then
    pass "namespace/cosign-system tồn tại"
    k get pods -n cosign-system --no-headers 2>/dev/null | sed 's/^/      /'
  else warn "namespace/cosign-system thiếu" "snapshot: policy-controller deployed"; fi

  # 3 ClusterImagePolicy: passthrough, apps-signed, keyless
  if k get crd clusterimagepolicies.policy.sigstore.dev >/dev/null 2>&1; then
    local cip; cip="$(k get clusterimagepolicy --no-headers 2>/dev/null | count_lines)"
    pass "ClusterImagePolicy count=$cip (snapshot: 3 — passthrough/apps-signed/keyless)"
    for p in passthrough apps-signed keyless; do
      k get clusterimagepolicy 2>/dev/null | grep -qi "$p" && pass "ClusterImagePolicy '$p' tồn tại" || warn "Không thấy CIP '$p'"
    done
  else warn "CRD clusterimagepolicies không tồn tại"; fi

  # Cosign public key (repo: ConfigMap security/zta-cosign-public-key — KHÔNG phải Secret;
  # tạo bởi scripts/zta-cosign-keygen.sh).
  if res_exists configmap zta-cosign-public-key security; then pass "configmap/zta-cosign-public-key (ns=security) tồn tại"
  elif res_exists secret zta-cosign-public-key security; then pass "secret/zta-cosign-public-key (ns=security) tồn tại"
  else warn "Không thấy configmap/secret zta-cosign-public-key (ns=security)" "snapshot: real PEM 178 bytes (zta-cosign-keygen.sh)"; fi
}

# =============================================================================
# SECTION 15 — TETRAGON RUNTIME PEP (doc/14, snapshot 40)
# =============================================================================
sec_tetragon() {
  need_cluster "Tetragon runtime PEP" || return 0
  local tds; tds="$(k get ds -A 2>/dev/null | grep -i tetragon | head -1)"
  if [ -n "$tds" ]; then
    note "$tds"
    pass "Tetragon DaemonSet tồn tại (snapshot: 3-4 node ready)"
  else warn "Không thấy Tetragon DaemonSet" "doc/14 + snapshot: block-suspicious-exec deployed"; fi

  if k get crd tracingpolicies.cilium.io >/dev/null 2>&1; then
    local tp tpn
    tp="$(k get tracingpolicy --no-headers 2>/dev/null | count_lines)"
    tpn="$(k get tracingpolicynamespaced -A --no-headers 2>/dev/null | count_lines)"
    if [ "$(( ${tp:-0} + ${tpn:-0} ))" -ge 1 ]; then pass "TracingPolicy=${tp} + TracingPolicyNamespaced=${tpn}"
    else warn "Không thấy TracingPolicy nào"; fi
    # block-suspicious-exec là kind TracingPolicyNamespaced (không ra trong `get tracingpolicy`).
    if { k get tracingpolicy -o name 2>/dev/null; k get tracingpolicynamespaced -A -o name 2>/dev/null; } | grep -qi 'block-suspicious-exec'; then
      pass "block-suspicious-exec tồn tại (TracingPolicyNamespaced)"
    else warn "Không thấy block-suspicious-exec"; fi
  else warn "CRD tracingpolicies.cilium.io không tồn tại"; fi
}

# =============================================================================
# SECTION 16 — THREAT INTELLIGENCE (snapshot 40 NEW 2026-05-27)
# =============================================================================
sec_threat_intel() {
  need_cluster "Threat intelligence feeds" || return 0
  # CronJob threat-intel-refresh
  local cj; cj="$(k get cronjob -A 2>/dev/null | grep -i threat-intel | head -1)"
  [ -n "$cj" ] && pass "CronJob threat-intel-refresh tồn tại ($(echo "$cj" | awk '{print $1"/"$2}'))" || warn "Không thấy CronJob threat-intel-refresh" "snapshot: hourly refresh"
  # CoreDNS sinkhole ConfigMap
  if res_exists configmap coredns-sinkhole kube-system || k get cm -A 2>/dev/null | grep -qi coredns-sinkhole; then
    pass "ConfigMap coredns-sinkhole tồn tại (snapshot: 507 URLhaus FQDN)"
  else warn "Không thấy coredns-sinkhole CM"; fi
  # CoreDNS forward upstream hardcoded 1.1.1.1 8.8.8.8 1.0.0.1
  local corecfg; corecfg="$(k -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)"
  if echo "$corecfg" | grep -qE '1\.1\.1\.1|8\.8\.8\.8'; then
    pass "CoreDNS forward upstream hardcode public DNS (snapshot Decision 3 — CGNAT)"
  else warn "CoreDNS không forward 1.1.1.1/8.8.8.8" "snapshot ghi hardcode public DNS"; fi
  # security-cdm ns: allow-threat-intel-egress (snapshot: bundle partial)
  if ns_exists security-cdm; then
    if k get cnp -n security-cdm 2>/dev/null | grep -qi 'allow-threat-intel-egress'; then
      pass "CNP allow-threat-intel-egress (ns=security-cdm) tồn tại (snapshot)"
    else warn "Không thấy allow-threat-intel-egress trong security-cdm"; fi
    note "snapshot: default-deny bundle của security-cdm CHƯA thấy live (partial)"
  else warn "namespace/security-cdm thiếu"; fi
}

# =============================================================================
# SECTION 17 — TRIVY (snapshot 40: DEFERRED vì RAM; 45 VulnerabilityReport cũ)
# =============================================================================
sec_trivy() {
  need_cluster "Trivy vulnerability scanning" || return 0
  note "snapshot 40: Trivy Operator DEFERRED (RAM); 45 VulnerabilityReport CR còn lại từ scan trước"
  if k get crd vulnerabilityreports.aquasecurity.github.io >/dev/null 2>&1; then
    local vr; vr="$(k get vulnerabilityreports -A --no-headers 2>/dev/null | count_lines)"
    if [ "${vr:-0}" -ge 1 ]; then pass "VulnerabilityReport CR count=$vr (snapshot ~45)"
    else warn "0 VulnerabilityReport (snapshot ghi 45 — có thể đã GC)"; fi
  else warn "CRD vulnerabilityreports không tồn tại (Trivy CRD chưa cài — khớp 'deferred')"; fi
  if k get pods -n trivy-system --no-headers 2>/dev/null | grep -qi .; then
    warn "trivy-system có pod đang chạy" "snapshot ghi DEFERRED/0-0 — cập nhật snapshot nếu đã bật lại"
    drift "snapshot 40 ghi Trivy Operator DEFERRED nhưng trivy-system có pod chạy. Cập nhật snapshot."
  else
    pass "trivy-system không có pod (khớp snapshot: deferred)"
  fi
}

# =============================================================================
# SECTION 18 — PDP ADAPTIVE LOOP (snapshot 40: score-bucket PENDING)
# =============================================================================
sec_pdp_adaptive() {
  need_cluster "PDP adaptive loop" || return 0
  note "snapshot 40: PDP target label cilium.zta/score-bucket CHƯA xuất hiện; cnp-block-low-trust-to-vault CHƯA apply"
  # score-bucket labels trên pods
  local sb; sb="$(k get pods -A -l 'cilium.zta/score-bucket' --no-headers 2>/dev/null | count_lines)"
  if [ "${sb:-0}" -eq 0 ]; then
    pass "Không có pod nào mang label cilium.zta/score-bucket (khớp snapshot: PENDING)"
  else
    pass "Có $sb pod mang score-bucket label (snapshot ghi PENDING → đã rollout)"
    drift "snapshot 40 ghi score-bucket PENDING nhưng cluster đã có $sb pod gắn label. Cập nhật snapshot."
  fi
  # cnp-block-low-trust-to-vault
  if k get cnp -A 2>/dev/null | grep -qi 'block-low-trust-to-vault'; then
    pass "CNP cnp-block-low-trust-to-vault ĐÃ apply (snapshot ghi pending → tiến triển)"
    drift "snapshot 40: cnp-block-low-trust-to-vault chưa apply; cluster đã có. Cập nhật snapshot + mục 'Gap còn lại'."
  else
    warn "cnp-block-low-trust-to-vault chưa apply (khớp snapshot: gap còn lại)" "file: cilium-policies/namespaces/17-*.yaml"
  fi
  # PDP Prometheus metrics (snapshot: 9 series)
  if [ "$NO_EXEC" -eq 0 ]; then
    local ppod; ppod="$(k get pods -n security -o name 2>/dev/null | grep -i pdp | head -1 | sed 's#pod/##')"
    if [ -n "$ppod" ]; then
      kx "$ppod" -n security -- sh -c 'curl -sf http://localhost:8080/metrics 2>/dev/null | grep -c "^pdp_" ' >/dev/null 2>&1 \
        && pass "PDP expose /metrics (snapshot: 9 series)" || warn "Không scrape được PDP /metrics"
    fi
  else skip "PDP metrics" "--no-exec"; fi
}

# =============================================================================
# SECTION 19 — RESOURCE BUDGET (doc/06) — informational
# =============================================================================
sec_resources() {
  need_cluster "Resource budget" || return 0
  note "doc/06 ghi: ~12GB total (Kind) — nhưng snapshot 40 nói đã sang multi-VM 32GB. DRIFT."
  drift "doc/06 còn nói 'Kind control-plane' + '~12GB total'; snapshot 40 nói đã migrate sang multi-VM kubeadm 32GB. doc/06 cần cập nhật khỏi Kind."
  echo "  Node allocatable memory:"
  k get nodes -o custom-columns='NODE:.metadata.name,ALLOC_MEM:.status.allocatable.memory,CPU:.status.allocatable.cpu' --no-headers 2>/dev/null | sed 's/^/      /'
  # Tổng pod đang chạy
  local pods; pods="$(k get pods -A --no-headers 2>/dev/null | count_lines)"
  note "Tổng pod (mọi ns): ${pods:-?}"
  # phpMyAdmin toggle (doc/07)
  if res_exists deployment phpmyadmin management; then
    local rep; rep="$(k get deploy phpmyadmin -n management -o jsonpath='{.spec.replicas}' 2>/dev/null)"
    note "phpmyadmin replicas=$rep (doc/07: có thể toggle off để tiết kiệm ~128Mi)"
  fi
}

# =============================================================================
# SECTION 20 — INGRESS / NORTH-SOUTH ENTRY (port-mapping)
# =============================================================================
sec_ingress() {
  need_cluster "Ingress / North-South entry" || return 0
  # ingress-nginx NodePort 30003 (HTTP) / 30001 (HTTPS)
  local inp; inp="$(k get svc -n ingress-nginx -o jsonpath='{range .items[*]}{.metadata.name}{":"}{range .spec.ports[*]}{.nodePort}{" "}{end}{"\n"}{end}' 2>/dev/null)"
  note "ingress-nginx svc nodePorts:"; echo "$inp" | sed 's/^/      /'
  echo "$inp" | grep -q '30003' && pass "ingress-nginx NodePort 30003 (HTTP) — đúng port-map" || warn "Không thấy NodePort 30003"
  echo "$inp" | grep -q '30001' && pass "ingress-nginx NodePort 30001 (HTTPS) — đúng port-map" || warn "Không thấy NodePort 30001"

  # Ingress objects (api.job7189.com, auth.job7189.local)
  if k get ingress -A >/dev/null 2>&1; then
    local hosts; hosts="$(k get ingress -A -o jsonpath='{range .items[*]}{.spec.rules[*].host}{" "}{end}' 2>/dev/null)"
    note "ingress hosts: ${hosts:-none}"
    echo "$hosts" | grep -q 'job7189' && pass "Ingress host chứa 'job7189' (doc/04 routing)" || warn "Không thấy ingress host job7189.*"
  fi
}

# =============================================================================
# SECTION 21 — STATIC: KB references vs repo files (không cần cluster)
# =============================================================================
sec_static_refs() {
  note "Kiểm tra các file mà KB trỏ tới có thật trong repo không (REPO_ROOT=$REPO_ROOT)"
  local files=(
    "infras/kong/kong.yml"
    "infras/k8s-yaml/11-vault.yaml"
    "infras/k8s-yaml/02-keycloak.yaml"
    "infras/k8s-yaml/01-mysql-phpmyadmin.yaml"
    "infras/k8s-yaml/03-kafka.yaml"
    "infras/k8s-yaml/04-kong-dbless.yaml"
    "infras/k8s-yaml/05-elasticsearch.yaml"
    "infras/k8s-yaml/06-filebeat.yaml"
    "infras/k8s-yaml/08-prometheus.yaml"
    "infras/k8s-yaml/09-grafana.yaml"
    "infras/k8s-yaml/20-security-policies.yaml"
    "k8s-management/helmfile.yaml"
    "scripts/zta-rebuild.sh"
    "scripts/zta-apply-workload-labels.sh"
    "scripts/zta-verify-labels.sh"
    "scripts/toggle-internal-ui.sh"
    "01-setup-cluster.sh"
    "02-deploy-infrastructure.sh"
    "03-deploy-microservices.sh"
    "05-seed-databases.sh"
    "07-deploy-monitoring-exporters.sh"
    "08-harden-security.sh"
    "09-verify-zta.sh"
    "10-deploy-tetragon.sh"
    "11-provision-dashboards.sh"
  )
  for f in "${files[@]}"; do
    if [ -f "${REPO_ROOT}/$f" ]; then pass "repo file tồn tại: $f"
    else fail "KB trỏ tới file KHÔNG tồn tại: $f" "sửa KB hoặc khôi phục file"; fi
  done

  # cilium-policies microseg files (doc/04 buoc 1-5)
  echo "  Cilium policy files (doc/04):"
  for f in 00-default-deny 01-allow-egress-dns 02-allow-egress-data 03-allow-ingress-kong 04-allow-internal-api-strict; do
    if ls "${REPO_ROOT}"/infras/k8s-yaml/cilium-policies/${f}*.yaml >/dev/null 2>&1; then pass "policy file ${f}*.yaml tồn tại"
    else warn "Không thấy policy ${f}*.yaml" "doc/04 liệt kê 5 bước"; fi
  done

  # DB seed files (05-seed-databases doc)
  echo "  DB seed files (DB/*.sql):"
  local sqlc; sqlc="$(ls "${REPO_ROOT}"/DB/*.sql 2>/dev/null | count_lines)"
  [ "${sqlc:-0}" -ge 1 ] && pass "Tìm thấy $sqlc file .sql trong DB/" || warn "Không thấy DB/*.sql" "doc/08: seed 7 DB từ DB/"
}

# =============================================================================
# SECTION 22 — KB INTERNAL CONSISTENCY (static, doc-vs-doc drift đã biết)
# =============================================================================
sec_kb_consistency() {
  local KB="${REPO_ROOT}/doc"
  [ -d "${REPO_ROOT}/knowledge-base" ] && KB="${REPO_ROOT}/knowledge-base"
  note "KB dir: $KB"
  if [ ! -d "$KB" ]; then warn "Không thấy thư mục KB (doc/ hoặc knowledge-base/)"; return 0; fi

  # README KB nói '32 chương' — đếm file numbered
  local nch; nch="$(ls "$KB"/[0-9][0-9]-*.md 2>/dev/null | count_lines)"
  note "Số chương numbered NN-*.md hiện có: ${nch}"
  if [ "${nch:-0}" -ge 30 ]; then pass "KB có ~$nch chương (README ghi 32)"
  else warn "KB chỉ có $nch chương numbered" "README ghi 32 — kiểm tra"; fi

  # 3 incident reports
  local inc; inc="$(ls "$KB"/incident-*.md 2>/dev/null | count_lines)"
  [ "${inc:-0}" -ge 3 ] && pass "Có $inc incident report (README ghi 3)" || warn "Chỉ có $inc incident report (README ghi 3)"

  # Drift doc-vs-doc đã biết. Cái nào ĐÃ được section live phát hiện (ES/encryption/
  # frontend/Kind-resource) thì CHỈ in ở chế độ offline để tránh trùng lặp DRIFT WATCH.
  drift "doc/00 + doc/08 (Kind 1CP+3W) vs snapshot 40 (kubeadm srv01..05) — cluster type lệch."
  if [ "$CLUSTER_OK" -ne 1 ]; then
    drift "doc/05 (ES 8.x) vs snapshot 40 (ES 7.17.18) — version Elasticsearch lệch."
    drift "doc/04 (mTLS/WireGuard ĐÃ BẬT) vs snapshot 40 (mesh-auth DISABLED) — encryption lệch."
    drift "doc/06 (Kind, ~12GB) vs snapshot 40 (multi-VM kubeadm, 32GB) — hạ tầng lệch."
    drift "Port-mapping doc (ns 'frontend' fe-candidate/fe-recruiter) vs doc/19 (FE tách khỏi cluster) — frontend lệch."
  fi
  pass "Đã liệt kê các drift doc-vs-doc đã biết (xem mục DRIFT WATCH cuối file)"
}

# -----------------------------------------------------------------------------
# Đăng ký section (id, title, func)
# -----------------------------------------------------------------------------
register 0  "Preflight (cluster, version, node)"            sec_preflight
register 1  "Namespace inventory"                            sec_namespaces
register 2  "7 backend microservices"                        sec_backend_services
register 3  "Per-service Redis cache"                        sec_redis
register 4  "Identity (Keycloak/Vault/SPIRE/PDP)"            sec_identity
register 5  "ServiceAccount mapping"                         sec_serviceaccounts
register 6  "Kong Gateway + JWT matrix"                      sec_kong
register 7  "Cilium microsegmentation"                       sec_cilium
register 8  "Encryption (mTLS/WireGuard)"                    sec_encryption
register 9  "Data layer (MySQL/7DB/Kafka/MinIO)"             sec_data
register 10 "Vault dynamic credentials (JIT)"                sec_vault_dynamic
register 11 "Observability (EFK/Prom/Grafana/Hubble)"        sec_observability
register 12 "Workload label schema (6 labels)"              sec_labels
register 13 "OPA Gatekeeper"                                 sec_gatekeeper
register 14 "Image provenance (Cosign)"                      sec_image_provenance
register 15 "Tetragon runtime PEP"                           sec_tetragon
register 16 "Threat intelligence feeds"                      sec_threat_intel
register 17 "Trivy vulnerability scanning"                   sec_trivy
register 18 "PDP adaptive loop (score-bucket)"               sec_pdp_adaptive
register 19 "Resource budget"                                sec_resources
register 20 "Ingress / North-South entry"                    sec_ingress
register 21 "STATIC: KB → repo file refs"                    sec_static_refs
register 22 "KB internal consistency / drift"                sec_kb_consistency

# --list
if [ "$LIST_ONLY" -eq 1 ]; then
  echo "Các section có thể chạy (dùng --only id1,id2,...):"
  for i in "${!SECTION_IDS[@]}"; do printf "  %-3s %s\n" "${SECTION_IDS[$i]}" "${SECTION_TITLES[$i]}"; done
  exit 0
fi

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------
echo ""
hr2
echo "${C_BLD}  ZTA KNOWLEDGE-BASE ↔ RUNNING-SYSTEM RECONCILIATION${C_RST}"
hr2
echo "  Thời điểm    : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "  Repo root    : $REPO_ROOT"
echo "  kubectl      : $KUBECTL  (context: ${KCTX:-<current>})"
echo "  Log file     : $LOG_FILE"
echo "  Mode         : $([ "$STATIC_ONLY" -eq 1 ] && echo 'STATIC-ONLY' || echo 'FULL')$([ "$NO_EXEC" -eq 1 ] && echo ' + NO-EXEC')"
[ -n "$ONLY_SECTIONS" ] && echo "  Only sections: $ONLY_SECTIONS"
echo "  Nguồn KB     : doc/40-snapshot (live), doc/00/03/04/05/06/07/08/19, doc/architecture/*"
echo "  Lưu ý        : READ-ONLY. Mỗi section có fallback — lỗi 1 phần KHÔNG dừng script."
hr2

# Dò kết nối cluster Ở SHELL CHA — vì mỗi section chạy trong subshell `( )`,
# biến set BÊN TRONG subshell sẽ không truyền ngược ra. Đặt CLUSTER_OK ở đây
# để mọi section con (fork sau) đều thấy.
if [ "$STATIC_ONLY" -ne 1 ] && command -v "$KUBECTL" >/dev/null 2>&1; then
  if k cluster-info >/dev/null 2>&1 || k get --raw='/readyz' >/dev/null 2>&1; then
    CLUSTER_OK=1
  fi
fi

START_EPOCH=$(date +%s)
for i in "${!SECTION_IDS[@]}"; do
  # --static: chỉ chạy section tĩnh 21,22 (+ preflight 0)
  if [ "$STATIC_ONLY" -eq 1 ]; then
    case "${SECTION_IDS[$i]}" in 0|21|22) : ;; *) continue ;; esac
  fi
  run_section "${SECTION_IDS[$i]}" "${SECTION_TITLES[$i]}" "${SECTION_FUNCS[$i]}"
done
END_EPOCH=$(date +%s)

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
NP="$(grep -c '^PASS' "$RESULT_LOG" 2>/dev/null)"; NP=${NP:-0}
NF="$(grep -c '^FAIL' "$RESULT_LOG" 2>/dev/null)"; NF=${NF:-0}
NW="$(grep -c '^WARN' "$RESULT_LOG" 2>/dev/null)"; NW=${NW:-0}
NS="$(grep -c '^SKIP' "$RESULT_LOG" 2>/dev/null)"; NS=${NS:-0}
NTOTAL=$((NP+NF+NW+NS))

echo ""
hr2
echo "${C_BLD}  TỔNG KẾT ĐỐI CHIẾU${C_RST}"
hr2
printf "  %s✅ PASS%s : %4d\n" "$C_GRN" "$C_RST" "$NP"
printf "  %s❌ FAIL%s : %4d\n" "$C_RED" "$C_RST" "$NF"
printf "  %s⚠️  WARN%s : %4d\n" "$C_YEL" "$C_RST" "$NW"
printf "  %s⏭️  SKIP%s : %4d\n" "$C_BLU" "$C_RST" "$NS"
printf "  ───────────────\n"
printf "  TOTAL  : %4d checks trong %ds\n" "$NTOTAL" "$((END_EPOCH-START_EPOCH))"

if [ "$NF" -gt 0 ]; then
  echo ""
  echo "  ${C_RED}${C_BLD}DANH SÁCH FAIL (KB nói có nhưng cluster KHÔNG đúng):${C_RST}"
  grep '^FAIL' "$RESULT_LOG" | sed 's/^FAIL|/    ❌ /'
fi

if [ "$NW" -gt 0 ]; then
  echo ""
  echo "  ${C_YEL}${C_BLD}DANH SÁCH WARN (cần xem lại / chưa xác minh được):${C_RST}"
  grep '^WARN' "$RESULT_LOG" | sed 's/^WARN|/    ⚠️  /' | head -60
  wn="$(grep -c '^WARN' "$RESULT_LOG")"
  [ "$wn" -gt 60 ] && echo "    ... (còn $((wn-60)) WARN nữa, xem $LOG_FILE)"
fi

if [ -s "$DRIFT_LOG" ]; then
  echo ""
  hr2
  echo "${C_BLD}${C_YEL}  🔀 DRIFT WATCH — lệch giữa KB ↔ KB hoặc KB ↔ cluster (tự quyết sửa):${C_RST}"
  hr2
  nl -ba "$DRIFT_LOG" | sed 's/^/    /'
fi

echo ""
hr2
echo "  Log đầy đủ: $LOG_FILE"
echo "  Gợi ý: chạy lại 1 phần bằng  --only <id>  (xem  --list)."
echo "  Sau khi sửa KB cho khớp cluster (hoặc ngược lại), commit + chạy lại để xác nhận 0 FAIL."
hr2

# Dọn temp
rm -f "$RESULT_LOG" "$DRIFT_LOG" 2>/dev/null

# Exit code
if [ "$CLUSTER_OK" -ne 1 ] && [ "$STATIC_ONLY" -ne 1 ]; then exit 2; fi
[ "$NF" -gt 0 ] && exit 1
exit 0
