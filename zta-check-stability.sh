#!/usr/bin/env bash
# zta-check-stability.sh — read-only health check trước khi apply CNP wave
# An toàn: KHÔNG sửa gì, chỉ đọc.
set -uo pipefail

H(){ printf '\n========== %s ==========\n' "$*"; }
OUT=/tmp/zta-stability-$(date +%s).log
exec > >(tee "$OUT") 2>&1

H "1/6 Pod NotReady / CrashLoop / Init stuck"
kubectl get pod -A --no-headers 2>/dev/null \
  | awk '$4!="Running" && $4!="Completed" {print}' \
  | head -50
echo "(empty = mọi pod Running/Completed)"

H "2/6 CNP VALID status"
kubectl get cnp -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' \
  | grep -v ' True' | head -30
echo "(empty = mọi CNP VALID=True)"

H "3/6 Vault status"
kubectl exec -n vault vault-0 -c vault -- sh -c \
  "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status" 2>&1 \
  | grep -E "Sealed|Initialized|HA Enabled" || echo "(vault unreachable)"

H "4/6 Vault auth k8s config (token-reviewer health)"
ROOT=$(jq -r .root_token ~/projects/DATN/infras/k8s-yaml/vault-scripts/vault-prod-init.json 2>/dev/null)
if [ -n "$ROOT" ] && [ "$ROOT" != "null" ]; then
  kubectl exec -n vault vault-0 -c vault -- sh -c \
    "VAULT_TOKEN=$ROOT VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault read auth/kubernetes/config" 2>&1 \
    | grep -E "issuer|kubernetes_host|disable_iss_validation" || echo "(read failed)"
else
  echo "(vault-prod-init.json missing — skip)"
fi

H "5/6 Hubble drop trong 10 phút gần nhất (top 20)"
CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CILIUM" ]; then
  kubectl -n kube-system exec "$CILIUM" -c cilium-agent -- \
    hubble observe --verdict DROPPED --since 10m --output compact 2>/dev/null \
    | head -20
  echo "(empty = không có drop nào trong 10 phút qua)"
else
  echo "(no cilium pod found)"
fi

H "6/6 Pod restart count > 5 (suspicious)"
kubectl get pod -A --no-headers 2>/dev/null \
  | awk '$5 > 5 {print $1, $2, "restarts="$5}' \
  | head -20
echo "(empty = không pod nào restart > 5)"

H "KẾT LUẬN"
echo "Log: $OUT"
echo
echo "Hệ thống ổn định nếu:"
echo "  ✓ Mục 1 empty (mọi pod Running)"
echo "  ✓ Mục 2 empty (mọi CNP VALID=True)"
echo "  ✓ Mục 3 Sealed=false Initialized=true"
echo "  ✓ Mục 5 không có drop của flow hợp pháp (DNS, vault, kafka, mysql, intra-redis)"
echo
echo "Gửi log $OUT cho mình để mình quyết định apply wave 1."
