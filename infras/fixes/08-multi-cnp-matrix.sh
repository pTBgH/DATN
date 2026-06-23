#!/usr/bin/env bash
# =============================================================================
# FIX 08 (HARD-ish) — Multi-CNP trust-response matrix (medium/low buckets)
# -----------------------------------------------------------------------------
# Gap: only ONE policy reacts to the trust score (vault/cnp-block-low-trust-to-
#      vault, ingress side). The design calls for a graduated matrix: as a pod
#      drops bucket, tighten East-West to sensitive namespaces while keeping
#      North-South.
#
# Fix: apply two CiliumClusterwideNetworkPolicies (manifests/08-trust-matrix.yaml):
#        ccnp-medium-trust-restrict-ew  medium -> egressDeny to vault
#        ccnp-low-trust-isolate-ew      low    -> egressDeny to vault/data/management
#      They use `egressDeny` (deny-precedence) so they DON'T trigger default-deny
#      and layer cleanly on existing allow policies.
#
# SAFETY: today every pod is `high`, so NO pod matches these selectors — applying
#         is inert until the PDP demotes a pod. The script prints the current
#         medium/low pod count before applying so you can confirm it's 0.
#
# Risk: MEDIUM. A wrong selector could cut a mislabeled pod's E-W. Verify the
#       match count is 0 (or expected) first; revert is a clean delete.
# Revert: delete both CCNPs.
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="08-multi-cnp-matrix"
MANIFEST="$FIXES_DIR/manifests/08-trust-matrix.yaml"
POLICIES=(ccnp-medium-trust-restrict-ew ccnp-low-trust-isolate-ew)
ZTA_NS=(data vault security monitoring gateway management job7189-apps)

_count_bucket() {  # $1=bucket
  local n=0 ns c
  for ns in "${ZTA_NS[@]}"; do
    c="$("$KUBECTL" -n "$ns" get pods -l "zta.job7189/score-bucket=$1" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    n=$((n + c))
  done
  echo "$n"
}

status() {
  need_kubectl
  printf '%-32s %s\n' POLICY PRESENT
  for p in "${POLICIES[@]}"; do
    if "$KUBECTL" get ciliumclusterwidenetworkpolicy "$p" >/dev/null 2>&1; then
      printf '%-32s %s\n' "$p" yes
    else
      printf '%-32s %s\n' "$p" no
    fi
  done
  echo
  log "pods currently medium: $(_count_bucket medium)   low: $(_count_bucket low)  (0 = applying is inert)"
}

apply() {
  need_kubectl
  [[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"
  local m l; m="$(_count_bucket medium)"; l="$(_count_bucket low)"
  log "Current matches — medium=$m low=$l (these pods WILL be restricted E-W)"

  local bdir; bdir="$(new_backup_dir "$FIX")"
  for p in "${POLICIES[@]}"; do
    "$KUBECTL" get ciliumclusterwidenetworkpolicy "$p" -o yaml > "$bdir/$p.yaml" 2>/dev/null && ok "backed up $p" || true
  done

  confirm "Apply trust-response matrix (2 CCNPs)? medium=$m low=$l pods affected now"
  "$KUBECTL" apply -f "$MANIFEST"
  ok "matrix applied. Observe with: hubble observe --verdict DROPPED | grep -E 'vault|data|management'"
  ok "Backup at: $bdir"
}

revert() {
  need_kubectl
  for p in "${POLICIES[@]}"; do
    "$KUBECTL" delete ciliumclusterwidenetworkpolicy "$p" --ignore-not-found
  done
  ok "trust-response matrix removed"
}

case "${1:-status}" in
  apply)  apply ;;
  revert) revert ;;
  status) status ;;
  *) die "usage: $0 {status | apply | revert}" ;;
esac
