#!/usr/bin/env bash
# =============================================================================
# Diagnose tại sao identity-service / job-service stuck Init:0/4 sau startup.
# 100% read-only. Chạy ngay sau khi startup time-out để xác định root cause.
# =============================================================================
set -uo pipefail

OUT="/tmp/zta-startup-diag-$(date +%H%M%S).log"
exec > >(tee "$OUT") 2>&1

H(){ printf '\n========== %s ==========\n' "$*"; }

H "1. Pod state job7189-apps (init container details)"
kubectl get pod -n job7189-apps -o wide
echo
for POD in $(kubectl get pod -n job7189-apps -l 'app in (identity-service,job-service)' -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- $POD ---"
  kubectl get pod -n job7189-apps "$POD" -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: ready={.ready} state={.state}{"\n"}{end}'
  echo "  --- describe init containers (events tail) ---"
  kubectl describe pod -n job7189-apps "$POD" | sed -n '/^Init Containers:/,/^Containers:/p' | head -60
  echo "  --- events liên quan ---"
  kubectl get events -n job7189-apps --field-selector involvedObject.name="$POD" --sort-by='.lastTimestamp' | tail -10
done

H "2. Logs vault-agent-init (init container đầu tiên)"
for POD in $(kubectl get pod -n job7189-apps -l 'app in (identity-service,job-service)' -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- $POD vault-agent-init logs ---"
  kubectl logs -n job7189-apps "$POD" -c vault-agent-init --tail=40 2>&1 | head -50
done

H "3. Vault status (sealed? auth backend OK?)"
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault status -format=json' 2>&1 | head -30

H "4. Vault auth kubernetes config + roles"
ROOT_TOKEN=$(jq -r '.root_token' ~/projects/DATN/infras/k8s-yaml/vault-scripts/vault-prod-init.json 2>/dev/null)
if [ -n "$ROOT_TOKEN" ] && [ "$ROOT_TOKEN" != "null" ]; then
  kubectl exec -n vault vault-0 -- sh -c \
    "VAULT_TOKEN='$ROOT_TOKEN' VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault list auth/kubernetes/role 2>&1" \
    | head -20
  echo "--- read role identity-service ---"
  kubectl exec -n vault vault-0 -- sh -c \
    "VAULT_TOKEN='$ROOT_TOKEN' VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 vault read auth/kubernetes/role/identity-service 2>&1" \
    | head -25
else
  echo "Không đọc được root_token — bỏ qua step này"
fi

H "5. Deployment spec: identity-service initContainers (xem có create-dummy-env không)"
kubectl get deploy -n job7189-apps identity-service -o jsonpath='{range .spec.template.spec.initContainers[*]}{.name}{"\n"}{end}'
echo "--- annotation agent-inject ---"
kubectl get deploy -n job7189-apps identity-service -o jsonpath='{.spec.template.metadata.annotations}' | python3 -m json.tool 2>/dev/null | grep -i vault | head -20

H "6. CNP trong job7189-apps + status VALID"
kubectl get cnp -n job7189-apps -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status' 2>/dev/null
echo "--- default-deny-all spec (sau khi PR #13 merge phải có enableDefaultDeny) ---"
kubectl get cnp -n job7189-apps default-deny-all -o jsonpath='{.spec}' | python3 -m json.tool 2>/dev/null

H "7. Tetragon policies active"
kubectl get tracingpolicynamespaced -A
echo "--- action (Sigkill hay Post?) ---"
kubectl get tracingpolicynamespaced -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.kprobes[0].selectors[0].matchActions[0].action}{"\n"}{end}' 2>/dev/null

H "8. Sigstore policy-controller pod label (sao startup.sh bị wait fail?)"
kubectl get pod -n cosign-system --show-labels

H "9. Test connectivity identity-service → vault từ cùng node (debug pod)"
NODE=$(kubectl get pod -n job7189-apps -l app=identity-service -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)
echo "Identity-service đang trên node: $NODE"
VAULT_NODE=$(kubectl get pod -n vault vault-0 -o jsonpath='{.spec.nodeName}')
echo "Vault-0 đang trên node: $VAULT_NODE"
echo "Cùng node? $([ "$NODE" = "$VAULT_NODE" ] && echo YES || echo NO)"

H "10. Vault-agent-init image (xem dùng image gì)"
kubectl get pod -n job7189-apps -l app=identity-service -o jsonpath='{.items[0].spec.initContainers[?(@.name=="vault-agent-init")].image}'
echo

H "DONE — log lưu tại: $OUT"
