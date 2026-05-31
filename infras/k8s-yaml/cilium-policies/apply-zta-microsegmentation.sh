#!/bin/bash
# Apply ZTA Microsegmentation policies for namespace job7189-apps
# Can be called from any directory
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🛡️ Áo giáp ZTA (Microsegmentation) đang được kích hoạt qua Cilium..."
kubectl apply -f "$SCRIPT_DIR/00-default-deny.yaml"
kubectl apply -f "$SCRIPT_DIR/01-allow-egress-dns.yaml"
kubectl apply -f "$SCRIPT_DIR/02-allow-egress-data.yaml"
kubectl apply -f "$SCRIPT_DIR/03-allow-ingress-kong.yaml"
kubectl apply -f "$SCRIPT_DIR/04-allow-internal-api-strict.yaml"
# Ingress phía data: cho phép app gọi MySQL (cặp với egress ở 02-allow-egress-data.yaml)
kubectl apply -f "$SCRIPT_DIR/10-allow-ingress-mysql-from-apps.yaml"

echo ""
echo "✅ Microsegmentation cho namespace 'job7189-apps' đã được bật!"
echo ""
echo "📋 Policies đã apply:"
kubectl get ciliumnetworkpolicies -n job7189-apps 2>/dev/null || true
