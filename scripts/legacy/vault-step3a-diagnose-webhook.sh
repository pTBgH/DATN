#!/bin/bash
# =========================================================================
# Vault Cấp Cứu — STEP 3A: Diagnose vì sao MutatingWebhookConfiguration
# không xuất hiện sau khi helm install vault-agent
# =========================================================================
# 100% read-only (logs / describe / get). KHÔNG apply / delete / restart.
# =========================================================================
set -u

echo "===== A. Helm release + pod injector ====="
helm list -n vault
echo ---
kubectl get pod -n vault -l app.kubernetes.io/name=vault-agent-injector -o wide
kubectl get pod -n vault -l app.kubernetes.io/instance=vault-agent

echo
echo "===== B. Injector pod describe (events + restart count) ====="
INJ_POD=$(kubectl get pod -n vault -l app.kubernetes.io/name=vault-agent-injector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "INJ_POD=$INJ_POD"
if [ -n "$INJ_POD" ]; then
  kubectl describe pod "$INJ_POD" -n vault | tail -60
fi

echo
echo "===== C. Log injector 150 dòng cuối ====="
if [ -n "$INJ_POD" ]; then
  kubectl logs -n vault "$INJ_POD" --tail=150 2>&1 || echo "(no log)"
  echo --- previous ---
  kubectl logs -n vault "$INJ_POD" --previous --tail=50 2>&1 || echo "(no previous log)"
fi

echo
echo "===== D. ClusterRole / ClusterRoleBinding của injector ====="
kubectl get clusterrole | grep -E 'vault-agent|injector'
echo ---
kubectl get clusterrolebinding | grep -E 'vault-agent|injector'
echo ---
# Check serviceaccount has permission to create mutatingwebhookconfigurations
kubectl auth can-i create mutatingwebhookconfigurations \
  --as=system:serviceaccount:vault:vault-agent-agent-injector 2>&1 || true
kubectl auth can-i patch mutatingwebhookconfigurations \
  --as=system:serviceaccount:vault:vault-agent-agent-injector 2>&1 || true
kubectl auth can-i update mutatingwebhookconfigurations \
  --as=system:serviceaccount:vault:vault-agent-agent-injector 2>&1 || true

echo
echo "===== E. MutatingWebhookConfiguration toàn cluster (lọc vault) ====="
kubectl get mutatingwebhookconfiguration | grep -iE 'vault|injector' || echo "(không có mwc nào liên quan vault)"
echo ---
kubectl get mutatingwebhookconfiguration -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

echo
echo "===== F. Sigstore policy-controller có chặn admission CREATE mwc không? ====="
kubectl logs -n cosign-system deploy/policy-controller-webhook --tail=200 2>&1 \
  | grep -iE 'mutatingwebhook|vault-agent-injector' | tail -10 || echo "(không có log liên quan)"

echo
echo "===== G. Gatekeeper constraint có chặn mwc creation không? ====="
kubectl get constrainttemplates 2>/dev/null | head -20
kubectl get constraints -A 2>/dev/null | head -20

echo
echo "===== H. Validating webhooks có chặn POST /mutatingwebhookconfigurations không? ====="
kubectl get validatingwebhookconfiguration -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .webhooks[*]}{.name}{","}{range .rules[*]}{.resources}{" "}{end}{"\t"}{end}{"\n"}{end}' \
  | grep -i 'mutating' || echo "(không có validating webhook chặn mwc)"

echo
echo "===== I. Helm chart values của vault-agent (xem có disable injector không) ====="
helm get values vault-agent -n vault 2>/dev/null | sed -n '1,40p'

echo
echo "===== DONE ====="
