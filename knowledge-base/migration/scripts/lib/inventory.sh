#!/usr/bin/env bash
# knowledge-base/migration/scripts/lib/inventory.sh
#
# Maps a server identifier (01, 02, 03, 04 — or any hostname matching the
# CP_HOSTNAME / WORKER_HOSTNAMES from config.env) to a role + canonical
# hostname. Sourced by bootstrap.sh so a single `--server=NN` flag is all
# the user has to type on each VM.
#
# Public API (functions exported into the caller's shell):
#   inventory_resolve_role  <server_id>   -> echoes "control-plane" | "worker"
#   inventory_resolve_host  <server_id>   -> echoes the canonical hostname
#                                            (e.g. "7189srv02")
#   inventory_list                        -> prints "<host> <role>" rows
#
# `<server_id>` accepts:
#   - the short suffix (01, 02, 03, 04)
#   - the full hostname (7189srv01, 7189srv02, …)
#   - the special token "auto" -> resolves via `hostname` of the local VM
#
# Depends on:
#   - load_config (must be called first) so CP_HOSTNAME + WORKER_HOSTNAMES
#     are populated from config.env / env vars.

# ---- internal helpers ----------------------------------------------------

_inventory_normalize_host() {
  # Accepts "01", "1", "srv01", "7189srv01", returns the canonical hostname
  # as configured in CP_HOSTNAME / WORKER_HOSTNAMES.
  local raw="$1" candidate
  # Try literal match first
  for h in "${CP_HOSTNAME}" ${WORKER_HOSTNAMES}; do
    if [ "${raw}" = "${h}" ]; then printf '%s' "${h}"; return 0; fi
  done
  # Match by suffix: strip leading non-digits and zero-pad to 2 digits
  local stripped="${raw##*[!0-9]}"
  if [ -n "${stripped}" ]; then
    local padded
    padded="$(printf '%02d' "${stripped}" 2>/dev/null || echo "${stripped}")"
    for h in "${CP_HOSTNAME}" ${WORKER_HOSTNAMES}; do
      case "${h}" in
        *"${padded}") printf '%s' "${h}"; return 0 ;;
      esac
    done
  fi
  return 1
}

# ---- public API ----------------------------------------------------------

inventory_resolve_host() {
  local raw="$1"
  if [ "${raw}" = "auto" ]; then
    raw="$(hostname)"
  fi
  if ! _inventory_normalize_host "${raw}"; then
    log_err "Unknown server id '${raw}'. Known hosts:"
    log_err "  CP:      ${CP_HOSTNAME}"
    log_err "  Workers: ${WORKER_HOSTNAMES}"
    return 1
  fi
}

inventory_resolve_role() {
  local host
  host="$(inventory_resolve_host "$1")" || return 1
  if [ "${host}" = "${CP_HOSTNAME}" ]; then
    printf 'control-plane'
  else
    case " ${WORKER_HOSTNAMES} " in
      *" ${host} "*) printf 'worker' ;;
      *) log_err "Host '${host}' is not in CP_HOSTNAME or WORKER_HOSTNAMES"; return 1 ;;
    esac
  fi
}

inventory_list() {
  printf '  %-12s %s\n' "${CP_HOSTNAME}" "control-plane"
  for h in ${WORKER_HOSTNAMES}; do
    printf '  %-12s %s\n' "${h}" "worker"
  done
}
