#!/bin/bash
# ==========================================
# Script 10: Deploy Tetragon Runtime Security
# ==========================================
# PURPOSE: Deploy Tetragon eBPF runtime enforcement (PEP Runtime layer)
#          and apply TracingPolicy to block suspicious syscalls in job7189-apps.
# RUN AFTER: Script 08 (Security Hardening)
# RESOURCE: ~256Mi per worker node (DaemonSet), total ~768Mi for 3 workers
# NOTE: By default this script does NOT schedule Tetragon on the control-plane
#       node — set TETRAGON_INCLUDE_CONTROL_PLANE=1 to override.
# ROLLBACK: helm uninstall tetragon -n kube-system
#
# Pre-flight strategy (RAM-first, not timeout-first):
#   - Per-node memory availability check: aborts if any target node lacks RAM
#   - Auto-runs scripts/free-ram-for-tetragon.sh if host avail RAM < 900Mi
#   - Sets Tetragon resource limit to 256Mi/pod — the agent's BPF maps and
#     event ringbuf grow with kprobe rate, and 192Mi was triggering periodic
#     OOM-kills + liveness-probe failures on busy nodes (php-fpm forking,
#     openresty workers).
#
# Idempotency:
#   By default this script does a CLEAN install: any existing Tetragon helm
#   release + CRDs are uninstalled before re-installing. Set
#   TETRAGON_FRESH_INSTALL=0 to attempt an in-place helm upgrade instead
#   (use only if previous install was healthy).
# ==========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"

# ==================== TUNABLES ====================
# Resource ceiling for Tetragon — 256Mi is the production-recommended floor
# from upstream docs. Lower values trigger gRPC livenessProbe failures on
# busy nodes (PHP-FPM, OpenResty) because the BPF event ringbuf backs up
# faster than the agent can drain it under cgroup memory pressure.
TETRAGON_MEM_REQ="${TETRAGON_MEM_REQ:-128Mi}"
TETRAGON_MEM_LIM="${TETRAGON_MEM_LIM:-256Mi}"
TETRAGON_CPU_REQ="${TETRAGON_CPU_REQ:-50m}"
TETRAGON_CPU_LIM="${TETRAGON_CPU_LIM:-300m}"
TETRAGON_OPERATOR_MEM_LIM="${TETRAGON_OPERATOR_MEM_LIM:-64Mi}"

# By default skip control-plane node — workloads run on workers, monitoring
# kube-system is not the priority. Set to 1 to also run on control-plane.
TETRAGON_INCLUDE_CONTROL_PLANE="${TETRAGON_INCLUDE_CONTROL_PLANE:-0}"

# By default uninstall existing tetragon + delete CRDs before re-installing.
# This avoids stuck CrashLoopBackOff state from previous broken policies and
# is safe because Tetragon is observation-only (deleting the agent doesn't
# break workloads). Set to 0 to attempt helm upgrade in-place.
TETRAGON_FRESH_INSTALL="${TETRAGON_FRESH_INSTALL:-1}"

# Per-node free memory required to schedule a Tetragon pod = limit + 25% buffer.
# (256Mi limit * 1.25 ≈ 320Mi). A node with less than this is rejected.
TETRAGON_PER_NODE_HEADROOM_MI="${TETRAGON_PER_NODE_HEADROOM_MI:-320}"

# Pin chart version for reproducibility.
TETRAGON_CHART_VERSION="${TETRAGON_CHART_VERSION:-1.2.0}"

# RAM target for pre-flight on the host. If host avail < target, free-ram
# script runs. 900Mi gives buffer for 3 × 256Mi (=768Mi) plus operator + churn.
TETRAGON_RAM_TARGET_MI="${TETRAGON_RAM_TARGET_MI:-900}"

# Restart-count threshold beyond which we automatically dump --previous logs
# of the tetragon container. Helps diagnose mid-life crashes (BPF map OOM,
# liveness probe failure) without the user having to look up commands.
TETRAGON_CRASH_DUMP_THRESHOLD="${TETRAGON_CRASH_DUMP_THRESHOLD:-2}"

# Timeouts kept at sensible defaults — not the variable that needs tuning.
HELM_TIMEOUT="${HELM_TIMEOUT:-300s}"
DS_ROLLOUT_TIMEOUT="${DS_ROLLOUT_TIMEOUT:-300s}"
CRD_WAIT_TIMEOUT="${CRD_WAIT_TIMEOUT:-90s}"
POLICY_APPLY_RETRIES="${POLICY_APPLY_RETRIES:-12}"
POLICY_APPLY_BACKOFF="${POLICY_APPLY_BACKOFF:-5}"

echo ""
echo "============================================================"
echo "🛡️ SCRIPT 10: TETRAGON RUNTIME SECURITY"
echo "============================================================"
echo ""

avail_mi() { free -m | awk '/^Mem:/ {print $7}'; }

# ========================
# Step 0: Clean up any existing/broken install
# ========================
# Tetragon is observation-only (eBPF tracepoints are kernel-side; uninstalling
# the userspace agent doesn't disrupt workloads). A clean reinstall is the
# fastest way to recover from a CrashLoopBackOff state, and idempotent.
cleanup_existing() {
  echo "━━━ Step 0: Clean-up existing Tetragon (FRESH_INSTALL=${TETRAGON_FRESH_INSTALL}) ━━━"
  if [ "$TETRAGON_FRESH_INSTALL" != "1" ]; then
    echo "   Skipped — will attempt in-place helm upgrade later."
    return 0
  fi

  if helm status tetragon -n kube-system >/dev/null 2>&1; then
    echo "   Found existing helm release — uninstalling..."
    helm uninstall tetragon -n kube-system --wait --timeout=60s 2>&1 | sed 's/^/      /' || true
  else
    echo "   No existing helm release — nothing to uninstall."
  fi

  # Delete any orphan tetragon pods (left over if previous helm uninstall failed)
  ORPHAN_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon -o name 2>/dev/null || true)
  if [ -n "$ORPHAN_PODS" ]; then
    echo "   Deleting orphan tetragon pods..."
    kubectl delete -n kube-system $ORPHAN_PODS --grace-period=10 --timeout=30s 2>&1 | sed 's/^/      /' || true
  fi

  # Delete CRDs so we don't carry over a partially-applied schema. Helm will
  # reinstall them. Any existing TracingPolicy / TracingPolicyNamespaced
  # objects are removed by the CRD deletion (cascading delete).
  for crd in tracingpolicies.cilium.io tracingpoliciesnamespaced.cilium.io \
             podinfo.cilium.io; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
      echo "   Deleting CRD ${crd}..."
      kubectl delete crd "$crd" --timeout=30s 2>&1 | sed 's/^/      /' || true
    fi
  done

  rm -rf "${HOME}/.kube/cache/discovery" 2>/dev/null || true
  echo "   ✓ Cleanup complete"
  echo ""
}
cleanup_existing

# ========================
# Step 1: RAM-first pre-flight
# ========================
echo "━━━ Step 1: Pre-flight (RAM-first) ━━━"
echo "   Available RAM: $(avail_mi)Mi (target ${TETRAGON_RAM_TARGET_MI}Mi)"

if [ "$(avail_mi)" -lt "$TETRAGON_RAM_TARGET_MI" ]; then
  FREE_SCRIPT="${SCRIPT_DIR}/scripts/free-ram-for-tetragon.sh"
  if [ -x "$FREE_SCRIPT" ]; then
    echo "   Below target → running free-ram-for-tetragon.sh"
    FREE_RAM_TARGET_MI="$TETRAGON_RAM_TARGET_MI" "$FREE_SCRIPT" || true
  else
    echo "   ⚠ free-ram-for-tetragon.sh not executable — skipping auto-cleanup"
    echo "     Suggest: bash scripts/toggle-internal-ui.sh off"
    read -p "   Continue with current RAM? [y/N]: " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { echo "   Aborted."; exit 0; }
  fi
fi

# Cluster reachable?
if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
  echo "❌ Cluster API not reachable — aborting"
  exit 1
fi

# Determine target nodes (skip control-plane unless explicitly enabled)
if [ "$TETRAGON_INCLUDE_CONTROL_PLANE" = "1" ]; then
  TARGET_NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
  echo "   Target nodes: ALL (control-plane + workers)"
else
  TARGET_NODES=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')
  echo "   Target nodes: workers only (set TETRAGON_INCLUDE_CONTROL_PLANE=1 to also include CP)"
fi
NODE_COUNT=$(echo "$TARGET_NODES" | wc -w)
echo "   Will deploy ${NODE_COUNT} Tetragon pod(s)"
echo ""

# Per-node memory pre-check — abort if any target node has < headroom free.
# This is the test that prevents "DaemonSet stuck at 2/3 Ready forever".
echo "   Per-node memory headroom check (need ≥${TETRAGON_PER_NODE_HEADROOM_MI}Mi free):"
NODE_FAILED=0
for node in $TARGET_NODES; do
  # Allocatable memory in Mi
  ALLOC=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.memory}' 2>/dev/null)
  ALLOC_MI=$(python3 -c "
import re,sys
v='''$ALLOC'''
m=re.match(r'(\d+)([KMGTP]?i?)',v)
if not m: print(0); sys.exit()
n=int(m.group(1)); u=m.group(2)
fact={'Ki':1/1024,'Mi':1,'Gi':1024,'Ti':1024*1024}.get(u,1/1024/1024)
print(int(n*fact))
" 2>/dev/null || echo 0)
  # Sum of memory requests already scheduled on the node (in Mi).
  REQ_MI=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$node" \
    -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.resources.requests.memory}{"\n"}{end}{end}' 2>/dev/null \
    | python3 -c "
import re,sys
total=0
for line in sys.stdin:
    v=line.strip()
    if not v: continue
    m=re.match(r'(\d+)([KMGTP]?i?)?',v)
    if not m: continue
    n=int(m.group(1)); u=m.group(2) or 'Mi'
    fact={'Ki':1/1024,'Mi':1,'Gi':1024,'Ti':1024*1024,'':1/1024/1024}.get(u,1)
    total+=n*fact
print(int(total))
" 2>/dev/null || echo 0)
  FREE_MI=$((ALLOC_MI - REQ_MI))
  if [ "$FREE_MI" -lt "$TETRAGON_PER_NODE_HEADROOM_MI" ]; then
    printf "     ✗ %-40s alloc=%4dMi  used=%4dMi  free=%4dMi  (need ≥%dMi)\n" \
      "$node" "$ALLOC_MI" "$REQ_MI" "$FREE_MI" "$TETRAGON_PER_NODE_HEADROOM_MI"
    NODE_FAILED=$((NODE_FAILED + 1))
  else
    printf "     ✓ %-40s alloc=%4dMi  used=%4dMi  free=%4dMi\n" \
      "$node" "$ALLOC_MI" "$REQ_MI" "$FREE_MI"
  fi
done
echo ""

if [ "$NODE_FAILED" -gt 0 ]; then
  echo "❌ ${NODE_FAILED} node(s) lack ≥${TETRAGON_PER_NODE_HEADROOM_MI}Mi free for Tetragon."
  echo "   Without this, the DaemonSet will get stuck at $((NODE_COUNT - NODE_FAILED))/${NODE_COUNT} Ready forever."
  echo ""
  echo "   Options:"
  echo "     1) bash scripts/free-ram-for-tetragon.sh        (toggle UI off, scale vault-dev)"
  echo "     2) FREE_RAM_AGGRESSIVE=1 bash scripts/free-ram-for-tetragon.sh"
  echo "     3) Reduce some pod's memory request, e.g.:"
  echo "          kubectl -n monitoring patch ds filebeat ... requests.memory=64Mi"
  echo "     4) Override TETRAGON_PER_NODE_HEADROOM_MI=200 (risky — pod may OOM)"
  exit 1
fi

# ========================
# Step 2: Install Tetragon via Helm
# ========================
echo "━━━ Step 2: Installing Tetragon ━━━"

helm repo add cilium https://helm.cilium.io 2>/dev/null || true
wait_for_dns helm.cilium.io
helm_repo_update_retry cilium

HELM_SET_FLAGS=(
  --set "tetragon.resources.requests.memory=${TETRAGON_MEM_REQ}"
  --set "tetragon.resources.limits.memory=${TETRAGON_MEM_LIM}"
  --set "tetragon.resources.requests.cpu=${TETRAGON_CPU_REQ}"
  --set "tetragon.resources.limits.cpu=${TETRAGON_CPU_LIM}"
  --set "tetragonOperator.resources.requests.memory=32Mi"
  --set "tetragonOperator.resources.limits.memory=${TETRAGON_OPERATOR_MEM_LIM}"
  --set "export.stdout.enabled=true"
  --set "export.stdout.resources.requests.memory=16Mi"
  --set "export.stdout.resources.limits.memory=32Mi"
)

# By default keep Tetragon off the control-plane node — saves ~192Mi RAM
# and avoids racing the API server / etcd. Set TETRAGON_INCLUDE_CONTROL_PLANE=1
# to schedule on all nodes.
#
# IMPORTANT: chart values for tolerations/affinity are at TOP LEVEL
# (.Values.tolerations, .Values.affinity), NOT under .Values.tetragon.*.
# The chart's default `tolerations: [{operator: Exists}]` tolerates ALL taints
# including control-plane, so we must (a) override that list AND (b) add a
# nodeAffinity exclusion. Using --set-json for the array overrides cleanly.
if [ "$TETRAGON_INCLUDE_CONTROL_PLANE" != "1" ]; then
  HELM_SET_FLAGS+=(
    --set-json 'tolerations=[{"key":"kubernetes.io/os","operator":"Exists"}]'
    --set-json 'affinity={"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"node-role.kubernetes.io/control-plane","operator":"DoesNotExist"}]}]}}}'
  )
fi

if helm status tetragon -n kube-system >/dev/null 2>&1; then
  echo "   ℹ️  Tetragon already installed, upgrading..."
  helm upgrade tetragon cilium/tetragon -n kube-system \
    --version "$TETRAGON_CHART_VERSION" \
    "${HELM_SET_FLAGS[@]}" \
    --wait --timeout="$HELM_TIMEOUT"
else
  echo "   Installing Tetragon (chart ${TETRAGON_CHART_VERSION})..."
  helm install tetragon cilium/tetragon -n kube-system \
    --version "$TETRAGON_CHART_VERSION" \
    "${HELM_SET_FLAGS[@]}" \
    --wait --timeout="$HELM_TIMEOUT"
fi

# ========================
# Step 3: Wait for CRD Established
# ========================
# This is a CORRECTNESS fix, not a timeout one — Helm's --wait does not block
# until CustomResourceDefinitions reach Established=True, and kubectl caches
# API discovery for ~30s, so a TracingPolicy apply right after helm install
# can race with "no matches for kind".
echo ""
echo "━━━ Step 3: Waiting for TracingPolicy CRD (Established=True) ━━━"

CRDS_NEEDED=( tracingpolicies.cilium.io tracingpoliciesnamespaced.cilium.io )

for crd in "${CRDS_NEEDED[@]}"; do
  if ! kubectl wait --for=condition=Established "crd/${crd}" --timeout="${CRD_WAIT_TIMEOUT}" 2>/dev/null; then
    # Maybe CRD object itself does not exist yet (Helm just applied it)
    if ! kubectl get crd "${crd}" >/dev/null 2>&1; then
      echo "   ❌ CRD ${crd} not registered. Did helm install actually run?"
      exit 1
    fi
    echo "   ❌ CRD ${crd} not Established"
    kubectl describe "crd/${crd}" | tail -20
    exit 1
  fi
  echo "   ✓ ${crd} Established"
done

# Force kubectl to refresh its API discovery cache so the next apply sees the CRD.
rm -rf "${HOME}/.kube/cache/discovery" 2>/dev/null || true
kubectl api-resources --api-group=cilium.io >/dev/null 2>&1 || true

# ========================
# Step 4: Wait for at least one Tetragon pod to be Ready
# ========================
echo ""
echo "━━━ Step 4: Waiting for Tetragon DaemonSet ━━━"

if ! kubectl rollout status daemonset/tetragon -n kube-system --timeout="${DS_ROLLOUT_TIMEOUT}"; then
  echo "   ⚠ Full DaemonSet not Ready — likely a node lacks RAM. Listing state:"
  kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon -o wide || true
  kubectl describe ds tetragon -n kube-system | tail -40 || true
  echo "   Continuing if at least one node is Ready (single-node policies still work)"
fi

TETRAGON_DESIRED=$(kubectl get ds tetragon -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
TETRAGON_READY=$(kubectl get ds tetragon -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
echo "   Tetragon: ${TETRAGON_READY}/${TETRAGON_DESIRED} nodes Ready"

# Sanity: desiredNumberScheduled should match the pre-flight expected count.
if [ "$TETRAGON_DESIRED" != "$NODE_COUNT" ]; then
  echo "   ⚠ Expected ${NODE_COUNT} Tetragon pods but DaemonSet schedules ${TETRAGON_DESIRED}."
  echo "     Toleration/affinity override may not have applied — investigate before policies."
fi

if [ "$TETRAGON_READY" = "0" ]; then
  echo "   ❌ No Tetragon pod Ready — refusing to apply policies"
  echo "      Pre-flight passed memory checks, so the failure is likely:"
  echo "        - Image pull error: kubectl describe pods -n kube-system -l app.kubernetes.io/name=tetragon"
  echo "        - eBPF kernel feature missing: check kernel version (need ≥5.4)"
  echo "        - SELinux/AppArmor blocking: check pod events"
  exit 1
fi

# Crash diagnostic — if any tetragon container has restarted ≥ threshold,
# auto-dump --previous logs + last events. Pod restarting in a loop is the
# #1 reason for "policies applied but nothing fires" debugging sessions.
HIGH_RESTART_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.containerStatuses[?(@.name=="tetragon")]}{.restartCount}{"\n"}{end}{end}' 2>/dev/null \
  | awk -v th="$TETRAGON_CRASH_DUMP_THRESHOLD" '$2 >= th {print $1}' || true)

if [ -n "$HIGH_RESTART_PODS" ]; then
  echo ""
  echo "   ⚠ Detected pods with tetragon container restartCount ≥ ${TETRAGON_CRASH_DUMP_THRESHOLD}:"
  for pod in $HIGH_RESTART_PODS; do
    echo "   ── ${pod} ──"
    echo "      Last termination reason:"
    kubectl get pod -n kube-system "$pod" -o jsonpath='{range .status.containerStatuses[?(@.name=="tetragon")]}{.lastState.terminated.reason}{"  exitCode="}{.lastState.terminated.exitCode}{"\n"}{end}' 2>/dev/null \
      | sed 's/^/        /' || true
    echo "      Last 30 lines of previous tetragon container:"
    kubectl logs -n kube-system "$pod" -c tetragon --previous --tail=30 2>&1 | sed 's/^/        /' || true
  done
  echo ""
  echo "   Common causes:"
  echo "     - OOMKilled / exit code 137: bump TETRAGON_MEM_LIM (current ${TETRAGON_MEM_LIM})"
  echo "     - 'failed to load BPF': kernel too old or kprobe symbol missing"
  echo "     - 'context deadline' on liveness gRPC: agent overwhelmed, increase CPU limit"
  echo ""
fi

# ========================
# Step 5: Render TracingPolicies
# ========================
echo ""
echo "━━━ Step 5: Rendering TracingPolicies ━━━"

POLICY_DIR="${SCRIPT_DIR}/infras/k8s-yaml/tetragon-policies"
mkdir -p "$POLICY_DIR"

# Policies are tracked in git and may have been hand-edited. Only render
# defaults if the file is missing — never overwrite committed YAML.
# Schema notes:
#   - K8s namespace filtering uses TracingPolicyNamespaced (kind), NOT
#     matchNamespaces (which is for Linux kernel namespaces).
#   - matchArgs.operator: "Equal" + values list does OR-match. "In" is invalid.
if [ ! -f "${POLICY_DIR}/block-suspicious-exec.yaml" ]; then
  cat > "${POLICY_DIR}/block-suspicious-exec.yaml" <<'POLICY'
apiVersion: cilium.io/v1alpha1
kind: TracingPolicyNamespaced
metadata:
  name: block-suspicious-exec
  namespace: job7189-apps
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchArgs:
      - index: 0
        operator: "Equal"
        values:
        - "/bin/sh"
        - "/bin/bash"
        - "/usr/bin/curl"
        - "/usr/bin/wget"
        - "/usr/bin/nc"
        - "/usr/bin/ncat"
        - "/usr/bin/nmap"
      matchActions:
      - action: Sigkill
POLICY
fi

if [ ! -f "${POLICY_DIR}/monitor-sensitive-files.yaml" ]; then
  cat > "${POLICY_DIR}/monitor-sensitive-files.yaml" <<'POLICY'
apiVersion: cilium.io/v1alpha1
kind: TracingPolicyNamespaced
metadata:
  name: monitor-sensitive-files
  namespace: job7189-apps
spec:
  kprobes:
  - call: "sys_openat"
    syscall: true
    args:
    - index: 1
      type: "string"
    selectors:
    - matchArgs:
      - index: 1
        operator: "Prefix"
        values:
        - "/etc/shadow"
        - "/etc/passwd"
        - "/proc/self/environ"
        - "/var/run/secrets/kubernetes.io"
      matchActions:
      - action: Post
POLICY
fi

# ========================
# Step 6: Apply policies with retry on transient errors
# ========================
echo ""
echo "━━━ Step 6: Applying TracingPolicies ━━━"

apply_with_retry() {
  local file="$1"
  local name; name=$(basename "$file" .yaml)
  local attempt=1 err
  while [ "$attempt" -le "$POLICY_APPLY_RETRIES" ]; do
    if err=$(kubectl apply -f "$file" 2>&1); then
      echo "   ✅ ${name} applied (attempt ${attempt})"
      return 0
    fi
    if echo "$err" | grep -qE 'no matches for kind|the server could not find the requested resource|connection refused|context deadline'; then
      echo "   ... ${name} attempt ${attempt}/${POLICY_APPLY_RETRIES}: discovery cache stale, retrying"
      sleep "$POLICY_APPLY_BACKOFF"
      attempt=$((attempt + 1))
      continue
    fi
    echo "   ❌ ${name} non-transient error:"
    echo "$err" | sed 's/^/      /'
    return 1
  done
  echo "   ❌ ${name} failed after ${POLICY_APPLY_RETRIES} retries"
  return 1
}

POLICY_FAILED=0
POLICY_FILE_COUNT=0
shopt -s nullglob
for policy_file in "${POLICY_DIR}"/*.yaml; do
  POLICY_FILE_COUNT=$((POLICY_FILE_COUNT + 1))
  apply_with_retry "$policy_file" || POLICY_FAILED=$((POLICY_FAILED+1))
done
shopt -u nullglob

if [ "$POLICY_FILE_COUNT" -eq 0 ]; then
  echo "   ❌ No TracingPolicy YAML files found in ${POLICY_DIR}"
  exit 1
fi

# ========================
# Step 7: Verify
# ========================
echo ""
echo "━━━ Step 7: Verification ━━━"

POLICY_COUNT=$(kubectl get tracingpoliciesnamespaced -A --no-headers 2>/dev/null | wc -l || echo "0")
echo "   TracingPoliciesNamespaced: ${POLICY_COUNT}"
kubectl get tracingpoliciesnamespaced -A 2>/dev/null || true

if [ "$POLICY_FAILED" -gt 0 ]; then
  echo "❌ ${POLICY_FAILED} policy(ies) failed to apply"
  exit 1
fi

echo ""
echo "============================================================"
echo "✅ TETRAGON RUNTIME SECURITY DEPLOYED"
echo "============================================================"
echo "   DaemonSet: ${TETRAGON_READY}/${TETRAGON_DESIRED} nodes"
echo "   Policies:  ${POLICY_COUNT} TracingPolicy(ies)"
echo "   RAM avail: $(avail_mi)Mi"
echo ""
echo "   Test exec block:"
echo "     kubectl exec -n job7189-apps deploy/identity-service -c app -- /bin/sh"
echo ""
echo "   Stream events:"
echo "     kubectl logs -n kube-system ds/tetragon -c export-stdout --tail=20 -f"
echo ""
echo "   Restore Kibana/Grafana when done analysing:"
echo "     bash scripts/toggle-internal-ui.sh on"
echo ""
echo "   Rollback:"
echo "     helm uninstall tetragon -n kube-system"
echo "     kubectl delete -f ${POLICY_DIR}/"
echo ""
