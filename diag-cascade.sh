#!/usr/bin/env bash
# diag-cascade.sh — diagnose the leader-election cascade you've been seeing
# Usage:
#   bash diag-cascade.sh                  # writes to ./diag-<timestamp>/
#   OUT=/tmp/diag bash diag-cascade.sh    # custom output dir
#
# Safe to run multiple times. Read-only against the cluster.
# Uploads nothing; everything stays local. Tar the dir at the end if you want
# to share it.

set -u
shopt -s nullglob

TS="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-./diag-${TS}}"
mkdir -p "${OUT}"
LOG_DIR="${OUT}/logs"
mkdir -p "${LOG_DIR}"

# Pods we care about most (the chain that was crashing in your last snapshot)
SUSPECTS=(
  "kube-system/kube-controller-manager-job7189-control-plane"
  "kube-system/kube-scheduler-job7189-control-plane"
  "kube-system/cilium-operator"
  "spire/spire-server-0"
  "security/keycloak"
  "security/oauth2-proxy"
  "vault/vault-0"
  "vault/vault-agent-agent-injector"
  "cosign-system/policy-controller-webhook"
  "cert-manager/cert-manager"
  "cert-manager/cert-manager-webhook"
)

note() { printf "\n=== %s ===\n" "$*"; }
run()  { printf '\n$ %s\n' "$*"; eval "$@" 2>&1 || true; }

###############################################################################
# 0. Versions + node capacity
###############################################################################
{
  note "kubectl + cluster versions"
  run kubectl version
  run kubectl get nodes -o wide
  run "kubectl describe nodes | sed -n '/Capacity:/,/System Info:/p'"
  note "Node-level Allocated resources (gives 'Requests vs Capacity')"
  run "kubectl describe nodes | sed -n '/Allocated resources/,/Events/p'"
} > "${OUT}/00-cluster.txt"

###############################################################################
# 1. Pod inventory + restart counts (sorted)
###############################################################################
{
  note "All pods, sorted by restart count desc"
  kubectl get pods -A --no-headers \
    -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.containerStatuses[*].ready,RESTART:.status.containerStatuses[*].restartCount,STATUS:.status.phase,REASON:.status.containerStatuses[*].lastState.terminated.reason,EXITCODE:.status.containerStatuses[*].lastState.terminated.exitCode,AGE:.metadata.creationTimestamp' \
    | awk '{
        # naive: sum the comma-separated restart counts
        n=split($4, a, ","); s=0; for(i=1;i<=n;i++) s+=a[i]; $4=s; print $0
      }' | sort -k4 -n -r | head -60
} > "${OUT}/01-pods-by-restarts.txt"

###############################################################################
# 2. Cluster events (warnings only), most recent first
###############################################################################
{
  note "Recent Warning events (whole cluster, last hour)"
  run "kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -100"
  note "All events sorted by time (last 60)"
  run "kubectl get events -A --sort-by=.lastTimestamp | tail -60"
  note "OOMKilling events specifically"
  run "kubectl get events -A --field-selector reason=OOMKilling --sort-by=.lastTimestamp"
  run "kubectl get events -A --field-selector reason=Killing --sort-by=.lastTimestamp | tail -40"
} > "${OUT}/02-events.txt"

###############################################################################
# 3. Leader-election leases (the smoking gun)
###############################################################################
{
  note "All leases — holder + renewTime + leaseDurationSeconds"
  run "kubectl get leases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,HOLDER:.spec.holderIdentity,RENEW:.spec.renewTime,DURATION:.spec.leaseDurationSeconds,TRANSITIONS:.spec.leaseTransitions'"
  note "Leader-election relevant leases (kube-cm, scheduler, cilium-operator, spire-controller-manager)"
  for ns_lease in \
    "kube-system kube-controller-manager" \
    "kube-system kube-scheduler" \
    "kube-system cilium-operator-resource-lock" \
    "spire spire-controller-manager" ; do
    set -- $ns_lease
    note "lease ${1}/${2}"
    run "kubectl -n ${1} get lease ${2} -o yaml"
  done
  note "Lease transition rate (high = thrashing)"
  run "kubectl get leases -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}\t{.spec.leaseTransitions}{\"\n\"}{end}' | sort -k2 -n -r | head -20"
} > "${OUT}/03-leases.txt"

###############################################################################
# 4. Resource pressure (only if metrics-server is up)
###############################################################################
{
  note "Top nodes (CPU/RAM)"
  run "kubectl top nodes"
  note "Top pods across all namespaces, by CPU"
  run "kubectl top pods -A --sort-by=cpu | head -30"
  note "Top pods by memory"
  run "kubectl top pods -A --sort-by=memory | head -30"
} > "${OUT}/04-resource-pressure.txt"

###############################################################################
# 5. API-server / etcd health probes
###############################################################################
{
  note "etcd health endpoint"
  run "kubectl get --raw='/readyz?verbose'"
  run "kubectl get --raw='/livez?verbose'"
  note "API request duration p99 (top 20 verbs)"
  run "kubectl get --raw='/metrics' | grep -E 'apiserver_request_duration_seconds_bucket{.*le=\"1\"}|apiserver_request_duration_seconds_bucket{.*le=\"5\"}' | head -40"
  note "etcd request slowness — server side"
  run "kubectl -n kube-system logs etcd-job7189-control-plane --tail=200 | grep -Ei 'slow|took|timeout' | tail -50"
} > "${OUT}/05-apiserver-etcd.txt"

###############################################################################
# 6. Suspect pods — describe + current logs + previous logs
###############################################################################
note_suspects() {
  local NS_PREFIX="$1"
  # NS_PREFIX is "ns/name-prefix" — we resolve the full pod name
  local NS="${NS_PREFIX%%/*}"
  local PRE="${NS_PREFIX##*/}"
  kubectl -n "${NS}" get pods --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null \
    | grep -F "${PRE}" | head -3
}

for s in "${SUSPECTS[@]}"; do
  ns="${s%%/*}"
  for pod in $(note_suspects "${s}"); do
    safe="$(echo "${ns}-${pod}" | tr '/' '_')"
    {
      note "describe ${ns}/${pod}"
      run "kubectl -n ${ns} describe pod ${pod}"
    } > "${LOG_DIR}/${safe}-describe.txt"

    # logs for each container, current + previous
    containers=$(kubectl -n "${ns}" get pod "${pod}" \
      -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
    for c in ${containers}; do
      kubectl -n "${ns}" logs "${pod}" -c "${c}" --tail=200 \
        > "${LOG_DIR}/${safe}-${c}-current.log" 2>&1 || true
      kubectl -n "${ns}" logs "${pod}" -c "${c}" --previous --tail=200 \
        > "${LOG_DIR}/${safe}-${c}-previous.log" 2>&1 || true
    done
  done
done

###############################################################################
# 7. Quick analyzer pass
###############################################################################
{
  note "ANALYZER — concentrated lease loss / probe failure / OOM"
  echo
  echo "[a] Pods with lastState.terminated.reason ≠ empty in last hour:"
  kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.containerStatuses[*].lastState.terminated.reason}{"\t"}{.status.containerStatuses[*].lastState.terminated.exitCode}{"\n"}{end}' \
    | awk -F'\t' '$2 != "" && $2 != "<nil>" {print}'
  echo
  echo "[b] Containers killed by signal (OOMKilled / Error / DeadlineExceeded):"
  kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.status.containerStatuses[*].lastState.terminated.reason}{"\n"}{end}' \
    | grep -E 'OOMKilled|Error|DeadlineExceeded' | sort -u
  echo
  echo "[c] Probe-failure patterns in logs (timeout/leader/lease/refused):"
  for f in "${LOG_DIR}"/*.log; do
    [ -s "${f}" ] || continue
    hits=$(grep -Ec 'leader election lost|lost lease|context deadline|connection refused|probe failed|i/o timeout' "${f}")
    [ "${hits}" -gt 0 ] && printf '%4d  %s\n' "${hits}" "${f}"
  done | sort -k1 -n -r | head -20
  echo
  echo "[d] Common verdict heuristics:"
  if grep -q "OOMKilled" "${OUT}/02-events.txt" 2>/dev/null; then
    echo "  → OOMKilled present → memory limit too low or memory pressure on node."
  fi
  if grep -qiE 'context deadline|leader election lost|lost lease' "${LOG_DIR}"/*.log 2>/dev/null; then
    echo "  → leader-election cascade (apiserver/etcd lag); same pattern as previous incident."
  fi
  if grep -qi 'probe failed' "${OUT}/02-events.txt" 2>/dev/null; then
    echo "  → liveness/readiness probes timing out; either CPU starvation or slow init."
  fi
  if grep -qiE 'too many open files|cannot allocate memory|fork/exec' "${LOG_DIR}"/*.log 2>/dev/null; then
    echo "  → host kernel limits (ulimit, inotify, fs.file-max). Check kind node sysctls."
  fi
} > "${OUT}/06-analysis.txt"

###############################################################################
# 8. Tar it up for sharing
###############################################################################
TAR="${OUT}.tar.gz"
tar -czf "${TAR}" -C "$(dirname "${OUT}")" "$(basename "${OUT}")" 2>/dev/null \
  && echo "Bundle: ${TAR}"

cat <<EOF

============================================================
Done. Read these in order:
  ${OUT}/06-analysis.txt        ← start here
  ${OUT}/01-pods-by-restarts.txt
  ${OUT}/02-events.txt
  ${OUT}/03-leases.txt          ← look at TRANSITIONS column
  ${OUT}/04-resource-pressure.txt
  ${OUT}/05-apiserver-etcd.txt
  ${OUT}/logs/*-previous.log    ← logs from the moment they crashed

Ship me ${TAR} (or just 06-analysis.txt + the few previous.log files
that 06 highlights) and I'll point at the cause.
============================================================
EOF
