#!/usr/bin/env bash
# doc/migration/scripts/99-rollback.sh
#
# Rollback the LAST attempted phase that didn't complete (according to
# ~/.zta-migration/<phase>.state). Usable in two modes:
#
#   1. Auto-rollback: detected failure (state file says 'failed ...')
#      → script runs the recorded rollback stack from the LAST log file.
#
#   2. Forced rollback: --force --phase=<name>
#      → fully wipes that phase even if marked completed.
#
# IMPORTANT: This script is destructive on the LOCAL VM only.
# - For control-plane:    runs `kubeadm reset --force` → cluster gone
# - For worker-join:      runs `kubeadm reset --force` → leaves cluster
# - For cilium:           `helm uninstall cilium -n kube-system`
# - For cluster-services: `helm uninstall` of each release
# - For host-prep:        best-effort revert of containerd/kubeadm install
#
# Phase names after the refactor: host-prep | control-plane | worker-join |
#                                 cilium | cluster-services
# Legacy names (01-host-prep, 02-control-plane-init, ...) still accepted.
#
# Usage:
#   sudo -E bash doc/migration/scripts/99-rollback.sh                 # auto
#   sudo -E bash doc/migration/scripts/99-rollback.sh --force --phase=control-plane

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root
load_config "${SCRIPT_DIR}/config.env"
ZTA_AUTO_ROLLBACK=0
migration_start "99-rollback"

FORCE=0
TARGET_PHASE=""
for a in "$@"; do
  case "$a" in
    --force)            FORCE=1 ;;
    --phase=*)          TARGET_PHASE="${a#--phase=}" ;;
    --help|-h)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *) log_warn "unknown arg: $a" ;;
  esac
done

# ===== Determine target phase =====
if [ -z "${TARGET_PHASE}" ]; then
  # Find most recent state file
  TARGET_PHASE="$(ls -t "${ZTA_STATE_DIR}"/*.state 2>/dev/null | head -1 | xargs -I{} basename {} .state || true)"
fi

if [ -z "${TARGET_PHASE}" ]; then
  log_err "No phase specified and no state file found in ${ZTA_STATE_DIR}/"
  log_err "Use: 99-rollback.sh --force --phase=<phase-name>"
  exit 1
fi

# Normalize legacy phase names to the new short names so users can pass
# either `--phase=01-host-prep` or `--phase=host-prep`. Must happen BEFORE
# state-file lookup so we read the correct file.
case "${TARGET_PHASE}" in
  01-host-prep)          TARGET_PHASE="host-prep" ;;
  02-control-plane-init) TARGET_PHASE="control-plane" ;;
  03-worker-join)        TARGET_PHASE="worker-join" ;;
  04-cilium-install)     TARGET_PHASE="cilium" ;;
  05-cluster-services)   TARGET_PHASE="cluster-services" ;;
esac

STATE_FILE="${ZTA_STATE_DIR}/${TARGET_PHASE}.state"
log_info "Rolling back phase: ${TARGET_PHASE}"
[ -f "${STATE_FILE}" ] && log_info "  state: $(cat "${STATE_FILE}")" || log_info "  (no state file)"

if [ -f "${STATE_FILE}" ] && grep -q "^completed" "${STATE_FILE}" && [ "${FORCE}" != "1" ]; then
  log_warn "Phase '${TARGET_PHASE}' is marked completed."
  log_warn "Re-run with --force --phase=${TARGET_PHASE} to wipe."
  migration_end
  exit 0
fi

# ===== Per-phase rollback procedures =====
case "${TARGET_PHASE}" in
  host-prep)
    log_warn "Rolling back host-prep (best-effort)"
    if [ "${FORCE}" = "1" ]; then
      try_step "stop kubelet" bash -c 'systemctl stop kubelet 2>/dev/null || true; systemctl disable kubelet 2>/dev/null || true'
      try_step "remove kubeadm/kubelet/kubectl binaries" rm -f /usr/local/bin/kubeadm /usr/local/bin/kubelet /usr/local/bin/kubectl
      try_step "remove crictl + config" bash -c 'rm -f /usr/local/bin/crictl /etc/crictl.yaml'
      try_step "remove CNI plugins" rm -rf /opt/cni/bin
      try_step "remove kubelet systemd unit" rm -f /etc/systemd/system/kubelet.service /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
      try_step "remove legacy kubernetes apt repo (if any)" rm -f /etc/apt/sources.list.d/kubernetes.list /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      try_step "systemctl daemon-reload" systemctl daemon-reload
      try_step "remove containerd config" rm -f /etc/containerd/config.toml
      try_step "remove sysctl/modules" bash -c \
        'rm -f /etc/sysctl.d/99-zta.conf /etc/modules-load.d/k8s.conf; sysctl --system >/dev/null'
      try_step "tailscale down" tailscale down
      try_step "remove done markers" rm -f "${ZTA_STATE_DIR}"/done.*
    else
      log_warn "  (use --force to wipe this phase — non-destructive rollback already happened during the failure)"
    fi
    ;;

  control-plane)
    log_warn "Rolling back control-plane (kubeadm reset)"
    try_step "kubeadm reset" kubeadm reset --force
    try_step "remove CNI"     rm -rf /etc/cni/net.d /var/lib/cni
    try_step "restart kubelet+containerd" bash -c 'systemctl restart containerd kubelet || true'
    try_step "remove kubeadm-config.yaml" rm -f /root/kubeadm-config.yaml /etc/kubernetes/zta-join.sh
    INVOKING_USER="${SUDO_USER:-${USER:-root}}"
    USER_HOME="$(getent passwd "${INVOKING_USER}" | cut -d: -f6 || echo /root)"
    try_step "remove user kubeconfig" rm -f "${USER_HOME}/.kube/config"
    ;;

  worker-join)
    log_warn "Rolling back worker join (kubeadm reset)"
    try_step "kubeadm reset" kubeadm reset --force
    try_step "remove CNI"     rm -rf /etc/cni/net.d /var/lib/cni
    try_step "restart kubelet+containerd" bash -c 'systemctl restart containerd kubelet || true'
    try_step "remove join YAML" rm -f /root/kubeadm-join.yaml /etc/kubernetes/zta-join.cmd
    ;;

  cilium)
    log_warn "Rolling back Cilium"
    try_step "helm uninstall cilium" bash -c \
      'helm uninstall cilium -n kube-system >/dev/null 2>&1 || true'
    try_step "remove cilium values" rm -f "${ZTA_STATE_DIR}/cilium-values-multi-vm.yaml"
    log_warn "Nodes will become NotReady until Cilium re-installs."
    ;;

  cluster-services)
    log_warn "Rolling back cluster services"
    for release_ns in \
      "metrics-server kube-system" \
      "ingress-nginx ingress-nginx" \
      "cert-manager cert-manager"
    do
      r="${release_ns% *}"; n="${release_ns#* }"
      try_step "helm uninstall ${r} (-n ${n})" bash -c "helm uninstall ${r} -n ${n} >/dev/null 2>&1 || true"
    done
    try_step "remove standard StorageClass alias" \
      kubectl delete -f "${ZTA_STATE_DIR}/standard-storageclass.yaml" --ignore-not-found
    log_warn "local-path-provisioner is left installed — delete manually if needed."
    ;;

  00-status|99-rollback|status|rollback)
    log_warn "Phase '${TARGET_PHASE}' has no state changes — nothing to roll back."
    ;;

  *)
    log_err "Unknown phase: ${TARGET_PHASE}"
    log_err "Known: host-prep | control-plane | worker-join | cilium | cluster-services"
    exit 1
    ;;
esac

# ===== Cleanup state =====
log_step "Cleanup state file"
[ -f "${STATE_FILE}" ] && rm -f "${STATE_FILE}"
log_ok "Removed ${STATE_FILE}"

migration_end
log_ok "Rollback of ${TARGET_PHASE} complete on $(hostname)."
