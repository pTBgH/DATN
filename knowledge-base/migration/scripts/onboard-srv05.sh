#!/usr/bin/env bash
# knowledge-base/migration/scripts/onboard-srv05.sh
#
# Onboard the replacement data-tier VM (default hostname: 7189srv05) into
# the existing job7189 cluster. Designed for the case where srv04 is stuck
# behind double-NAT (libvirt NAT + ISP CGNAT) on Ubuntu host and Tailscale
# can't direct-P2P → kubelet/cilium TCP gets stranded on the DERP-hkg relay.
# srv05 is provisioned with BRIDGE networking on the same Ubuntu host so it
# gets a routable LAN IP and Tailscale can NAT-punch cleanly.
#
# This script is a thin wrapper around bootstrap.sh — it does not
# duplicate phase logic. Steps:
#
#   1. Pre-flight on srv05:
#        - Confirm distro = Ubuntu 24.04 (warn on other)
#        - Confirm not on libvirt NAT (192.168.122.0/24) → bridge expected
#        - Confirm hostname == ZTA_NEW_HOSTNAME OR HOSTNAME_OVERRIDE set
#        - Confirm config.env contains the new hostname in WORKER_HOSTNAMES
#        - Confirm ZTA_JOIN_CMD or /etc/kubernetes/zta-join.cmd is available
#   2. Run bootstrap.sh --server=NN --yes  (with HOSTNAME_OVERRIDE if needed)
#   3. Print follow-up instructions for the CP (decommission-srv04.sh)
#
# IMPORTANT — this script runs ON srv05 itself, NOT on a control node.
#
# Required env / inputs:
#   ZTA_NEW_HOSTNAME  Hostname this VM should run under (default: 7189srv05).
#                    Must already appear in WORKER_HOSTNAMES of config.env.
#   ZTA_JOIN_CMD     The full `kubeadm join ...` from the CP. Obtain via:
#                    on srv01: sudo kubeadm token create --print-join-command
#                    Either export this env var, OR place the command in
#                    /etc/kubernetes/zta-join.cmd before running.
#   TS_AUTHKEY        (host-prep needs this) Tailscale pre-auth key OR run
#                    `sudo tailscale up --auth-key=tskey-... --advertise-tags=tag:zta-cluster
#                       --hostname=$(hostname) --accept-dns=true` manually first.
#
# Usage:
#   sudo -E ZTA_JOIN_CMD="kubeadm join ..." TS_AUTHKEY="tskey-..." \
#     bash knowledge-base/migration/scripts/onboard-srv05.sh
#
#   # Or with all knobs:
#   sudo -E ZTA_NEW_HOSTNAME=7189srv05 \
#     ZTA_JOIN_CMD="kubeadm join ..." \
#     TS_AUTHKEY="tskey-..." \
#     bash knowledge-base/migration/scripts/onboard-srv05.sh
#
# Why a wrapper instead of editing bootstrap.sh:
#   - Keeps the existing srv01..04 flow untouched (request from operator).
#   - Centralises the pre-flight check that prevents the double-NAT
#     regression: if /etc/libvirt-style NAT addresses are detected, abort
#     with a clear message so we don't waste hours discovering the same
#     issue post-bootstrap.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/inventory.sh
. "${SCRIPT_DIR}/lib/inventory.sh"

CONFIG="${SCRIPT_DIR}/config.env"
load_config "${CONFIG}"

ZTA_NEW_HOSTNAME="${ZTA_NEW_HOSTNAME:-7189srv05}"

# ===== 1. Pre-flight =====
log_step "Pre-flight: distro / network / inventory"

# 1a) Must be root
if [ "$(id -u)" -ne 0 ]; then
  log_err "onboard-srv05.sh requires root. Re-run with:"
  log_err "  sudo -E ZTA_JOIN_CMD=\"...\" TS_AUTHKEY=\"...\" bash $0"
  exit 1
fi

# 1b) Distro check (warn-only — host-prep also handles ubuntu)
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "${ID}:${VERSION_ID:-?}" in
    ubuntu:24.04) log_ok "Distro: ${PRETTY_NAME}" ;;
    ubuntu:*)     log_warn "Distro is Ubuntu ${VERSION_ID} — host-prep is tested on 24.04" ;;
    debian:*)     log_warn "Distro is Debian — onboard-srv05.sh was written for Ubuntu bridge VMs but should work" ;;
    *)            log_warn "Untested distro: ${PRETTY_NAME:-${ID}:${VERSION_ID:-?}}" ;;
  esac
else
  log_warn "/etc/os-release missing — cannot confirm distro"
fi

# 1c) Network sanity — refuse if the VM looks like it's behind libvirt NAT.
#     The whole reason for replacing srv04 is to escape 192.168.122.0/24.
LOCAL_IPS="$(ip -4 -o addr show scope global | awk '{print $4}' | awk -F/ '{print $1}' | sort -u)"
log_info "  Local IPv4 addresses: $(echo "${LOCAL_IPS}" | tr '\n' ' ')"

NAT_HIT=""
for ip in ${LOCAL_IPS}; do
  case "${ip}" in
    192.168.122.*)
      NAT_HIT="${ip}"
      break
      ;;
  esac
done

if [ -n "${NAT_HIT}" ]; then
  log_err "Refusing to onboard: this VM has IP ${NAT_HIT} in libvirt default NAT range 192.168.122.0/24."
  log_err ""
  log_err "  This is the exact failure mode we are replacing srv04 to avoid."
  log_err "  Reconfigure the VM to use BRIDGE networking before re-running:"
  log_err ""
  log_err "  On the Ubuntu host:"
  log_err "    virsh edit <vm-name>"
  log_err "      <interface type='bridge'>"
  log_err "        <source bridge='br0'/>           # or the bridge name you've created"
  log_err "        <model type='virtio'/>"
  log_err "      </interface>"
  log_err "    virsh destroy <vm-name> && virsh start <vm-name>"
  log_err ""
  log_err "  After reboot, this VM should have an IP from your LAN (e.g. 192.168.1.x),"
  log_err "  not 192.168.122.x. Then re-run this script."
  log_err ""
  log_err "  To override this check (NOT recommended) set ZTA_ALLOW_LIBVIRT_NAT=1."
  if [ "${ZTA_ALLOW_LIBVIRT_NAT:-0}" != "1" ]; then
    exit 1
  fi
  log_warn "  ZTA_ALLOW_LIBVIRT_NAT=1 set — continuing despite libvirt NAT (you accept Tailscale DERP relay risk)."
fi

# 1d) Hostname / inventory sanity
case " ${WORKER_HOSTNAMES} " in
  *" ${ZTA_NEW_HOSTNAME} "*)
    log_ok "Inventory: ${ZTA_NEW_HOSTNAME} is in WORKER_HOSTNAMES"
    ;;
  *)
    log_err "${ZTA_NEW_HOSTNAME} is NOT in WORKER_HOSTNAMES from ${CONFIG}:"
    log_err "  WORKER_HOSTNAMES=\"${WORKER_HOSTNAMES}\""
    log_err ""
    log_err "Add it first, e.g.:"
    log_err "  WORKER_HOSTNAMES=\"7189srv02 7189srv03 7189srv04 7189srv05\""
    log_err "  DATA_NODE=\"7189srv05\""
    log_err ""
    log_err "If this is intentional and you really want a different name, set"
    log_err "  ZTA_NEW_HOSTNAME=<your-hostname>"
    exit 1
    ;;
esac

CUR_HOST="$(hostname)"
if [ "${CUR_HOST}" != "${ZTA_NEW_HOSTNAME}" ]; then
  log_warn "Local hostname is '${CUR_HOST}'. host-prep will rename to '${ZTA_NEW_HOSTNAME}' via HOSTNAME_OVERRIDE."
  export HOSTNAME_OVERRIDE="${ZTA_NEW_HOSTNAME}"
else
  log_ok "Hostname already '${CUR_HOST}'"
fi

# 1e) Join command sanity
if [ -z "${ZTA_JOIN_CMD:-}" ] && [ ! -f /etc/kubernetes/zta-join.cmd ]; then
  log_err "No kubeadm join command available. Get one from the CP:"
  log_err ""
  log_err "  ssh ptb@${CP_HOSTNAME}.${TAILNET_DOMAIN} \\"
  log_err "    'sudo kubeadm token create --print-join-command'"
  log_err ""
  log_err "Then either export it:"
  log_err "  export ZTA_JOIN_CMD=\"kubeadm join ${CP_HOSTNAME}:6443 --token ... --discovery-token-ca-cert-hash sha256:...\""
  log_err ""
  log_err "OR drop it in:"
  log_err "  echo 'kubeadm join ...' | sudo tee /etc/kubernetes/zta-join.cmd"
  log_err ""
  log_err "Then re-run this script."
  exit 1
fi

if [ -n "${ZTA_JOIN_CMD:-}" ]; then
  log_ok "Join command provided via ZTA_JOIN_CMD env var"
else
  log_ok "Join command available at /etc/kubernetes/zta-join.cmd"
fi

# 1f) Tailscale auth sanity (informational)
if ! command -v tailscale >/dev/null 2>&1 || [ -z "$(tailscale ip -4 2>/dev/null | head -1 || true)" ]; then
  if [ -z "${TS_AUTHKEY:-}" ]; then
    log_warn "Tailscale not authenticated AND TS_AUTHKEY env var not set."
    log_warn "  host-prep will install tailscale but skip 'tailscale up' — you must run it manually."
    log_warn "  Recommended: export TS_AUTHKEY=tskey-... before re-running, OR run after host-prep:"
    log_warn "    sudo tailscale up --auth-key=tskey-... \\"
    log_warn "      --advertise-tags=tag:zta-cluster --hostname=$(hostname) --accept-dns=true"
  else
    log_ok "TS_AUTHKEY provided — host-prep will run 'tailscale up'"
  fi
else
  TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || echo unknown)"
  log_ok "Tailscale already up: ${TS_IP}"
fi

# 1g) Show what's about to happen
SERVER_SUFFIX="${ZTA_NEW_HOSTNAME##*[!0-9]}"
[ -n "${SERVER_SUFFIX}" ] || SERVER_SUFFIX="${ZTA_NEW_HOSTNAME: -2}"

cat <<EOF

==========================================================
Onboard ${ZTA_NEW_HOSTNAME} into cluster '${CLUSTER_NAME}'
==========================================================
  this host       : $(hostname)
  becomes         : ${ZTA_NEW_HOSTNAME}
  role            : worker
  cp endpoint     : ${CP_HOSTNAME}.${TAILNET_DOMAIN}:6443
  bootstrap call  : sudo bash bootstrap.sh --server=${SERVER_SUFFIX} --yes
  next step       : (on srv01) bash knowledge-base/migration/scripts/decommission-srv04.sh
EOF

if [ "${ZTA_ONBOARD_DRY_RUN:-0}" = "1" ]; then
  log_ok "DRY-RUN mode — exiting without invoking bootstrap.sh"
  exit 0
fi

if [ "${ZTA_YES:-0}" != "1" ]; then
  printf '\n%s' "Proceed with bootstrap.sh? [y/N] "
  read -r ans
  case "${ans}" in y|Y|yes|YES) ;; *) log_err "Aborted by user."; exit 2 ;; esac
fi

# ===== 2. Run bootstrap.sh =====
log_step "Invoking bootstrap.sh --server=${SERVER_SUFFIX}"
exec env \
  HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-}" \
  ZTA_JOIN_CMD="${ZTA_JOIN_CMD:-}" \
  TS_AUTHKEY="${TS_AUTHKEY:-}" \
  bash "${SCRIPT_DIR}/bootstrap.sh" --server="${SERVER_SUFFIX}" --yes
