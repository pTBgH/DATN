#!/usr/bin/env bash
# knowledge-base/migration/scripts/phases/control-plane.sh
#
# Run on 7189srv01 ONLY (the control-plane VM). Idempotent.
# This script:
#   1. Pre-flight: kubeadm, containerd, tailscale, hostname == CP_HOSTNAME
#   2. Pull required images
#   3. Render kubeadm-config.yaml using Tailscale IP of THIS host
#   4. `kubeadm init --skip-phases=addon/kube-proxy`
#   5. Set up kubeconfig for the invoking user
#   6. Print the join command for workers
#   7. Save kubeadm-join command to /etc/kubernetes/zta-join.sh (root-only)
#
# On error: ROLLBACK runs `kubeadm reset --force` to leave the host in a clean
# state. The rollback also removes /etc/cni and resets kubelet state.
#
# Usage (preferred — via the bootstrap orchestrator):
#   sudo -E bash knowledge-base/migration/scripts/bootstrap.sh --server=01 --phase=control-plane
# Or directly:
#   sudo -E bash knowledge-base/migration/scripts/phases/control-plane.sh

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# After the refactor to phases/, lib/ + config.env live in the parent dir.
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/lib/common.sh"

require_root
load_config "${ROOT_DIR}/config.env"
migration_start "control-plane"

# ===== Pre-flight =====
log_step "Pre-flight: tools + hostname + tailscale + RAM"
require_cmd kubeadm kubelet kubectl containerd tailscale || exit 1

if [ "$(hostname)" != "${CP_HOSTNAME}" ]; then
  log_err "This host's name is '$(hostname)' but CP_HOSTNAME='${CP_HOSTNAME}'."
  log_err "Run 02-control-plane-init.sh ONLY on the control-plane VM."
  log_err "If hostname mismatch is intentional, set CP_HOSTNAME=$(hostname) in config.env."
  exit 1
fi

CP_TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
if [ -z "${CP_TS_IP}" ]; then
  log_err "Tailscale IP not detected. Run 'sudo tailscale up ...' first."
  exit 1
fi
log_ok "Tailscale IP: ${CP_TS_IP}"

# Refuse if cluster already exists with healthy apiserver
if [ -f /etc/kubernetes/admin.conf ] && \
   kubectl --kubeconfig=/etc/kubernetes/admin.conf get --raw=/healthz --request-timeout=3s >/dev/null 2>&1; then
  log_warn "An existing healthy cluster is already present at $(hostname)."
  log_warn "Re-running this script would NOT re-init (kubeadm refuses)."
  log_warn "If you want a fresh init, run: sudo bash $(dirname "$0")/99-rollback.sh --force"
  log_info "Skipping init. Re-publishing join command for convenience..."
  kubeadm token create --print-join-command 2>/dev/null | tee /etc/kubernetes/zta-join.sh >/dev/null
  chmod 600 /etc/kubernetes/zta-join.sh
  log_ok "Updated /etc/kubernetes/zta-join.sh"
  migration_end
  exit 0
fi

require_min_ram_mib 1200 "kubeadm init" || true

# ===== Step 1: pull images =====
log_step "[1/5] kubeadm config images pull (~600 MB)"
step "Pull images" kubeadm config images pull --kubernetes-version "v${KUBE_VERSION}"

# ===== Step 2: render kubeadm-config.yaml =====
log_step "[2/5] Render /root/kubeadm-config.yaml"
KUBE_CONFIG_FILE="/root/kubeadm-config.yaml"

cat > "${KUBE_CONFIG_FILE}" <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${CP_TS_IP}"
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: "${CP_TS_IP}"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v${KUBE_VERSION}
clusterName: ${CLUSTER_NAME}
controlPlaneEndpoint: "${CP_TS_IP}:6443"
networking:
  podSubnet: "${POD_CIDR}"
  serviceSubnet: "${SVC_CIDR}"
  dnsDomain: cluster.local
apiServer:
  certSANs:
    - "${CP_TS_IP}"
    - "${CP_HOSTNAME}"
    - "${CP_HOSTNAME}.${TAILNET_DOMAIN}"
    - "127.0.0.1"
    - "localhost"
  extraArgs:
    profiling: "false"
controllerManager:
  extraArgs:
    leader-elect-lease-duration: "30s"
    leader-elect-renew-deadline: "20s"
    leader-elect-retry-period: "4s"
scheduler:
  extraArgs:
    leader-elect-lease-duration: "30s"
    leader-elect-renew-deadline: "20s"
    leader-elect-retry-period: "4s"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
failSwapOn: false
systemReserved:
  cpu: "100m"
  memory: "256Mi"
  ephemeral-storage: "1Gi"
kubeReserved:
  cpu: "100m"
  memory: "256Mi"
  ephemeral-storage: "1Gi"
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
EOF
chmod 600 "${KUBE_CONFIG_FILE}"
register_rollback "rm -f ${KUBE_CONFIG_FILE}"
log_ok "  wrote ${KUBE_CONFIG_FILE}"

# ===== Step 3: kubeadm init =====
log_step "[3/5] kubeadm init (this is the destructive step)"
register_rollback "kubeadm reset --force >/dev/null 2>&1 || true; rm -rf /etc/cni/net.d /var/lib/cni; systemctl restart containerd kubelet || true"

if [ "${ZTA_DRY_RUN}" = "1" ]; then
  log_dry "$ kubeadm init --config=${KUBE_CONFIG_FILE} --skip-phases=addon/kube-proxy --upload-certs"
else
  kubeadm init --config="${KUBE_CONFIG_FILE}" --skip-phases=addon/kube-proxy --upload-certs \
    | tee "${ZTA_LOG_DIR}/02-kubeadm-init.txt"
fi

# ===== Step 4: kubeconfig for the invoking user =====
log_step "[4/5] Set up kubeconfig for invoking user"
INVOKING_USER="${SUDO_USER:-${USER:-root}}"
USER_HOME="$(getent passwd "${INVOKING_USER}" | cut -d: -f6 || echo /root)"

if [ "${ZTA_DRY_RUN}" = "1" ]; then
  log_dry "$ install -d ${USER_HOME}/.kube; cp /etc/kubernetes/admin.conf ${USER_HOME}/.kube/config"
else
  install -d -m 0755 -o "${INVOKING_USER}" -g "${INVOKING_USER}" "${USER_HOME}/.kube"
  cp -f /etc/kubernetes/admin.conf "${USER_HOME}/.kube/config"
  chown "${INVOKING_USER}:${INVOKING_USER}" "${USER_HOME}/.kube/config"
  chmod 0600 "${USER_HOME}/.kube/config"
  log_ok "  ${USER_HOME}/.kube/config installed"
fi

# Smoke test
if [ "${ZTA_DRY_RUN}" != "1" ]; then
  if kubectl --kubeconfig="${USER_HOME}/.kube/config" get --raw=/healthz --request-timeout=10s >/dev/null 2>&1; then
    log_ok "  apiserver /healthz OK"
  else
    log_err "  apiserver did not respond — investigate before joining workers"
    exit 1
  fi
fi

# ===== Step 5: persist join command =====
log_step "[5/5] Persist worker join command"
if [ "${ZTA_DRY_RUN}" != "1" ]; then
  kubeadm token create --print-join-command \
    | tee /etc/kubernetes/zta-join.sh >/dev/null
  chmod 600 /etc/kubernetes/zta-join.sh
  log_ok "  /etc/kubernetes/zta-join.sh written (TTL: 24h)"
  log_info "  cat /etc/kubernetes/zta-join.sh"
fi

migration_end
log_ok "Control plane is up. Next: run 03-worker-join.sh on each worker VM."
