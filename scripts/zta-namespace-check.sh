#!/usr/bin/env bash
# =============================================================================
# zta-namespace-check.sh — Namespace consistency checker (ZTA / job7189)
# =============================================================================
#
# MỤC ĐÍCH
#   Sau đợt "chuẩn hóa / change namespace" gần đây (consolidation pdp-system →
#   security, trivy-system → security-cdm), script này soát TOÀN BỘ namespace
#   để phát hiện chỗ LỆCH / THIẾU / SÓT giữa 3 nguồn:
#
#     (A) CODE  — namespace thực sự được tạo / tham chiếu trong manifests +
#                 scripts (infras/, k8s-management/, scripts/, *.sh ở gốc).
#     (B) KB    — namespace được tài liệu hóa trong knowledge-base/ (đặc biệt
#                 bảng "Namespace Tiers" của 00-project-overview.md — index gốc).
#     (C) CLUSTER (tùy chọn, --cluster) — namespace thực tế trên cluster.
#
#   Mỗi mục in PASS / FAIL / WARN / SKIP. KHÔNG sửa gì cả (read-only thuần).
#   Script KHÔNG "claim" — mọi kết luận đều suy ra trực tiếp từ nội dung repo
#   (hoặc cluster nếu --cluster), và in kèm bằng chứng (file:line) để bạn tự
#   kiểm chứng.
#
# CHẠY Ở ĐÂU
#   - Mặc định (static): chạy được ở BẤT KỲ đâu có repo — không cần cluster,
#     không cần kubectl. Đây là chế độ chính để soát namespace.
#   - --cluster: chạy trên MÁY CÓ kubeconfig trỏ tới cluster ZTA để đối chiếu
#     thêm với `kubectl get ns`. Vẫn read-only.
#
# CÁCH CHẠY
#   bash scripts/zta-namespace-check.sh              # static (mặc định)
#   bash scripts/zta-namespace-check.sh --cluster    # + đối chiếu cluster
#   bash scripts/zta-namespace-check.sh --list        # liệt kê namespace CODE rồi thoát
#   REPO_ROOT=/path/to/DATN bash scripts/zta-namespace-check.sh
#
# BIẾN MÔI TRƯỜNG
#   REPO_ROOT   gốc repo (mặc định: tự dò từ vị trí script)
#   KUBECTL     lệnh kubectl (mặc định: kubectl) — chỉ dùng khi --cluster
#   KCTX        kube-context (mặc định: hiện tại)
#
# EXIT CODE
#   0  = không có FAIL (có thể còn WARN)
#   1  = có >=1 FAIL
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# 0. Cấu hình
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "$PWD")"
REPO_ROOT="${REPO_ROOT:-$DEFAULT_REPO_ROOT}"
KUBECTL="${KUBECTL:-kubectl}"
KCTX="${KCTX:-}"

DO_CLUSTER=0
LIST_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --cluster) DO_CLUSTER=1; shift ;;
    --list)    LIST_ONLY=1; shift ;;
    -h|--help) sed -n '1,55p' "$0"; exit 0 ;;
    *) echo "Tham số lạ: $1 (xem --help)"; shift ;;
  esac
done

# Thư mục chứa CODE sống (live). KB / backups / archive / evidence KHÔNG phải code.
SRC_DIRS=()
for d in infras k8s-management scripts; do
  [ -d "$REPO_ROOT/$d" ] && SRC_DIRS+=("$REPO_ROOT/$d")
done

# Namespace built-in của Kubernetes / add-on hạ tầng — KHÔNG bắt buộc tài liệu
# hóa trong bảng Namespace Tiers (chúng không phải workload ZTA).
BUILTIN_NS="kube-system kube-public kube-node-lease default local-path-storage"

# Namespace ĐÃ BỎ sau consolidation — KHÔNG được xuất hiện trong code sống
# (ngoại trừ script rollback + backups, vốn cố ý giữ để khôi phục).
DEPRECATED_NS="trivy-system pdp-system"

# Tên file của chính script này — tự loại khỏi mọi lần quét (nó chứa tên
# namespace dưới dạng dữ liệu/ví dụ, không phải tham chiếu thật).
SELF_BASE="$(basename "${BASH_SOURCE[0]}")"

# File được phép tham chiếu namespace deprecated (mục đích rollback/lịch sử).
ALLOW_DEPRECATED_REGEX="rollback-namespace-consolidation\.sh|/backups/|/archive/|/evidence/|$SELF_BASE"

# Namespace tham chiếu nhưng (theo KB) CHƯA deploy — bỏ qua khi soát "thiếu doc".
NOT_DEPLOYED_NS="job7189-infra"

# -----------------------------------------------------------------------------
# 0.1 Logging + bộ đếm
# -----------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RST=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_YEL=$'\033[33m'; C_BLU=$'\033[34m'; C_CYA=$'\033[36m'; C_BLD=$'\033[1m'
else
  C_RST=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYA=""; C_BLD=""
fi

N_PASS=0; N_FAIL=0; N_WARN=0; N_SKIP=0
banner() { echo; echo "=============================================================================="; echo "${C_BLD}${C_BLU}### $1${C_RST}"; echo "=============================================================================="; }
note()  { echo "    ${C_CYA}·${C_RST} $*"; }
pass()  { echo "    ${C_GRN}PASS${C_RST}  $1"; N_PASS=$((N_PASS+1)); }
fail()  { echo "    ${C_RED}FAIL${C_RST}  $1${2:+  — $2}"; N_FAIL=$((N_FAIL+1)); }
warn()  { echo "    ${C_YEL}WARN${C_RST}  $1${2:+  — $2}"; N_WARN=$((N_WARN+1)); }
skip()  { echo "    ${C_BLU}SKIP${C_RST}  $1${2:+  — $2}"; N_SKIP=$((N_SKIP+1)); }

# -----------------------------------------------------------------------------
# 0.2 Helpers
# -----------------------------------------------------------------------------
in_list() { # needle "space separated list"
  local x; for x in $2; do [ "$x" = "$1" ] && return 0; done; return 1; }

# Trích danh sách namespace từ CODE (manifests + scripts), unique + sorted.
extract_code_ns() {
  {
    # (1) trường `namespace:` trong YAML
    grep -rhoE "^[[:space:]]*namespace:[[:space:]]*[\"']?[a-z0-9][a-z0-9-]*" \
      --include=*.yaml --include=*.yml --exclude="$SELF_BASE" "${SRC_DIRS[@]}" 2>/dev/null \
      | sed -E "s/.*namespace:[[:space:]]*[\"']?//"
    # (2) cờ -n / --namespace trong shell
    grep -rhoE "(-n|--namespace=?)[[:space:]]+[a-z0-9][a-z0-9-]*" \
      --include=*.sh --exclude="$SELF_BASE" "${SRC_DIRS[@]}" "$REPO_ROOT"/*.sh 2>/dev/null \
      | sed -E "s/.*(-n|--namespace=?)[[:space:]]+//"
    # (3) metadata.name ngay dưới `kind: Namespace`
    grep -rhA3 -E "kind:[[:space:]]*Namespace" \
      --include=*.yaml --include=*.yml --exclude="$SELF_BASE" "${SRC_DIRS[@]}" 2>/dev/null \
      | grep -oE "name:[[:space:]]*[a-z0-9][a-z0-9-]*" | sed -E "s/name:[[:space:]]*//"
  } | sort -u | grep -vE "^(true|false|[0-9]+)$"
}

# -----------------------------------------------------------------------------
# 1. Inventory namespace CODE
# -----------------------------------------------------------------------------
CODE_NS="$(extract_code_ns | tr '\n' ' ')"

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "Namespace tìm thấy trong CODE (manifests + scripts):"
  for ns in $CODE_NS; do echo "  - $ns"; done
  exit 0
fi

banner "1. Inventory — namespace trong CODE (manifests + scripts)"
note "REPO_ROOT = $REPO_ROOT"
note "Nguồn quét: ${SRC_DIRS[*]#$REPO_ROOT/} + *.sh (gốc repo)"
if [ -z "${CODE_NS// /}" ]; then
  fail "Không trích được namespace nào từ code" "kiểm tra REPO_ROOT có đúng repo DATN không"
else
  COUNT=0; for ns in $CODE_NS; do COUNT=$((COUNT+1)); done
  pass "Trích được $COUNT namespace từ code"
  for ns in $CODE_NS; do echo "        - $ns"; done
fi

# -----------------------------------------------------------------------------
# 2. KB coverage — mỗi namespace ZTA có nằm trong bảng "Namespace Tiers" của
#    00-project-overview.md không? (index gốc dùng để định hướng người đọc)
# -----------------------------------------------------------------------------
banner "2. KB coverage — bảng 'Namespace Tiers' (00-project-overview.md)"
OVERVIEW="$REPO_ROOT/knowledge-base/00-project-overview.md"
if [ ! -f "$OVERVIEW" ]; then
  skip "00-project-overview.md" "không tìm thấy file"
else
  TIER_NS="$(awk '/## Namespace Tiers/{f=1;next} /^## /{f=0} f' "$OVERVIEW" \
    | grep -oE "\`[a-z0-9-]+\`" | tr -d '\`' | sort -u | tr '\n' ' ')"
  note "Namespace liệt kê trong bảng Tiers: ${TIER_NS:-<rỗng>}"
  for ns in $CODE_NS; do
    in_list "$ns" "$BUILTIN_NS"      && continue   # built-in: không cần
    in_list "$ns" "$NOT_DEPLOYED_NS" && { skip "ns '$ns' (chưa deploy theo KB) — bỏ qua coverage"; continue; }
    if in_list "$ns" "$TIER_NS"; then
      pass "ns '$ns' có trong bảng Namespace Tiers"
    else
      # Còn được nhắc ở chỗ khác trong KB không?
      kbhits="$(grep -rlw "$ns" "$REPO_ROOT/knowledge-base" --include=*.md 2>/dev/null | wc -l | tr -d ' ')"
      if [ "${kbhits:-0}" -gt 0 ]; then
        warn "ns '$ns' THIẾU trong bảng Namespace Tiers" "chỉ được nhắc rải rác ở $kbhits file KB — nên thêm vào 00-project-overview.md"
      else
        fail "ns '$ns' KHÔNG được tài liệu hóa ở đâu trong knowledge-base" "namespace live nhưng KB hoàn toàn không nhắc"
      fi
    fi
  done
fi

# -----------------------------------------------------------------------------
# 3. Deprecated leftovers — namespace đã bỏ còn sót trong code sống?
# -----------------------------------------------------------------------------
banner "3. Deprecated leftovers — $DEPRECATED_NS"
for old in $DEPRECATED_NS; do
  hits="$(grep -rnw "$old" "${SRC_DIRS[@]}" "$REPO_ROOT"/*.sh \
            --include=*.sh --include=*.yaml --include=*.yml --include=*.py \
            --exclude="$SELF_BASE" 2>/dev/null \
            | grep -vE "$ALLOW_DEPRECATED_REGEX" || true)"
  if [ -z "$hits" ]; then
    pass "không còn tham chiếu '$old' trong code sống (đã loại sạch)"
  else
    n="$(echo "$hits" | wc -l | tr -d ' ')"
    fail "còn $n tham chiếu '$old' trong code sống" "namespace này đã consolidation, cần xóa/đổi"
    echo "$hits" | sed -E "s#^$REPO_ROOT/##" | sed 's/^/        /'
  fi
done

# -----------------------------------------------------------------------------
# 4. Namespace-policy integrity — file CiliumNetworkPolicy theo namespace
#    (infras/k8s-yaml/cilium-policies/namespaces/) + applier ORDER.
# -----------------------------------------------------------------------------
banner "4. Cilium namespace-policy integrity (microperimeter)"
NSDIR="$REPO_ROOT/infras/k8s-yaml/cilium-policies/namespaces"
APPLIER="$NSDIR/apply-zta-namespace-policies.sh"
if [ ! -f "$APPLIER" ]; then
  skip "apply-zta-namespace-policies.sh" "không tìm thấy"
else
  # 4a. Mọi entry "ns:file" trong ORDER phải trỏ tới file tồn tại.
  ORDER_ENTRIES="$(awk '/^ORDER=\(/{f=1;next} /^\)/{f=0} f' "$APPLIER" \
    | grep -oE "[a-z0-9-]+:[0-9A-Za-z._-]+\.yaml" || true)"
  ORDER_NS=""
  for e in $ORDER_ENTRIES; do
    ns="${e%%:*}"; file="${e##*:}"; ORDER_NS="$ORDER_NS $ns"
    if [ -f "$NSDIR/$file" ]; then
      pass "ORDER '$ns' → $file tồn tại"
    else
      fail "ORDER '$ns' → $file KHÔNG tồn tại" "file đã bị xóa nhưng applier còn liệt kê (stale)"
    fi
    if in_list "$ns" "$DEPRECATED_NS"; then
      fail "ORDER còn liệt kê namespace deprecated '$ns'" "cần gỡ entry này khỏi applier"
    fi
  done
  # 4b. Mỗi namespace ZTA live (không built-in / chưa-deploy) nên có entry ORDER.
  for ns in $CODE_NS; do
    in_list "$ns" "$BUILTIN_NS"      && continue
    in_list "$ns" "$NOT_DEPLOYED_NS" && continue
    in_list "$ns" "$ORDER_NS" && continue
    # job7189-apps có policy strict riêng (04-allow-internal-api-strict) → chỉ WARN.
    warn "ns '$ns' KHÔNG có entry trong ORDER của applier" "namespace live nhưng không được áp namespace-policy qua --all"
  done
fi

# -----------------------------------------------------------------------------
# 5. App-tier consistency — helmfile releases vs KB label-schema
# -----------------------------------------------------------------------------
banner "5. App-tier consistency (helmfile ↔ KB)"
HELMFILE="$REPO_ROOT/k8s-management/helmfile.yaml"
LABELKB="$REPO_ROOT/knowledge-base/19-label-schema.md"
if [ -f "$HELMFILE" ]; then
  HELM_NS="$(grep -oE "namespace:[[:space:]]*[a-z0-9-]+" "$HELMFILE" | sed -E 's/namespace:[[:space:]]*//' | sort -u | tr '\n' ' ')"
  note "Helmfile namespace(s): ${HELM_NS:-<none>}"
  hn=0; for x in $HELM_NS; do hn=$((hn+1)); done
  if [ "$hn" -eq 1 ]; then
    pass "tất cả release helmfile dùng 1 namespace duy nhất: $HELM_NS"
  else
    warn "helmfile dùng nhiều namespace: $HELM_NS" "xác nhận đây là chủ đích"
  fi
  for x in $HELM_NS; do
    if [ -f "$LABELKB" ] && grep -qw "$x" "$LABELKB"; then
      pass "namespace helmfile '$x' khớp KB 19-label-schema.md"
    else
      warn "namespace helmfile '$x' không thấy trong 19-label-schema.md" "kiểm tra lại bảng workload→labels"
    fi
  done
else
  skip "helmfile.yaml" "không tìm thấy"
fi

# -----------------------------------------------------------------------------
# 6. (tùy chọn) Đối chiếu CLUSTER thực tế
# -----------------------------------------------------------------------------
banner "6. Cluster cross-check (--cluster)"
if [ "$DO_CLUSTER" -ne 1 ]; then
  skip "đối chiếu cluster" "chạy lại với --cluster (cần kubeconfig)"
else
  KARGS=(); [ -n "$KCTX" ] && KARGS=(--context "$KCTX")
  if ! "$KUBECTL" "${KARGS[@]}" get ns >/dev/null 2>&1; then
    fail "không kết nối được cluster" "kiểm tra kubeconfig/context (KUBECTL=$KUBECTL, KCTX=${KCTX:-current})"
  else
    LIVE_NS="$("$KUBECTL" "${KARGS[@]}" get ns -o name 2>/dev/null | sed 's#namespace/##' | sort -u | tr '\n' ' ')"
    note "Namespace trên cluster: $LIVE_NS"
    # 6a. namespace deprecated còn tồn tại trên cluster?
    for old in $DEPRECATED_NS; do
      if in_list "$old" "$LIVE_NS"; then
        warn "namespace deprecated '$old' VẪN tồn tại trên cluster" "cân nhắc 'kubectl delete ns $old' sau khi xác nhận trống"
      else
        pass "namespace deprecated '$old' không còn trên cluster"
      fi
    done
    # 6b. namespace code chưa có trên cluster (chưa deploy)?
    for ns in $CODE_NS; do
      in_list "$ns" "$NOT_DEPLOYED_NS" && continue
      if in_list "$ns" "$LIVE_NS"; then
        pass "ns code '$ns' tồn tại trên cluster"
      else
        warn "ns code '$ns' CHƯA có trên cluster" "manifest/script tham chiếu nhưng namespace chưa được tạo"
      fi
    done
    # 6c. namespace trên cluster mà code không nhắc (ngoài built-in)?
    for ns in $LIVE_NS; do
      in_list "$ns" "$BUILTIN_NS" && continue
      in_list "$ns" "$CODE_NS"    && continue
      warn "ns cluster '$ns' không xuất hiện trong code" "có thể là tàn dư hoặc tạo thủ công"
    done
    # 6d. CDM workloads đúng namespace security-cdm?
    if in_list "security-cdm" "$LIVE_NS"; then
      pods="$("$KUBECTL" "${KARGS[@]}" -n security-cdm get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')"
      pass "ns security-cdm tồn tại (pods: ${pods:-0}) — CDM tier (Trivy Operator + Threat-Intel)"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# Tổng kết
# -----------------------------------------------------------------------------
banner "TỔNG KẾT"
echo "    PASS=$N_PASS  FAIL=$N_FAIL  WARN=$N_WARN  SKIP=$N_SKIP"
echo
if [ "$N_FAIL" -gt 0 ]; then
  echo "${C_RED}Có $N_FAIL FAIL — cần xử lý (xem chi tiết + fix commands).${C_RST}"
  exit 1
fi
echo "${C_GRN}Không có FAIL.${C_RST}${N_WARN:+ Còn $N_WARN WARN nên rà soát.}"
exit 0
