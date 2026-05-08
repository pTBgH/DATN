#!/usr/bin/env bash
# =============================================================================
# zta-deploy-threat-intel.sh — deploy Threat Intelligence feed integration
#
# Deploys:
#   1. RBAC (ServiceAccount + Role + RoleBinding) in security-cdm
#   2. CronJob threat-intel-refresh (hourly FireHOL + URLhaus fetch)
#   3. CCNP cnp-threat-intel-egress-deny (block known-bad CIDRs)
#   4. CNP egress for CronJob to reach external feeds + kube-apiserver
#
# Pre-req: security-cdm namespace exists (created by zta-deploy-trivy.sh).
#
# Usage:
#   bash scripts/zta-deploy-threat-intel.sh           # full deploy
#   bash scripts/zta-deploy-threat-intel.sh --trigger  # trigger immediate fetch
#   bash scripts/zta-deploy-threat-intel.sh --uninstall
#
# Reference: doc/zta-gap-decision.md (Decision 3)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/infras/k8s-yaml/threat-intel"

# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh" 2>/dev/null || true

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

uninstall() {
  blue "Uninstalling Threat Intelligence..."
  kubectl delete -f "$MANIFEST_DIR/04-cnp-cronjob-egress.yaml" --ignore-not-found
  kubectl delete -f "$MANIFEST_DIR/03-ccnp.yaml" --ignore-not-found
  kubectl delete -f "$MANIFEST_DIR/02-cronjob.yaml" --ignore-not-found
  kubectl delete -f "$MANIFEST_DIR/01-rbac.yaml" --ignore-not-found
  kubectl delete cm -n security-cdm threat-intel-blocklist --ignore-not-found
  green "Threat Intelligence uninstalled"
  exit 0
}

trigger_now() {
  blue "Triggering immediate threat-intel-refresh job..."
  kubectl -n security-cdm create job --from=cronjob/threat-intel-refresh \
    "threat-intel-manual-$(date +%s)" 2>/dev/null || {
    red "ERR: CronJob threat-intel-refresh not found — deploy first"
    exit 1
  }
  green "Manual job created. Watch: kubectl -n security-cdm get jobs -w"
  exit 0
}

case "${1:-}" in
  --uninstall) uninstall ;;
  --trigger)   trigger_now ;;
  -h|--help)   sed -n '2,18p' "$0"; exit 0 ;;
esac

if ! command -v kubectl >/dev/null 2>&1; then
  red "ERR: kubectl not in PATH"; exit 1
fi
if ! kubectl get ns security-cdm >/dev/null 2>&1; then
  blue "Creating namespace security-cdm..."
  kubectl apply -f "$MANIFEST_DIR/00-namespace.yaml"
fi

blue "================================================================"
blue " Threat Intelligence Deploy (PR-K)"
blue "================================================================"

blue "[1/4] Namespace..."
kubectl apply -f "$MANIFEST_DIR/00-namespace.yaml"

blue "[2/4] RBAC..."
kubectl apply -f "$MANIFEST_DIR/01-rbac.yaml"

blue "[3/4] CronJob threat-intel-refresh..."
kubectl apply -f "$MANIFEST_DIR/02-cronjob.yaml"

blue "[4/4] CCNP + CronJob egress CNP..."
kubectl apply -f "$MANIFEST_DIR/03-ccnp.yaml"
kubectl apply -f "$MANIFEST_DIR/04-cnp-cronjob-egress.yaml"

echo
blue "Triggering initial feed fetch..."
kubectl -n security-cdm create job --from=cronjob/threat-intel-refresh \
  "threat-intel-init-$(date +%s)" 2>/dev/null || true

echo
green "================================================================"
green " Threat Intelligence deployed"
green "================================================================"
echo
echo "Verify:"
echo "  kubectl -n security-cdm get cronjob threat-intel-refresh"
echo "  kubectl -n security-cdm get cm threat-intel-blocklist -o yaml | head -30"
echo "  kubectl get ccnp cnp-threat-intel-egress-deny -o yaml"
echo
echo "Run 09-verify-zta.sh — Test 4n will check feed freshness."
