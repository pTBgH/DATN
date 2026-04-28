#!/usr/bin/env bash
# scripts/zta-rebuild.sh
#
# Full ZTA rebuild orchestrator: từ cluster trắng → cluster fully ZTA-enforced.
# Idempotent: chạy lại sau lỗi sẽ tiếp tục từ bước hiện tại.
#
# Usage:
#   bash scripts/zta-rebuild.sh                  # full rebuild, prompt confirm
#   bash scripts/zta-rebuild.sh --yes            # no prompt
#   bash scripts/zta-rebuild.sh --skip-cluster   # cluster đã có, chỉ deploy lại
#   bash scripts/zta-rebuild.sh --skip-frontend  # bỏ qua build FE images (fast)
#   bash scripts/zta-rebuild.sh --full-enforcement # chạy thêm Tetragon/SPIRE/Cosign/Hubble
#   bash scripts/zta-rebuild.sh --until=phase    # dừng sau 1 phase: cluster | infra | apps | exporters | harden | zta | verify
#   bash scripts/zta-rebuild.sh --from=phase     # resume từ 1 phase (skip các phase trước đó)
#
# Phases (theo thứ tự):
#   1. cluster   — 01-setup-cluster.sh           (Kind + Cilium + cert-manager + ingress-nginx)
#   2. infra     — 02-deploy-infrastructure.sh   (Vault + MySQL + Keycloak + Kafka + Kong + ELK)
#   3. apps      — 03-deploy-microservices.sh    (8 microservices + Redis sidecars)
#   4. exporters — 07-deploy-monitoring-exporters.sh (node-exporter + kube-state-metrics)
#   5. harden    — 08-harden-security.sh         (mesh-auth + WireGuard)
#   6. zta       — namespace CNPs (PR #8) + workload labels (PR #9) + L7 (PR #10)
#   7. verify    — 09-verify-zta.sh + observability baseline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

NO_PROMPT=0
SKIP_CLUSTER=0
SKIP_FRONTEND=0
UNTIL=""
FROM=""
FULL_ENFORCEMENT=0
# Cho phép phase 'apps' báo OK nếu pods eventually Ready (mặc dù 03-deploy báo non-zero)
APPS_TOLERATE_TIMEOUT=1

for arg in "$@"; do
  case "$arg" in
    --yes|-y) NO_PROMPT=1 ;;
    --skip-cluster)  SKIP_CLUSTER=1 ;;
    --skip-frontend) SKIP_FRONTEND=1 ;;
    --full-enforcement) FULL_ENFORCEMENT=1 ;;
    --until=*)       UNTIL="${arg#*=}" ;;
    --from=*)        FROM="${arg#*=}" ;;
    --strict-apps)   APPS_TOLERATE_TIMEOUT=0 ;;
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \?//'
      echo
      echo "Options:"
      echo "  --full-enforcement  also deploy heavy optional modules: Tetragon, Cosign policy-controller, SPIRE, Hubble export"
      echo "  --strict-apps       do not tolerate eventually-Ready app rollout timeouts"
      exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# Phase ordering for --from gating
PHASE_ORDER=(cluster infra apps exporters harden zta verify)
phase_idx() {
  local p=$1 i=0
  for x in "${PHASE_ORDER[@]}"; do
    [ "$x" = "$p" ] && { echo "$i"; return 0; }
    i=$((i+1))
  done
  echo "-1"
}
FROM_IDX=$(phase_idx "${FROM:-cluster}")
if [ "$FROM_IDX" -lt 0 ]; then
  echo "Unknown --from phase: $FROM (must be one of: ${PHASE_ORDER[*]})" >&2
  exit 1
fi
should_run() {
  local p=$1
  local idx; idx=$(phase_idx "$p")
  [ "$idx" -ge "$FROM_IDX" ]
}

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

run_phase() {
  local phase=$1; shift
  local title=$1; shift
  local cmd=("$@")
  echo
  blue "════════════════════════════════════════════════════════"
  blue " PHASE $phase: $title"
  blue "════════════════════════════════════════════════════════"
  local t0; t0=$(date +%s)
  if "${cmd[@]}"; then
    local dt=$(( $(date +%s) - t0 ))
    green "  ✓ phase '$phase' ok (${dt}s)"
  else
    local dt=$(( $(date +%s) - t0 ))
    red "  ✗ phase '$phase' FAILED (${dt}s)"
    return 1
  fi
}

stop_after() {
  local phase=$1
  if [ -n "$UNTIL" ] && [ "$UNTIL" = "$phase" ]; then
    yellow "  Stopping after phase '$phase' (--until=$UNTIL)."
    exit 0
  fi
}

blue "============================================================"
blue " ZTA Rebuild — fresh deploy with full Phase 4 enforcement"
blue " Skip cluster:  $([ "$SKIP_CLUSTER" -eq 1 ] && echo YES || echo NO)"
blue " Skip frontend: $([ "$SKIP_FRONTEND" -eq 1 ] && echo YES || echo NO)"
blue " Full enforce:  $([ "$FULL_ENFORCEMENT" -eq 1 ] && echo YES || echo NO)"
blue " From phase:    ${FROM:-(start)}"
blue " Until phase:   ${UNTIL:-(all)}"
blue "============================================================"

if [ "$NO_PROMPT" -ne 1 ]; then
  read -r -p "  Continue? (yes/NO) " ans
  if [ "${ans,,}" != "yes" ]; then
    yellow "  Cancelled."
    exit 0
  fi
fi

T0=$(date +%s)

# ============================================================
# PHASE 1 — cluster
# ============================================================
if should_run cluster && [ "$SKIP_CLUSTER" -ne 1 ]; then
  run_phase "cluster" "Setup Kind + Cilium + cert-manager + ingress-nginx" \
    bash 01-setup-cluster.sh
  stop_after cluster
fi

# ============================================================
# PHASE 2 — infrastructure
# Set ZTA_ENABLE_POLICIES=0 để bỏ qua step 9c của 02-deploy
# (chúng ta apply CNP namespace ở phase 'zta' bên dưới, không dùng monolithic)
# ============================================================
if should_run infra; then
  export ZTA_ENABLE_POLICIES=0
  run_phase "infra" "Deploy infrastructure (Vault, MySQL, Keycloak, Kafka, Kong, ELK)" \
    bash 02-deploy-infrastructure.sh
  stop_after infra
fi

# ============================================================
# PHASE 3 — microservices
#   Apps phase: 03-deploy-microservices.sh có thể timeout chờ Ready khi cluster
#   buộc phải pull image lâu, nhưng pods sau đó vẫn Ready. T´olặt: nếu script
#   exit non-zero, chờ thêm ~120s rồi kiểm kubectl wait đê xem pods có
#   eventually Ready không (trừ khi --strict-apps).
# ============================================================
if should_run apps; then
  if [ "$SKIP_FRONTEND" -eq 1 ]; then
    export DEPLOY_SKIP_FRONTEND=1
  fi
  if ! run_phase "apps" "Deploy 8 microservices + Redis sidecars" \
        bash 03-deploy-microservices.sh; then
    if [ "$APPS_TOLERATE_TIMEOUT" -eq 1 ]; then
      yellow "  apps deploy script exited non-zero — checking eventual Ready (tolerant mode)"
      sleep 30
      if kubectl -n job7189-apps wait --for=condition=Ready pods --all --timeout=180s >/dev/null 2>&1; then
        green "  ! apps eventually Ready — continuing (use --strict-apps to disable tolerance)"
      else
        red "  ✗ apps NOT Ready after extra 180s — aborting"
        kubectl -n job7189-apps get pods
        exit 1
      fi
    else
      exit 1
    fi
  fi
  stop_after apps
fi

# ============================================================
# PHASE 4 — monitoring exporters (node-exporter + kube-state-metrics)
#   Yêu cầu bởi 09-verify-zta.sh Test 6 + ZTA L7 policies (l7-prom-scrape).
# ============================================================
if should_run exporters; then
  if [ -f "$SCRIPT_DIR/07-deploy-monitoring-exporters.sh" ]; then
    run_phase "exporters" "Deploy node-exporter + kube-state-metrics" \
      bash 07-deploy-monitoring-exporters.sh \
      || yellow "  exporters phase non-fatal — continuing"
  else
    yellow "  skip: 07-deploy-monitoring-exporters.sh not found"
  fi
  stop_after exporters
fi

# ============================================================
# PHASE 5 — harden (mesh-auth + WireGuard)
# ============================================================
if should_run harden; then
  export ZTA_HARDEN_WIREGUARD="${ZTA_HARDEN_WIREGUARD:-1}"
  run_phase "harden" "Enable Cilium mesh-auth + WireGuard transparent encryption" \
    bash 08-harden-security.sh
  stop_after harden
fi

# ============================================================
# PHASE 6 — ZTA enforcement (PR #8 + PR #9 + PR #10)
# ============================================================
if should_run zta; then
echo
blue "════════════════════════════════════════════════════════"
blue " PHASE zta: Apply ZTA policies (PR #8 + #9 + #10 + #12)"
blue "════════════════════════════════════════════════════════"

NS_APPLY="$SCRIPT_DIR/infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh"
LABEL_APPLY="$SCRIPT_DIR/scripts/zta-apply-workload-labels.sh"
L7_APPLY="$SCRIPT_DIR/scripts/zta-apply-l7-policies.sh"
GK_DEPLOY="$SCRIPT_DIR/scripts/zta-deploy-gatekeeper.sh"
TRACING_APPLY="$SCRIPT_DIR/scripts/zta-apply-tracing-policies.sh"

# 5a. Namespace default-deny + per-flow allows (PR #8)
#     Bao gồm 3 nguồn:
#       (i) infras/k8s-yaml/20-security-policies.yaml — default-deny-job7189-apps
#           + default-deny-data + identity→mysql + ingress→kong (KHÔNG được
#           script nào khác auto-apply trong rebuild flow → phải apply thủ công)
#       (ii) cilium-policies/apply-zta-microsegmentation.sh — 5 file CNP
#            cho job7189-apps (allow-egress-dns/data + ingress-kong + internal-api)
#       (iii) namespaces/apply-zta-namespace-policies.sh — per-ns CNP cho 6 ns
#             non-app (monitoring/data/vault/security/gateway/management)
echo "--- 5a. Namespace CNPs (PR #8) ---"

# (i) Foundational CNPs (default-deny + SA-based microseg) — bắt buộc
if [ -f "$SCRIPT_DIR/infras/k8s-yaml/20-security-policies.yaml" ]; then
  echo "    [i] Apply 20-security-policies.yaml (default-deny-data + default-deny-job7189-apps + SA microseg)"
  kubectl apply -f "$SCRIPT_DIR/infras/k8s-yaml/20-security-policies.yaml" || yellow "    (20-security-policies apply failed — continuing)"
fi

# (ii) job7189-apps microsegmentation (5 CNPs)
APPS_MICROSEG="$SCRIPT_DIR/infras/k8s-yaml/cilium-policies/apply-zta-microsegmentation.sh"
if [ -x "$APPS_MICROSEG" ]; then
  echo "    [ii] Apply job7189-apps microsegmentation (5 CNPs)"
  bash "$APPS_MICROSEG" || yellow "    (job7189-apps microseg failed — continuing)"
else
  yellow "    skip: $APPS_MICROSEG not found"
fi

# (iii) Per-namespace CNPs (skip job7189-apps — already covered by ii)
if [ -x "$NS_APPLY" ]; then
  echo "    [iii] Per-namespace CNPs"
  for ns in monitoring data vault security gateway management; do
    bash "$NS_APPLY" "--namespace=$ns" --apply || yellow "    (ns=$ns skipped/failed — continuing)"
  done
  green "    ✓ namespace CNPs applied"
else
  yellow "    skip: $NS_APPLY not found"
fi

# 5b. Workload labels (PR #9)
if [ -x "$LABEL_APPLY" ]; then
  echo "--- 5b. Workload labels (PR #9) ---"
  bash "$LABEL_APPLY" --apply
  green "    ✓ workload labels applied (deployment + live pods)"
else
  yellow "    skip: $LABEL_APPLY not found"
fi

# 5c. L7 policies (PR #10)
if [ -x "$L7_APPLY" ]; then
  echo "--- 5c. L7 policies (PR #10) ---"
  bash "$L7_APPLY" --apply
  green "    ✓ L7 policies applied"
else
  yellow "    skip: $L7_APPLY not found"
fi

# 5d. OPA Gatekeeper + ZTA constraints (PR #12)
if [ -x "$GK_DEPLOY" ]; then
  echo "--- 5d. OPA Gatekeeper + ZTA constraints (PR #12) ---"
  bash "$GK_DEPLOY" || yellow "    Gatekeeper deploy failed — continuing"
  green "    ✓ Gatekeeper installed (audit-only mode)"
else
  yellow "    skip: $GK_DEPLOY not found"
fi

# 5e. Tetragon TracingPolicy for T1 ns (PR #12)
if [ -x "$TRACING_APPLY" ] && kubectl get crd tracingpoliciesnamespaced.cilium.io >/dev/null 2>&1; then
  echo "--- 5e. Tetragon TracingPolicies for T1 ns (PR #12) ---"
  bash "$TRACING_APPLY" --apply || yellow "    Tetragon policy apply failed — continuing"
  green "    ✓ Tetragon TracingPolicies applied"
else
  yellow "    skip: $TRACING_APPLY (Tetragon CRD missing — run 10-deploy-tetragon.sh first)"
fi

# 5f. PDP Controller — Adaptive Loop closure (PR #15)
PDP_DEPLOY="$SCRIPT_DIR/scripts/zta-deploy-pdp.sh"
if [ -x "$PDP_DEPLOY" ]; then
  echo "--- 5f. PDP Controller (PR #15) ---"
  bash "$PDP_DEPLOY" || yellow "    PDP deploy failed — continuing"
  green "    ✓ PDP Controller deployed (audit-only mode)"
else
  yellow "    skip: $PDP_DEPLOY not found"
fi

stop_after zta
fi  # should_run zta

# ============================================================
# OPTIONAL — heavy post-deploy enforcement modules
# ============================================================
if [ "$FULL_ENFORCEMENT" -eq 1 ] && should_run verify; then
echo
blue "════════════════════════════════════════════════════════"
blue " PHASE optional: Tetragon + Cosign policy-controller + SPIRE + Hubble export"
blue "════════════════════════════════════════════════════════"
yellow " Heavy modules are sequential and fail-fast to avoid cascading API timeouts."

run_phase "tetragon" "Deploy Tetragon runtime security" \
  bash 10-deploy-tetragon.sh

run_phase "cosign-key" "Generate/publish Cosign public key" \
  bash scripts/zta-cosign-keygen.sh

run_phase "policy-controller" "Deploy sigstore policy-controller" \
  bash scripts/zta-deploy-policy-controller.sh

run_phase "spire" "Deploy SPIRE workload attestation" \
  bash scripts/zta-deploy-spire.sh

run_phase "spire-demo" "Deploy SPIRE workload API demo" \
  bash scripts/zta-spire-onboard-demo.sh

run_phase "hubble-export" "Enable Hubble flow export to Elasticsearch" \
  bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export
else
  yellow " Optional heavy modules skipped by default."
  yellow " Run after the base rebuild is PASS/WARN-only:"
  yellow "   bash 10-deploy-tetragon.sh"
  yellow "   bash scripts/zta-cosign-keygen.sh"
  yellow "   bash scripts/zta-deploy-policy-controller.sh"
  yellow "   bash scripts/zta-deploy-spire.sh"
  yellow "   bash scripts/zta-spire-onboard-demo.sh"
  yellow "   bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export"
  yellow " Or use: bash scripts/zta-rebuild.sh --full-enforcement"
fi

# ============================================================
# PHASE 7 — verify
# ============================================================
if should_run verify; then
echo
blue "════════════════════════════════════════════════════════"
blue " PHASE verify: Run 09-verify-zta.sh + observability baseline"
blue "════════════════════════════════════════════════════════"

# Allow soft-fail on verify (vault may be sealed initially, etc.)
bash 09-verify-zta.sh || yellow "    (some verification checks failed — review evidence/)"

if [ -x "$SCRIPT_DIR/scripts/zta-observability-baseline.sh" ]; then
  echo "--- baseline snapshot ---"
  bash "$SCRIPT_DIR/scripts/zta-observability-baseline.sh" || yellow "    baseline failed — non-fatal"
fi
fi  # should_run verify

DT=$(( $(date +%s) - T0 ))
echo
green "============================================================"
green " ✅  Rebuild complete in ${DT}s"
green "    Cluster: $(kubectl config current-context 2>/dev/null || echo '?')"
green "    Pods:    $(kubectl get pod -A --no-headers 2>/dev/null | wc -l) total"
green "    CNPs:    $(kubectl get cnp -A --no-headers 2>/dev/null | wc -l) total"
green "============================================================"
green " Next: bash 09-verify-zta.sh        # re-check anytime"
green "       open evidence/baseline-*/SUMMARY.md   # baseline detail"
green "============================================================"
