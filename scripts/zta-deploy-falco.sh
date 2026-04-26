#!/usr/bin/env bash
# scripts/zta-deploy-falco.sh
#
# Deploy Falco runtime detection + Falcosidekick (PR #22).
#
# Outputs alerts to:
#   - stdout (kubectl logs ds/falco)
#   - HTTP → falcosidekick service (port 2801)
#   - falcosidekick → elasticsearch.monitoring:9200 index falco-events-*
#
# Usage:
#   bash scripts/zta-deploy-falco.sh                # install
#   bash scripts/zta-deploy-falco.sh --uninstall    # remove
#
# Resource budget: ~800-1024Mi RAM (4 nodes × 200-512Mi falco + 1 sidekick).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

NAMESPACE="${FALCO_NS:-falco}"
RELEASE="${FALCO_RELEASE:-falco}"
HELM_REPO_NAME="${HELM_REPO_NAME:-falcosecurity}"
HELM_REPO_URL="${HELM_REPO_URL:-https://falcosecurity.github.io/charts}"
VALUES_FILE="$SCRIPT_DIR/infras/k8s-yaml/falco/values.yaml"

UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Step 2.3.12 — Falco runtime detection + Falcosidekick"
blue "   namespace:        $NAMESPACE"
blue "   helm release:     $RELEASE"
blue "   driver:           modern_ebpf (CO-RE)"
blue "   sink:             elasticsearch.monitoring:9200 (falco-events-*)"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/3] Uninstalling helm release '$RELEASE'..."
  helm uninstall -n "$NAMESPACE" "$RELEASE" 2>&1 | sed 's/^/    /' || true
  yellow "[2/3] Removing namespace..."
  kubectl delete ns "$NAMESPACE" --ignore-not-found 2>&1 | sed 's/^/    /'
  green "✓ Falco removed"
  exit 0
fi

# ---------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------
yellow "[pre-flight] Checking host kernel version (modern_ebpf needs >= 5.8)..."
KERNEL=$(uname -r 2>/dev/null || echo "unknown")
KMAJ=$(echo "$KERNEL" | cut -d. -f1)
KMIN=$(echo "$KERNEL" | cut -d. -f2)
if [ "$KMAJ" -gt 5 ] 2>/dev/null || { [ "$KMAJ" -eq 5 ] 2>/dev/null && [ "$KMIN" -ge 8 ] 2>/dev/null; }; then
  green "    ✓ kernel $KERNEL supports modern_ebpf"
else
  red   "    ⚠ kernel $KERNEL too old for modern_ebpf — pods may CrashLoopBackOff"
  red   "      Fix: edit values.yaml driver.kind to 'ebpf' (legacy probe)."
  red   "      Continuing anyway — falco DS will report driver error if unsupported."
fi

yellow "[pre-flight] Checking Elasticsearch availability..."
if kubectl -n monitoring get svc elasticsearch >/dev/null 2>&1; then
  green "    ✓ elasticsearch.monitoring:9200 reachable target found"
else
  yellow "    ⚠ elasticsearch service missing — falcosidekick will retry"
fi

# ---------------------------------------------------------------
# Install
# ---------------------------------------------------------------
blue "[1/4] Adding helm repo: $HELM_REPO_NAME ($HELM_REPO_URL)..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" 2>&1 | sed 's/^/    /' || true
helm repo update 2>&1 | grep -E "(Falco|falco)" | sed 's/^/    /' || true

blue "[2/4] Creating namespace + cleaning failed releases..."
kubectl create ns "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - 2>&1 | sed 's/^/    /'
# Auto-recover from failed/pending-install state
RELEASE_STATUS=$(helm list -n "$NAMESPACE" --filter "^${RELEASE}\$" --all -o json 2>/dev/null \
  | python3 -c "import sys,json; r=json.load(sys.stdin); print(r[0]['status'] if r else '')" 2>/dev/null)
if [ -n "$RELEASE_STATUS" ] && [ "$RELEASE_STATUS" != "deployed" ]; then
  yellow "    Existing release in '$RELEASE_STATUS' state — uninstalling first..."
  helm uninstall -n "$NAMESPACE" "$RELEASE" 2>&1 | sed 's/^/      /' || true
fi

blue "[3/4] Installing/upgrading $RELEASE chart (3-5 min for image pull + eBPF probe build)..."
if ! helm upgrade --install "$RELEASE" "$HELM_REPO_NAME/falco" \
     --namespace "$NAMESPACE" \
     --values "$VALUES_FILE" \
     --timeout 8m 2>&1 | tail -10; then
  red "  ✗ helm install/upgrade failed"
  red "    Diagnose:"
  red "      helm list -n $NAMESPACE --all"
  red "      kubectl -n $NAMESPACE describe ds falco | tail -30"
  red "      kubectl -n $NAMESPACE logs ds/falco --tail=40 -c falco"
  exit 1
fi

blue "[4/4] Waiting for Falco DaemonSet rollout..."
if ! kubectl -n "$NAMESPACE" rollout status ds/falco --timeout=300s; then
  red "  ✗ Falco rollout did not complete — common causes:"
  red "      1. Driver init failed (modern_ebpf unsupported)"
  red "         → kubectl -n $NAMESPACE logs ds/falco -c falco --tail=40"
  red "         → if 'modern_ebpf' shown failed, edit values.yaml driver.kind to 'ebpf' and retry"
  red "      2. ImagePullBackOff (falcosecurity/falco rate-limit)"
  red "         → kubectl -n $NAMESPACE describe pod -l app.kubernetes.io/name=falco"
  red "      3. SecurityContextConstraint (privileged required)"
  red "         → check Pod Security Admission level on $NAMESPACE ns"
  exit 1
fi

# Falcosidekick (Deployment, separate from Falco DS)
if kubectl -n "$NAMESPACE" get deploy falco-falcosidekick >/dev/null 2>&1; then
  blue "[4b/4] Waiting for falcosidekick Deployment rollout..."
  kubectl -n "$NAMESPACE" rollout status deploy/falco-falcosidekick --timeout=120s || true
fi

green "============================================================"
green " ✓ Falco runtime detection deployed"
green "============================================================"
echo
echo "Verify driver loaded:"
echo "  kubectl -n $NAMESPACE logs ds/falco -c falco --tail=30 | grep -i 'driver\\|engine'"
echo
echo "List ZTA custom rules loaded:"
echo "  kubectl -n $NAMESPACE exec ds/falco -c falco -- falco --list 2>&1 | grep -i 'ZTA'"
echo
echo "Trigger a test alert (read /etc/shadow from sample pod):"
echo "  kubectl -n default run alert-test --image=alpine --restart=Never --rm -it -- \\"
echo "    cat /etc/shadow"
echo "  # Watch sidekick:"
echo "  kubectl -n $NAMESPACE logs deploy/falco-falcosidekick --tail=10"
echo
echo "Query ES alerts:"
echo "  kubectl -n monitoring exec es-0 -- \\"
echo "    curl -s http://localhost:9200/_cat/indices/falco-events-*"
echo
echo "Run 09-verify-zta.sh — Test 4m checks Falco health + custom rules."
