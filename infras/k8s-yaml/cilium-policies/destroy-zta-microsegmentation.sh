#!/bin/bash
kubectl delete -f 04-allow-internal-api-strict.yaml --ignore-not-found
kubectl delete -f 03-allow-ingress-kong.yaml --ignore-not-found
kubectl delete -f 02-allow-egress-data.yaml --ignore-not-found
kubectl delete -f 01-allow-egress-dns.yaml --ignore-not-found
kubectl delete -f 00-default-deny.yaml --ignore-not-found
echo "🔓 Microsegmentation đã bị gỡ."
