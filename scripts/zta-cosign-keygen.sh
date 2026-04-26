#!/usr/bin/env bash
# scripts/zta-cosign-keygen.sh
#
# Generate Cosign keypair for ZTA workload signing + create ConfigMap
# `zta-cosign-public-key` in security namespace so verifiers can pull the
# public key from the cluster.
#
# Outputs:
#   infras/cosign-keys/zta.key      — private (gitignored, NEVER commit)
#   infras/cosign-keys/zta.pub      — public  (committed)
#   ConfigMap security/zta-cosign-public-key.cosign-public-key.pem
#
# Usage:
#   bash scripts/zta-cosign-keygen.sh             # generate (skip if key exists)
#   bash scripts/zta-cosign-keygen.sh --rotate    # force regenerate
#
# Cosign password handling:
#   Pass via $COSIGN_PASSWORD or interactive prompt. For CI / automation,
#   use empty password (we keep the private key in a gitignored dir;
#   passwordless makes scripted signing simpler).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_DIR="${REPO_ROOT}/infras/cosign-keys"
PRIVATE_KEY="${KEY_DIR}/zta.key"
PUBLIC_KEY="${KEY_DIR}/zta.pub"
ROTATE=0

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

for arg in "$@"; do
  case "$arg" in
    --rotate) ROTATE=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) red "Unknown flag: $arg"; exit 1 ;;
  esac
done

if ! command -v cosign >/dev/null 2>&1; then
  red "ERROR: cosign not installed."
  yellow "  Install:  go install github.com/sigstore/cosign/v2/cmd/cosign@latest"
  yellow "  Or:       https://docs.sigstore.dev/cosign/installation/"
  exit 1
fi

mkdir -p "$KEY_DIR"

blue "============================================================"
blue " ZTA Cosign keypair generation"
blue "   key dir: $KEY_DIR"
blue "============================================================"

if [ -f "$PRIVATE_KEY" ] && [ "$ROTATE" -ne 1 ]; then
  yellow "Private key already exists at $PRIVATE_KEY"
  yellow "Pass --rotate to force regeneration (then re-sign all workloads)."
else
  if [ "$ROTATE" -eq 1 ] && [ -f "$PRIVATE_KEY" ]; then
    yellow "Rotating: backing up old key to ${PRIVATE_KEY}.old.$(date +%s)"
    mv "$PRIVATE_KEY" "${PRIVATE_KEY}.old.$(date +%s)"
    [ -f "$PUBLIC_KEY" ] && mv "$PUBLIC_KEY" "${PUBLIC_KEY}.old.$(date +%s)"
  fi
  blue "[1/2] Generating ECDSA-P256 keypair..."
  ( cd "$KEY_DIR" && \
      COSIGN_PASSWORD="${COSIGN_PASSWORD:-}" cosign generate-key-pair \
      --output-key-prefix zta )
  green "    ✓ Keypair created: $PRIVATE_KEY (private), $PUBLIC_KEY (public)"
fi

if [ ! -f "$PUBLIC_KEY" ]; then
  red "ERROR: public key not found after generation. Aborting."
  exit 1
fi

blue "[2/2] Publishing public key to cluster as ConfigMap..."
if ! command -v kubectl >/dev/null 2>&1; then
  yellow "    kubectl not found — skipping ConfigMap publish."
else
  kubectl create ns security --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl create configmap zta-cosign-public-key \
    -n security \
    --from-file=cosign-public-key.pem="$PUBLIC_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
  green "    ✓ ConfigMap security/zta-cosign-public-key applied"
fi

green "============================================================"
green " ✓ Cosign setup complete"
green "============================================================"
echo
echo "Next:"
echo "  1. Add infras/cosign-keys/*.key to .gitignore (DO NOT commit private key)"
echo "  2. Sign workloads:"
echo "       bash scripts/zta-cosign-sign-deployment.sh path/to/deploy.yaml"
echo "  3. Apply Constraints:"
echo "       bash scripts/zta-deploy-gatekeeper.sh --constraints-only"
