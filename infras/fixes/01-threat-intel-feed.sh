#!/usr/bin/env bash
# =============================================================================
# FIX 01 (EASY) — Activate the threat-intel feed
# -----------------------------------------------------------------------------
# Gap: CronJob `threat-intel-refresh` ships with `suspend: true`, so the
#      FireHOL/URLhaus feed never runs. As a result CiliumCIDRGroup
#      `externalCIDRs` and the sinkhole hosts file stay empty, and egress
#      blocking to known-bad IPs/domains is effectively only "default-deny",
#      not threat-intel driven.
#
# Fix: un-suspend the CronJob and kick off one manual Job now, then verify the
#      output ConfigMap got populated.
#
# Risk: LOW. Worst case the feed pulls a few thousand CIDRs that egress is
#       already denying anyway; it does not open anything up.
# Revert: re-suspend the CronJob (feed stops refreshing; existing blocklist
#         entries remain until you also clear the ConfigMap).
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="01-threat-intel-feed"
NS="security-cdm"
CRONJOB="threat-intel-refresh"
OUT_CM="threat-intel-blocklist"

status() {
  need_kubectl
  log "CronJob suspend state:"
  "$KUBECTL" -n "$NS" get cronjob "$CRONJOB" \
    -o jsonpath='{.metadata.name}{"  suspend="}{.spec.suspend}{"\n"}' 2>/dev/null \
    || warn "cronjob $NS/$CRONJOB not found"
  log "Output ConfigMap size:"
  "$KUBECTL" -n "$NS" get cm "$OUT_CM" \
    -o jsonpath='{range .data}{@}{end}' 2>/dev/null | wc -c \
    || warn "configmap $NS/$OUT_CM not found"
  log "Recent jobs:"
  "$KUBECTL" -n "$NS" get jobs -l app=threat-intel-refresh 2>/dev/null || true
}

apply() {
  need_kubectl
  local bdir; bdir="$(new_backup_dir "$FIX")"
  dump_obj "$NS" "cronjob/$CRONJOB" "$bdir/cronjob.yaml"
  dump_obj "$NS" "cm/$OUT_CM"       "$bdir/configmap-before.yaml"

  confirm "Un-suspend $NS/$CRONJOB and run one manual feed job now?"

  "$KUBECTL" -n "$NS" patch cronjob "$CRONJOB" \
    --type merge -p '{"spec":{"suspend":false}}'
  ok "CronJob un-suspended"

  local job="ti-manual-$(ts)"
  "$KUBECTL" -n "$NS" create job "$job" --from="cronjob/$CRONJOB"
  ok "Manual job $job created — waiting (up to 10m)..."
  if "$KUBECTL" -n "$NS" wait --for=condition=complete "job/$job" --timeout=600s; then
    ok "Feed job completed"
  else
    warn "Job did not complete in time — inspect with:"
    warn "  $KUBECTL -n $NS logs job/$job --all-containers"
  fi

  log "Output ConfigMap after run:"
  "$KUBECTL" -n "$NS" get cm "$OUT_CM" -o jsonpath='{range .data}{@}{end}' \
    2>/dev/null | wc -c
  ok "Done. Backup at: $bdir"
}

revert() {
  need_kubectl
  local bdir; bdir="$(resolve_revert_dir "$FIX" "${1:-}")"
  log "Reverting from $bdir"
  if [[ -f "$bdir/cronjob.yaml" ]]; then
    "$KUBECTL" apply -f "$bdir/cronjob.yaml"
    ok "Restored original CronJob spec (suspend state)"
  else
    warn "no cronjob backup; just re-suspending"
    "$KUBECTL" -n "$NS" patch cronjob "$CRONJOB" \
      --type merge -p '{"spec":{"suspend":true}}'
  fi
  warn "Manual ti-manual-* jobs are left in place; delete with:"
  warn "  $KUBECTL -n $NS delete jobs -l app=threat-intel-refresh"
}

case "${1:-status}" in
  apply)  apply ;;
  revert) revert "${2:-}" ;;
  status) status ;;
  *) die "usage: $0 {apply|revert [backup-dir]|status}" ;;
esac
