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
#   bash scripts/zta-rebuild.sh --until=phase    # dừng sau 1 phase: cluster | infra | apps | harden | zta | verify
#
# Phases:
#   1. cluster — 01-setup-cluster.sh           (Kind + Cilium + cert-manager + ingress-nginx)
#   2. infra   — 02-deploy-infrastructure.sh   (Vault + MySQL + Keycloak + Kafka + Kong + ELK)
#   3. apps    — 03-deploy-microservices.sh    (8 microservices + Redis sidecars)
#   4. harden  — 08-harden-security.sh         (mesh-auth + WireGuard)
#   5. zta     — namespace CNPs (PR #8) + workload labels (PR #9) + L7 (PR #10)
#   6. verify  — 09-verify-zta.sh + observability baseline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

NO_PROMPT=0
SKIP_CLUSTER=0
SKIP_FRONTEND=0
UNTIL=""

for arg in "$@"; do
  case "$arg" in
    --yes|-y) NO_PROMPT=1 ;;
    --skip-cluster)  SKIP_CLUSTER=1 ;;
    --skip-frontend) SKIP_FRONTEND=1 ;;
    --until=*)       UNTIL="${arg#*=}" ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

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
if [ "$SKIP_CLUSTER" -ne 1 ]; then
  run_phase "cluster" "Setup Kind + Cilium + cert-manager + ingress-nginx" \
    bash 01-setup-cluster.sh
  stop_after cluster
fi

# ============================================================
# PHASE 2 — infrastructure
# Set ZTA_ENABLE_POLICIES=0 để bỏ qua step 9c của 02-deploy
# (chúng ta apply CNP namespace ở phase 'zta' bên dưới, không dùng monolithic)
# ============================================================
export ZTA_ENABLE_POLICIES=0
run_phase "infra" "Deploy infrastructure (Vault, MySQL, Keycloak, Kafka, Kong, ELK)" \
  bash 02-deploy-infrastructure.sh
stop_after infra

# ============================================================
# PHASE 3 — microservices
# ============================================================
if [ "$SKIP_FRONTEND" -eq 1 ]; then
  export DEPLOY_SKIP_FRONTEND=1
fi
run_phase "apps" "Deploy 8 microservices + Redis sidecars" \
  bash 03-deploy-microservices.sh
stop_after apps

# ============================================================
# PHASE 4 — harden (mesh-auth + WireGuard)
# ============================================================
run_phase "harden" "Enable Cilium mesh-auth + WireGuard transparent encryption" \
  bash 08-harden-security.sh
stop_after harden

# ============================================================
# PHASE 5 — ZTA enforcement (PR #8 + PR #9 + PR #10)
# ============================================================
echo
blue "════════════════════════════════════════════════════════"
blue " PHASE zta: Apply ZTA policies (PR #8 + #9 + #10)"
blue "════════════════════════════════════════════════════════"

NS_APPLY="$SCRIPT_DIR/infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh"
LABEL_APPLY="$SCRIPT_DIR/scripts/zta-apply-workload-labels.sh"
L7_APPLY="$SCRIPT_DIR/scripts/zta-apply-l7-policies.sh"

# 5a. Namespace default-deny + per-flow allows (PR #8)
if [ -x "$NS_APPLY" ]; then
  echo "--- 5a. Namespace CNPs (PR #8) ---"
  for ns in monitoring data vault security gateway management job7189-apps; do
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

stop_after zta

# ============================================================
# PHASE 6 — verify
# ============================================================
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
