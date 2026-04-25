#!/bin/bash
# Remove ZTA Microsegmentation policies from namespace job7189-apps
# Can be called from any directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔓 Gỡ Microsegmentation policies..."
kubectl delete -f "$SCRIPT_DIR/04-allow-internal-api-strict.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/03-allow-ingress-kong.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/02-allow-egress-data.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/01-allow-egress-dns.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/00-default-deny.yaml" --ignore-not-found
echo "🔓 Microsegmentation đã bị gỡ."
