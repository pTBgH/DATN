#!/usr/bin/env bash
# =============================================================================
# zta-deploy-trivy.sh — deploy Trivy Operator (CDM tier — PIP 4)
#
# Step: PR-I in doc/zta-gap-decision.md.
# Output CR: VulnerabilityReport (consumed by PDP in PR-J).
#
# Usage:
#   bash scripts/zta-deploy-trivy.sh             # install
#   bash scripts/zta-deploy-trivy.sh --uninstall
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"

NAMESPACE="security-cdm"
CHART_VERSION="${TRIVY_OPERATOR_VERSION:-0.22.0}"
CHART_REPO="https://aquasecurity.github.io/helm-charts/"
RELEASE="trivy-operator"
MANIFEST_DIR="$SCRIPT_DIR/infras/k8s-yaml/trivy-operator"
VALUES="$MANIFEST_DIR/01-values.yaml"

UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA PR-I — Trivy Operator (PIP 4 / CDM)"
blue " Mode: $([ "$UNINSTALL" -eq 1 ] && echo UNINSTALL || echo INSTALL)"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/3] Uninstalling helm release..."
  if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE"; then
    helm uninstall "$RELEASE" -n "$NAMESPACE" || true
  fi
  yellow "[2/3] Removing CNPs..."
  kubectl delete -f "$MANIFEST_DIR/02-cnp.yaml" --ignore-not-found
  yellow "[3/3] Removing namespace..."
  kubectl delete ns "$NAMESPACE" --ignore-not-found
  green "✓ Trivy Operator removed"
  exit 0
fi

# ---------------------------------------------------------------
# INSTALL — pre-flight
# ---------------------------------------------------------------
# Why 1500 MiB (not the previous 400 MiB)?
#
# 400 MiB only covered the operator + the initial Trivy DB pull (~80 MiB).
# It did NOT account for the *concurrent scan jobs* the operator launches
# right after install, each of which spikes ~500 MiB during DB load. With
# scanJobsConcurrentLimit=3 (previous default) that's ~1.5 GiB of peak
# usage on top of the operator. On the 12 GiB lab box this routinely
# pushed host MemAvailable below 200 MiB, the kube-apiserver lease (5s)
# missed, and the cluster cascaded into a leader-election storm:
# cilium-operator / scheduler / controller-manager / spire-server-0 all
# CrashLooped until the scan jobs finished and RAM was released. See
# doc/32-deploy-script-troubleshooting.md §7-8.
#
# 1500 MiB matches the standard host RAM gate used by spire / tetragon /
# gatekeeper deploy scripts and is safe even when scanJobsConcurrentLimit
# is dropped to 1 (the new default in 01-values.yaml).
#
# Override with TRIVY_REQUIRED_HOST_MI when you know what you're doing
# (e.g. dedicated 32 GiB box where 800 MiB is plenty).
blue "[0/4] Pre-flight: host RAM gate (1500 MiB default, see doc/32 §7.4)..."
if ! require_host_ram_mi "${TRIVY_REQUIRED_HOST_MI:-1500}" trivy; then
  red "      Skip step entirely via: ZTA_REBUILD_SKIP=28-trivy"
  red "      Or free RAM first via:    bash scripts/free-ram-for-tetragon.sh"
  exit 1
fi

# ---------------------------------------------------------------
# INSTALL — namespace + CNP first (so CNP exists before pod starts and
# default-deny doesn't block first reconcile)
# ---------------------------------------------------------------
blue "[1/4] Apply namespace + CNPs..."
kubectl apply -f "$MANIFEST_DIR/00-namespace.yaml"
kubectl apply -f "$MANIFEST_DIR/02-cnp.yaml"

# ---------------------------------------------------------------
# Helm install
# ---------------------------------------------------------------
blue "[2/4] Helm repo update..."
if ! helm repo list 2>/dev/null | grep -q "^aquasecurity\b"; then
  helm repo add aquasecurity "$CHART_REPO"
fi
helm_repo_update_retry aquasecurity || true

blue "[3/4] Helm install $RELEASE (chart version $CHART_VERSION)..."
# --no-hooks to avoid post-install Job that may hang on RBAC race.
helm upgrade --install "$RELEASE" aquasecurity/trivy-operator \
  --version "$CHART_VERSION" \
  --namespace "$NAMESPACE" \
  -f "$VALUES" \
  --wait \
  --atomic --cleanup-on-fail \
  --no-hooks \
  --timeout=600s

# ---------------------------------------------------------------
# Wait for operator + first VulnerabilityReport CR
# ---------------------------------------------------------------
blue "[4/4] Wait operator Ready + first VulnerabilityReport CR (up to 600s)..."
if ! kubectl rollout status deploy/trivy-operator -n "$NAMESPACE" --timeout=300s; then
  red "✗ trivy-operator rollout timeout"
  kubectl describe deploy/trivy-operator -n "$NAMESPACE" | tail -40
  exit 1
fi
green "    ✓ trivy-operator deployment Ready"

# Trivy needs to scan first images — VulnerabilityReport CRs appear after
# scan jobs finish (~60-180s per image). Don't fail the step if 0 reports
# show up after 300s; the operator just needs more time on a busy cluster.
echo
blue "    Polling VulnerabilityReport CRs (up to 300s, non-blocking)..."
for i in $(seq 1 30); do
  count=$(kubectl get vulnerabilityreports.aquasecurity.github.io --all-namespaces \
    --no-headers 2>/dev/null | wc -l || echo 0)
  if [ "${count:-0}" -gt 0 ]; then
    green "    ✓ Found ${count} VulnerabilityReport CR(s) — Trivy is scanning"
    break
  fi
  echo "    [$i/30] no reports yet — waiting 10s..."
  sleep 10
done

if [ "${count:-0}" -eq 0 ]; then
  yellow "    ⚠ No VulnerabilityReport CR yet — operator is still scanning."
  yellow "      Re-check after 5 minutes: kubectl get vulnerabilityreports -A"
fi

echo
green "════════════════════════════════════════════════════════"
green " ✓ Trivy Operator deployed (PR-I done — PIP 4 active)"
green "════════════════════════════════════════════════════════"
echo
echo "Verify:"
echo "  kubectl -n $NAMESPACE get pod -l app.kubernetes.io/name=trivy-operator"
echo "  kubectl get vulnerabilityreports -A"
echo "  kubectl get configauditreports -A"
echo
echo "PDP (PR-J) sẽ list các CR này để compute trust score."
