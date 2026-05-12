#!/usr/bin/env bash
# doc/migration/scripts/bootstrap.sh
#
# Single-entry-point orchestrator for the ZTA multi-VM Kubernetes migration.
# Run this ONE script on EACH VM with the appropriate --server flag:
#
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=01   # on 7189srv01 (control-plane)
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=02   # on 7189srv02 (worker)
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=03   # on 7189srv03 (worker)
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=04   # on 7189srv04 (worker)
#
# Or auto-detect role from local hostname (recommended once you trust the
# inventory mapping in config.env):
#
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=auto
#
# The orchestrator resolves --server -> role -> phase sequence:
#   control-plane: host-prep, control-plane, cilium, cluster-services
#   worker       : host-prep, worker-join
#
# Each phase is a separate idempotent script in phases/. Failed phases halt
# the run unless --continue-on-fail is set. All phase logs are aggregated in
# ~/.zta-migration/runs/<ts>/ together with a SUMMARY.md.
#
# CLI flags (subset of zta-rebuild.sh's contract — same idioms):
#   --server=NN            (required) Server identifier: 01..04, "auto", or
#                          a full hostname matching CP_HOSTNAME / WORKER_HOSTNAMES
#   --phase=NAME[,NAME...] Run only the named phase(s) for this server's role
#   --from=NAME            Resume from phase NAME (inclusive)
#   --to=NAME              Stop after phase NAME (inclusive)
#   --skip=NAME[,NAME...]  Skip these phases
#   --list                 Print the phase plan + exit (does not need sudo)
#   --dry-run              Show what would run; execute nothing
#   --yes / -y             Skip confirmation prompts
#   --continue-on-fail     Don't halt on individual phase failure
#   --help / -h            Show this help
#
# Env vars passed through to phase scripts:
#   ZTA_JOIN_CMD           (worker only) Full `kubeadm join ...` command.
#                          Without this, worker-join.sh tries:
#                          (a) /etc/kubernetes/zta-join.sh on this host
#                          (b) ssh ptb@${CP_HOSTNAME} sudo cat ... (SSH_FETCH=1)
#                          Set ZTA_JOIN_CMD=... to skip fetching.
#   HOSTNAME_OVERRIDE      (host-prep only) Force hostname to NAME on this VM.
#   ZTA_AUTO_ROLLBACK=0    Disable each phase's auto-rollback on failure.
#
# Examples:
#   # Full bring-up on the control-plane VM (4 phases):
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --yes
#
#   # Skip cluster-services on initial CP bring-up (you'll run it later
#   # after all workers are joined):
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 \
#       --skip=cluster-services --yes
#
#   # Run only cilium phase (the cluster is already up, you're re-installing CNI):
#   sudo -E bash doc/migration/scripts/bootstrap.sh --server=01 --phase=cilium --yes
#
#   # Dry-run to inspect what would happen on srv02:
#   bash doc/migration/scripts/bootstrap.sh --server=02 --dry-run
#
# Logs (per run):
#   ~/.zta-migration/runs/<timestamp>/host-prep.log
#   ~/.zta-migration/runs/<timestamp>/control-plane.log
#   ~/.zta-migration/runs/<timestamp>/cilium.log
#   ~/.zta-migration/runs/<timestamp>/SUMMARY.md
#
set -uo pipefail   # NOT -e: each phase's failure is handled by run_phase

# ===== Resolve paths =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASES_DIR="${SCRIPT_DIR}/phases"

# ===== Source library + inventory =====
# common.sh sets ZTA_STATE_DIR + logging helpers + colors. We source it but do
# NOT call migration_start() — bootstrap.sh is the orchestrator, each phase
# script calls migration_start() itself.
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/inventory.sh
. "${SCRIPT_DIR}/lib/inventory.sh"

load_config "${SCRIPT_DIR}/config.env"

# ===== Phase catalog =====
# Each entry: "phase-name|description|script-file"
# script-file is resolved relative to PHASES_DIR.
declare -a PHASES=(
  "host-prep|Install kube binaries + containerd + CNI plugins + Tailscale + sysctls|host-prep.sh"
  "control-plane|kubeadm init (skip kube-proxy addon, Tailscale-aware)|control-plane.sh"
  "worker-join|kubeadm join (fetches token from CP)|worker-join.sh"
  "cilium|Install Cilium CNI (kube-proxy replacement, VXLAN tunnel)|cilium.sh"
  "cluster-services|Gateway API CRDs + cert-manager + ingress-nginx + metrics-server + local-path|cluster-services.sh"
)

# Phase sequences per role.
declare -a CP_PHASE_ORDER=(host-prep control-plane cilium cluster-services)
declare -a WORKER_PHASE_ORDER=(host-prep worker-join)

# ===== CLI defaults =====
SERVER=""
PHASE_FILTER=""        # comma-separated explicit phases
FROM_PHASE=""
TO_PHASE=""
SKIP_PHASES=""
DRY_RUN=0
LIST_ONLY=0
NO_PROMPT=0
CONTINUE_ON_FAIL=0

usage() {
  sed -n '2,68p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in
    --server=*)        SERVER="${arg#--server=}" ;;
    --phase=*)         PHASE_FILTER="${arg#--phase=}" ;;
    --from=*)          FROM_PHASE="${arg#--from=}" ;;
    --to=*)            TO_PHASE="${arg#--to=}" ;;
    --skip=*)          SKIP_PHASES="${arg#--skip=}" ;;
    --list)            LIST_ONLY=1 ;;
    --dry-run)         DRY_RUN=1 ;;
    --yes|-y)          NO_PROMPT=1 ;;
    --continue-on-fail) CONTINUE_ON_FAIL=1 ;;
    --help|-h)         usage 0 ;;
    *)
      log_err "Unknown argument: $arg"
      usage 2
      ;;
  esac
done

# ===== Validate =====
if [ -z "${SERVER}" ] && [ "${LIST_ONLY}" -ne 1 ]; then
  log_err "--server=NN is required (or use --list to inspect the phase catalog)"
  usage 2
fi

if [ "${LIST_ONLY}" -eq 1 ] && [ -z "${SERVER}" ]; then
  # Pure --list (no --server): show the inventory + phase catalog and exit
  printf '\n%s\n' "Inventory (from config.env / env vars):"
  inventory_list
  printf '\n%s\n' "Phase catalog (all phases — actual run depends on role):"
  for entry in "${PHASES[@]}"; do
    IFS='|' read -r name desc file <<<"${entry}"
    printf '  %-18s %s\n' "${name}" "${desc}"
  done
  printf '\n%s\n' "Role -> phase order:"
  printf '  %-18s %s\n' "control-plane" "${CP_PHASE_ORDER[*]}"
  printf '  %-18s %s\n' "worker"        "${WORKER_PHASE_ORDER[*]}"
  exit 0
fi

# Resolve server -> hostname + role
TARGET_HOST="$(inventory_resolve_host "${SERVER}")" || exit 1
TARGET_ROLE="$(inventory_resolve_role "${SERVER}")" || exit 1

# Verify we're actually running ON the right VM. Refuse to run on the wrong
# host unless --yes is given (override for special cases like a fresh
# re-image where hostname hasn't been set yet — host-prep will fix it).
LOCAL_HOST="$(hostname)"
if [ "${LOCAL_HOST}" != "${TARGET_HOST}" ]; then
  log_warn "Host mismatch: local='${LOCAL_HOST}' target='${TARGET_HOST}'"
  log_warn "  bootstrap.sh is intended to run ON each VM, not orchestrate remotely."
  log_warn "  If this is a fresh VM and host-prep will rename it, continue with --yes."
  if [ "${NO_PROMPT}" -ne 1 ] && [ "${DRY_RUN}" -ne 1 ] && [ "${LIST_ONLY}" -ne 1 ]; then
    printf '%s' "Continue anyway? [y/N] "
    read -r ans
    case "${ans}" in y|Y|yes|YES) ;; *) log_err "Aborted by user."; exit 2 ;; esac
  fi
fi

# Build the phase sequence for this role.
if [ "${TARGET_ROLE}" = "control-plane" ]; then
  PHASE_ORDER=("${CP_PHASE_ORDER[@]}")
else
  PHASE_ORDER=("${WORKER_PHASE_ORDER[@]}")
fi

# Filter by --phase / --from / --to / --skip
filter_phases() {
  local -n in_arr=$1
  local -n out_arr=$2
  local include=1
  if [ -n "${FROM_PHASE}" ]; then include=0; fi
  out_arr=()
  for p in "${in_arr[@]}"; do
    # --phase= explicit list overrides everything
    if [ -n "${PHASE_FILTER}" ]; then
      case ",${PHASE_FILTER}," in
        *",${p},"*) out_arr+=("${p}") ;;
      esac
      continue
    fi
    # --from: start including once we see the from-phase
    if [ "${include}" -eq 0 ] && [ "${p}" = "${FROM_PHASE}" ]; then
      include=1
    fi
    [ "${include}" -eq 1 ] || continue
    # --skip
    case ",${SKIP_PHASES}," in
      *",${p},"*) continue ;;
    esac
    out_arr+=("${p}")
    # --to: stop after the to-phase
    if [ -n "${TO_PHASE}" ] && [ "${p}" = "${TO_PHASE}" ]; then
      include=0
    fi
  done
}

declare -a PLAN
filter_phases PHASE_ORDER PLAN

# ===== List mode (with --server) =====
if [ "${LIST_ONLY}" -eq 1 ]; then
  printf '\n%s\n' "Target: ${TARGET_HOST} (role=${TARGET_ROLE})"
  printf '%s\n' "Plan:"
  for p in "${PLAN[@]}"; do
    for entry in "${PHASES[@]}"; do
      IFS='|' read -r name desc file <<<"${entry}"
      [ "${name}" = "${p}" ] || continue
      printf '  %-18s %s\n' "${name}" "${desc}"
    done
  done
  exit 0
fi

if [ "${#PLAN[@]}" -eq 0 ]; then
  log_err "No phases to run after applying filters."
  log_err "  role: ${TARGET_ROLE}"
  log_err "  phase order: ${PHASE_ORDER[*]}"
  log_err "  --phase: ${PHASE_FILTER:-<none>}"
  log_err "  --from:  ${FROM_PHASE:-<none>}"
  log_err "  --to:    ${TO_PHASE:-<none>}"
  log_err "  --skip:  ${SKIP_PHASES:-<none>}"
  exit 2
fi

# ===== Pre-flight =====
if [ "${DRY_RUN}" -ne 1 ] && [ "${LIST_ONLY}" -ne 1 ]; then
  if [ "$(id -u)" -ne 0 ]; then
    log_err "bootstrap.sh requires root (phases write to /etc, systemctl, etc.)."
    log_err "  Re-run with: sudo -E bash doc/migration/scripts/bootstrap.sh --server=${SERVER}"
    exit 1
  fi
fi

# ===== Run banner =====
RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${ZTA_STATE_DIR}/runs/${RUN_TS}"
mkdir -p "${RUN_DIR}"
SUMMARY="${RUN_DIR}/SUMMARY.md"

cat <<EOF | tee "${RUN_DIR}/banner.txt" >&2
======================================================================
ZTA multi-VM migration — bootstrap.sh
======================================================================
  local host : ${LOCAL_HOST}
  target host: ${TARGET_HOST}
  role       : ${TARGET_ROLE}
  phases     : ${PLAN[*]}
  log dir    : ${RUN_DIR}
  dry-run    : $([ "${DRY_RUN}" -eq 1 ] && echo YES || echo no)
======================================================================
EOF

if [ "${NO_PROMPT}" -ne 1 ] && [ "${DRY_RUN}" -ne 1 ]; then
  printf '%s' "Proceed? [y/N] "
  read -r ans
  case "${ans}" in y|Y|yes|YES) ;; *) log_err "Aborted by user."; exit 2 ;; esac
fi

# ===== Run each phase =====
declare -a RESULTS

run_phase() {
  local phase="$1" file="" desc="" entry
  for entry in "${PHASES[@]}"; do
    IFS='|' read -r name desc file <<<"${entry}"
    [ "${name}" = "${phase}" ] || continue
    break
  done
  if [ -z "${file}" ]; then
    log_err "Unknown phase '${phase}'"
    RESULTS+=("${phase}|UNKNOWN|0|-")
    return 2
  fi
  local script="${PHASES_DIR}/${file}"
  if [ ! -f "${script}" ]; then
    log_err "Phase script not found: ${script}"
    RESULTS+=("${phase}|MISSING|0|-")
    return 2
  fi

  local logfile="${RUN_DIR}/${phase}.log"
  log_step "════════ ${phase} ════════"
  log_info "  desc:   ${desc}"
  log_info "  script: ${script}"
  log_info "  log:    ${logfile}"

  if [ "${DRY_RUN}" -eq 1 ]; then
    log_dry "  [dry-run] would run: bash ${script}"
    RESULTS+=("${phase}|DRY|0|${logfile}")
    return 0
  fi

  # Each phase script:
  # - re-sources common.sh (uses its own SCRIPT_DIR -> phases/, then derives
  #   ROOT_DIR for lib/common.sh + config.env)
  # - re-calls migration_start() with its own phase name -> writes its own
  #   per-phase log to ~/.zta-migration/logs/ AS WELL AS the per-run log
  #   captured here via tee.
  local t0; t0=$(date +%s)
  if bash "${script}" 2>&1 | tee "${logfile}"; then
    local dt=$(( $(date +%s) - t0 ))
    log_ok "  ${phase} OK (${dt}s)"
    RESULTS+=("${phase}|OK|${dt}|${logfile}")
    return 0
  else
    local rc=${PIPESTATUS[0]}
    local dt=$(( $(date +%s) - t0 ))
    log_err "  ${phase} FAILED (exit=${rc}, ${dt}s)"
    RESULTS+=("${phase}|FAIL(${rc})|${dt}|${logfile}")
    return "${rc}"
  fi
}

OVERALL_RC=0
for phase in "${PLAN[@]}"; do
  if ! run_phase "${phase}"; then
    OVERALL_RC=$?
    if [ "${CONTINUE_ON_FAIL}" -ne 1 ]; then
      log_err "Halting (use --continue-on-fail to proceed past phase failures)."
      break
    fi
  fi
done

# ===== Write summary =====
write_summary() {
  {
    printf '# bootstrap.sh run %s\n\n' "${RUN_TS}"
    # `printf --` disables option parsing so leading `-` in the format string
    # isn't treated as a flag (would otherwise fail with "invalid option").
    printf -- '- **Host**: %s (role=%s)\n' "${TARGET_HOST}" "${TARGET_ROLE}"
    printf -- '- **Local hostname**: %s\n' "${LOCAL_HOST}"
    printf -- '- **Plan**: %s\n' "${PLAN[*]}"
    printf -- '- **Started**: %s\n' "${RUN_TS}"
    printf -- '- **Finished**: %s\n\n' "$(date -u +%Y%m%dT%H%M%SZ)"
    printf '## Results\n\n'
    printf '| Phase | Status | Duration | Log |\n'
    printf '|-------|--------|----------|-----|\n'
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r name status dt log <<<"${r}"
      printf '| %s | %s | %ss | %s |\n' "${name}" "${status}" "${dt}" "${log}"
    done
    printf '\n'
    if [ "${OVERALL_RC}" -eq 0 ]; then
      printf '**Overall: SUCCESS**\n'
    else
      printf '**Overall: FAILURE (exit=%s)**\n' "${OVERALL_RC}"
    fi
  } > "${SUMMARY}"
  log_info "Summary: ${SUMMARY}"
}
write_summary

if [ "${OVERALL_RC}" -eq 0 ]; then
  log_ok "bootstrap.sh completed for ${TARGET_HOST} (${TARGET_ROLE})"
  if [ "${TARGET_ROLE}" = "control-plane" ] && [ -z "${PHASE_FILTER}" ] && [ -z "${TO_PHASE}" ]; then
    log_info ""
    log_info "Next steps:"
    log_info "  1. On each worker VM, run:"
    for h in ${WORKER_HOSTNAMES}; do
      # extract numeric suffix
      local_num="${h##*[!0-9]}"
      log_info "       sudo -E bash doc/migration/scripts/bootstrap.sh --server=${local_num}"
    done
    log_info "  2. After all workers join, on srv01 verify:"
    log_info "       kubectl get nodes -o wide"
  fi
else
  log_err "bootstrap.sh failed. See ${SUMMARY} for the failure summary."
fi

exit "${OVERALL_RC}"
