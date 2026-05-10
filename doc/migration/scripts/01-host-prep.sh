#!/usr/bin/env bash
# doc/migration/scripts/01-host-prep.sh
#
# Idempotent host preparation. Run on EACH of the 4 VMs (srv01..04) AS ROOT
# (or via sudo). Safe to re-run.
#
# This script ONLY touches the OS — it does NOT init/join Kubernetes.
# Steps:
#   1. APT update + install base packages
#   2. Install Tailscale + (optional) auth (skip if already up)
#   3. Set hostname (if HOSTNAME_OVERRIDE is set)
#   4. Tune swap + sysctl + modules
#   5. Install containerd 1.7 with SystemdCgroup + pause:3.9
#   6. Install kubelet/kubeadm/kubectl ${KUBE_MINOR}
#   7. Verify
#
# Each step registers a ROLLBACK action. On ERR, all actions are
# undone in reverse order. Idempotency markers are stored in
# ~/.zta-migration/done.<step>.
#
# Usage:
#   sudo -E bash doc/migration/scripts/01-host-prep.sh
#   # or with explicit hostname:
#   sudo HOSTNAME_OVERRIDE=7189srv02 -E bash doc/migration/scripts/01-host-prep.sh
#   # dry-run:
#   sudo ZTA_DRY_RUN=1 -E bash doc/migration/scripts/01-host-prep.sh

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root
load_config "${SCRIPT_DIR}/config.env"
migration_start "01-host-prep"

# ===== Pre-flight =====
log_step "Pre-flight: assert OS + RAM + disk"
[ -f /etc/os-release ] || { log_err "/etc/os-release missing"; exit 1; }
. /etc/os-release
case "${ID}" in
  debian|ubuntu) log_ok "Distro: ${PRETTY_NAME}" ;;
  *) log_warn "Untested distro '${ID}' — proceed with caution" ;;
esac

require_min_ram_mib 800 "host-prep" || true     # 800 MiB headroom; not fatal
require_min_disk_gib 10 "/" || { log_err "Need >=10 GiB on /"; exit 1; }
require_min_disk_gib 5  "/var" || true

# ===== STEP 1: apt update + base packages =====
log_step "[1/7] apt update + install base packages"
if ! already_done "apt-base"; then
  step "apt-get update" apt-get update
  step "apt-get install base" apt-get install -y --no-install-recommends \
    curl wget gnupg ca-certificates apt-transport-https \
    iproute2 iptables ipset conntrack ethtool socat \
    jq vim less tmux htop git unzip lsb-release
  mark_done "apt-base"
else
  log_info "  already done (apt-base)"
fi

# ===== STEP 2: Tailscale install + auth =====
log_step "[2/7] Tailscale install"
if ! command -v tailscale >/dev/null 2>&1; then
  step "Install Tailscale via official script" bash -c \
    'curl -fsSL https://tailscale.com/install.sh | sh'
  register_rollback "apt-get remove -y tailscale && rm -f /etc/apt/sources.list.d/tailscale.list"
else
  log_info "  tailscale already installed: $(tailscale version 2>/dev/null | head -1 || echo unknown)"
fi

# Auth (only if not already up)
TS_CURRENT_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
if [ -z "${TS_CURRENT_IP}" ]; then
  if [ -z "${TS_AUTHKEY:-}" ]; then
    log_warn "  Tailscale not authenticated and TS_AUTHKEY is empty."
    log_warn "  Run manually: sudo tailscale up --auth-key=tskey-... \\"
    log_warn "                  --advertise-tags=tag:zta-cluster --hostname=\$(hostname) --accept-dns=true"
    log_warn "  Then re-run this script."
  else
    step "tailscale up" tailscale up \
      --auth-key="${TS_AUTHKEY}" \
      --advertise-tags=tag:zta-cluster \
      --hostname="$(hostname)" \
      --accept-dns=true
    register_rollback "tailscale down || true"
    log_ok "  tailscaled now: $(tailscale ip -4 | head -1)"
  fi
else
  log_ok "  tailscale already up: ${TS_CURRENT_IP}"
fi

# ===== STEP 3: Hostname =====
log_step "[3/7] Hostname"
CUR_HOST="$(hostname)"
if [ -n "${HOSTNAME_OVERRIDE:-}" ] && [ "${CUR_HOST}" != "${HOSTNAME_OVERRIDE}" ]; then
  step "Set hostname -> ${HOSTNAME_OVERRIDE}" hostnamectl set-hostname "${HOSTNAME_OVERRIDE}"
  register_rollback "hostnamectl set-hostname '${CUR_HOST}'"
  log_warn "  Hostname changed. You may need to reboot for kubelet to pick it up cleanly."
else
  log_info "  hostname stays as '${CUR_HOST}'"
fi

# ===== STEP 4: swap + sysctl + modules =====
log_step "[4/7] Swap policy + sysctl + kernel modules"

# 4a) modules-load
MODULES_FILE="/etc/modules-load.d/k8s.conf"
if [ ! -f "${MODULES_FILE}" ] || ! grep -q "^br_netfilter$" "${MODULES_FILE}"; then
  step "Write ${MODULES_FILE}" tee "${MODULES_FILE}" >/dev/null <<'EOF'
overlay
br_netfilter
EOF
  register_rollback "rm -f ${MODULES_FILE}"
fi
modprobe overlay 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true

# 4b) sysctl
SYSCTL_FILE="/etc/sysctl.d/99-zta.conf"
if [ ! -f "${SYSCTL_FILE}" ]; then
  step "Write ${SYSCTL_FILE}" tee "${SYSCTL_FILE}" >/dev/null <<'EOF'
# K8s
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
# eBPF + Tetragon
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
# OOM behavior
vm.swappiness = 10
vm.overcommit_memory = 1
vm.panic_on_oom = 0
kernel.panic = 10
EOF
  register_rollback "rm -f ${SYSCTL_FILE} && sysctl --system"
  step "Reload sysctl" sysctl --system
else
  log_info "  ${SYSCTL_FILE} already present"
fi

# 4c) Swap policy: keep swap (don't disable on small VMs) but reduce swappiness.
#     Kubelet will be configured with failSwapOn=false in 02-control-plane-init.sh.
log_info "  swap will remain enabled with swappiness=10 (failSwapOn=false in kubelet config)"

# ===== STEP 5: containerd 1.7 + SystemdCgroup + pause:3.9 =====
log_step "[5/7] containerd"
if ! already_done "containerd-installed"; then
  if ! command -v containerd >/dev/null 2>&1; then
    KEYRING_DIR="/etc/apt/keyrings"
    install -m 0755 -d "${KEYRING_DIR}"
    step "Add Docker apt key" bash -c \
      'curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && chmod a+r /etc/apt/keyrings/docker.asc'
    step "Add Docker apt repo" bash -c \
      'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list'
    register_rollback "rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc"
    step "apt update for docker repo" apt-get update
    step "Install containerd.io" apt-get install -y containerd.io
    register_rollback "apt-get remove -y containerd.io"
  else
    log_info "  containerd already installed: $(containerd --version | head -1)"
  fi

  # Generate config (idempotent — only write if differs / missing)
  CFG=/etc/containerd/config.toml
  mkdir -p /etc/containerd
  TMP="$(mktemp)"
  containerd config default > "${TMP}"
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' "${TMP}"
  sed -i 's#sandbox_image = "registry.k8s.io/pause:[^"]*"#sandbox_image = "registry.k8s.io/pause:3.9"#' "${TMP}"
  if ! cmp -s "${TMP}" "${CFG}"; then
    [ -f "${CFG}" ] && cp -a "${CFG}" "${CFG}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    cp "${TMP}" "${CFG}"
    register_rollback "rm -f ${CFG}; ls ${CFG}.bak.* >/dev/null 2>&1 && cp -a \$(ls -t ${CFG}.bak.* | head -1) ${CFG}; systemctl restart containerd || true"
    step "Restart containerd" systemctl restart containerd
  else
    log_info "  containerd config already up-to-date"
  fi
  rm -f "${TMP}"

  systemctl enable --now containerd >/dev/null
  mark_done "containerd-installed"
else
  log_info "  already done (containerd-installed)"
fi

# ===== STEP 6: kubeadm + kubelet + kubectl =====
log_step "[6/7] kubeadm/kubelet/kubectl ${KUBE_MINOR}"
if ! already_done "kube-installed"; then
  KEY_FILE="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
  LIST_FILE="/etc/apt/sources.list.d/kubernetes.list"
  if [ ! -f "${KEY_FILE}" ]; then
    step "Add k8s apt key" bash -c \
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_MINOR}/deb/Release.key | gpg --dearmor -o ${KEY_FILE}"
    register_rollback "rm -f ${KEY_FILE}"
  fi
  EXPECTED_LIST="deb [signed-by=${KEY_FILE}] https://pkgs.k8s.io/core:/stable:/v${KUBE_MINOR}/deb/ /"
  if [ ! -f "${LIST_FILE}" ] || [ "$(cat "${LIST_FILE}")" != "${EXPECTED_LIST}" ]; then
    printf '%s\n' "${EXPECTED_LIST}" > "${LIST_FILE}"
    register_rollback "rm -f ${LIST_FILE}"
  fi

  step "apt update for k8s repo" apt-get update
  step "Install k8s tooling"     apt-get install -y kubelet kubeadm kubectl
  step "apt-mark hold"           apt-mark hold kubelet kubeadm kubectl
  register_rollback "apt-mark unhold kubelet kubeadm kubectl || true; apt-get remove -y kubelet kubeadm kubectl || true"

  step "Enable kubelet" systemctl enable kubelet
  mark_done "kube-installed"
else
  log_info "  already done (kube-installed)"
fi

# ===== STEP 7: verify =====
log_step "[7/7] Verify"
log_info "  containerd: $(containerd --version | head -1)"
log_info "  kubeadm   : $(kubeadm version -o short 2>/dev/null || true)"
log_info "  kubelet   : $(kubelet --version 2>/dev/null || true)"
log_info "  tailscale : $(tailscale ip -4 2>/dev/null | head -1 || echo '(not authed)')"

migration_end
log_ok "Host prep complete on $(hostname). Re-run safely with 'bash $0' anytime."
