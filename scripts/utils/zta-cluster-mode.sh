#!/usr/bin/env bash
# zta-cluster-mode.sh — shared cluster-mode helper.
#
# Two modes:
#   vm    (default) — 4-VM cluster bootstrapped via kubeadm + Tailscale.
#                     See doc/migration/scripts/bootstrap.sh + phases/*.sh.
#   kind            — legacy single-host Kind cluster, useful for local dev
#                     and CI smoke tests. Kept behind a flag/env var so the
#                     old workflow still works.
#
# Mode is resolved in this priority order (highest first):
#   1. ZTA_CLUSTER_MODE env var ("vm" or "kind")
#   2. --kind / --vm CLI flag (parsed via zta_parse_mode_flag)
#   3. default: "vm"
#
# Source this file from any script that needs to branch on mode. Functions
# defined here use the `zta_` prefix to avoid colliding with script-local
# functions.

ZTA_CLUSTER_MODE=${ZTA_CLUSTER_MODE:-vm}

# is_kind_mode: returns 0 if mode == "kind".
is_kind_mode() {
  [ "${ZTA_CLUSTER_MODE}" = "kind" ]
}

# is_vm_mode: returns 0 if mode == "vm".
is_vm_mode() {
  [ "${ZTA_CLUSTER_MODE}" = "vm" ]
}

# zta_parse_mode_flag: parses --kind / --vm out of the script's argv.
#
# CANNOT use `$(...)` here: command substitution runs in a subshell, so
# mutations to ZTA_CLUSTER_MODE would be lost. Instead, write the remaining
# args into a global array `ZTA_PARSED_ARGS` and let the caller rebind $@:
#
#   zta_parse_mode_flag "$@"
#   set -- "${ZTA_PARSED_ARGS[@]:-}"
#
# After the call, ZTA_CLUSTER_MODE is updated if --kind / --vm was present,
# and ZTA_PARSED_ARGS contains every other argv element (order preserved).
zta_parse_mode_flag() {
  ZTA_PARSED_ARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) ZTA_CLUSTER_MODE=kind ;;
      --vm)   ZTA_CLUSTER_MODE=vm ;;
      *)      ZTA_PARSED_ARGS+=("$1") ;;
    esac
    shift
  done
  export ZTA_CLUSTER_MODE
}

# zta_apply_parsed_args: rebind $@ in the caller's scope. Use AFTER calling
# zta_parse_mode_flag. This wraps the `set --` boilerplate so callers don't
# have to dance around `set -u` and empty arrays:
#
#   zta_parse_mode_flag "$@"
#   eval "$(zta_apply_parsed_args_cmd)"
#
# Returns a string the caller `eval`s. Bash 4.x compatible.
zta_apply_parsed_args_cmd() {
  if [ "${#ZTA_PARSED_ARGS[@]}" -eq 0 ]; then
    echo "set --"
    return
  fi
  local out='set -- '
  local arg
  for arg in "${ZTA_PARSED_ARGS[@]}"; do
    out+="$(printf '%q ' "$arg")"
  done
  echo "$out"
}

# zta_mode_banner: prints a one-line banner showing which mode is active.
# Call early in a script after parsing flags so logs are unambiguous.
zta_mode_banner() {
  local script_name=${1:-${BASH_SOURCE[1]##*/}}
  if is_kind_mode; then
    echo "🔧 [${script_name}] Cluster mode: KIND (legacy single-host)"
  else
    echo "🔧 [${script_name}] Cluster mode: VM (4-node kubeadm cluster)"
  fi
}

# zta_require_kind: hard-exit with a helpful pointer if not in Kind mode.
# Used by Kind-only scripts (e.g. 01-setup-cluster.sh) that have no VM
# equivalent built in. Intentionally non-destructive: simply exits with
# a pointer to the VM equivalent so the user can switch tracks safely.
#   $1: name of the calling script (for the message)
#   $2: pointer to the VM equivalent
zta_require_kind() {
  if is_kind_mode; then
    return 0
  fi
  local script_name="${1:-${BASH_SOURCE[1]##*/}}"
  local vm_pointer="${2:-doc/migration/scripts/bootstrap.sh}"
  echo "❌ ${script_name} is a KIND-ONLY script."
  echo
  echo "   Current mode: ZTA_CLUSTER_MODE=${ZTA_CLUSTER_MODE}."
  echo
  echo "   This script creates / manipulates a Kind cluster and would do"
  echo "   nothing useful (or worse) against a real VM cluster. Refusing"
  echo "   to run to avoid corrupting state."
  echo
  echo "   To run anyway against a Kind cluster:"
  echo "     ${script_name} --kind        # (or: ZTA_CLUSTER_MODE=kind ${script_name})"
  echo
  echo "   For the VM-mode equivalent, see:"
  echo "     ${vm_pointer}"
  exit 1
}

# zta_require_vm: hard-exit if not in VM mode. Mirror of zta_require_kind for
# scripts that only make sense against a real cluster (e.g. decommission-srv04.sh).
zta_require_vm() {
  if is_vm_mode; then
    return 0
  fi
  local script_name="${1:-${BASH_SOURCE[1]##*/}}"
  echo "❌ ${script_name} is a VM-ONLY script."
  echo
  echo "   Current mode: ZTA_CLUSTER_MODE=${ZTA_CLUSTER_MODE}."
  echo
  echo "   This script manipulates the multi-node kubeadm cluster and is"
  echo "   not meaningful for a single-host Kind cluster."
  echo
  echo "   Override (not recommended) with:"
  echo "     ${script_name} --vm          # (or: ZTA_CLUSTER_MODE=vm ${script_name})"
  exit 1
}

# zta_resolve_vm_registry_host: print the <host:port> a host-side docker can
# push images to so the in-cluster pull will succeed.
#
# Resolution order (highest priority first):
#   1. $VM_REGISTRY_HOST env var (explicit override).
#   2. kubectl: read NodePort from svc/docker-registry-nodeport in the
#      `registry` namespace, then pair it with the node hosting the
#      registry pod (resolved via getent → tailnet/LAN hostname when
#      reachable, falling back to the node's InternalIP).
#
# Returns 0 and prints "host:port" on success, returns non-zero with
# nothing on stdout on failure. Callers should treat failure as
# "registry not deployed yet" and surface a helpful error.
#
# Why no `localhost:5000` fallback: srv01 has no host-level docker
# daemon push target — using localhost:5000 silently pushes to nothing
# (or the wrong target if the operator coincidentally has another
# registry running) and the cluster pull then ImagePullBackOff's. We
# would rather fail fast than push to /dev/null.
zta_resolve_vm_registry_host() {
  if [ -n "${VM_REGISTRY_HOST:-}" ]; then
    echo "$VM_REGISTRY_HOST"
    return 0
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    return 1
  fi

  local nodeport
  nodeport=$(kubectl get svc -n registry docker-registry-nodeport \
    -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)
  if [ -z "$nodeport" ]; then
    return 1
  fi

  local node_hostname
  node_hostname=$(kubectl get pods -n registry \
    -l app=docker-registry \
    -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
  if [ -z "$node_hostname" ]; then
    return 1
  fi

  if command -v getent >/dev/null 2>&1 \
      && getent hosts "$node_hostname" >/dev/null 2>&1; then
    echo "${node_hostname}:${nodeport}"
    return 0
  fi

  local node_ip
  node_ip=$(kubectl get node "$node_hostname" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' \
    2>/dev/null || true)
  if [ -n "$node_ip" ]; then
    echo "${node_ip}:${nodeport}"
    return 0
  fi

  return 1
}

# zta_resolve_vm_registry_host_or_die: convenience wrapper that prints a
# uniform error message + exits 1 when resolution fails. Use this when
# the script can't proceed without a registry endpoint.
#
#   REGISTRY_HOST="$(zta_resolve_vm_registry_host_or_die)"
zta_resolve_vm_registry_host_or_die() {
  local resolved
  if resolved="$(zta_resolve_vm_registry_host)" && [ -n "$resolved" ]; then
    echo "$resolved"
    return 0
  fi
  {
    echo "❌ VM mode: cannot resolve registry endpoint."
    echo
    echo "   Either:"
    echo "     1. Deploy the in-cluster registry first:"
    echo "          kubectl apply -f infras/k8s-yaml/12-docker-registry.yaml"
    echo "          kubectl -n registry wait --for=condition=Ready pod \\"
    echo "            -l app=docker-registry --timeout=120s"
    echo "        Then re-run this script — host:port auto-resolves from svc."
    echo
    echo "     2. Or set VM_REGISTRY_HOST explicitly, e.g.:"
    echo "          export VM_REGISTRY_HOST=7189srv05.taildc1739.ts.net:30005"
  } >&2
  exit 1
}
