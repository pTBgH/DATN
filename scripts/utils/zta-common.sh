#!/usr/bin/env bash

yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }

wait_for_dns() {
  local hosts=("$@")
  local timeout="${ZTA_DNS_WAIT_TIMEOUT:-120}"
  local interval="${ZTA_DNS_WAIT_INTERVAL:-5}"
  local elapsed=0

  [ "${#hosts[@]}" -gt 0 ] || hosts=(github.com)

  while true; do
    local failed=()
    for host in "${hosts[@]}"; do
      if ! getent ahosts "$host" >/dev/null 2>&1; then
        failed+=("$host")
      fi
    done

    if [ "${#failed[@]}" -eq 0 ]; then
      return 0
    fi

    if [ "$elapsed" -ge "$timeout" ]; then
      yellow "    DNS still failing after ${timeout}s: ${failed[*]}"
      yellow "    Check host resolver: resolvectl status / sudo systemctl restart systemd-resolved"
      return 1
    fi

    yellow "    DNS not ready for: ${failed[*]} — retrying in ${interval}s (${elapsed}/${timeout}s)"
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
}

helm_repo_update_retry() {
  local attempts="${ZTA_HELM_REPO_UPDATE_RETRIES:-5}"
  local delay="${ZTA_HELM_REPO_UPDATE_BACKOFF:-10}"
  local cmd=(helm repo update "$@")

  for attempt in $(seq 1 "$attempts"); do
    if "${cmd[@]}"; then
      return 0
    fi
    yellow "    helm repo update failed (attempt ${attempt}/${attempts})"
    [ "$attempt" -lt "$attempts" ] || break
    sleep "$delay"
  done

  return 1
}

# require_host_ram_mi <required_available_mi> <component_name>
#
# Refuses to proceed if the *host VM* has less than the requested amount of
# RAM available (column "available" from `free -m`). On Kind, every node
# container shares the same host kernel, so host RAM pressure manifests as
# kube-apiserver lease timeouts (5s) → leader-election cascades on
# kube-scheduler, kube-controller-manager, cilium-operator,
# spire-controller-manager, etc. — even when `kubectl top node` reports
# plenty of headroom (cgroup vs. kernel pressure mismatch).
#
# Override by setting ZTA_HOST_RAM_CHECK_FATAL=0 to convert error -> warning,
# or COMPONENT_REQUIRED_HOST_MI to lower the threshold.
require_host_ram_mi() {
  local required_mi="${1:-1500}"
  local component="${2:-component}"

  if ! command -v free >/dev/null 2>&1; then
    yellow "    [pre-flight] 'free' not available — skipping host RAM check for $component"
    return 0
  fi

  local available_mi
  available_mi=$(free -m | awk '/^Mem:/ {print $7}')

  if [ -z "$available_mi" ] || ! [[ "$available_mi" =~ ^[0-9]+$ ]]; then
    yellow "    [pre-flight] could not parse 'free -m' output — skipping host RAM check for $component"
    return 0
  fi

  if [ "$available_mi" -lt "$required_mi" ]; then
    yellow "    [pre-flight] $component wants >=${required_mi}Mi available on HOST VM"
    yellow "                 host has only ${available_mi}Mi available right now"
    yellow "                 (Kind nodes share host kernel — apiserver will flap if host is squeezed)"
    yellow "                 free more RAM first, e.g.:"
    yellow "                   bash scripts/free-ram-for-tetragon.sh"
    if [ "${ZTA_HOST_RAM_CHECK_FATAL:-1}" = "1" ]; then
      yellow "                 (set ZTA_HOST_RAM_CHECK_FATAL=0 to bypass)"
      return 1
    fi
  else
    yellow "    [pre-flight] host RAM OK for $component: ${available_mi}Mi available (need ${required_mi}Mi)"
  fi
  return 0
}

# require_node_ram_mi <required_per_node_mi> <component_name>
#
# Refuses to proceed if any cluster node has less free memory than the
# requested amount. Falls back to a warning if `kubectl top node` is not
# available (e.g. metrics-server not installed yet).
#
# Note: this checks per-Kind-node cgroup memory, NOT host VM RAM. For Kind
# clusters the host VM is the actual constraint — call require_host_ram_mi
# in addition.
require_node_ram_mi() {
  local required_mi="${1:-512}"
  local component="${2:-component}"

  if ! command -v kubectl >/dev/null 2>&1; then
    return 0
  fi

  local hint_free_ram="bash scripts/free-ram-for-tetragon.sh"

  # We approximate "free RAM per node" from `kubectl top node`.
  # kubectl top sometimes warns "metrics not available yet", so allow override.
  local top_out
  top_out=$(kubectl top node --no-headers 2>/dev/null || true)
  if [ -z "$top_out" ]; then
    yellow "    [pre-flight] kubectl top node unavailable — skipping RAM check for $component"
    yellow "                 (check manually: free -m on host; aim for >=${required_mi}Mi free)"
    return 0
  fi

  local node mem_used_mi mem_pct under=0 worst_mi="" worst_node=""
  while read -r line; do
    [ -z "$line" ] && continue
    node=$(awk '{print $1}' <<<"$line")
    # column 4 is memory bytes-used (e.g. 1234Mi), column 5 is percent
    mem_used_mi=$(awk '{print $4}' <<<"$line" | sed -E 's/Mi$//; s/Gi$/000/')
    mem_pct=$(awk '{print $5}' <<<"$line" | tr -d '%')
    if [ -z "$mem_used_mi" ] || [ -z "$mem_pct" ] || [ "$mem_pct" -le 0 ]; then
      continue
    fi

    # capacity_mi = used * 100 / pct ; free_mi = capacity_mi - used
    local cap_mi free_mi
    cap_mi=$(( mem_used_mi * 100 / mem_pct ))
    free_mi=$(( cap_mi - mem_used_mi ))

    if [ "$free_mi" -lt "$required_mi" ]; then
      under=$((under + 1))
      if [ -z "$worst_mi" ] || [ "$free_mi" -lt "$worst_mi" ]; then
        worst_mi="$free_mi"
        worst_node="$node"
      fi
    fi
  done <<<"$top_out"

  if [ "$under" -gt 0 ]; then
    yellow "    [pre-flight] $component wants >=${required_mi}Mi free per node"
    yellow "                 worst node $worst_node has only ${worst_mi}Mi free"
    yellow "                 free more RAM first, e.g.:"
    yellow "                   $hint_free_ram"
    if [ "${ZTA_RAM_CHECK_FATAL:-1}" = "1" ]; then
      yellow "                 (set ZTA_RAM_CHECK_FATAL=0 to bypass)"
      return 1
    fi
  fi
  return 0
}

# helm_install_with_recovery <release> <chart> <namespace> <values_file> <timeout>
# Wrapper that adds:
#   - --atomic --cleanup-on-fail   so failed installs roll back instead of
#                                  leaving orphan workloads.
#   - retry once with --replace if first attempt hits a "release in unknown
#     state" error (rare, happens after kubelet evict during install).
helm_install_with_recovery() {
  local release="$1" chart="$2" namespace="$3" values="$4" timeout="${5:-600s}"
  shift 5

  helm upgrade --install "$release" "$chart" \
    -n "$namespace" \
    -f "$values" \
    --wait \
    --atomic --cleanup-on-fail \
    --timeout="$timeout" "$@"
}
