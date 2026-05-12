#!/usr/bin/env bash
# doc/migration/scripts/phases/worker-join.sh
#
# Run on each WORKER VM (7189srv02, 7189srv03, 7189srv04) AFTER the control
# plane is initialized. Idempotent.
#
# Inputs (one of):
#   1. Env var ZTA_JOIN_CMD="kubeadm join 100.64.10.1:6443 --token ... --discovery-token-ca-cert-hash sha256:..."
#   2. File /etc/kubernetes/zta-join.cmd (contents = the same kubeadm join string)
#   3. Auto-fetch via SSH from CP if SSH_FETCH=1 and the user has key-auth to CP
#
# Steps:
#   1. Pre-flight: tools, hostname, tailscale up, RAM
#   2. Render /root/kubeadm-join.yaml with --node-ip = our Tailscale IP
#   3. kubeadm join
#   4. Verify kubelet active
#
# On error: ROLLBACK runs `kubeadm reset --force` and clears /etc/cni.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# After the refactor to phases/, lib/ + config.env live in the parent dir.
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/lib/common.sh"

require_root
load_config "${ROOT_DIR}/config.env"
migration_start "worker-join"

# ===== Pre-flight =====
log_step "Pre-flight: tools + hostname + tailscale"
require_cmd kubeadm kubelet containerd tailscale || exit 1

case " ${WORKER_HOSTNAMES} " in
  *" $(hostname) "*) log_ok "Hostname '$(hostname)' is in WORKER_HOSTNAMES" ;;
  *)
    log_err "This host's name is '$(hostname)' but WORKER_HOSTNAMES='${WORKER_HOSTNAMES}'."
    log_err "Set HOSTNAME_OVERRIDE in 01-host-prep.sh or update config.env."
    exit 1
    ;;
esac

WORKER_TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
if [ -z "${WORKER_TS_IP}" ]; then
  log_err "Tailscale IP not detected. Run 'sudo tailscale up ...' first."
  exit 1
fi
log_ok "Worker Tailscale IP: ${WORKER_TS_IP}"

# Refuse if already joined
if [ -f /etc/kubernetes/kubelet.conf ] && systemctl is-active kubelet >/dev/null 2>&1; then
  if kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get --raw=/healthz --request-timeout=3s >/dev/null 2>&1; then
    log_warn "Worker already joined to a healthy cluster (kubelet active + apiserver reachable)."
    log_warn "If you want to re-join, run: sudo bash $(dirname "$0")/99-rollback.sh --force"
    migration_end
    exit 0
  fi
fi

# ===== Resolve join command =====
log_step "Resolve kubeadm join command"
ZTA_JOIN_CMD="${ZTA_JOIN_CMD:-}"

if [ -z "${ZTA_JOIN_CMD}" ] && [ -f /etc/kubernetes/zta-join.cmd ]; then
  ZTA_JOIN_CMD="$(cat /etc/kubernetes/zta-join.cmd)"
  log_info "  loaded from /etc/kubernetes/zta-join.cmd"
fi

if [ -z "${ZTA_JOIN_CMD}" ] && [ "${SSH_FETCH:-0}" = "1" ]; then
  log_info "  attempting scp fetch from ${CP_HOSTNAME}.${TAILNET_DOMAIN}"
  ZTA_JOIN_CMD="$(ssh "${SUDO_USER:-${USER}}@${CP_HOSTNAME}.${TAILNET_DOMAIN}" \
    'sudo cat /etc/kubernetes/zta-join.sh' 2>/dev/null || true)"
fi

if [ -z "${ZTA_JOIN_CMD}" ]; then
  log_err "No join command available. Provide one of:"
  log_err "  1) export ZTA_JOIN_CMD=\"kubeadm join ${CP_HOSTNAME}:6443 --token ... --discovery-token-ca-cert-hash sha256:...\""
  log_err "  2) Place the same command in /etc/kubernetes/zta-join.cmd"
  log_err "  3) Set SSH_FETCH=1 and ensure passwordless SSH to ${CP_HOSTNAME}"
  exit 1
fi

# Sanity check
if ! [[ "${ZTA_JOIN_CMD}" =~ ^kubeadm[[:space:]]join ]]; then
  log_err "ZTA_JOIN_CMD doesn't look like 'kubeadm join ...': '${ZTA_JOIN_CMD}'"
  exit 1
fi

# Extract apiServerEndpoint, token, hash from the command
APISERVER_ENDPOINT="$(awk '{for (i=1;i<=NF;i++) if ($i ~ /:6443$/) {print $i; exit}}' <<< "${ZTA_JOIN_CMD}")"
TOKEN="$(awk '{for (i=1;i<=NF;i++) if ($i=="--token") {print $(i+1); exit}}' <<< "${ZTA_JOIN_CMD}")"
HASH="$(awk '{for (i=1;i<=NF;i++) if ($i=="--discovery-token-ca-cert-hash") {print $(i+1); exit}}' <<< "${ZTA_JOIN_CMD}")"

if [ -z "${APISERVER_ENDPOINT}" ] || [ -z "${TOKEN}" ] || [ -z "${HASH}" ]; then
  log_err "Failed to parse endpoint/token/hash from join command:"
  log_err "  endpoint='${APISERVER_ENDPOINT}' token='${TOKEN}' hash='${HASH}'"
  exit 1
fi
log_ok "Parsed join: endpoint=${APISERVER_ENDPOINT} token=${TOKEN:0:6}... hash=${HASH:0:25}..."

# ===== Render join YAML =====
log_step "Render /root/kubeadm-join.yaml (force --node-ip)"
JOIN_YAML="/root/kubeadm-join.yaml"
cat > "${JOIN_YAML}" <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: "${WORKER_TS_IP}"
discovery:
  bootstrapToken:
    apiServerEndpoint: "${APISERVER_ENDPOINT}"
    token: "${TOKEN}"
    caCertHashes:
      - "${HASH}"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
failSwapOn: false
systemReserved:
  cpu: "100m"
  memory: "256Mi"
kubeReserved:
  cpu: "100m"
  memory: "256Mi"
evictionHard:
  memory.available: "200Mi"
  nodefs.available: "10%"
EOF
chmod 600 "${JOIN_YAML}"
register_rollback "rm -f ${JOIN_YAML}"

# ===== Join =====
log_step "kubeadm join (destructive)"
register_rollback "kubeadm reset --force >/dev/null 2>&1 || true; rm -rf /etc/cni/net.d /var/lib/cni; systemctl restart containerd kubelet || true"

if [ "${ZTA_DRY_RUN}" = "1" ]; then
  log_dry "$ kubeadm join --config=${JOIN_YAML}"
else
  kubeadm join --config="${JOIN_YAML}" | tee "${ZTA_LOG_DIR}/03-kubeadm-join.txt"
fi

# ===== Verify =====
log_step "Verify kubelet active"
sleep 3
if [ "${ZTA_DRY_RUN}" != "1" ]; then
  if systemctl is-active kubelet >/dev/null 2>&1; then
    log_ok "  kubelet active"
  else
    log_err "  kubelet NOT active — see: journalctl -u kubelet -n 50"
    exit 1
  fi
fi

migration_end
log_ok "Worker $(hostname) joined cluster. From the CP, run: kubectl get nodes -o wide"
log_info "Node will be NotReady until Cilium is installed (see 04-cilium-install.sh)."
