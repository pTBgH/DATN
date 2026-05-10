#!/usr/bin/env bash
# doc/migration/scripts/lib/common.sh
#
# Common library for ZTA multi-VM migration scripts.
# Provides:
#   - Strict bash mode + trap-based try/catch
#   - Rollback action stack
#   - Idempotency helpers (skip-if-exists)
#   - Logging with timestamps + color
#   - Status report writers (markdown)
#
# Usage:
#   #!/usr/bin/env bash
#   set -Eeuo pipefail
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "${SCRIPT_DIR}/lib/common.sh"
#   migration_start "phase-name"
#   register_rollback "echo 'undo step 1'"
#   step "Doing X" do_x_command
#   migration_end

# ===== Strict mode (caller must already set this; we re-set defensively) =====
set -Eeuo pipefail

# ===== Constants =====
ZTA_STATE_DIR="${ZTA_STATE_DIR:-${HOME}/.zta-migration}"
ZTA_LOG_DIR="${ZTA_LOG_DIR:-${ZTA_STATE_DIR}/logs}"
ZTA_REPORT_DIR="${ZTA_REPORT_DIR:-${ZTA_STATE_DIR}/reports}"
mkdir -p "${ZTA_STATE_DIR}" "${ZTA_LOG_DIR}" "${ZTA_REPORT_DIR}"

# ===== Colors (disabled if not TTY) =====
if [ -t 1 ] && [ "${NO_COLOR:-0}" != "1" ]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[1;31m'; C_GRN=$'\033[1;32m'
  C_YEL=$'\033[1;33m'; C_BLU=$'\033[1;34m'; C_CYN=$'\033[1;36m'; C_GRY=$'\033[0;37m'
else
  C_RESET=''; C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_CYN=''; C_GRY=''
fi

# ===== Globals =====
ZTA_PHASE_NAME=""
ZTA_PHASE_LOG=""
ZTA_DRY_RUN="${ZTA_DRY_RUN:-0}"
ZTA_AUTO_ROLLBACK="${ZTA_AUTO_ROLLBACK:-1}"
declare -a ZTA_ROLLBACK_STACK=()
ZTA_PHASE_START_EPOCH=0
ZTA_FAILED_CMD=""
ZTA_FAILED_LINE=""

# ===== Logging =====
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

_log() {
  local level="$1"; shift
  local color="$1"; shift
  local msg="$*"
  local line="$(ts) [${level}] ${msg}"
  printf '%s%s%s\n' "${color}" "${line}" "${C_RESET}" >&2
  if [ -n "${ZTA_PHASE_LOG}" ]; then
    printf '%s\n' "${line}" >> "${ZTA_PHASE_LOG}"
  fi
}

log_info() { _log "INFO " "${C_BLU}" "$*"; }
log_ok()   { _log "OK   " "${C_GRN}" "$*"; }
log_warn() { _log "WARN " "${C_YEL}" "$*"; }
log_err()  { _log "ERROR" "${C_RED}" "$*"; }
log_step() { _log "STEP " "${C_CYN}" "$*"; }
log_dry()  { _log "DRY  " "${C_GRY}" "$*"; }

# ===== Phase lifecycle =====
migration_start() {
  ZTA_PHASE_NAME="${1:-unnamed}"
  ZTA_PHASE_START_EPOCH=$(date +%s)
  ZTA_PHASE_LOG="${ZTA_LOG_DIR}/${ZTA_PHASE_NAME}-$(date -u +%Y%m%dT%H%M%SZ).log"
  : > "${ZTA_PHASE_LOG}"

  trap '_zta_on_err $LINENO "$BASH_COMMAND"' ERR
  trap '_zta_on_exit' EXIT

  log_info "==================================================================="
  log_info "Phase: ${ZTA_PHASE_NAME}"
  log_info "Host : $(hostname) ($(uname -s) $(uname -r))"
  log_info "User : ${USER:-$(id -un)}"
  log_info "Time : $(date -Iseconds)"
  log_info "Log  : ${ZTA_PHASE_LOG}"
  log_info "Dry  : ${ZTA_DRY_RUN}  AutoRollback: ${ZTA_AUTO_ROLLBACK}"
  log_info "==================================================================="
}

migration_end() {
  trap - ERR
  local elapsed=$(( $(date +%s) - ZTA_PHASE_START_EPOCH ))
  log_ok "Phase '${ZTA_PHASE_NAME}' completed successfully in ${elapsed}s"
  # Mark the phase as completed so subsequent rollback skips it unless forced
  printf 'completed\n' > "${ZTA_STATE_DIR}/${ZTA_PHASE_NAME}.state"
}

_zta_on_err() {
  ZTA_FAILED_LINE="$1"
  ZTA_FAILED_CMD="$2"
  log_err "Failed at line ${ZTA_FAILED_LINE}: ${ZTA_FAILED_CMD}"
  log_err "See ${ZTA_PHASE_LOG} for details"
  printf 'failed line=%s cmd=%q\n' "${ZTA_FAILED_LINE}" "${ZTA_FAILED_CMD}" \
    > "${ZTA_STATE_DIR}/${ZTA_PHASE_NAME}.state"
  if [ "${ZTA_AUTO_ROLLBACK}" = "1" ]; then
    log_warn "Auto-rollback ON — undoing recorded actions in reverse order"
    _zta_rollback
  else
    log_warn "Auto-rollback OFF — re-run with ZTA_AUTO_ROLLBACK=1 or use 99-rollback.sh"
  fi
}

_zta_on_exit() {
  local rc=$?
  if [ "${rc}" -ne 0 ] && [ -z "${ZTA_FAILED_CMD}" ]; then
    log_err "Exiting with code ${rc} (no specific failed command captured)"
  fi
  trap - EXIT
  exit "${rc}"
}

# ===== Rollback stack =====
register_rollback() {
  # Push a shell command (string) to be executed in reverse order on failure.
  ZTA_ROLLBACK_STACK+=("$1")
  log_info "  +rollback: $1"
}

_zta_rollback() {
  local i n="${#ZTA_ROLLBACK_STACK[@]}"
  if [ "${n}" -eq 0 ]; then
    log_warn "Rollback stack is empty — nothing to undo"
    return 0
  fi
  log_warn "Running ${n} rollback action(s) in reverse..."
  for ((i=n-1; i>=0; i--)); do
    local cmd="${ZTA_ROLLBACK_STACK[$i]}"
    log_warn "  rollback[$i]: ${cmd}"
    if [ "${ZTA_DRY_RUN}" = "1" ]; then
      log_dry "    (dry-run; not executed)"
      continue
    fi
    # Best-effort; never fail the rollback itself
    bash -c "${cmd}" || log_warn "    rollback[$i] returned non-zero — continuing"
  done
  log_warn "Rollback finished."
}

# ===== Step wrapper =====
step() {
  local label="$1"; shift
  log_step "${label}"
  if [ "${ZTA_DRY_RUN}" = "1" ]; then
    log_dry "$ $*"
    return 0
  fi
  "$@"
}

# Run a command, swallow non-zero into a logged warning (for best-effort steps)
try_step() {
  local label="$1"; shift
  log_step "${label} (best-effort)"
  if [ "${ZTA_DRY_RUN}" = "1" ]; then
    log_dry "$ $*"
    return 0
  fi
  if "$@"; then
    return 0
  else
    local rc=$?
    log_warn "  best-effort step returned ${rc} — continuing"
    return 0
  fi
}

# ===== Idempotency helpers =====
already_done() {
  # Mark feature done so re-runs skip it. Caller passes a unique key.
  local key="$1"
  [ -f "${ZTA_STATE_DIR}/done.${key}" ]
}
mark_done() {
  local key="$1"
  printf '%s\n' "$(ts)" > "${ZTA_STATE_DIR}/done.${key}"
}

# ===== Pre-flight assertions =====
require_root() {
  if [ "${EUID}" -ne 0 ]; then
    log_err "This script needs sudo/root. Re-run with: sudo -E bash $0 $*"
    exit 1
  fi
}

require_cmd() {
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      log_err "Required command not found: $c"
      return 1
    fi
  done
}

require_min_ram_mib() {
  local need="$1" who="${2:-this script}"
  local have
  have="$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)"
  if [ "${have}" -lt "${need}" ]; then
    log_err "Not enough RAM for ${who}: need ${need} MiB available, have ${have} MiB"
    return 1
  fi
  log_ok "RAM OK for ${who}: ${have} MiB available (need ${need})"
}

require_min_disk_gib() {
  local need="$1" path="${2:-/}"
  local have
  have="$(df -BG "${path}" --output=avail 2>/dev/null | tail -n1 | tr -dc '0-9')"
  have="${have:-0}"
  if [ "${have}" -lt "${need}" ]; then
    log_err "Not enough disk on ${path}: need ${need} GiB free, have ${have} GiB"
    return 1
  fi
  log_ok "Disk OK on ${path}: ${have} GiB free (need ${need})"
}

# ===== File mutation helpers (idempotent, with rollback) =====
backup_file() {
  local src="$1"
  if [ -f "${src}" ]; then
    local bk="${src}.zta-bak-$(date -u +%Y%m%dT%H%M%SZ)"
    cp -a "${src}" "${bk}"
    register_rollback "cp -a '${bk}' '${src}' && rm -f '${bk}'"
    log_info "Backed up ${src} -> ${bk}"
    printf '%s' "${bk}"
  fi
}

write_file_if_changed() {
  local dst="$1" content="$2"
  if [ -f "${dst}" ] && [ "$(cat "${dst}")" = "${content}" ]; then
    log_info "  ${dst} unchanged"
    return 0
  fi
  backup_file "${dst}" >/dev/null
  printf '%s\n' "${content}" | sudo tee "${dst}" >/dev/null
  log_ok "  wrote ${dst}"
}

# ===== Markdown status report writer =====
md_emit() {
  printf '%s\n' "$*" >> "${ZTA_CURRENT_REPORT:-/dev/null}"
}

md_section() { md_emit ""; md_emit "## $*"; md_emit ""; }
md_kv()      { printf '| %s | %s |\n' "$1" "$2" >> "${ZTA_CURRENT_REPORT:-/dev/null}"; }
md_code()    {
  md_emit '```'
  md_emit "$*"
  md_emit '```'
}
md_codeblock_start() { md_emit '```'; }
md_codeblock_end()   { md_emit '```'; }

# Sets the global ZTA_CURRENT_REPORT and seeds the file with a header.
# Caller should NOT capture stdout (the function is side-effect only).
start_report() {
  local title="$1"
  ZTA_CURRENT_REPORT="${ZTA_REPORT_DIR}/${title}-$(hostname)-$(date -u +%Y%m%dT%H%M%SZ).md"
  : > "${ZTA_CURRENT_REPORT}"
  md_emit "# ${title} — $(hostname)"
  md_emit ""
  md_emit "Generated: $(date -Iseconds)"
  md_emit ""
  log_info "Report path: ${ZTA_CURRENT_REPORT}"
}

end_report() {
  log_ok "Report: ${ZTA_CURRENT_REPORT}"
}

# ===== Config loader =====
load_config() {
  # Loads doc/migration/scripts/config.env if present.
  # Caller can also pre-set variables via environment.
  local cfg="${1:-${SCRIPT_DIR:-.}/config.env}"
  if [ -f "${cfg}" ]; then
    # shellcheck disable=SC1090
    set -a; . "${cfg}"; set +a
    log_info "Loaded config: ${cfg}"
  else
    log_info "No config file at ${cfg}; using env vars and defaults"
  fi

  # Defaults
  : "${TAILNET_DOMAIN:=example.ts.net}"
  : "${CP_HOSTNAME:=7189srv01}"
  : "${WORKER_HOSTNAMES:=7189srv02 7189srv03 7189srv04}"
  : "${DATA_NODE:=7189srv04}"
  : "${KUBE_VERSION:=1.30.0}"
  : "${KUBE_MINOR:=1.30}"
  : "${CILIUM_VERSION:=1.19.1}"
  : "${POD_CIDR:=10.244.0.0/16}"
  : "${SVC_CIDR:=10.96.0.0/12}"
  : "${CLUSTER_NAME:=job7189}"
  : "${RESOURCE_PROFILE:=tight}"   # tight | normal
  : "${REGISTRY_NODEPORT:=30005}"
  : "${HTTP_NODEPORT:=30003}"
  : "${HTTPS_NODEPORT:=30001}"
  export TAILNET_DOMAIN CP_HOSTNAME WORKER_HOSTNAMES DATA_NODE \
         KUBE_VERSION KUBE_MINOR CILIUM_VERSION POD_CIDR SVC_CIDR \
         CLUSTER_NAME RESOURCE_PROFILE REGISTRY_NODEPORT HTTP_NODEPORT HTTPS_NODEPORT
}
