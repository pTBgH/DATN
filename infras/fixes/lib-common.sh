#!/usr/bin/env bash
# =============================================================================
# lib-common.sh — shared helpers for the ZTA hardening fix scripts.
#
# Every fix script sources this file. The design rule is "backup before
# mutate": no script changes a live object until the current state of that
# object has been dumped to a timestamped folder under backups/. Each script
# also ships a `revert` subcommand that restores from the newest backup (or
# from a backup folder you pass explicitly).
#
#   source "$(dirname "$0")/lib-common.sh"
#
# Conventions used by the scripts:
#   ./NN-name.sh apply            apply the change (after a confirmation)
#   ./NN-name.sh revert           undo using the newest backup of this fix
#   ./NN-name.sh revert <dir>     undo using a specific backup folder
#   ./NN-name.sh status           show current state, change nothing
#
# Env knobs:
#   ASSUME_YES=1   skip the interactive confirmation (for CI / batch runs)
#   KUBECTL=...    override the kubectl binary (default: kubectl)
# =============================================================================
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
FIXES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-$FIXES_DIR/backups}"

# --- pretty logging ----------------------------------------------------------
_c() { printf '\033[%sm' "$1"; }
log()  { printf '%s[*]%s %s\n' "$(_c 36)" "$(_c 0)" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$(_c 32)" "$(_c 0)" "$*"; }
warn() { printf '%s[!]%s %s\n' "$(_c 33)" "$(_c 0)" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$(_c 31)" "$(_c 0)" "$*" >&2; exit 1; }

ts() { date -u +%Y%m%d-%H%M%S; }

# --- preconditions -----------------------------------------------------------
need_kubectl() {
  command -v "$KUBECTL" >/dev/null 2>&1 || die "kubectl not found (set \$KUBECTL)"
  "$KUBECTL" version --output=json >/dev/null 2>&1 \
    || "$KUBECTL" cluster-info >/dev/null 2>&1 \
    || die "cannot reach the cluster — check your kubeconfig/context"
  log "kubectl OK, context = $("$KUBECTL" config current-context 2>/dev/null || echo '?')"
}

confirm() {
  local prompt="${1:-Proceed?}"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then return 0; fi
  read -r -p "$(_c 33)$prompt$(_c 0) [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || die "aborted by user"
}

# --- backup helpers ----------------------------------------------------------
# new_backup_dir <fix-id>   -> prints a fresh timestamped backup folder
new_backup_dir() {
  local fix="$1" dir
  dir="$BACKUP_ROOT/$fix/$(ts)"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

# latest_backup_dir <fix-id>  -> prints the newest backup folder, or empty
latest_backup_dir() {
  local fix="$1"
  ls -1dt "$BACKUP_ROOT/$fix"/*/ 2>/dev/null | head -1 || true
}

# dump_obj <ns> <kind/name> <outfile>   -> save a live object as YAML (if it exists)
dump_obj() {
  local ns="$1" obj="$2" out="$3"
  if "$KUBECTL" -n "$ns" get "$obj" >/dev/null 2>&1; then
    # strip server-managed noise so re-apply is clean
    "$KUBECTL" -n "$ns" get "$obj" -o yaml \
      | sed '/^  *resourceVersion:/d;/^  *uid:/d;/^  *creationTimestamp:/d;/^  *generation:/d' \
      > "$out"
    ok "backed up $ns/$obj -> $out"
  else
    warn "$ns/$obj not found — nothing to back up"
  fi
}

# resolve the backup dir for a revert: $1=fix-id, $2=optional explicit dir
resolve_revert_dir() {
  local fix="$1" explicit="${2:-}"
  if [[ -n "$explicit" ]]; then
    [[ -d "$explicit" ]] || die "backup dir not found: $explicit"
    printf '%s\n' "$explicit"; return
  fi
  local d; d="$(latest_backup_dir "$fix")"
  [[ -n "$d" ]] || die "no backup found for '$fix' under $BACKUP_ROOT/$fix — pass a dir explicitly"
  printf '%s\n' "$d"
}
