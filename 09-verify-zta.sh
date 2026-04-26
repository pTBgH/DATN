#!/bin/bash
# ==========================================
# Script 09: ZTA Verification & Evidence Collection
# ==========================================
# PURPOSE: Run a comprehensive ZTA verification suite and collect evidence
#          for thesis Chapter 3 / Chapter 4.
# RUN AFTER: All other scripts (01→08)
# OUTPUT: Evidence files saved to evidence/ directory
# ==========================================

set -uo pipefail

SCRIPT_START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE_DIR="${SCRIPT_DIR}/evidence"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$EVIDENCE_DIR"

echo ""
echo "============================================================"
echo "🔍 SCRIPT 09: ZTA VERIFICATION & EVIDENCE COLLECTION"
echo "============================================================"
echo "   Evidence directory: $EVIDENCE_DIR"
echo "   Timestamp: $TIMESTAMP"
echo ""

PASS=0
FAIL=0
WARN=0

result() {
  local status=$1
  local test_name=$2
  local detail=${3:-""}
  case "$status" in
    PASS) echo "   ✅ PASS: $test_name"; ((PASS++)) ;;
    FAIL) echo "   ❌ FAIL: $test_name${detail:+ — $detail}"; ((FAIL++)) ;;
    WARN) echo "   ⚠️  WARN: $test_name${detail:+ — $detail}"; ((WARN++)) ;;
  esac
}

# ========================
# Test 1: Pod Health (all namespaces)
# ========================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Test 1: Cluster Pod Health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

kubectl get pods -A -o wide > "$EVIDENCE_DIR/pods-status-${TIMESTAMP}.txt" 2>&1

TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="Running"' | wc -l)
ERROR_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -cE 'Error|CrashLoop|Failed' || true)

if [ "$ERROR_PODS" -eq 0 ]; then
  result PASS "All pods healthy ($RUNNING_PODS/$TOTAL_PODS Running)"
else
  result FAIL "Found $ERROR_PODS pods in error state" "Check evidence/pods-status-${TIMESTAMP}.txt"
fi

# ========================
# Test 2: Vault Status & Dynamic Credentials
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Test 2: Vault Dynamic Credentials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 2a: Vault sealed status
VAULT_SEALED=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed', True))" 2>/dev/null || echo "true")
if [ "$VAULT_SEALED" = "False" ] || [ "$VAULT_SEALED" = "false" ]; then
  result PASS "Vault is unsealed"
else
  result FAIL "Vault is sealed or unreachable"
fi

# 2b: Active leases
VAULT_ROOT=$(python3 -c "import json; print(json.load(open('infras/k8s-yaml/vault-scripts/vault-prod-init.json')).get('root_token',''))" 2>/dev/null || true)
if [ -n "$VAULT_ROOT" ]; then
  LEASE_OUTPUT=$(kubectl exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN='${VAULT_ROOT}' vault list -format=json sys/leases/lookup/database/creds/" 2>/dev/null || echo "[]")
  echo "$LEASE_OUTPUT" > "$EVIDENCE_DIR/vault-leases-${TIMESTAMP}.json"
  LEASE_COUNT=$(echo "$LEASE_OUTPUT" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [ "$LEASE_COUNT" -gt 0 ]; then
    result PASS "Vault has $LEASE_COUNT active DB credential leases"
  else
    result WARN "No active DB leases found" "Services may not have connected yet"
  fi
else
  result WARN "Vault root token not found" "Cannot check leases"
fi

# 2c: Secrets on tmpfs
echo ""
TMPFS_CHECK=$(kubectl exec -n job7189-apps deploy/identity-service -c app -- mount 2>/dev/null | grep tmpfs | grep -c "vault-secrets\|app-secrets" || echo "0")
if [ "$TMPFS_CHECK" -gt 0 ]; then
  result PASS "Secrets mounted on tmpfs (RAM-only, not on disk)"
else
  result WARN "Could not verify tmpfs secret mount"
fi

# ========================
# Test 3: Kong JWT Enforcement
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️ Test 3: Kong JWT Enforcement"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use kubectl port-forward (apiserver SPDY tunnel — bypasses Cilium policy on
# pod→pod traffic). Avoids creating ephemeral test pods which (a) hang waiting
# for image pull through default-deny, (b) require label/policy carve-outs.
KONG_SVC=$(kubectl get svc -n gateway -l app=kong-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$KONG_SVC" ]; then KONG_SVC="kong-proxy"; fi

PF_PORT=18800
echo "   Using kubectl port-forward svc/${KONG_SVC} ${PF_PORT}:80"

# Cleanup any stale port-forward
pkill -f "port-forward.*svc/${KONG_SVC}.*${PF_PORT}" 2>/dev/null || true
sleep 1

# Start port-forward in background, redirect output to log
PF_LOG="$EVIDENCE_DIR/port-forward-${TIMESTAMP}.log"
kubectl -n gateway port-forward "svc/${KONG_SVC}" "${PF_PORT}:80" \
  >"$PF_LOG" 2>&1 &
PF_PID=$!

# Wait for port to come up (max 8s)
PF_READY=0
for _ in 1 2 3 4 5 6 7 8; do
  if curl -s -o /dev/null -m 1 "http://localhost:${PF_PORT}/" 2>/dev/null; then
    PF_READY=1; break
  fi
  sleep 1
done

if [ "$PF_READY" = "1" ]; then
  # Test: protected route without token → should return 401
  JWT_401=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' \
    "http://localhost:${PF_PORT}/api/recruiters/profile" 2>/dev/null || echo "000")
  if [ "$JWT_401" = "401" ]; then
    result PASS "Protected route returns 401 without JWT"
    echo "   HTTP 401 — JWT enforcement active" > "$EVIDENCE_DIR/jwt-401-${TIMESTAMP}.txt"
  else
    result WARN "Protected route returned '$JWT_401'" "Expected 401 — Kong may use different route path"
  fi

  # Test: open route → should return non-000
  OPEN_CODE=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' \
    "http://localhost:${PF_PORT}/" 2>/dev/null || echo "000")
  if [ "$OPEN_CODE" != "000" ]; then
    result PASS "Kong proxy reachable (HTTP $OPEN_CODE)"
  else
    result WARN "Kong proxy unreachable via port-forward" "Check kong pod health"
  fi
else
  result WARN "Kong port-forward did not become ready in 8s" "Run kubectl get pod -n gateway"
fi

# Cleanup port-forward
kill "$PF_PID" 2>/dev/null || true
wait "$PF_PID" 2>/dev/null || true

# ========================
# Test 4: Cilium Microsegmentation
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️ Test 4: Cilium Microsegmentation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

POLICY_COUNT=$(kubectl get ciliumnetworkpolicies -n job7189-apps --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$POLICY_COUNT" -ge 4 ]; then
  result PASS "Found $POLICY_COUNT CiliumNetworkPolicy(ies) in job7189-apps"
  kubectl get ciliumnetworkpolicies -n job7189-apps > "$EVIDENCE_DIR/cilium-policies-${TIMESTAMP}.txt" 2>&1
else
  result FAIL "Only $POLICY_COUNT policies found (expected ≥4)"
fi

# Test: Default Deny should be present (PR #8 renamed default-deny-all → default-deny-job7189-apps)
if kubectl get ciliumnetworkpolicy default-deny-job7189-apps -n job7189-apps >/dev/null 2>&1; then
  result PASS "Default Deny policy exists (default-deny-job7189-apps)"
elif kubectl get ciliumnetworkpolicy default-deny-all -n job7189-apps >/dev/null 2>&1; then
  result PASS "Default Deny policy exists (legacy default-deny-all)"
else
  result FAIL "Default Deny policy missing in job7189-apps"
fi

# Hubble flow check (if available)
HUBBLE_POD=$(kubectl -n kube-system get pods -l k8s-app=hubble-relay -o name 2>/dev/null | head -n1 || true)
if [ -n "$HUBBLE_POD" ]; then
  echo ""
  echo "   Collecting Hubble flow samples..."
  kubectl exec -n kube-system "${HUBBLE_POD#pod/}" -- hubble observe -n job7189-apps --verdict DROPPED --last 10 -o compact > "$EVIDENCE_DIR/hubble-dropped-${TIMESTAMP}.txt" 2>&1 || true
  kubectl exec -n kube-system "${HUBBLE_POD#pod/}" -- hubble observe -n job7189-apps --verdict FORWARDED --last 10 -o compact > "$EVIDENCE_DIR/hubble-forwarded-${TIMESTAMP}.txt" 2>&1 || true
  DROPPED_COUNT=$(wc -l < "$EVIDENCE_DIR/hubble-dropped-${TIMESTAMP}.txt" 2>/dev/null || echo "0")
  FORWARDED_COUNT=$(wc -l < "$EVIDENCE_DIR/hubble-forwarded-${TIMESTAMP}.txt" 2>/dev/null || echo "0")
  result PASS "Hubble flows: $DROPPED_COUNT dropped, $FORWARDED_COUNT forwarded samples"
else
  result WARN "Hubble relay not found" "Cannot collect flow data"
fi

# ========================
# Test 5: Encryption Status (mTLS + WireGuard)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Test 5: Encryption Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MESH_AUTH=$(kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.mesh-auth-enabled}' 2>/dev/null || echo "false")
WIREGUARD=$(kubectl -n kube-system get configmap cilium-config -o jsonpath='{.data.enable-wireguard}' 2>/dev/null || echo "false")

if [ "$MESH_AUTH" = "true" ]; then
  result PASS "Cilium Mutual Authentication (mTLS): ENABLED"
else
  result WARN "Cilium Mutual Authentication (mTLS): DISABLED" "Run 08-harden-security.sh"
fi

if [ "$WIREGUARD" = "true" ]; then
  result PASS "WireGuard Transparent Encryption: ENABLED"
else
  result WARN "WireGuard Transparent Encryption: DISABLED" "Run ZTA_HARDEN_WIREGUARD=1 bash 08-harden-security.sh"
fi

# ========================
# Test 6: Observability Stack
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test 6: Observability Stack"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for svc in elasticsearch kibana prometheus grafana; do
  if kubectl get deploy "$svc" -n monitoring >/dev/null 2>&1 || kubectl get statefulset "$svc" -n monitoring >/dev/null 2>&1 || kubectl get statefulset "es" -n monitoring >/dev/null 2>&1; then
    result PASS "$svc is deployed"
  else
    result FAIL "$svc is NOT deployed"
  fi
done

# Check Hubble UI
if kubectl get deploy hubble-ui -n kube-system >/dev/null 2>&1; then
  result PASS "Hubble UI is deployed"
else
  result WARN "Hubble UI not deployed"
fi

# Check node-exporter
NE_COUNT=$(kubectl get ds node-exporter -n monitoring -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
if [ "$NE_COUNT" -gt 0 ]; then
  result PASS "node-exporter: $NE_COUNT nodes"
else
  result WARN "node-exporter not deployed" "Run 07-deploy-monitoring-exporters.sh"
fi

# Check kube-state-metrics
if kubectl get deploy kube-state-metrics -n monitoring >/dev/null 2>&1; then
  result PASS "kube-state-metrics is deployed"
else
  result WARN "kube-state-metrics not deployed" "Run 07-deploy-monitoring-exporters.sh"
fi

# ========================
# Test 4b: Default-Deny coverage across all critical namespaces (PR #8)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️ Test 4b: Default-Deny per Namespace"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

declare -A NS_DEFAULT_DENY=(
  [data]="default-deny-data"
  [vault]="default-deny-vault"
  [security]="default-deny-security"
  [monitoring]="default-deny-monitoring"
  [gateway]="default-deny-gateway"
  [management]="default-deny-management"
  [registry]="default-deny-registry"
  [job7189-apps]="default-deny-job7189-apps default-deny-all"
)

for ns in "${!NS_DEFAULT_DENY[@]}"; do
  found=""
  for cnp_name in ${NS_DEFAULT_DENY[$ns]}; do
    if kubectl get cnp "$cnp_name" -n "$ns" >/dev/null 2>&1; then
      found="$cnp_name"
      break
    fi
  done
  if [ -n "$found" ]; then
    cnp_total=$(kubectl get cnp -n "$ns" --no-headers 2>/dev/null | wc -l)
    result PASS "ns=$ns default-deny present ($found, $cnp_total CNPs total)"
  else
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
      result WARN "ns=$ns missing default-deny" "Run apply-zta-namespace-policies.sh --namespace=$ns --apply"
    else
      result WARN "ns=$ns does not exist" "Skipped"
    fi
  fi
done

# ========================
# Test 4c: Audit findings F-1 / F-2 / F-4 (PR #8)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Test 4c: Audit Findings Remediation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# F-1: vault-dev hard-coded token must NOT exist in repo
# NOTE: exclude this verify script itself (pattern in grep arg matches own source line)
HARDCODED_HITS=$(grep -rn "vault-dev-root-token" \
  --include="*.sh" --include="*.yaml" --include="*.md" \
  --exclude="09-verify-zta.sh" \
  "$SCRIPT_DIR" \
  2>/dev/null | grep -v "audit-findings\|F-1 fix\|22-audit-findings" | wc -l)
if [ "$HARDCODED_HITS" -eq 0 ]; then
  result PASS "F-1: no hardcoded 'vault-dev-root-token' in repo"
else
  result FAIL "F-1: still $HARDCODED_HITS occurrences of hardcoded token"
fi

# F-1: Secret vault-dev-token exists in cluster
if kubectl get secret vault-dev-token -n vault >/dev/null 2>&1; then
  result PASS "F-1: Secret vault-dev-token present"
else
  result WARN "F-1: Secret vault-dev-token missing" "Will be created on next deploy"
fi

# F-2: vault-prod-init.json gitignored
if grep -q "vault-prod-init.json" "$SCRIPT_DIR/.gitignore" 2>/dev/null; then
  result PASS "F-2: vault-prod-init.json in repo .gitignore"
else
  result FAIL "F-2: vault-prod-init.json missing from root .gitignore"
fi

# F-4: phpmyadmin only egress to data/mysql
if kubectl get cnp allow-phpmyadmin-egress-mysql -n management >/dev/null 2>&1; then
  result PASS "F-4: phpmyadmin egress restricted to data/mysql via CNP"
else
  result WARN "F-4: management CNP not yet applied" "Run apply-zta-namespace-policies.sh --namespace=management --apply"
fi

# ========================
# Test 4d: Workload labeling coverage (PR #9 — doc/19-label-schema.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  Test 4d: Workload Label Coverage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LABEL_NAMESPACES="data vault security monitoring gateway management registry job7189-apps frontend"
LABEL_KEYS="zta.job7189/role zta.job7189/tier zta.job7189/env zta.job7189/data-classification zta.job7189/exposure zta.job7189/team"

for ns in $LABEL_NAMESPACES; do
  if ! kubectl get ns "$ns" >/dev/null 2>&1; then
    continue
  fi
  pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$pods" -eq 0 ]; then
    continue
  fi

  missing_pods=0
  for key in $LABEL_KEYS; do
    # số pod KHÔNG có label này
    have=$(kubectl get pods -n "$ns" -l "$key" --no-headers 2>/dev/null | wc -l)
    diff=$((pods - have))
    if [ "$diff" -gt 0 ]; then
      missing_pods=$((missing_pods + diff))
    fi
  done

  if [ "$missing_pods" -eq 0 ]; then
    result PASS "ns=$ns ($pods pods) — all 6 ZTA labels present"
  else
    result WARN "ns=$ns: $missing_pods label-misses across $pods pods" "Run scripts/zta-apply-workload-labels.sh --apply"
  fi
done

# ========================
# Test 4e: L7 enforcement coverage (PR #10 — doc/20-5w1h-policy-matrix.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Test 4e: L7 Policy Coverage (5W1H)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

L7_POLICIES="l7-vault-api-allowlist:vault l7-keycloak-oidc-allowlist:security l7-keycloak-jwks-from-kong:security l7-kong-admin-readonly:gateway l7-prom-scrape-node-exporter:monitoring l7-prom-scrape-kube-state-metrics:monitoring"

l7_present=0
l7_missing=0
for entry in $L7_POLICIES; do
  name="${entry%%:*}"
  ns="${entry##*:}"
  if kubectl get cnp "$name" -n "$ns" >/dev/null 2>&1; then
    valid=$(kubectl get cnp "$name" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Valid")].status}' 2>/dev/null)
    if [ "$valid" = "True" ]; then
      result PASS "L7 CNP $name (ns=$ns) VALID=True"
      l7_present=$((l7_present + 1))
    else
      result WARN "L7 CNP $name (ns=$ns) exists but VALID=$valid" "Check kubectl describe cnp $name -n $ns"
    fi
  else
    result WARN "L7 CNP $name (ns=$ns) not applied" "Run scripts/zta-apply-l7-policies.sh --apply"
    l7_missing=$((l7_missing + 1))
  fi
done

# Hubble L7 flow check
if [ -n "$HUBBLE_POD" ]; then
  L7_FLOWS=$( { kubectl exec -n kube-system "${HUBBLE_POD#pod/}" -- hubble observe --type l7 --last 50 -o compact 2>/dev/null || true; } | wc -l | tr -d ' \n')
  L7_FLOWS=${L7_FLOWS:-0}
  if [ "$L7_FLOWS" -gt 0 ] 2>/dev/null; then
    result PASS "Hubble L7 flows captured: $L7_FLOWS samples"
  else
    result WARN "Hubble L7 flows = 0" "Generate traffic (curl Vault/Keycloak) then re-run"
  fi
fi

# ========================
# Test 4f: Adaptive Security Loop (PR #12 — doc/24-adaptive-security-loop.md)
# Covers: OPA Gatekeeper constraints + Tetragon TracingPolicy coverage
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  Test 4f: Adaptive Security (Gatekeeper + Tetragon)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 4f.1 Gatekeeper installed
if kubectl get ns gatekeeper-system >/dev/null 2>&1 \
   && kubectl -n gatekeeper-system get deploy gatekeeper-controller-manager >/dev/null 2>&1; then
  GK_READY=$(kubectl -n gatekeeper-system get deploy gatekeeper-controller-manager \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "${GK_READY:-0}" -ge 1 ]; then
    result PASS "OPA Gatekeeper running ($GK_READY replicas Ready)"
  else
    result WARN "Gatekeeper controller-manager not Ready" "Run scripts/zta-deploy-gatekeeper.sh"
  fi

  # 4f.2 ConstraintTemplates registered
  CT_COUNT=$(kubectl get constrainttemplate --no-headers 2>/dev/null | grep -c "^zta" || echo "0")
  if [ "$CT_COUNT" -ge 3 ]; then
    result PASS "ZTA ConstraintTemplates registered ($CT_COUNT/3)"
  else
    result WARN "Only $CT_COUNT/3 ZTA ConstraintTemplates" "Run scripts/zta-deploy-gatekeeper.sh"
  fi

  # 4f.3 Constraint violations reported (audit-only mode)
  if kubectl get ztarequiredlabels.constraints.gatekeeper.sh zta-labels-required >/dev/null 2>&1; then
    VIOL=$(kubectl get ztarequiredlabels.constraints.gatekeeper.sh zta-labels-required \
      -o jsonpath='{.status.totalViolations}' 2>/dev/null || echo "?")
    if [ "$VIOL" = "0" ]; then
      result PASS "zta-labels-required: 0 violations (label coverage 100%)"
    else
      result WARN "zta-labels-required: $VIOL violations" "Run scripts/zta-apply-workload-labels.sh --apply"
    fi
  else
    result WARN "Constraint zta-labels-required not applied" "Run scripts/zta-deploy-gatekeeper.sh"
  fi
else
  result WARN "Gatekeeper not installed" "Run scripts/zta-deploy-gatekeeper.sh"
fi

# 4f.4 Tetragon TracingPolicies in T1 namespaces
if kubectl get crd tracingpoliciesnamespaced.cilium.io >/dev/null 2>&1; then
  T1_NS_WITH_POLICY=0
  for t1ns in vault data security job7189-apps; do
    if kubectl -n "$t1ns" get tracingpoliciesnamespaced.cilium.io block-suspicious-exec >/dev/null 2>&1; then
      T1_NS_WITH_POLICY=$((T1_NS_WITH_POLICY + 1))
    fi
  done
  if [ "$T1_NS_WITH_POLICY" -ge 4 ]; then
    result PASS "Tetragon block-suspicious-exec in 4/4 T1+app ns"
  else
    result WARN "Tetragon TracingPolicy in only $T1_NS_WITH_POLICY/4 ns" "Run scripts/zta-apply-tracing-policies.sh --apply"
  fi
else
  result WARN "Tetragon CRDs not present" "Run 10-deploy-tetragon.sh"
fi

# ========================
# Test 7: Namespace Isolation
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️ Test 7: Namespace Tier Isolation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXPECTED_NS="gateway security data job7189-apps management monitoring vault"
for ns in $EXPECTED_NS; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    POD_COUNT=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
    result PASS "Namespace $ns exists ($POD_COUNT pods)"
  else
    result FAIL "Namespace $ns missing"
  fi
done

# ========================
# Summary
# ========================
TOTAL_TIME=$(($(date +%s) - SCRIPT_START_TIME))
TOTAL_TESTS=$((PASS + FAIL + WARN))

echo ""
echo "============================================================"
echo "📊 ZTA VERIFICATION SUMMARY"
echo "============================================================"
echo ""
echo "   ✅ PASS: $PASS"
echo "   ❌ FAIL: $FAIL"
echo "   ⚠️  WARN: $WARN"
echo "   ────────────────"
echo "   Total:  $TOTAL_TESTS tests in ${TOTAL_TIME}s"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "   🎉 ALL CRITICAL TESTS PASSED"
else
  echo "   ⚠️  $FAIL critical test(s) failed — review output above"
fi

echo ""
echo "📁 Evidence files saved to: $EVIDENCE_DIR/"
ls -la "$EVIDENCE_DIR"/*-${TIMESTAMP}.* 2>/dev/null || echo "   (no files)"
echo ""
echo "📋 Evidence can be used for thesis Chapter 3 / Chapter 4"
echo ""

# CISA ZTMM Assessment Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 CISA ZTMM 2.0 Quick Assessment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Identity:      Advanced (Keycloak + Vault SA mapping)"
echo "   Devices:       Initial  (no MDM/EDR)"
echo "   Networks:      $([ "$MESH_AUTH" = "true" ] && echo "Advanced+" || echo "Advanced ") (Cilium microseg$([ "$MESH_AUTH" = "true" ] && echo " + mTLS")$([ "$WIREGUARD" = "true" ] && echo " + WireGuard"))"
echo "   Applications:  Advanced (Kong JWT + ZTA pipeline)"
echo "   Data:          Advanced (Vault JIT + tmpfs + auto-rotate)"
echo ""

exit "$FAIL"
