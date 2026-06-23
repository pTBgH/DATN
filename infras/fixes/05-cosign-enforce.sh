#!/usr/bin/env bash
# =============================================================================
# FIX 05 (HARD) — Cosign ClusterImagePolicy  warn -> enforce
# -----------------------------------------------------------------------------
# Gap: policy-controller ClusterImagePolicies are all `mode: warn` (admit +
#      warn). Real signature enforcement is off; the only hard control today
#      is digest-pinning.
#
# Fix: flip a chosen ClusterImagePolicy to `mode: enforce`. SAFETY GATE: the
#      script scans the policy-controller webhook logs for unsigned/"no
#      matching signatures" warnings; if any are found in the lookback window
#      it REFUSES to enforce (you would brick deploys/pod-restarts of those
#      images). Pass FORCE=1 to override.
#
# Default target: zta-job7189-apps-signed (the app namespace policy). The
# infra passthrough policy (zta-system-passthrough) should stay warn/allow.
#
# Risk: HIGH. enforce rejects admission of any unsigned image it matches —
#       including pod restarts of already-running unsigned images.
# Revert: flip the same policy back to warn (instant).
#
# Prereq before enforcing (do NOT skip):
#   * every app image in job7189-apps is cosign-signed in the registry
#   * the 'warn' window shows ZERO unsigned warnings for several days
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="05-cosign-enforce"
CIP="${CIP:-zta-job7189-apps-signed}"           # ClusterImagePolicy to flip
PC_NS="${PC_NS:-cosign-system}"                  # policy-controller namespace
PC_SELECTOR="${PC_SELECTOR:-control-plane=sigstore-policy-controller-webhook}"
LOOKBACK="${LOOKBACK:-2000}"                      # log lines to scan for warns

# Find the policy-controller webhook pods; fall back to a name grep across ns.
_pc_logs() {
  local out
  out="$("$KUBECTL" -n "$PC_NS" logs -l "$PC_SELECTOR" --tail="$LOOKBACK" --all-containers 2>/dev/null)"
  if [[ -z "$out" ]]; then
    local ref
    ref="$("$KUBECTL" get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null \
           | grep -i 'policy-controller' | head -1)"
    [[ -n "$ref" ]] && out="$("$KUBECTL" -n "${ref%%/*}" logs "${ref##*/}" --tail="$LOOKBACK" 2>/dev/null)"
  fi
  printf '%s' "$out"
}

_warn_count() {
  _pc_logs | grep -Eic 'no matching signatures|failed policy|unsigned|signature.*not|admission.*denied' || true
}

status() {
  need_kubectl
  printf '%-34s %-10s %s\n' NAME MODE SCOPE
  "$KUBECTL" get clusterimagepolicy -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.mode}{"\t"}{.metadata.annotations.zta-policy/scope}{"\n"}{end}' 2>/dev/null \
    | awk -F'\t' '{printf "%-34s %-10s %s\n",$1,($2==""?"warn":$2),$3}'
  echo
  local w; w="$(_warn_count)"
  log "policy-controller unsigned/denied warnings in last $LOOKBACK log lines: ${w:-?}"
  [[ "${w:-1}" == "0" ]] && ok "warn window clean — safe to consider enforce" \
                          || warn "non-zero warnings — DO NOT enforce until these are signed"
}

apply() {
  need_kubectl
  "$KUBECTL" get clusterimagepolicy "$CIP" >/dev/null 2>&1 || die "ClusterImagePolicy not found: $CIP (set \$CIP)"

  local cur; cur="$("$KUBECTL" get clusterimagepolicy "$CIP" -o jsonpath='{.spec.mode}' 2>/dev/null)"
  [[ "$cur" == "enforce" ]] && { ok "$CIP already enforce — nothing to do"; return; }

  local w; w="$(_warn_count)"
  log "$CIP currently mode=${cur:-warn}; webhook unsigned/denied warnings (last $LOOKBACK lines)=${w:-?}"
  if [[ "${w:-1}" != "0" && "${FORCE:-0}" != "1" ]]; then
    die "refusing to enforce — sign the images / clear the $w warning(s) first, or re-run with FORCE=1"
  fi

  local bdir; bdir="$(new_backup_dir "$FIX")"
  "$KUBECTL" get clusterimagepolicy "$CIP" -o yaml \
    | sed '/resourceVersion:/d;/uid:/d;/creationTimestamp:/d;/generation:/d' > "$bdir/$CIP.yaml"
  ok "backed up clusterimagepolicy/$CIP -> $bdir/$CIP.yaml"

  confirm "Flip ClusterImagePolicy $CIP to mode=enforce? (unsigned images in scope will be REJECTED)"
  "$KUBECTL" patch clusterimagepolicy "$CIP" --type merge -p '{"spec":{"mode":"enforce"}}'
  ok "$CIP is now ENFORCE. Revert with: $0 revert"
  log "Validate: deploy an unsigned image into scope -> should be rejected; signed -> admitted."
}

revert() {
  need_kubectl
  local bdir; bdir="$(resolve_revert_dir "$FIX" "${1:-}")"
  if [[ -f "$bdir/$CIP.yaml" ]]; then
    "$KUBECTL" apply -f "$bdir/$CIP.yaml"
  else
    "$KUBECTL" patch clusterimagepolicy "$CIP" --type merge -p '{"spec":{"mode":"warn"}}'
  fi
  ok "$CIP reverted to warn"
}

case "${1:-status}" in
  apply)  apply ;;
  revert) revert "${2:-}" ;;
  status) status ;;
  *) die "usage: CIP=<policy> $0 {status | apply | revert [backup-dir]}" ;;
esac
