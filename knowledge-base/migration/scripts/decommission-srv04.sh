#!/usr/bin/env bash
# knowledge-base/migration/scripts/decommission-srv04.sh
#
# Remove the old data-tier VM (default: 7189srv04) from the cluster after a
# replacement (e.g. 7189srv05) is Ready. Designed to be run from the
# control-plane VM (7189srv01) where kubectl is configured.
#
# This is the SECOND half of the srv04→srv05 swap:
#   1. (on srv05) onboard-srv05.sh -> bootstrap.sh -> Ready
#   2. (on srv01) decommission-srv04.sh -> cordon, drain, delete
#
# Idempotent and safe to re-run:
#   - cordon: noop if already cordoned
#   - drain : noop if no workload remains on the node
#   - delete: noop if node already deleted
#
# Required pre-conditions:
#   - kubectl can reach the apiserver (you're on srv01 or have KUBECONFIG)
#   - The replacement node (srv05) is in `kubectl get nodes -o wide` with
#     STATUS=Ready. Override this safety check with ZTA_FORCE=1 only if you
#     know what you're doing (e.g. srv04 is unreachable and you just want
#     it gone regardless).
#
# Inputs (env / flags):
#   ZTA_OLD_HOSTNAME   Default: 7189srv04
#   ZTA_NEW_HOSTNAME   Default: 7189srv05 (must be Ready before drain)
#   ZTA_FORCE          Skip "is replacement Ready?" safety check
#   --yes / -y         Don't prompt for confirmation
#   --dry-run          Show plan and exit
#
# After this script:
#   - On the OLD VM (srv04) you should run, as a courtesy, to free disk:
#       sudo kubeadm reset --force
#       sudo rm -rf /etc/cni/net.d /var/lib/cni /var/lib/containerd
#     The script prints the exact commands at the end.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
load_config "${SCRIPT_DIR}/config.env"

ZTA_OLD_HOSTNAME="${ZTA_OLD_HOSTNAME:-7189srv04}"
ZTA_NEW_HOSTNAME="${ZTA_NEW_HOSTNAME:-7189srv05}"
DRY_RUN=0
NO_PROMPT=0

for arg in "$@"; do
  case "${arg}" in
    --yes|-y)    NO_PROMPT=1 ;;
    --dry-run)   DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,35p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      log_err "Unknown argument: ${arg}"
      exit 2
      ;;
  esac
done

# ===== 1. Pre-flight =====
log_step "Pre-flight"
command -v kubectl >/dev/null || { log_err "kubectl not in PATH. Run this on the CP."; exit 1; }

if ! kubectl get --raw=/livez --request-timeout=5s >/dev/null 2>&1; then
  log_err "Cannot reach apiserver. Check KUBECONFIG or run from srv01."
  exit 1
fi
log_ok "apiserver reachable"

# Confirm old node exists in cluster
if ! kubectl get node "${ZTA_OLD_HOSTNAME}" >/dev/null 2>&1; then
  log_warn "Node '${ZTA_OLD_HOSTNAME}' is NOT in the cluster — already removed?"
  kubectl get nodes
  exit 0
fi

# Confirm new node is Ready (unless force)
if [ "${ZTA_FORCE:-0}" != "1" ]; then
  NEW_STATUS="$(kubectl get node "${ZTA_NEW_HOSTNAME}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo MISSING)"
  case "${NEW_STATUS}" in
    True)
      log_ok "Replacement '${ZTA_NEW_HOSTNAME}' is Ready"
      ;;
    MISSING)
      log_err "Replacement node '${ZTA_NEW_HOSTNAME}' not in cluster. Onboard it first:"
      log_err "  (on the new VM) sudo bash knowledge-base/migration/scripts/onboard-srv05.sh"
      log_err "  Or set ZTA_FORCE=1 to bypass this check (drains workload to nowhere)."
      exit 1
      ;;
    *)
      log_err "Replacement '${ZTA_NEW_HOSTNAME}' is NOT Ready (status='${NEW_STATUS}'). Wait for it."
      log_err "Set ZTA_FORCE=1 to bypass."
      exit 1
      ;;
  esac
fi

# Show plan
PODS_ON_OLD="$(kubectl get pod -A --field-selector spec.nodeName="${ZTA_OLD_HOSTNAME}" --no-headers 2>/dev/null | wc -l)"
cat <<EOF

==========================================================
Decommission ${ZTA_OLD_HOSTNAME}
==========================================================
  old node       : ${ZTA_OLD_HOSTNAME}
  replacement    : ${ZTA_NEW_HOSTNAME} (Ready)
  pods on old    : ${PODS_ON_OLD}
  actions        :
    1. kubectl cordon  ${ZTA_OLD_HOSTNAME}
    2. kubectl drain   ${ZTA_OLD_HOSTNAME} --ignore-daemonsets --delete-emptydir-data --grace-period=60 --timeout=5m
    3. kubectl delete node ${ZTA_OLD_HOSTNAME}
    4. (manual on old VM, if reachable):
         sudo kubeadm reset --force
         sudo rm -rf /etc/cni/net.d /var/lib/cni
EOF

if [ "${DRY_RUN}" -eq 1 ]; then
  log_ok "DRY-RUN — exiting without changes"
  exit 0
fi

if [ "${NO_PROMPT}" -ne 1 ]; then
  printf '\n%s' "Proceed? [y/N] "
  read -r ans
  case "${ans}" in y|Y|yes|YES) ;; *) log_err "Aborted by user."; exit 2 ;; esac
fi

# ===== 2. Cordon =====
log_step "[1/3] Cordon ${ZTA_OLD_HOSTNAME}"
if kubectl get node "${ZTA_OLD_HOSTNAME}" -o jsonpath='{.spec.unschedulable}' 2>/dev/null | grep -q true; then
  log_info "  already cordoned"
else
  kubectl cordon "${ZTA_OLD_HOSTNAME}"
  log_ok "  cordoned"
fi

# ===== 3. Drain =====
log_step "[2/3] Drain ${ZTA_OLD_HOSTNAME}"
# Why these flags:
#   --ignore-daemonsets       : cilium-agent and node-exporter are DS;
#                              they cannot be drained, only deleted with the node.
#   --delete-emptydir-data    : permitted because no stateful workload should be
#                              pinned here yet (PROGRESS Phase 3 not started).
#   --force                   : tolerate orphan pods (kubelet on old node may be
#                              unreachable; the controller-manager will GC).
#   --grace-period=60         : give pods time to shut down cleanly.
#   --timeout=5m              : bound the operation so we don't block forever
#                              if old node never acks the eviction.
#   --skip-wait-for-delete-timeout=30 : if a pod takes >30s to confirm deletion
#                              (typical when kubelet is unreachable), proceed.
if ! kubectl drain "${ZTA_OLD_HOSTNAME}" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force \
  --grace-period=60 \
  --timeout=5m \
  --skip-wait-for-delete-timeout=30; then
  log_warn "  drain finished with non-zero status (old node likely unreachable)."
  log_warn "  Continuing — apiserver will GC orphan pods after eviction window."
fi
log_ok "  drain phase complete"

# ===== 4. Delete node =====
log_step "[3/3] Delete node ${ZTA_OLD_HOSTNAME}"
kubectl delete node "${ZTA_OLD_HOSTNAME}" --ignore-not-found
log_ok "  node deleted"

# ===== 5. Verify =====
log_step "Verify cluster state"
kubectl get nodes -o wide
log_info ""
log_info "Pods still on Pending due to nodeAffinity? Check:"
log_info "  kubectl get pod -A -o wide | grep ${ZTA_OLD_HOSTNAME} || echo '(none)'"
log_info ""
log_info "If you had stateful workloads pinned to ${ZTA_OLD_HOSTNAME} via"
log_info "nodeAffinity, update their manifests now to point at ${ZTA_NEW_HOSTNAME}:"
log_info "  grep -rln '${ZTA_OLD_HOSTNAME}' infras/k8s-yaml/ k8s-management/"
log_info ""

cat <<EOF

==========================================================
Manual follow-up on the OLD VM (${ZTA_OLD_HOSTNAME})
==========================================================
If ${ZTA_OLD_HOSTNAME} is still bootable and reachable, run there to free
its disk and stop kubelet from trying to rejoin a dead identity:

  sudo systemctl stop kubelet
  sudo kubeadm reset --force
  sudo rm -rf /etc/cni/net.d /var/lib/cni /var/lib/containerd
  sudo systemctl disable kubelet

If you plan to delete the VM, just power it off in libvirt/VMware first.

Don't forget to update PROGRESS.md "Recent events" and bump the
WORKER_HOSTNAMES / DATA_NODE entries in config.env to reflect the new
data-tier node.
EOF
