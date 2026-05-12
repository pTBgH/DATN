#!/usr/bin/env bash
# doc/migration/scripts/phases/host-prep.sh
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
#   6. Install kubelet/kubeadm/kubectl ${KUBE_VERSION} (binary download)
#      + crictl + CNI plugins + kubelet systemd unit
#   7. Verify
#
# Why binary download instead of apt? Debian 13 (Trixie) uses sqv (Sequoia
# PGP) to verify apt repo signatures and rejects v3 OpenPGP signature
# packets from 2026-02-01. The pkgs.k8s.io repo still signs InRelease with
# v3 packets => apt-get update fails with:
#   "Signature Packet v3 is not considered secure since 2026-02-01T00:00:00Z"
# Binary releases on dl.k8s.io are signed via SHA256 sums (not GPG packets)
# and are the *official* alternative install method documented by k8s.
#
# Each step registers a ROLLBACK action. On ERR, all actions are
# undone in reverse order. Idempotency markers are stored in
# ~/.zta-migration/done.<step>.
#
# Usage:
#   sudo -E bash doc/migration/scripts/01-host-prep.sh
#   # or with explicit hostname:
#   sudo HOSTNAME_OVERRIDE=7189srv02 -E bash doc/migration/scripts/phases/host-prep.sh
#   # dry-run:
#   sudo ZTA_DRY_RUN=1 -E bash doc/migration/scripts/phases/host-prep.sh
#
# In most cases you should run this via the bootstrap orchestrator:
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=01

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# After the refactor to phases/, lib/ + config.env live in the parent dir.
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/lib/common.sh"

require_root
load_config "${ROOT_DIR}/config.env"
migration_start "host-prep"

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
if ! already_done_and "containerd-installed" 'command -v containerd'; then
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
    log_info "  containerd already installed: $(containerd --version 2>/dev/null | head -1 || echo unknown)"
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

# ===== STEP 6: kubeadm + kubelet + kubectl + crictl + CNI =====
# Install via binary download from dl.k8s.io (NOT apt repo) — Debian Trixie
# rejects v3 GPG packets used by pkgs.k8s.io InRelease since 2026-02-01.
log_step "[6/7] kubeadm/kubelet/kubectl ${KUBE_VERSION} (binary install)"

# Detect architecture (typically amd64 on x86_64 VMs)
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "${ARCH}" in
  amd64|x86_64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) log_warn "Unknown ARCH '${ARCH}' — defaulting to amd64"; ARCH="amd64" ;;
esac

# Versions for ancillary tooling — pinned to a 1.30.x-compatible patch.
CRICTL_VERSION="${CRICTL_VERSION:-v1.30.1}"
CNI_PLUGINS_VERSION="${CNI_PLUGINS_VERSION:-v1.5.1}"
KUBE_RELEASE_TEMPLATE_VERSION="${KUBE_RELEASE_TEMPLATE_VERSION:-v0.18.0}"

if ! already_done_and "kube-installed" '[ -x /usr/local/bin/kubeadm ] && [ -x /usr/local/bin/kubelet ] && [ -x /usr/local/bin/kubectl ]'; then
  # 6a) kubeadm, kubelet, kubectl binaries -> /usr/local/bin/
  KUBE_INSTALLED_VER=""
  if command -v kubeadm >/dev/null 2>&1; then
    KUBE_INSTALLED_VER="$(kubeadm version -o short 2>/dev/null | sed 's/^v//' || true)"
  fi
  if [ "${KUBE_INSTALLED_VER}" != "${KUBE_VERSION}" ]; then
    for bin in kubeadm kubelet kubectl; do
      step "Download ${bin} v${KUBE_VERSION} (${ARCH})" curl -fsSL --retry 3 -o "/usr/local/bin/${bin}.new" \
        "https://dl.k8s.io/release/v${KUBE_VERSION}/bin/linux/${ARCH}/${bin}"
      step "Install ${bin}" bash -c "chmod +x /usr/local/bin/${bin}.new && mv -f /usr/local/bin/${bin}.new /usr/local/bin/${bin}"
    done
    register_rollback "rm -f /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl"
  else
    log_info "  kubeadm/kubelet/kubectl ${KUBE_VERSION} already installed"
  fi

  # 6b) crictl (kubeadm preflight needs it)
  if ! command -v crictl >/dev/null 2>&1; then
    step "Download crictl ${CRICTL_VERSION} (${ARCH})" curl -fsSL --retry 3 -o /tmp/crictl.tgz \
      "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz"
    step "Install crictl" tar -C /usr/local/bin -xzf /tmp/crictl.tgz
    rm -f /tmp/crictl.tgz
    register_rollback "rm -f /usr/local/bin/crictl"
  else
    log_info "  crictl already installed: $(crictl --version 2>/dev/null | head -1 || echo unknown)"
  fi

  # crictl runtime endpoint config (avoids the "using default endpoints" warning)
  CRICTL_CFG=/etc/crictl.yaml
  if [ ! -f "${CRICTL_CFG}" ]; then
    cat > "${CRICTL_CFG}" <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
    register_rollback "rm -f ${CRICTL_CFG}"
  fi

  # 6c) CNI plugins -> /opt/cni/bin (Cilium replaces most but pause sandbox needs loopback)
  CNI_DIR="/opt/cni/bin"
  if [ ! -f "${CNI_DIR}/loopback" ]; then
    mkdir -p "${CNI_DIR}"
    step "Download CNI plugins ${CNI_PLUGINS_VERSION} (${ARCH})" curl -fsSL --retry 3 -o /tmp/cni.tgz \
      "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz"
    # --no-same-owner: the upstream containernetworking/plugins tarball is built
    # by a non-root user (UID 1001 GID 127 as of v1.5.1). Without this flag, tar
    # preserves that ownership on extraction, leaving /opt/cni/bin owned by
    # UID 1001 GID 127. Cilium's init containers (e.g. mount-cgroup) run with
    # capabilities.drop=ALL — even though they exec as UID 0, dropping
    # CAP_DAC_OVERRIDE means root can no longer bypass DAC, so `cp /usr/bin/...
    # /hostbin/cilium-mount` fails with "Permission denied" because /hostbin
    # (the host's /opt/cni/bin) is owned by UID 1001. Forcing extraction under
    # root:root is the simplest, most idiomatic fix.
    step "Extract CNI plugins (--no-same-owner)" tar --no-same-owner -C "${CNI_DIR}" -xzf /tmp/cni.tgz
    # Defensive chown in case --no-same-owner is silently ignored (some old
    # tar builds) or the directory itself was created with a non-root owner.
    chown -R root:root /opt/cni
    rm -f /tmp/cni.tgz
    register_rollback "rm -rf ${CNI_DIR}"
  else
    # Defensive: if a previous run left /opt/cni owned by UID 1001 (the
    # tarball's original owner), normalize it on every invocation so Cilium
    # init containers can write to /hostbin without CAP_DAC_OVERRIDE.
    if [ "$(stat -c '%U' /opt/cni/bin 2>/dev/null)" != "root" ]; then
      log_warn "  /opt/cni/bin is owned by $(stat -c '%U:%G' /opt/cni/bin) — fixing to root:root"
      chown -R root:root /opt/cni
    fi
    log_info "  CNI plugins already present at ${CNI_DIR}"
  fi

  # 6d) kubelet systemd unit + 10-kubeadm.conf drop-in
  KUBELET_UNIT=/etc/systemd/system/kubelet.service
  KUBEADM_DROPIN_DIR=/etc/systemd/system/kubelet.service.d
  KUBEADM_DROPIN="${KUBEADM_DROPIN_DIR}/10-kubeadm.conf"

  if [ ! -f "${KUBELET_UNIT}" ]; then
    step "Fetch kubelet.service template" bash -c \
      "curl -fsSL --retry 3 https://raw.githubusercontent.com/kubernetes/release/${KUBE_RELEASE_TEMPLATE_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service | sed 's|/usr/bin|/usr/local/bin|g' > ${KUBELET_UNIT}"
    register_rollback "rm -f ${KUBELET_UNIT}"
  fi

  if [ ! -f "${KUBEADM_DROPIN}" ]; then
    mkdir -p "${KUBEADM_DROPIN_DIR}"
    step "Fetch 10-kubeadm.conf drop-in" bash -c \
      "curl -fsSL --retry 3 https://raw.githubusercontent.com/kubernetes/release/${KUBE_RELEASE_TEMPLATE_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf | sed 's|/usr/bin|/usr/local/bin|g' > ${KUBEADM_DROPIN}"
    register_rollback "rm -f ${KUBEADM_DROPIN}"
  fi

  step "systemctl daemon-reload" systemctl daemon-reload
  step "Enable kubelet" systemctl enable kubelet
  # NB: don't `start` yet — kubelet without /etc/kubernetes/bootstrap-kubelet.conf
  # would crashloop. kubeadm init/join will create that config then start kubelet.

  mark_done "kube-installed"
else
  log_info "  already done (kube-installed)"
fi

# ===== STEP 7: verify =====
# Verify is INFORMATIONAL ONLY. Failures here must NOT trigger rollback.
# Disable ERR trap and use defensive evaluation for every probe.
log_step "[7/7] Verify"
trap - ERR

_verify_probe() {
  # Echo "<label>: <output-of-cmd>" with graceful fallback. The inner
  # command group ALWAYS exits 0 (note the `; true`), so the surrounding
  # substitution and log_info cannot fail even with errexit / pipefail /
  # inherit_errexit enabled.
  local label="$1"; shift
  local out
  out="$( { "$@" 2>/dev/null; true; } | head -1 || true )"
  log_info "  ${label}: ${out:-not found}"
}

_verify_probe "containerd" bash -c 'command -v containerd >/dev/null && containerd --version'
_verify_probe "kubeadm   " bash -c 'command -v kubeadm    >/dev/null && kubeadm version -o short'
_verify_probe "kubelet   " bash -c 'command -v kubelet    >/dev/null && kubelet --version'
_verify_probe "kubectl   " bash -c 'command -v kubectl    >/dev/null && kubectl version --client -o yaml | awk "/gitVersion/ {print \$2; exit}"'
_verify_probe "crictl    " bash -c 'command -v crictl     >/dev/null && crictl --version'
_verify_probe "tailscale " bash -c 'command -v tailscale  >/dev/null && tailscale ip -4'
log_info "  CNI dir   : $(ls /opt/cni/bin/ 2>/dev/null | wc -l) plugin(s) in /opt/cni/bin"

# Re-arm ERR trap before migration_end so any post-verify catastrophe
# (there shouldn't be any) is still caught.
trap '_zta_on_err $LINENO "$BASH_COMMAND"' ERR

migration_end
log_ok "Host prep complete on $(hostname). Re-run safely with 'bash $0' anytime."
