#!/bin/bash
echo "🛡️ Áo giáp ZTA (Microsegmentation) đang được kích hoạt qua Cilium..."
kubectl apply -f 00-default-deny.yaml
kubectl apply -f 01-allow-egress-dns.yaml
kubectl apply -f 02-allow-egress-data.yaml
kubectl apply -f 03-allow-ingress-kong.yaml
kubectl apply -f 04-allow-internal-api-strict.yaml
echo "✅ Microsegmentation cho namespace 'job7189-apps' đã được bật!"
