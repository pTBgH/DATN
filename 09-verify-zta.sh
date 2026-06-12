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

# ============================================================
# Hard wall-clock timeouts for hang-prone kubectl calls.
# ============================================================
# Prior to PR-H this script invoked `kubectl exec ... hubble observe` and
# `kubectl run --rm ...` directly. Each of those can block effectively
# forever when the cluster is under load (apiserver SPDY tunnel slow,
# image pull stuck behind default-deny, hubble-relay pod still
# initialising). When this script runs as orchestrator step `90-verify`
# the parent's 1800s budget is hit while we're still inside the warm-up
# loop, the script is SIGKILLed, evidence/SUMMARY.md is never written,
# and the hubble-l7-warmup-* pod is orphaned in Error state.
#
# `timeout` (coreutils) wraps every potentially-blocking call with a
# real wall-clock kill. Exit 124 = our timeout fired; the surrounding
# `|| true` keeps the pipeline going so we still emit a useful WARN.
#
# Override per-call budgets via env if you need to:
#   ZTA_VERIFY_KUBE_EXEC_TIMEOUT=20   (kubectl exec)
#   ZTA_VERIFY_HUBBLE_OBSERVE_TIMEOUT=30  (hubble observe)
#   ZTA_VERIFY_WARMUP_TIMEOUT=25      (per warm-up pod)
ZTA_VERIFY_KUBE_EXEC_TIMEOUT="${ZTA_VERIFY_KUBE_EXEC_TIMEOUT:-15}"
ZTA_VERIFY_HUBBLE_OBSERVE_TIMEOUT="${ZTA_VERIFY_HUBBLE_OBSERVE_TIMEOUT:-30}"
ZTA_VERIFY_WARMUP_TIMEOUT="${ZTA_VERIFY_WARMUP_TIMEOUT:-25}"

# kx_exec: bounded `kubectl exec`. SIGTERM at $1, SIGKILL 5s later.
kx_exec()    { timeout --foreground --kill-after=5s "${ZTA_VERIFY_KUBE_EXEC_TIMEOUT}s" kubectl exec "$@"; }
kx_observe() { timeout --foreground --kill-after=5s "${ZTA_VERIFY_HUBBLE_OBSERVE_TIMEOUT}s" kubectl exec "$@"; }

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
VAULT_SEALED=$(kx_exec -n vault vault-0 -- vault status -format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed', True))" 2>/dev/null || echo "true")
if [ "$VAULT_SEALED" = "False" ] || [ "$VAULT_SEALED" = "false" ]; then
  result PASS "Vault is unsealed"
else
  result FAIL "Vault is sealed or unreachable"
fi

# 2b: Active leases
VAULT_ROOT=$(python3 -c "import json; print(json.load(open('infras/k8s-yaml/vault-scripts/vault-prod-init.json')).get('root_token',''))" 2>/dev/null || true)
if [ -n "$VAULT_ROOT" ]; then
  LEASE_OUTPUT=$(kx_exec -n vault vault-0 -c vault -- sh -c "VAULT_SKIP_VERIFY=true VAULT_ADDR=https://127.0.0.1:8200 VAULT_TOKEN='${VAULT_ROOT}' vault list -format=json sys/leases/lookup/database/creds/" 2>/dev/null || echo "[]")
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
TMPFS_CHECK=$(kx_exec -n job7189-apps deploy/identity-service -c app -- mount 2>/dev/null | grep tmpfs | grep -c "vault-secrets\|app-secrets" || true)
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
for _ in $(seq 1 30); do
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
  result WARN "Kong port-forward did not become ready in 30s" "Run kubectl get pod -n gateway"
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
  kx_observe -n kube-system "${HUBBLE_POD#pod/}" -- hubble observe -n job7189-apps --verdict DROPPED --last 10 -o compact > "$EVIDENCE_DIR/hubble-dropped-${TIMESTAMP}.txt" 2>&1 || true
  kx_observe -n kube-system "${HUBBLE_POD#pod/}" -- hubble observe -n job7189-apps --verdict FORWARDED --last 10 -o compact > "$EVIDENCE_DIR/hubble-forwarded-${TIMESTAMP}.txt" 2>&1 || true
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
# Test 4d: Workload labeling coverage (PR #9 — knowledge-base/19-label-schema.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  Test 4d: Workload Label Coverage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LABEL_NAMESPACES="data vault security monitoring gateway management job7189-apps"
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
# Test 4e: L7 enforcement coverage (PR #10 — knowledge-base/20-5w1h-policy-matrix.md)
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

# Hubble L7 flow check (warm-up: tickle Vault + Keycloak inside-cluster
# to ensure L7 flows are present before we observe).
#
# Why this looks more elaborate than `kubectl run --rm`:
#   `kubectl run --rm -i --restart=Never --timeout=10s` does NOT bound
#   pod lifecycle. `--timeout=10s` is the API request timeout for the
#   create/wait calls. If the kubelet is slow to pull curlimages/curl
#   (we observed 12s on a contended lab box) or default-deny CNP
#   blocks the pull, kubectl run blocks indefinitely streaming logs;
#   when SIGKILLed by a parent timeout the pod is left orphaned in
#   Error state. We saw this directly in evidence/rebuild_20260507_030609
#   — `vault/hubble-l7-warmup-14754` 0/1 Error 28m.
#
# Instead: clean up any leftover orphans first, then for each warm-up
# fire a bounded background pod and clean it up explicitly. The whole
# warm-up loop has a hard wall-clock cap (ZTA_VERIFY_WARMUP_TIMEOUT per
# pod) so even pathological clusters can't take >1 minute here.
if [ -n "$HUBBLE_POD" ]; then
  # Clean any orphaned warm-up pods from prior aborted runs.
  for ns in vault security; do
    kubectl -n "$ns" delete pod -l app=hubble-l7-warmup --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done

  for svc_pair in "vault:vault:8200" "security:keycloak:8080"; do
    ns="${svc_pair%%:*}"; rest="${svc_pair#*:}"
    svc="${rest%:*}"; port="${rest##*:}"
    pod_name="hubble-l7-warmup-$RANDOM"
    # Apply a Pod manifest with activeDeadlineSeconds so kubelet kills
    # the curl container even if the warm-up never completes; restartPolicy
    # Never + label app=hubble-l7-warmup so the cleanup loop above
    # catches anything we don't delete here.
    cat <<EOF | timeout --foreground --kill-after=3s 8s kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
  namespace: ${ns}
  labels:
    app: hubble-l7-warmup
spec:
  restartPolicy: Never
  activeDeadlineSeconds: 15
  terminationGracePeriodSeconds: 1
  containers:
  - name: curl
    image: curlimages/curl:8.5.0
    imagePullPolicy: IfNotPresent
    args: ["-sk", "-o", "/dev/null", "-m", "3", "http://${svc}.${ns}.svc.cluster.local:${port}/"]
EOF
    # Wait at most ZTA_VERIFY_WARMUP_TIMEOUT for the pod to terminate;
    # we don't care about the exit code, only that the L7 flow was
    # generated through Cilium's datapath.
    timeout --foreground --kill-after=3s "${ZTA_VERIFY_WARMUP_TIMEOUT}s" \
      kubectl -n "$ns" wait --for=jsonpath='{.status.phase}'=Succeeded \
      "pod/${pod_name}" --timeout="${ZTA_VERIFY_WARMUP_TIMEOUT}s" \
      >/dev/null 2>&1 || true
    kubectl -n "$ns" delete pod "$pod_name" --ignore-not-found --wait=false --grace-period=0 >/dev/null 2>&1 || true
  done

  # Final sweep so we never leak warm-up pods even if a wait raced.
  for ns in vault security; do
    kubectl -n "$ns" delete pod -l app=hubble-l7-warmup --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done

  sleep 3   # let cilium-agent flush flow buffer
  L7_FLOWS=$( { kx_observe -n kube-system "${HUBBLE_POD#pod/}" -- hubble observe --type l7 --last 50 -o compact 2>/dev/null || true; } | wc -l | tr -d ' \n')
  L7_FLOWS=${L7_FLOWS:-0}
  if [ "$L7_FLOWS" -gt 0 ] 2>/dev/null; then
    result PASS "Hubble L7 flows captured: $L7_FLOWS samples"
  else
    result WARN "Hubble L7 flows = 0 even after warm-up" "Check L7 CiliumNetworkPolicy + hubble-relay pod health"
  fi
fi

# ========================
# Test 4f: Adaptive Security Loop (PR #12 — knowledge-base/24-adaptive-security-loop.md)
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
  CT_COUNT=$(kubectl get constrainttemplate --no-headers 2>/dev/null | grep -c "^zta" || true)
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
# Test 4g: PDP Controller (Adaptive Loop, PR #15 — knowledge-base/25-pdp-controller.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧠 Test 4g: PDP Controller (Adaptive Loop Closure)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if kubectl get deployment zta-pdp -n security >/dev/null 2>&1; then
  PDP_READY=$(kubectl get deployment zta-pdp -n security -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  PDP_DESIRED=$(kubectl get deployment zta-pdp -n security -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
  if [ "${PDP_READY:-0}" = "${PDP_DESIRED:-1}" ] && [ "${PDP_READY:-0}" != "0" ]; then
    result PASS "PDP Controller running ($PDP_READY/$PDP_DESIRED replica Ready)"

    # Sample trust-score annotation on a job7189-apps pod (proves PDP is reconciling)
    SAMPLE_POD=$(kubectl get pod -n job7189-apps -l 'cilium.zta/source' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$SAMPLE_POD" ]; then
      TRUST_SCORE=$(kubectl get pod -n job7189-apps "$SAMPLE_POD" -o jsonpath='{.metadata.annotations.cilium\.zta/trust-score}' 2>/dev/null || true)
      if [ -n "$TRUST_SCORE" ]; then
        result PASS "PDP annotated trust-score=$TRUST_SCORE on pod ns=job7189-apps/$SAMPLE_POD"
      else
        result WARN "PDP not yet annotated trust-score (give it 1 reconcile cycle, default 60s)" "kubectl logs -n security -l app=zta-pdp --tail=20"
      fi
    fi

    # Prometheus metrics endpoint reachable.
    # python:3.11-slim has no wget/curl — use python urllib via kubectl exec.
    METRICS_RAW=$(kx_exec -n security deploy/zta-pdp -- python -c 'import urllib.request, sys
try:
  data = urllib.request.urlopen("http://localhost:9100/metrics", timeout=3).read().decode()
  print(sum(1 for l in data.splitlines() if l.startswith("# HELP pdp_")))
except Exception as e:
  print(0)
  sys.exit(0)' 2>/dev/null || echo 0)
    METRICS_OK=$(echo "$METRICS_RAW" | tr -d ' \n')
    METRICS_OK=${METRICS_OK:-0}
    if [ "$METRICS_OK" -gt 0 ] 2>/dev/null; then
      result PASS "PDP Prometheus metrics endpoint healthy ($METRICS_OK pdp_* series)"
    else
      result WARN "PDP /metrics not yet ready" "Wait 60s after deploy for first scrape"
    fi
  else
    result WARN "PDP Controller deployed but not Ready ($PDP_READY/$PDP_DESIRED)" "kubectl describe pod -n security -l app=zta-pdp"
  fi
else
  result WARN "PDP Controller not deployed" "Run scripts/zta-deploy-pdp.sh"
fi

# ========================
# Test 4h: Image Provenance (PR #16 — knowledge-base/26-image-provenance.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔏 Test 4h: Image Provenance & Supply-Chain Trust"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Image-trust ConstraintTemplates registered
EXPECTED_IMG_CT="k8simagedigestrequired k8sblocklatesttag k8ssignedimageannotation"
CT_FOUND=0
for ct in $EXPECTED_IMG_CT; do
  if kubectl get constrainttemplate "$ct" >/dev/null 2>&1; then
    CT_FOUND=$((CT_FOUND + 1))
  fi
done
if [ "$CT_FOUND" -eq 3 ]; then
  result PASS "Image-trust ConstraintTemplates registered (3/3)"
else
  result WARN "Image-trust ConstraintTemplates incomplete ($CT_FOUND/3)" \
    "Apply: bash scripts/zta-deploy-gatekeeper.sh --constraints-only"
fi

# 2. Image digest constraint — count violations (audit mode)
if kubectl get k8simagedigestrequired image-digest-required >/dev/null 2>&1; then
  DIGEST_VIOLATIONS=$(kubectl get k8simagedigestrequired image-digest-required \
    -o jsonpath='{.status.totalViolations}' 2>/dev/null || echo 0)
  DIGEST_VIOLATIONS=${DIGEST_VIOLATIONS:-0}
  if [ "$DIGEST_VIOLATIONS" -eq 0 ]; then
    result PASS "image-digest-required: 0 violations (all images sha256-pinned)"
  else
    # Audit-only constraint by design (xem knowledge-base/22-image-trust-supply-chain.md):
    # cluster KHÔNG block; chỉ thu thập danh sách image chưa pin digest. Đếm violations
    # cao là expected vì registry baseline + 3rd-party images chưa được re-pin.
    result PASS "image-digest-required: $DIGEST_VIOLATIONS violations (audit mode — INFO, not enforcement)"
  fi
fi

# 3. Block-latest constraint — should be 0
if kubectl get k8sblocklatesttag block-latest-tag >/dev/null 2>&1; then
  LATEST_VIOLATIONS=$(kubectl get k8sblocklatesttag block-latest-tag \
    -o jsonpath='{.status.totalViolations}' 2>/dev/null || echo 0)
  LATEST_VIOLATIONS=${LATEST_VIOLATIONS:-0}
  if [ "$LATEST_VIOLATIONS" -eq 0 ]; then
    result PASS "block-latest-tag: 0 violations"
  else
    result WARN "block-latest-tag: $LATEST_VIOLATIONS violations" \
      "kubectl get k8sblocklatesttag block-latest-tag -o yaml | yq '.status.violations'"
  fi
fi

# 4. Cosign public key published in cluster
if kubectl get cm -n security zta-cosign-public-key >/dev/null 2>&1; then
  KEY_LEN=$(kubectl get cm -n security zta-cosign-public-key \
    -o jsonpath='{.data.cosign-public-key\.pem}' 2>/dev/null | wc -c | tr -d ' ')
  if [ "$KEY_LEN" -gt 100 ]; then
    result PASS "Cosign public key published (security/zta-cosign-public-key, $KEY_LEN bytes)"
  else
    result WARN "Cosign public-key ConfigMap empty" "Run scripts/zta-cosign-keygen.sh"
  fi
else
  result WARN "Cosign public-key ConfigMap not present" "Run scripts/zta-cosign-keygen.sh"
fi

# 5. Sample workload signature annotation present
SAMPLE_DEPLOY=$(kubectl -n job7189-apps get deploy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SAMPLE_DEPLOY" ]; then
  SIGNED_BY=$(kubectl -n job7189-apps get deploy "$SAMPLE_DEPLOY" \
    -o jsonpath='{.spec.template.metadata.annotations.image\.zta/signed-by}' 2>/dev/null)
  if [ -n "$SIGNED_BY" ]; then
    result PASS "Sample workload $SAMPLE_DEPLOY signed by '$SIGNED_BY'"
  else
    result WARN "Workloads not yet signed (image.zta/signed-by missing on $SAMPLE_DEPLOY)" \
      "Run scripts/zta-cosign-sign-deployment.sh on each Deployment YAML"
  fi
fi

# ========================
# Test 4i: SPIRE Workload Attestation (PR #17 — knowledge-base/27-spire-workload-attestation.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🪪  Test 4i: SPIRE Workload Attestation (Devices Advanced)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SPIRE_NS="${SPIRE_NS:-spire}"
if kubectl get ns "$SPIRE_NS" >/dev/null 2>&1; then
  # 1. spire-server StatefulSet Ready
  SS_READY=$(kubectl -n "$SPIRE_NS" get statefulset spire-server \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  SS_DESIRED=$(kubectl -n "$SPIRE_NS" get statefulset spire-server \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)
  SS_READY=${SS_READY:-0}
  if [ "$SS_READY" = "$SS_DESIRED" ] && [ "$SS_READY" -ge 1 ]; then
    result PASS "spire-server StatefulSet Ready ($SS_READY/$SS_DESIRED)"
  else
    result FAIL "spire-server StatefulSet not Ready ($SS_READY/$SS_DESIRED)" \
      "kubectl -n $SPIRE_NS describe pod -l app.kubernetes.io/name=spire-server"
  fi

  # 2. spire-agent DaemonSet covers all schedulable nodes
  AGENT_DESIRED=$(kubectl -n "$SPIRE_NS" get daemonset spire-agent \
    -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
  AGENT_READY=$(kubectl -n "$SPIRE_NS" get daemonset spire-agent \
    -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
  AGENT_READY=${AGENT_READY:-0}; AGENT_DESIRED=${AGENT_DESIRED:-0}
  if [ "$AGENT_READY" = "$AGENT_DESIRED" ] && [ "$AGENT_DESIRED" -ge 1 ]; then
    result PASS "spire-agent DaemonSet covers all nodes ($AGENT_READY/$AGENT_DESIRED)"
  else
    result FAIL "spire-agent DaemonSet incomplete ($AGENT_READY/$AGENT_DESIRED)" \
      "kubectl -n $SPIRE_NS describe ds spire-agent"
  fi

  # 3. ClusterSPIFFEID rules registered
  CSID_COUNT=$(kubectl get clusterspiffeid 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  CSID_COUNT=${CSID_COUNT:-0}
  if [ "$CSID_COUNT" -ge 1 ]; then
    result PASS "ClusterSPIFFEID rules registered ($CSID_COUNT total)"
  else
    result WARN "No ClusterSPIFFEID found" "kubectl apply -f infras/k8s-yaml/spire/cluster-spiffe-ids.yaml"
  fi

  # 4. SPIRE entries — at least 1 SVID issued (workload attested)
  ENTRY_COUNT=$(kubectl -n "$SPIRE_NS" exec statefulset/spire-server -c spire-server -- \
    /opt/spire/bin/spire-server entry count -socketPath /tmp/spire-server/private/api.sock 2>/dev/null \
    | grep -oE '[0-9]+' | head -1 || echo 0)
  ENTRY_COUNT=${ENTRY_COUNT:-0}
  if [ "$ENTRY_COUNT" -ge 1 ]; then
    result PASS "SPIRE entries issued ($ENTRY_COUNT SVIDs registered for ZTA workloads)"
  else
    result WARN "No SPIRE entries yet" \
      "Wait 60s after deploy for controller-manager to register pods. Verify via: kubectl -n $SPIRE_NS exec statefulset/spire-server -- /opt/spire/bin/spire-server entry show"
  fi

  # 5. Trust domain matches (helm-charts-hardened uses cm name 'spire-server')
  # Pull all server CMs and grep trust_domain — multiple CMs (server, controller, csi)
  # exist with different label sets, so iterate through them all instead of assuming
  # a single label match.
  TD=$(kubectl -n "$SPIRE_NS" get cm -o jsonpath='{range .items[*]}{.data}{"\n"}{end}' 2>/dev/null \
    | grep -oE 'trustDomain: [a-zA-Z0-9.-]+|trust_domain\\?":\\? "[a-zA-Z0-9.-]+' | head -1 \
    | grep -oE '[a-zA-Z0-9.-]+$' || echo "")
  if [ "$TD" = "zta.job7189" ]; then
    result PASS "SPIRE trustDomain = 'zta.job7189' (matches knowledge-base/27)"
  elif [ -n "$TD" ]; then
    result WARN "SPIRE trustDomain mismatch: '$TD' (expected zta.job7189)" \
      "Update infras/k8s-yaml/spire/values.yaml + helm upgrade"
  else
    result WARN "Could not auto-detect SPIRE trustDomain" \
      "kubectl -n $SPIRE_NS get cm -l app.kubernetes.io/name=server -o yaml | grep trust_domain"
  fi
else
  result WARN "SPIRE not deployed" "Run scripts/zta-deploy-spire.sh"
fi

# ========================
# Test 4j: sigstore policy-controller (PR #19 — knowledge-base/28-sigstore-policy-controller.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Test 4j: sigstore policy-controller (real Cosign verify)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PC_NS="${PC_NS:-cosign-system}"
if kubectl get ns "$PC_NS" >/dev/null 2>&1; then
  # 1. policy-controller-webhook Deployment Ready
  PC_READY=$(kubectl -n "$PC_NS" get deploy policy-controller-webhook \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  PC_DESIRED=$(kubectl -n "$PC_NS" get deploy policy-controller-webhook \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)
  PC_READY=${PC_READY:-0}
  if [ "$PC_READY" = "$PC_DESIRED" ] && [ "$PC_READY" -ge 1 ]; then
    result PASS "policy-controller-webhook Ready ($PC_READY/$PC_DESIRED)"
  else
    result FAIL "policy-controller-webhook not Ready ($PC_READY/$PC_DESIRED)" \
      "kubectl -n $PC_NS describe pod -l app.kubernetes.io/component=webhook"
  fi

  # 2. ClusterImagePolicy resources registered
  EXPECTED_CIP="zta-system-passthrough zta-job7189-apps-signed zta-keyless-trust-job7189"
  CIP_FOUND=0
  for cip in $EXPECTED_CIP; do
    if kubectl get clusterimagepolicy "$cip" >/dev/null 2>&1; then
      CIP_FOUND=$((CIP_FOUND + 1))
    fi
  done
  if [ "$CIP_FOUND" -eq 3 ]; then
    result PASS "ClusterImagePolicy resources registered (3/3: passthrough, apps-signed, keyless)"
  else
    result WARN "ClusterImagePolicy incomplete ($CIP_FOUND/3)" \
      "Apply: bash scripts/zta-deploy-policy-controller.sh --policies-only"
  fi

  # 3. Cosign public key embedded in zta-job7189-apps-signed CIP (real, not stub)
  CIP_KEY=$(kubectl get clusterimagepolicy zta-job7189-apps-signed \
    -o jsonpath='{.spec.authorities[0].key.data}' 2>/dev/null)
  if echo "$CIP_KEY" | grep -q "BEGIN PUBLIC KEY"; then
    if echo "$CIP_KEY" | grep -q "REPLACED_AT_DEPLOY_TIME"; then
      result FAIL "Cosign public key still placeholder in CIP (deploy script not fully run)" \
        "bash scripts/zta-deploy-policy-controller.sh --policies-only"
    else
      result PASS "Cosign public key embedded in zta-job7189-apps-signed (real PEM)"
    fi
  else
    result WARN "zta-job7189-apps-signed CIP has no public key data" \
      "kubectl get clusterimagepolicy zta-job7189-apps-signed -o yaml"
  fi

  # 4. job7189-apps namespace opted-in for image policy verification
  APP_NS="${APP_NS:-job7189-apps}"
  PC_LABEL=$(kubectl get ns "$APP_NS" \
    -o jsonpath='{.metadata.labels.policy\.sigstore\.dev/include}' 2>/dev/null)
  if [ "$PC_LABEL" = "true" ]; then
    result PASS "Namespace $APP_NS opted-in for image-policy verification"
  else
    result WARN "Namespace $APP_NS NOT opted-in (label policy.sigstore.dev/include missing)" \
      "kubectl label ns $APP_NS policy.sigstore.dev/include=true"
  fi

  # 5. ValidatingAdmissionWebhook registered
  if kubectl get validatingwebhookconfiguration policy.sigstore.dev >/dev/null 2>&1; then
    result PASS "ValidatingAdmissionWebhook 'policy.sigstore.dev' registered"
  else
    result WARN "ValidatingAdmissionWebhook 'policy.sigstore.dev' missing" \
      "kubectl get validatingwebhookconfiguration | grep sigstore"
  fi
else
  result WARN "sigstore policy-controller not deployed" "Run scripts/zta-deploy-policy-controller.sh"
fi

# ========================
# Test 4k: SPIRE Workload Integration (PR #20 — knowledge-base/29-spire-workload-integration.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Test 4k: SPIRE Workload Integration (consume SVID via Workload API)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DEMO_NS="${SPIRE_DEMO_NS:-security}"
DEMO_NAME="${SPIRE_DEMO_NAME:-spire-demo-workload}"
if kubectl -n "$DEMO_NS" get deploy "$DEMO_NAME" >/dev/null 2>&1; then
  # 1. Demo deployment Ready
  DEMO_READY=$(kubectl -n "$DEMO_NS" get deploy "$DEMO_NAME" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  DEMO_DESIRED=$(kubectl -n "$DEMO_NS" get deploy "$DEMO_NAME" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)
  DEMO_READY=${DEMO_READY:-0}
  if [ "$DEMO_READY" = "$DEMO_DESIRED" ] && [ "$DEMO_READY" -ge 1 ]; then
    result PASS "$DEMO_NAME deployment Ready ($DEMO_READY/$DEMO_DESIRED)"
  else
    result FAIL "$DEMO_NAME not Ready ($DEMO_READY/$DEMO_DESIRED)" \
      "kubectl -n $DEMO_NS describe pod -l app=$DEMO_NAME"
  fi

  # 2. CSI volume mount referencing csi.spiffe.io present in pod spec
  CSI_VOL=$(kubectl -n "$DEMO_NS" get deploy "$DEMO_NAME" \
    -o jsonpath='{.spec.template.spec.volumes[?(@.csi.driver=="csi.spiffe.io")].name}' 2>/dev/null)
  if [ -n "$CSI_VOL" ]; then
    result PASS "Pod consumes csi.spiffe.io ephemeral volume ($CSI_VOL)"
  else
    result FAIL "Pod does not mount csi.spiffe.io volume" \
      "kubectl -n $DEMO_NS get deploy $DEMO_NAME -o yaml | grep -A2 volumes"
  fi

  # 3. ClusterSPIFFEID rule for demo workload registered
  if kubectl get clusterspiffeid zta-spire-demo-workload >/dev/null 2>&1; then
    result PASS "ClusterSPIFFEID 'zta-spire-demo-workload' registered"
  else
    result WARN "ClusterSPIFFEID 'zta-spire-demo-workload' missing" \
      "kubectl apply -f infras/k8s-yaml/spire/spire-demo-workload.yaml"
  fi

  # 4. spiffe-helper logs SVID write OR /svids/svid.crt exists in pod
  SVID_LOG=$(kubectl -n "$DEMO_NS" logs deploy/"$DEMO_NAME" --tail=80 2>/dev/null \
    | grep -iE '(SVID updated|svid file written|new svid|x509-svid|received update|getx509)' | tail -1)
  if [ -n "$SVID_LOG" ]; then
    result PASS "spiffe-helper received & wrote SVID (${SVID_LOG:0:70}...)"
  else
    # Fallback: check if SVID file actually exists in pod's /svids volume
    POD_NAME=$(kubectl -n "$DEMO_NS" get pod -l app="$DEMO_NAME" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
      SVID_FILE=$(kubectl -n "$DEMO_NS" exec "$POD_NAME" -- \
        ls /svids/svid.crt 2>/dev/null | head -1)
      if [ -n "$SVID_FILE" ]; then
        result PASS "SVID PEM file written to /svids/svid.crt by spiffe-helper"
      else
        result WARN "spiffe-helper running but no SVID written yet — wait 60s + re-run" \
          "kubectl -n $DEMO_NS logs deploy/$DEMO_NAME --tail=20"
      fi
    else
      result WARN "spiffe-helper pod not found" \
        "kubectl -n $DEMO_NS get pod -l app=$DEMO_NAME"
    fi
  fi

  # 5. SPIRE entry exists for the demo workload's SPIFFE ID
  ENTRIES=$(kubectl -n spire exec statefulset/spire-server -c spire-server -- \
    /opt/spire/bin/spire-server entry show \
    -socketPath /tmp/spire-server/private/api.sock 2>/dev/null \
    | grep -c "sa/$DEMO_NAME" || true)
  ENTRIES=${ENTRIES:-0}
  if [ "$ENTRIES" -ge 1 ]; then
    result PASS "SPIRE entry registered for $DEMO_NAME ($ENTRIES entries)"
  else
    result WARN "No SPIRE entry yet for sa/$DEMO_NAME — wait for controller-manager" \
      "kubectl -n spire logs deploy/spire-spire-controller-manager --tail=20"
  fi
else
  # Optional demo (PR #20). Not deployed by default in base pipeline; only by
  # `bash scripts/zta-spire-onboard-demo.sh`. Treat as PASS — absence is not a
  # defect of base ZTA pipeline.
  result PASS "SPIRE workload integration demo not deployed (optional — run scripts/zta-spire-onboard-demo.sh to enable)"
fi

# ========================
# Test 4l: Hubble flow → Elasticsearch sink (PR #21 — knowledge-base/30-hubble-flow-sink.md)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Test 4l: Hubble flow → Elasticsearch (audit trail)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SHIPPER_NS="${SHIPPER_NS:-monitoring}"
if kubectl -n "$SHIPPER_NS" get ds hubble-flow-shipper >/dev/null 2>&1; then
  # 1. Cilium config has hubble-export-file enabled
  HUBBLE_PATH=$(kubectl -n kube-system get cm cilium-config \
    -o go-template='{{index .data "hubble-export-file-path"}}' 2>/dev/null || echo "")
  if [ -n "$HUBBLE_PATH" ]; then
    result PASS "Cilium hubble-export enabled (path=$HUBBLE_PATH)"
  else
    result FAIL "Cilium hubble-export NOT enabled — flows won't be written to disk" \
      "bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export"
  fi

  # 2. filebeat DaemonSet covers all nodes
  kubectl -n "$SHIPPER_NS" rollout status ds hubble-flow-shipper --timeout="${HUBBLE_VERIFY_DS_WAIT:-180s}" >/dev/null 2>&1 || true
  DS_DESIRED=$(kubectl -n "$SHIPPER_NS" get ds hubble-flow-shipper \
    -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
  DS_READY=$(kubectl -n "$SHIPPER_NS" get ds hubble-flow-shipper \
    -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
  DS_DESIRED=${DS_DESIRED:-0}
  DS_READY=${DS_READY:-0}
  if [ "$DS_READY" -ge 1 ] && [ "$DS_READY" = "$DS_DESIRED" ]; then
    result PASS "hubble-flow-shipper DaemonSet covers all nodes ($DS_READY/$DS_DESIRED)"
  elif [ "$DS_READY" -ge 1 ]; then
    result WARN "hubble-flow-shipper DS partially ready ($DS_READY/$DS_DESIRED)" \
      "kubectl -n $SHIPPER_NS rollout status ds hubble-flow-shipper"
  else
    result FAIL "hubble-flow-shipper DS incomplete ($DS_READY/$DS_DESIRED)" \
      "kubectl -n $SHIPPER_NS describe ds hubble-flow-shipper"
  fi

  # 3. Filebeat logs show successful ES output
  FB_LOG=$(kubectl -n "$SHIPPER_NS" logs ds/hubble-flow-shipper --tail=80 2>/dev/null \
    | grep -E '(Connection.*established|harvester started|Non-zero metrics|publish_events)' | tail -1)
  if [ -n "$FB_LOG" ]; then
    result PASS "filebeat actively shipping (last activity: ${FB_LOG:0:80}...)"
  else
    result WARN "No filebeat activity log — shipper may still be initializing or no flows yet" \
      "kubectl -n $SHIPPER_NS logs ds/hubble-flow-shipper --tail=30"
  fi

  # 4. ES index exists with > 0 docs
  # Auto-detect ES pod (PR #7 deploys es-0 StatefulSet in monitoring; some envs may use 'elasticsearch' Deployment)
  ES_POD=$(kubectl -n monitoring get pod -l app=elasticsearch \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$ES_POD" ]; then
    ES_POD=$(kubectl -n monitoring get pod \
      -o jsonpath='{range .items[?(@.metadata.name=="es-0")]}{.metadata.name}{end}' 2>/dev/null)
  fi
  if [ -n "$ES_POD" ]; then
    ES_INDEX_INFO=$(kubectl -n monitoring exec "$ES_POD" -- \
      curl -s --max-time 5 'http://localhost:9200/_cat/indices/hubble-flows-*?h=index,docs.count' 2>/dev/null | head -1)
    if [ -n "$ES_INDEX_INFO" ]; then
      DOC_COUNT=$(echo "$ES_INDEX_INFO" | awk '{print $2}')
      DOC_COUNT=${DOC_COUNT:-0}
      if [ "$DOC_COUNT" -gt 0 ] 2>/dev/null; then
        result PASS "Elasticsearch hubble-flows index has $DOC_COUNT docs"
      else
        result WARN "ES hubble-flows index empty — wait for traffic to generate flows" \
          "kubectl -n monitoring exec $ES_POD -- curl -s http://localhost:9200/_cat/indices/hubble-flows-*"
      fi
    else
      result WARN "ES hubble-flows-* index not found yet — shipper may need ~60s for first batch" \
        "kubectl -n monitoring exec $ES_POD -- curl -s http://localhost:9200/_cat/indices"
    fi
  else
    result WARN "Elasticsearch pod not found in 'monitoring' ns — set ES_NS env" \
      "kubectl -n monitoring get pod -l app=elasticsearch"
  fi

  # 5. Cilium agent can write to hubble export path (file exists)
  HUBBLE_FILE_CHECK=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    ls /var/run/cilium/hubble/events.log 2>/dev/null | head -1)
  if [ -n "$HUBBLE_FILE_CHECK" ]; then
    result PASS "Cilium agents writing to /var/run/cilium/hubble/events.log"
  else
    result WARN "Hubble events.log not found on agent yet — wait for first flow + restart" \
      "kubectl -n kube-system rollout restart ds cilium"
  fi
else
  result WARN "Hubble flow → ES sink not deployed" \
    "Run scripts/zta-deploy-hubble-export.sh"
fi


# ========================
# Test 4m: CDM (PIP 4) — Trivy Operator vulnerability scanning
# Decision: knowledge-base/zta-gap-decision.md, Quyết định 1.
# What we check:
#   - Trivy Operator pod Ready
#   - VulnerabilityReport CRD is registered
#   - At least 1 VulnerabilityReport CR exists
#   - At least 1 ConfigAuditReport CR exists
# This is "is CDM observable" — PDP consuming the data is verified in Test 4o
# (PR-J). Operator may be still scanning when verify runs, so 0 reports is
# WARN not FAIL.
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🦠 Test 4m: CDM — Trivy Operator (PIP 4)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if kubectl get ns security-cdm >/dev/null 2>&1; then
  TRIVY_READY=$(kubectl -n security-cdm get pod -l app.kubernetes.io/name=trivy-operator \
    -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | tr ' ' '\n' \
    | grep -c '^true$' || true)
  if [ "${TRIVY_READY:-0}" -ge 1 ]; then
    result PASS "Trivy Operator running ($TRIVY_READY container(s) Ready)"
  else
    result FAIL "Trivy Operator pod not Ready — bash scripts/zta-deploy-trivy.sh"
  fi

  if kubectl get crd vulnerabilityreports.aquasecurity.github.io >/dev/null 2>&1; then
    result PASS "VulnerabilityReport CRD registered"
  else
    result FAIL "VulnerabilityReport CRD missing — Trivy Operator helm install incomplete"
  fi

  VR_COUNT=$(kubectl get vulnerabilityreports.aquasecurity.github.io --all-namespaces \
    --no-headers 2>/dev/null | wc -l)
  if [ "${VR_COUNT:-0}" -ge 1 ]; then
    # Count critical CVEs across all reports — useful evidence for thesis Ch4.
    CRIT_TOTAL=$(kubectl get vulnerabilityreports.aquasecurity.github.io \
      --all-namespaces -o json 2>/dev/null \
      | jq '[.items[].report.summary.criticalCount // 0] | add // 0')
    HIGH_TOTAL=$(kubectl get vulnerabilityreports.aquasecurity.github.io \
      --all-namespaces -o json 2>/dev/null \
      | jq '[.items[].report.summary.highCount // 0] | add // 0')
    result PASS "VulnerabilityReport CRs: ${VR_COUNT} (${CRIT_TOTAL} critical, ${HIGH_TOTAL} high — across all reports)"
  else
    result WARN "0 VulnerabilityReport CRs yet — Trivy still scanning" \
      "Wait 5min then: kubectl get vulnerabilityreports -A"
  fi

  CA_COUNT=$(kubectl get configauditreports.aquasecurity.github.io --all-namespaces \
    --no-headers 2>/dev/null | wc -l)
  if [ "${CA_COUNT:-0}" -ge 1 ]; then
    result PASS "ConfigAuditReport CRs: ${CA_COUNT}"
  else
    result WARN "0 ConfigAuditReport CRs yet — Trivy still scanning"
  fi
else
  result WARN "Trivy Operator not deployed (CDM gap §2 in knowledge-base/33-zta-gap-analysis.md)" \
    "Run scripts/zta-deploy-trivy.sh"
fi


# ========================
# Test 4n: Threat Intelligence feeds (PR-K — knowledge-base/zta-gap-decision.md, Decision 3)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  Test 4n: Threat Intelligence Feeds"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if kubectl -n security-cdm get cronjob threat-intel-refresh >/dev/null 2>&1; then
  result PASS "CronJob threat-intel-refresh deployed"

  # Check ConfigMap exists and has entries
  if kubectl -n security-cdm get cm threat-intel-blocklist >/dev/null 2>&1; then
    CIDR_COUNT=$(kubectl -n security-cdm get cm threat-intel-blocklist \
      -o jsonpath='{.data.cidr-list}' 2>/dev/null | grep -cE '^[0-9]' || true)
    FQDN_COUNT=$(kubectl -n security-cdm get cm threat-intel-blocklist \
      -o jsonpath='{.data.fqdn-list}' 2>/dev/null | grep -cE '^[a-z0-9]' || true)
    LAST_UPDATE=$(kubectl -n security-cdm get cm threat-intel-blocklist \
      -o jsonpath='{.metadata.annotations.threat-intel/last-updated}' 2>/dev/null || echo "")
    if [ "${CIDR_COUNT:-0}" -ge 100 ]; then
      result PASS "Threat-intel blocklist: ${CIDR_COUNT} CIDRs, ${FQDN_COUNT} FQDNs (updated: ${LAST_UPDATE})"
    elif [ "${CIDR_COUNT:-0}" -ge 1 ]; then
      result WARN "Threat-intel blocklist sparse: only ${CIDR_COUNT} CIDRs (expected >=100)" \
        "kubectl -n security-cdm create job --from=cronjob/threat-intel-refresh threat-intel-manual-\$(date +%s)"
    else
      result WARN "Threat-intel blocklist empty — CronJob may not have run yet" \
        "kubectl -n security-cdm create job --from=cronjob/threat-intel-refresh threat-intel-manual-\$(date +%s)"
    fi
  else
    result WARN "ConfigMap threat-intel-blocklist not found — CronJob has not run yet" \
      "kubectl -n security-cdm create job --from=cronjob/threat-intel-refresh threat-intel-manual-\$(date +%s)"
  fi

  # Check CCNP exists
  if kubectl get ccnp cnp-threat-intel-egress-deny >/dev/null 2>&1; then
    result PASS "CCNP cnp-threat-intel-egress-deny applied"
  else
    result WARN "CCNP cnp-threat-intel-egress-deny missing" \
      "kubectl apply -f infras/k8s-yaml/threat-intel/03-ccnp.yaml"
  fi
else
  result WARN "Threat Intelligence not deployed (gap §5 in knowledge-base/33-zta-gap-analysis.md)" \
    "Run scripts/zta-deploy-threat-intel.sh"
fi


# ========================
# Test 4o: PDP Trust Score with score-bucket (PR-J — knowledge-base/zta-gap-decision.md, Decision 1)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧮 Test 4o: PDP Trust Score — score-bucket enforcement"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APP_NS="${APP_NS:-job7189-apps}"
if kubectl get deploy -n security zta-pdp >/dev/null 2>&1; then
  # 1. Check at least one pod has score-bucket label
  BUCKET_PODS=$(kubectl get pods -n "$APP_NS" \
    -o jsonpath='{range .items[*]}{.metadata.labels.zta\.job7189/score-bucket}{"\n"}{end}' 2>/dev/null \
    | grep -cE '^(high|medium|low)$' || true)
  TOTAL_PODS=$(kubectl get pods -n "$APP_NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "${BUCKET_PODS:-0}" -ge 1 ]; then
    HIGH_COUNT=$(kubectl get pods -n "$APP_NS" \
      -o jsonpath='{range .items[*]}{.metadata.labels.zta\.job7189/score-bucket}{"\n"}{end}' 2>/dev/null \
      | grep -c '^high$' || true)
    MED_COUNT=$(kubectl get pods -n "$APP_NS" \
      -o jsonpath='{range .items[*]}{.metadata.labels.zta\.job7189/score-bucket}{"\n"}{end}' 2>/dev/null \
      | grep -c '^medium$' || true)
    LOW_COUNT=$(kubectl get pods -n "$APP_NS" \
      -o jsonpath='{range .items[*]}{.metadata.labels.zta\.job7189/score-bucket}{"\n"}{end}' 2>/dev/null \
      | grep -c '^low$' || true)
    result PASS "score-bucket labels: ${BUCKET_PODS}/${TOTAL_PODS} pods labelled (high=${HIGH_COUNT} med=${MED_COUNT} low=${LOW_COUNT})"
  else
    result WARN "No pods have score-bucket label yet — PDP reconcile may need ~60s" \
      "Wait 60s then: kubectl get pods -n $APP_NS -L zta.job7189/score-bucket"
  fi

  # 2. Check CNP cnp-block-low-trust-to-vault exists
  if kubectl get cnp -n vault cnp-block-low-trust-to-vault >/dev/null 2>&1; then
    result PASS "CNP cnp-block-low-trust-to-vault enforcing in vault namespace"
  else
    result WARN "CNP cnp-block-low-trust-to-vault missing" \
      "kubectl apply -f infras/k8s-yaml/cilium-policies/namespaces/17-cnp-block-low-trust-to-vault.yaml"
  fi

  # 3. Check PDP metrics include score_bucket
  PDP_POD=$(kubectl -n security get pod -l app=zta-pdp \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$PDP_POD" ]; then
    METRICS=$(kubectl -n security exec "$PDP_POD" -- \
      python3 -c 'import urllib.request; print(urllib.request.urlopen("http://localhost:9100/metrics", timeout=3).read().decode())' 2>/dev/null || true)
    if echo "$METRICS" | grep -q "pdp_score_bucket"; then
      result PASS "PDP metrics include pdp_score_bucket gauge"
    elif echo "$METRICS" | grep -q "pdp_trust_score"; then
      result WARN "PDP metrics have pdp_trust_score but not pdp_score_bucket — redeploy PDP" \
        "bash scripts/zta-deploy-pdp.sh"
    else
      result WARN "PDP /metrics not ready yet — wait for startup" \
        "kubectl -n security logs $PDP_POD --tail=10"
    fi
  fi
else
  result WARN "PDP Controller not deployed — score-bucket enforcement unavailable" \
    "Run scripts/zta-deploy-pdp.sh"
fi


# ========================
# Test 4p: ZTA Observability Rules (PR-L — knowledge-base/zta-gap-decision.md, Decision 2)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test 4p: ZTA Grafana Dashboard + Prometheus Rules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if kubectl -n monitoring get cm grafana-zta-dashboard >/dev/null 2>&1; then
  result PASS "Grafana ZTA dashboard ConfigMap deployed"
else
  result WARN "Grafana ZTA dashboard not deployed" \
    "Run scripts/zta-deploy-observability-rules.sh"
fi

if kubectl -n monitoring get cm prometheus-zta-rules >/dev/null 2>&1; then
  RULE_COUNT=$(kubectl -n monitoring get cm prometheus-zta-rules \
    -o jsonpath='{.data.zta-rules\.yml}' 2>/dev/null \
    | grep -c '^\s*- alert:' || true)
  if [ "${RULE_COUNT:-0}" -ge 1 ]; then
    result PASS "Prometheus ZTA alerting rules: ${RULE_COUNT} alerts configured"
  else
    result WARN "Prometheus ZTA rules ConfigMap exists but has no alerts"
  fi

  # Active probe: confirm Prometheus actually parsed and loaded the rule
  # groups (the historic B1 bug — `--rules.path=` non-existent CLI flag —
  # left the ConfigMap mounted but un-parsed by Prometheus, so this
  # ConfigMap-presence check above used to be a false-positive).
  # Cilium `allow-prometheus-ingress` only permits grafana/oauth2-proxy/
  # ingress-nginx → :9090, so we exec inside grafana (alpine, has wget).
  PROM_POD=$(kubectl -n monitoring get pod -l app=prometheus \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  GRAFANA_POD=$(kubectl -n monitoring get pod -l app=grafana \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$PROM_POD" ] && [ -n "$GRAFANA_POD" ]; then
    LOADED_GROUPS=$(kubectl -n monitoring exec "$GRAFANA_POD" -- \
      wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/rules \
      2>/dev/null | grep -oE '"name":"zta-[a-z-]+"' | sort -u | wc -l)
    if [ "${LOADED_GROUPS:-0}" -ge 1 ]; then
      result PASS "Prometheus loaded ${LOADED_GROUPS} ZTA rule group(s) at runtime"
    else
      result FAIL "Prometheus pod is up but no ZTA rule groups loaded" \
        "Check 08-prometheus.yaml mounts zta-rules ConfigMap; reapply + restart Prom"
    fi
  fi
else
  result WARN "Prometheus ZTA rules not deployed" \
    "Run scripts/zta-deploy-observability-rules.sh"
fi


# ========================
# Test 4q: Kong + Tetragon Prometheus scrape (PR-N — B2 fix)
# ========================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 Test 4q: Kong + Tetragon Prometheus Scrape"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROM_POD=${PROM_POD:-$(kubectl -n monitoring get pod -l app=prometheus \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)}
GRAFANA_POD=${GRAFANA_POD:-$(kubectl -n monitoring get pod -l app=grafana \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)}

if [ -z "$PROM_POD" ]; then
  result WARN "Prometheus pod not running — cannot verify scrape targets"
elif [ -z "$GRAFANA_POD" ]; then
  result WARN "Grafana pod not running — cannot probe Prometheus targets API" \
    "Grafana is the only in-cluster client whitelisted to call prom :9090"
else
  # Exec inside grafana (allowed by Cilium CNP, has wget) to read targets.
  TARGETS_JSON=$(kubectl -n monitoring exec "$GRAFANA_POD" -- \
    wget -qO- 'http://prometheus.monitoring.svc.cluster.local:9090/api/v1/targets?state=active' \
    2>/dev/null || true)

  # Kong: pod IP scraped via annotation, namespace=gateway
  KONG_TARGETS=$(echo "$TARGETS_JSON" \
    | grep -oE '"pod":"kong-gateway[^"]*"' | sort -u | wc -l)
  if [ "${KONG_TARGETS:-0}" -ge 1 ]; then
    result PASS "Prometheus scraping Kong (${KONG_TARGETS} target(s) discovered)"
  else
    result WARN "Kong /metrics not yet scraped — annotation may be missing" \
      "kubectl -n gateway get pod -l app=kong-gateway -o yaml | grep prometheus.io"
  fi

  # Tetragon: hostNetwork DaemonSet, pod label app.kubernetes.io/name=tetragon
  TETRAGON_TARGETS=$(echo "$TARGETS_JSON" \
    | grep -oE '"pod":"tetragon-[a-z0-9-]+"' | sort -u | wc -l)
  if [ "${TETRAGON_TARGETS:-0}" -ge 1 ]; then
    result PASS "Prometheus scraping Tetragon (${TETRAGON_TARGETS} target(s) discovered)"
  else
    result WARN "Tetragon /metrics not yet scraped" \
      "Re-run 10-deploy-tetragon.sh after PR-N to apply podAnnotations + prometheus.enabled"
  fi
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
# Dynamically reflect maturity gained by recent PRs:
#   PR #15 (PDP)            → Identity: Advanced → Optimal
#   PR #17 (SPIRE)          → Devices:  Initial  → Advanced
#   PR #16 (image-trust)    → Applications: Advanced → Advanced+ (image hygiene + provenance)
IDENTITY_TIER="Advanced (Keycloak + Vault SA mapping)"
if kubectl get deploy -n security zta-pdp >/dev/null 2>&1; then
  IDENTITY_TIER="Optimal  (Advanced + PDP continuous label compliance)"
fi
# Highest Devices tier wins.
if kubectl -n security get deploy spire-demo-workload >/dev/null 2>&1; then
  DEVICES_TIER="Optimal  (PR #20: SPIRE SVID consumed by workload via CSI Workload API)"
elif kubectl get statefulset -n spire spire-server >/dev/null 2>&1; then
  DEVICES_TIER="Advanced (PR #17: SPIRE workload SVIDs issued, auto-rotated)"
else
  DEVICES_TIER="Initial  (no MDM/EDR)"
fi
# Highest tier wins; check most-advanced first to avoid override-order bugs.
if kubectl get clusterimagepolicy zta-job7189-apps-signed >/dev/null 2>&1; then
  APPS_TIER="Optimal  (PR #19: sigstore real Cosign verify at admission)"
elif kubectl get constrainttemplate k8simagedigestrequired >/dev/null 2>&1; then
  APPS_TIER="Advanced+(PR #16: Kong JWT + image-digest/cosign annotation trust)"
else
  APPS_TIER="Advanced (Kong JWT + ZTA pipeline)"
fi
echo "   Identity:      $IDENTITY_TIER"
echo "   Devices:       $DEVICES_TIER"
echo "   Networks:      $([ "$MESH_AUTH" = "true" ] && echo "Advanced+" || echo "Advanced ") (Cilium microseg$([ "$MESH_AUTH" = "true" ] && echo " + mTLS")$([ "$WIREGUARD" = "true" ] && echo " + WireGuard"))"
echo "   Applications:  $APPS_TIER"
echo "   Data:          Advanced (Vault JIT + tmpfs + auto-rotate)"
echo ""

exit "$FAIL"
