#!/usr/bin/env bash
# doc/migration/scripts/04-cilium-install.sh
#
# Run from a host with `helm` + a working `kubectl` context (typically the
# admin laptop OR 7189srv01 itself after step 02). Idempotent.
#
# Steps:
#   1. Pre-flight: helm, kubectl, all 4 nodes registered, control-plane TS IP
#   2. Add cilium helm repo
#   3. Render cilium-values-multi-vm.yaml (referencing CP_TS_IP)
#   4. helm upgrade --install cilium ...
#   5. Wait for cilium DS to be 4/4 ready
#   6. Wait for nodes to become Ready
#   7. Label data-tier always-on node
#
# On error: ROLLBACK runs `helm uninstall cilium`, leaving the cluster
# without CNI (nodes back to NotReady, but no etcd/apiserver state was
# changed by helm). Re-run is safe.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

load_config "${SCRIPT_DIR}/config.env"
migration_start "04-cilium-install"

# ===== Pre-flight =====
log_step "Pre-flight: helm + kubectl + nodes"
require_cmd helm kubectl || exit 1

if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
  log_err "kubectl can't reach the cluster. Set KUBECONFIG and retry."
  exit 1
fi

# Resolve CP_TS_IP from kubeadm endpoint
CP_TS_IP="$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' | sed -E 's#https?://##; s#:.*##')"
if [ -z "${CP_TS_IP}" ]; then
  log_err "Couldn't infer control-plane Tailscale IP from kubeconfig"
  exit 1
fi
log_ok "Control-plane endpoint: ${CP_TS_IP}"

# Confirm all 4 nodes registered (NotReady is OK at this stage)
NODE_COUNT="$(kubectl get nodes --no-headers 2>/dev/null | wc -l)"
log_info "Nodes registered: ${NODE_COUNT}"
if [ "${NODE_COUNT}" -lt 1 ]; then
  log_err "No nodes registered — run 02-control-plane-init.sh + 03-worker-join.sh first"
  exit 1
fi
if [ "${NODE_COUNT}" -lt 4 ]; then
  log_warn "Only ${NODE_COUNT}/4 nodes registered. Cilium will install but you must finish workers."
fi

# ===== Step 1: helm repo =====
log_step "[1/5] helm repo add cilium"
step "Add helm repo" helm repo add cilium https://helm.cilium.io/ --force-update >/dev/null
step "Update helm repos" helm repo update cilium >/dev/null

# ===== Step 2: render values =====
log_step "[2/5] Render cilium values"
VALUES_FILE="${ZTA_STATE_DIR}/cilium-values-multi-vm.yaml"
cat > "${VALUES_FILE}" <<EOF
cluster:
  name: ${CLUSTER_NAME}
  id: 1

# Apiserver Tailscale endpoint — avoid chicken-and-egg with kubernetes.default
k8sServiceHost: "${CP_TS_IP}"
k8sServicePort: 6443

ipam:
  mode: kubernetes

routingMode: tunnel
tunnelProtocol: vxlan
tunnelPort: 8472

kubeProxyReplacement: "true"

# Tailscale already encrypts L3 — disable Cilium WireGuard to avoid double encrypt.
encryption:
  enabled: false
  type: ""

# mTLS (mesh-auth) is enabled later by 08-harden-security.sh
authentication:
  enabled: false
  mutual:
    spire:
      enabled: false

ipv4NativeRoutingCIDR: ""
autoDirectNodeRoutes: false

ipv6:
  enabled: false

bpf:
  masquerade: true
  hostLegacyRouting: false
  preallocateMaps: true
  policyMapMax: 16384
  ctMapMax: 524288
  natMapMax: 524288
  neighMapMax: 524288

hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
  metrics:
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - icmp
      - http

operator:
  replicas: 1
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  nodeSelector:
    kubernetes.io/hostname: ${CP_HOSTNAME}
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "256Mi"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1
    memory: 256Mi

agentHealthPort: 9879
EOF
log_ok "  ${VALUES_FILE} written"
register_rollback "rm -f ${VALUES_FILE}"

# ===== Step 3: helm install =====
log_step "[3/5] helm upgrade --install cilium"
register_rollback "helm uninstall cilium -n kube-system >/dev/null 2>&1 || true"

if [ "${ZTA_DRY_RUN}" = "1" ]; then
  log_dry "$ helm upgrade --install cilium cilium/cilium --version ${CILIUM_VERSION} -n kube-system -f ${VALUES_FILE} --wait --timeout 10m"
else
  helm upgrade --install cilium cilium/cilium \
    --version "${CILIUM_VERSION}" \
    --namespace kube-system \
    -f "${VALUES_FILE}" \
    --wait --timeout 10m
fi

# ===== Step 4: wait for DS ready =====
log_step "[4/5] Wait for cilium DS to be Ready"
if [ "${ZTA_DRY_RUN}" != "1" ]; then
  for i in $(seq 1 60); do
    desired="$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
    ready="$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
    log_info "  ${ready}/${desired} cilium agents ready (attempt ${i}/60)"
    if [ -n "${desired}" ] && [ "${ready}" = "${desired}" ] && [ "${ready}" != "0" ]; then
      log_ok "  All ${ready} cilium agents Ready"
      break
    fi
    sleep 10
  done
fi

# ===== Step 5: wait for nodes Ready + label always-on =====
log_step "[5/5] Wait for nodes Ready + label data-tier"
if [ "${ZTA_DRY_RUN}" != "1" ]; then
  step "Wait for nodes Ready" kubectl wait node --all --for=condition=Ready --timeout=300s
  step "Label data tier" kubectl label node "${DATA_NODE}" zta.workload.always-on=true --overwrite
fi

migration_end
log_ok "Cilium installed. Run 'kubectl get nodes -o wide' to see Ready nodes."
log_info "Next: bash 05-cluster-services.sh (Gateway API CRDs, cert-manager, ingress, metrics-server, local-path)"
