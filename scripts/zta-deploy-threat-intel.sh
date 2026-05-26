#!/usr/bin/env bash
# =============================================================================
# zta-deploy-threat-intel.sh — deploy Threat Intelligence feed integration
#
# Deploys:
#   1. RBAC (ServiceAccount + Role + RoleBinding + ClusterRole + binding)
#   2. CronJob threat-intel-refresh (hourly FireHOL + URLhaus fetch)
#   3. CCNP cnp-threat-intel-egress-deny (block known-bad CIDRs)
#   4. CNP egress for CronJob to reach external feeds + kube-apiserver
#   5. CiliumCIDRGroup threat-intel-firehol (FireHOL CIDR data, patched
#      hourly by the CronJob — must exist BEFORE the CCNP that refs it)
#
# Features:
#   - Auto-rollback on failure (trap-based) — does NOT affect other modules
#   - All output logged to evidence/deploy-threat-intel-<ts>.log
#   - Health check with configurable timeout (default 120s)
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

# ---------------------------------------------------------------------------
# Logging — tee all output to evidence file
# ---------------------------------------------------------------------------
EVIDENCE_DIR="$SCRIPT_DIR/evidence"
mkdir -p "$EVIDENCE_DIR"
DEPLOY_TS=$(date -u +"%Y%m%d_%H%M%S")
LOGFILE="$EVIDENCE_DIR/deploy-threat-intel-${DEPLOY_TS}.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "[$(date -u +%FT%TZ)] Log: $LOGFILE"

# ---------------------------------------------------------------------------
# Rollback — remove only threat-intel resources, never touch other modules
# ---------------------------------------------------------------------------
APPLIED_MANIFESTS=()
ROLLBACK_TRIGGERED=0
DEPLOY_SUCCESS=0

rollback() {
  [ "$ROLLBACK_TRIGGERED" -eq 1 ] && return
  ROLLBACK_TRIGGERED=1
  echo
  red "════════════════════════════════════════════════════════"
  red " DEPLOY FAILED — rolling back threat-intel resources"
  red "════════════════════════════════════════════════════════"
  for ((i=${#APPLIED_MANIFESTS[@]}-1; i>=0; i--)); do
    # Never delete the namespace — Trivy Operator shares security-cdm
    case "${APPLIED_MANIFESTS[$i]}" in *00-namespace*) continue ;; esac
    yellow "  rollback: ${APPLIED_MANIFESTS[$i]}"
    kubectl delete -f "${APPLIED_MANIFESTS[$i]}" --ignore-not-found 2>/dev/null || true
  done
  kubectl delete cm -n security-cdm threat-intel-blocklist --ignore-not-found 2>/dev/null || true
  red "Rollback complete. Log: $LOGFILE"
  red "Other modules are NOT affected."
}

trap_handler() {
  if [ "$DEPLOY_SUCCESS" -eq 0 ]; then
    red "Unexpected error — triggering rollback"
    rollback
  fi
}
trap trap_handler ERR EXIT

apply_manifest() {
  local f="$1"
  local label="$2"
  blue "$label"
  if kubectl apply -f "$f"; then
    APPLIED_MANIFESTS+=("$f")
  else
    red "  FAILED: kubectl apply -f $f"
    rollback
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------
uninstall() {
  blue "Uninstalling Threat Intelligence..."
  kubectl delete -f "$MANIFEST_DIR/04-cnp-cronjob-egress.yaml" --ignore-not-found
  kubectl delete -f "$MANIFEST_DIR/03-ccnp.yaml" --ignore-not-found
  # CIDRGroup must be deleted AFTER the CCNP that references it to
  # avoid a brief window where the policy points at a non-existent group.
  kubectl delete -f "$MANIFEST_DIR/05-cidrgroup.yaml" --ignore-not-found
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
  -h|--help)   sed -n '2,24p' "$0"; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Deploy with rollback on failure
# ---------------------------------------------------------------------------
apply_manifest "$MANIFEST_DIR/00-namespace.yaml"   "[1/6] Namespace..."
apply_manifest "$MANIFEST_DIR/01-rbac.yaml"         "[2/6] RBAC (Role + ClusterRole patch on CIDR group)..."
apply_manifest "$MANIFEST_DIR/02-cronjob.yaml"      "[3/6] CronJob threat-intel-refresh..."
# CiliumCIDRGroup MUST be applied before the CCNP that references it.
# Cilium tolerates a dangling cidrGroupRef (treats the group as empty),
# but applying in this order keeps the policy effective from the moment
# it is admitted to the cluster.
# CiliumCIDRGroup: apply ONLY if it does not exist yet. Re-applying
# would wipe the live externalCIDRs list (the CronJob is the sole
# writer of that field; kubectl apply uses replace-semantics for
# unkeyed string lists). Existence check is a deliberate, idempotent
# guard — do not remove without rethinking the data ownership model.
blue "[4/6] CiliumCIDRGroup threat-intel-firehol (skeleton)..."
if kubectl get ciliumcidrgroup threat-intel-firehol >/dev/null 2>&1; then
  yellow "  already exists — skipping apply to preserve live CIDR list"
  APPLIED_MANIFESTS+=("$MANIFEST_DIR/05-cidrgroup.yaml")
else
  apply_manifest "$MANIFEST_DIR/05-cidrgroup.yaml" "  creating empty skeleton (CronJob will populate)"
fi
apply_manifest "$MANIFEST_DIR/03-ccnp.yaml"         "[5/6] CCNP cnp-threat-intel-egress-deny..."
apply_manifest "$MANIFEST_DIR/04-cnp-cronjob-egress.yaml" "[6/6] CNP allow-threat-intel-egress..."

# ---------------------------------------------------------------------------
# Cilium L7 DNS proxy warm-up
# ---------------------------------------------------------------------------
# After applying allow-threat-intel-egress (which puts the threat-intel pod
# into default-deny egress mode with an L7 DNS rule), the Cilium agent needs
# a few seconds to install the policy + DNS proxy redirect for the pod's
# identity. If we trigger the init Job immediately, curl runs before the
# proxy is ready and DNS UDP packets get dropped at the eBPF datapath —
# manifesting as `curl: (6) Could not resolve host`.
#
# 20s is empirically enough on a 4-node Kind cluster; override with
# THREAT_INTEL_POLICY_SETTLE_S for slower hosts.
POLICY_SETTLE="${THREAT_INTEL_POLICY_SETTLE_S:-20}"
blue "Waiting ${POLICY_SETTLE}s for Cilium to program the new CNP/CCNP..."
sleep "$POLICY_SETTLE"

echo
blue "Triggering initial feed fetch..."
JOB_NAME="threat-intel-init-$(date +%s)"
kubectl -n security-cdm create job --from=cronjob/threat-intel-refresh \
  "$JOB_NAME" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Health check — wait for init job to complete (configurable timeout)
# ---------------------------------------------------------------------------
# Default 600s budget breakdown (worst-case on the 3-node Cilium 1.19 lab):
#   - init container sleep + retries on DNS race    : up to ~120s
#   - alpine/k8s:1.29.10 image pull (first time)    : up to ~120s (~850MB)
#   - curl fetches (FireHOL + URLhaus) with retries : up to ~200s
#   - apply container kubectl apply round-trip       :       ~5s
#   - safety margin                                   :     ~155s
# 300s was too tight once bitnami/kubectl was replaced with the larger
# alpine/k8s image; 600s matches the CronJob's activeDeadlineSeconds.
HEALTH_TIMEOUT="${THREAT_INTEL_HEALTH_TIMEOUT:-600}"
blue "Waiting for initial fetch job to complete (timeout ${HEALTH_TIMEOUT}s)..."

job_ok=0
for ((t=0; t<HEALTH_TIMEOUT; t+=10)); do
  status=$(kubectl -n security-cdm get job "$JOB_NAME" \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
  failed=$(kubectl -n security-cdm get job "$JOB_NAME" \
    -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")

  if [ "$status" = "True" ]; then
    green "  ✓ Init job completed successfully"
    job_ok=1
    break
  fi
  if [ "$failed" = "True" ]; then
    red "  ✗ Init job failed"
    echo "  Logs (init container):"
    kubectl -n security-cdm logs "job/$JOB_NAME" -c fetch-feeds --tail=30 2>/dev/null || true
    echo "  Logs (apply container):"
    kubectl -n security-cdm logs "job/$JOB_NAME" -c apply-configmap --tail=30 2>/dev/null || true
    yellow "  Rolling back — CronJob will retry on next schedule (hourly)"
    rollback
    exit 1
  fi
  echo "  [${t}/${HEALTH_TIMEOUT}s] job still running..."
  sleep 10
done

if [ "$job_ok" -eq 0 ]; then
  yellow "  ⚠ Init job did not complete within ${HEALTH_TIMEOUT}s"
  echo "  Logs (init container):"
  kubectl -n security-cdm logs "job/$JOB_NAME" -c fetch-feeds --tail=30 2>/dev/null || true
  echo "  Logs (apply container):"
  kubectl -n security-cdm logs "job/$JOB_NAME" -c apply-configmap --tail=30 2>/dev/null || true
  yellow "  Keeping resources deployed — CronJob will retry hourly."
  yellow "  If issue persists, run: bash scripts/zta-deploy-threat-intel.sh --uninstall"
fi

# ---------------------------------------------------------------------------
# Verify ConfigMap was created
# ---------------------------------------------------------------------------
if kubectl -n security-cdm get cm threat-intel-blocklist >/dev/null 2>&1; then
  cidr_count=$(kubectl -n security-cdm get cm threat-intel-blocklist \
    -o jsonpath='{.metadata.annotations.threat-intel/firehol-count}' 2>/dev/null || echo "?")
  fqdn_count=$(kubectl -n security-cdm get cm threat-intel-blocklist \
    -o jsonpath='{.metadata.annotations.threat-intel/urlhaus-count}' 2>/dev/null || echo "?")
  green "  ✓ ConfigMap threat-intel-blocklist created (CIDRs=$cidr_count FQDNs=$fqdn_count)"
else
  yellow "  ⚠ ConfigMap threat-intel-blocklist not found — CronJob will create on next run"
fi

DEPLOY_SUCCESS=1

echo
green "================================================================"
green " Threat Intelligence deployed"
green "================================================================"
echo
echo "Log: $LOGFILE"
echo
echo "Verify:"
echo "  kubectl -n security-cdm get cronjob threat-intel-refresh"
echo "  kubectl -n security-cdm get cm threat-intel-blocklist -o yaml | head -30"
echo "  kubectl get ccnp cnp-threat-intel-egress-deny -o yaml"
echo
echo "Run 09-verify-zta.sh — Test 4n will check feed freshness."
