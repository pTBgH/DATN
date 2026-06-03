#!/usr/bin/env bash
# knowledge-base/migration/scripts/00-status-report.sh
#
# Inspect-only. Generates a Markdown status report covering:
#   - host OS (kernel, RAM, disk, swap, CPU load)
#   - network (Tailscale + ens33)
#   - container runtime (containerd)
#   - kubelet
#   - if kubectl is reachable: nodes, pods (top 20), top nodes/pods
#   - common files we care about (kubeadm-config.yaml, kubeconfig)
#
# This script makes ZERO state changes. Run it before/after each phase.
#
# Usage:
#   bash knowledge-base/migration/scripts/00-status-report.sh
#
# Output:
#   ~/.zta-migration/reports/00-status-<host>-<UTC>.md

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

load_config "${SCRIPT_DIR}/config.env"
migration_start "00-status"

start_report "00-status"
REPORT="${ZTA_CURRENT_REPORT}"

# ===== Host facts =====
md_section "Host"
md_emit "| Field | Value |"
md_emit "|-------|-------|"
md_kv "Hostname" "$(hostname)"
md_kv "Kernel"   "$(uname -r)"
md_kv "Distro"   "$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2- | tr -d '\"')"
md_kv "Uptime"   "$(uptime -p 2>/dev/null || uptime)"
md_kv "User"     "${USER:-$(id -un)}"
md_kv "Time"     "$(date -Iseconds)"

# ===== Resources =====
md_section "Resources"
md_codeblock_start
free -h >> "${ZTA_CURRENT_REPORT}"
md_codeblock_end

md_emit ""
md_emit "**Disk:**"
md_codeblock_start
df -h / /var /home 2>/dev/null | sort -u >> "${ZTA_CURRENT_REPORT}" || true
md_codeblock_end

md_emit ""
md_emit "**CPU:**"
md_codeblock_start
echo "cores: $(nproc)" >> "${ZTA_CURRENT_REPORT}"
echo "model: $(awk -F: '/^model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')" >> "${ZTA_CURRENT_REPORT}"
echo "load:  $(awk '{print $1, $2, $3}' /proc/loadavg)" >> "${ZTA_CURRENT_REPORT}"
md_codeblock_end

# ===== Swap =====
md_section "Swap"
md_codeblock_start
swapon --show 2>/dev/null >> "${ZTA_CURRENT_REPORT}" || echo "(no swap)" >> "${ZTA_CURRENT_REPORT}"
echo "" >> "${ZTA_CURRENT_REPORT}"
sysctl vm.swappiness 2>/dev/null >> "${ZTA_CURRENT_REPORT}" || true
md_codeblock_end

# ===== Network =====
md_section "Network"
md_emit "**Interfaces:**"
md_codeblock_start
ip -br addr 2>/dev/null >> "${ZTA_CURRENT_REPORT}" || ip addr >> "${ZTA_CURRENT_REPORT}"
md_codeblock_end

md_emit ""
md_emit "**Routes:**"
md_codeblock_start
ip route 2>/dev/null >> "${ZTA_CURRENT_REPORT}" || true
md_codeblock_end

md_emit ""
md_emit "**Tailscale:**"
md_codeblock_start
if command -v tailscale >/dev/null 2>&1; then
  echo "tailscale ip -4: $(tailscale ip -4 2>/dev/null || echo '(not up)')" >> "${ZTA_CURRENT_REPORT}"
  echo "" >> "${ZTA_CURRENT_REPORT}"
  tailscale status 2>/dev/null >> "${ZTA_CURRENT_REPORT}" || echo "(tailscale not authenticated)" >> "${ZTA_CURRENT_REPORT}"
else
  echo "(tailscale not installed)" >> "${ZTA_CURRENT_REPORT}"
fi
md_codeblock_end

md_emit ""
md_emit "**DNS:**"
md_codeblock_start
{
  echo "/etc/resolv.conf:"
  cat /etc/resolv.conf 2>/dev/null | head -10
  echo ""
  echo "Probing common targets:"
  for t in github.com pkgs.k8s.io download.docker.com helm.cilium.io; do
    if getent ahosts "${t}" >/dev/null 2>&1; then
      echo "  ${t}: OK"
    else
      echo "  ${t}: FAIL"
    fi
  done
} >> "${ZTA_CURRENT_REPORT}"
md_codeblock_end

# ===== Services =====
md_section "Services"
md_emit "| Service | Active | Enabled |"
md_emit "|---------|--------|---------|"
for s in tailscaled containerd kubelet docker; do
  active=$(systemctl is-active "${s}" 2>/dev/null || echo "(absent)")
  enabled=$(systemctl is-enabled "${s}" 2>/dev/null || echo "(absent)")
  md_kv "${s}" "${active} / ${enabled}"
done

# ===== K8s versions =====
md_section "K8s tooling"
md_emit "| Tool | Version |"
md_emit "|------|---------|"
for c in kubeadm kubelet kubectl helm cilium ctr containerd runc; do
  if command -v "${c}" >/dev/null 2>&1; then
    v="$(${c} --version 2>/dev/null | head -1 || ${c} version 2>/dev/null | head -1 || echo '(?)')"
    md_kv "${c}" "${v}"
  else
    md_kv "${c}" "(not installed)"
  fi
done

# ===== Cluster (if reachable) =====
md_section "Cluster (kubectl)"
if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
  md_emit "**cluster-info:**"
  md_codeblock_start
  kubectl cluster-info --request-timeout=5s >> "${ZTA_CURRENT_REPORT}" || true
  md_codeblock_end

  md_emit ""
  md_emit "**Nodes:**"
  md_codeblock_start
  kubectl get nodes -o wide --request-timeout=10s >> "${ZTA_CURRENT_REPORT}" 2>&1 || true
  md_codeblock_end

  md_emit ""
  md_emit "**Top nodes:**"
  md_codeblock_start
  kubectl top nodes --request-timeout=10s >> "${ZTA_CURRENT_REPORT}" 2>&1 || \
    echo "(metrics-server not yet up)" >> "${ZTA_CURRENT_REPORT}"
  md_codeblock_end

  md_emit ""
  md_emit "**Pods (kube-system):**"
  md_codeblock_start
  kubectl -n kube-system get pod -o wide --request-timeout=10s >> "${ZTA_CURRENT_REPORT}" 2>&1 || true
  md_codeblock_end

  md_emit ""
  md_emit "**Cilium status (if installed):**"
  md_codeblock_start
  if kubectl -n kube-system get ds cilium >/dev/null 2>&1; then
    kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium status --request-timeout=10s \
      >> "${ZTA_CURRENT_REPORT}" 2>&1 || echo "(cilium not ready)" >> "${ZTA_CURRENT_REPORT}"
  else
    echo "(cilium DS not present)" >> "${ZTA_CURRENT_REPORT}"
  fi
  md_codeblock_end
else
  md_emit "(kubectl not configured or apiserver unreachable from this host)"
fi

# ===== Files we care about =====
md_section "Migration state files"
md_emit "**~/.zta-migration/state.* (per-phase markers):**"
md_codeblock_start
ls -la "${ZTA_STATE_DIR}/" 2>/dev/null | sed 's|'"${HOME}"'|~|g' >> "${ZTA_CURRENT_REPORT}" || true
md_codeblock_end

md_emit ""
md_emit "**Done markers:**"
md_codeblock_start
ls -1 "${ZTA_STATE_DIR}/done."* 2>/dev/null | sed 's|'"${HOME}"'|~|g' >> "${ZTA_CURRENT_REPORT}" || \
  echo "(none)" >> "${ZTA_CURRENT_REPORT}"
md_codeblock_end

# ===== Summary =====
md_section "Quick assertions"

assert() {
  # $1 = label  $2 = expected  $3 = actual
  local pass="FAIL"
  if [ "$2" = "$3" ]; then pass="PASS"; fi
  printf '| %s | %s | %s | %s |\n' "$1" "$2" "$3" "${pass}" >> "${ZTA_CURRENT_REPORT}"
}

md_emit "| Check | Expected | Actual | Result |"
md_emit "|-------|----------|--------|--------|"

ts_active="$(systemctl is-active tailscaled 2>/dev/null || echo absent)"
assert "tailscaled active" "active" "${ts_active}"

ctr_active="$(systemctl is-active containerd 2>/dev/null || echo absent)"
assert "containerd active" "active" "${ctr_active}"

# Hostname matches expected for this VM (if config matches our 4 hostnames)
case "$(hostname)" in
  ${CP_HOSTNAME}|${WORKER_HOSTNAMES// /|}) ok=yes ;;
  *) ok=no ;;
esac
assert "hostname matches plan" "yes" "${ok:-no}"

# RAM check (>= 1500 MiB available)
ram_avail="$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)"
if [ "${ram_avail}" -ge 1000 ]; then ram_ok=yes; else ram_ok=no; fi
assert "RAM available >= 1000 MiB" "yes" "${ram_ok}"

# Swap behavior
swappiness="$(sysctl -n vm.swappiness 2>/dev/null || echo 60)"
if [ "${swappiness}" -le 30 ]; then sw_ok=yes; else sw_ok=no; fi
assert "swappiness tuned (<=30)" "yes" "${sw_ok}"

# Modules
for m in br_netfilter overlay; do
  has="$(lsmod 2>/dev/null | awk -v m="${m}" '$1==m {print "yes"; exit}')"
  assert "module ${m} loaded" "yes" "${has:-no}"
done

end_report

migration_end

echo ""
log_ok "Report written: ${REPORT}"
log_info "View it: less '${REPORT}'"
