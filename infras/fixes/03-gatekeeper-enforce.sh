#!/usr/bin/env bash
# =============================================================================
# FIX 03 (MEDIUM) — Promote Gatekeeper constraints from dryrun -> deny
# -----------------------------------------------------------------------------
# Gap: only `block-host-mounts` is enforced (deny). Five other constraints are
#      `dryrun` (audit only): zta-restrict-privileged, image-digest-required,
#      block-latest-tag, signed-image-annotation-required, zta-labels-required.
#
# Fix: flip a chosen constraint to `enforcementAction: deny`. SAFETY GATE: the
#      script refuses to promote a constraint that still has audit violations
#      (totalViolations > 0) unless you pass FORCE=1, because promoting a
#      violated constraint will start rejecting admission of those workloads.
#
# Recommended promotion order (least to most disruptive):
#   1. zta-restrict-privileged   (no workload here is privileged)
#   2. image-digest-required     (only after all images are digest-pinned)
#   3. block-latest-tag          (only after no :latest tags remain)
#   Leave signed-image + labels in dryrun until Cosign enforce (fix 05) is on.
#
# Risk: MEDIUM. A promoted constraint rejects *new/updated* non-compliant pods.
# Revert: flip the same constraint back to dryrun (instant, no workload change).
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="03-gatekeeper-enforce"

# kind:name pairs present in this repo
declare -A CONSTRAINTS=(
  [zta-restrict-privileged]="ZTARestrictPrivileged"
  [image-digest-required]="K8sImageDigestRequired"
  [block-latest-tag]="K8sBlockLatestTag"
  [signed-image-annotation-required]="K8sSignedImageAnnotation"
  [zta-labels-required]="ZTARequiredLabels"
)

_kind_for() { echo "${CONSTRAINTS[$1]:-}"; }

status() {
  need_kubectl
  printf '%-36s %-26s %-8s %s\n' NAME KIND ACTION VIOLATIONS
  for name in "${!CONSTRAINTS[@]}"; do
    local kind; kind="$(_kind_for "$name")"
    local action viol
    action="$("$KUBECTL" get "$kind" "$name" -o jsonpath='{.spec.enforcementAction}' 2>/dev/null || echo '?')"
    viol="$("$KUBECTL" get "$kind" "$name" -o jsonpath='{.status.totalViolations}' 2>/dev/null || echo '?')"
    printf '%-36s %-26s %-8s %s\n' "$name" "$kind" "${action:-dryrun}" "${viol:-0}"
  done
}

apply() {
  need_kubectl
  local name="${1:-}"; [[ -n "$name" ]] || die "usage: $0 apply <constraint-name>  (see 'status')"
  local kind; kind="$(_kind_for "$name")"; [[ -n "$kind" ]] || die "unknown constraint: $name"

  local viol; viol="$("$KUBECTL" get "$kind" "$name" -o jsonpath='{.status.totalViolations}' 2>/dev/null || echo 0)"
  log "$name has totalViolations=${viol:-0}"
  if [[ "${viol:-0}" != "0" && "${FORCE:-0}" != "1" ]]; then
    die "refusing to promote — clear the $viol audit violation(s) first, or re-run with FORCE=1"
  fi

  local bdir; bdir="$(new_backup_dir "$FIX")"
  "$KUBECTL" get "$kind" "$name" -o yaml > "$bdir/$name.yaml"
  ok "backed up $kind/$name -> $bdir/$name.yaml"

  confirm "Promote $kind/$name to enforcementAction=deny?"
  "$KUBECTL" patch "$kind" "$name" --type merge -p '{"spec":{"enforcementAction":"deny"}}'
  ok "$name is now DENY. Revert with: $0 revert $name"
}

revert() {
  need_kubectl
  local name="${1:-}"; [[ -n "$name" ]] || die "usage: $0 revert <constraint-name>"
  local kind; kind="$(_kind_for "$name")"; [[ -n "$kind" ]] || die "unknown constraint: $name"
  "$KUBECTL" patch "$kind" "$name" --type merge -p '{"spec":{"enforcementAction":"dryrun"}}'
  ok "$name reverted to DRYRUN (audit-only)"
}

case "${1:-status}" in
  apply)  apply "${2:-}" ;;
  revert) revert "${2:-}" ;;
  status) status ;;
  *) die "usage: $0 {status | apply <name> | revert <name>}" ;;
esac
