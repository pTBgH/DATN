#!/usr/bin/env bash
# =============================================================================
# FIX 10 (HARD, new infra) — Impossible-Travel detection — SHADOW / AUDIT-ONLY
# -----------------------------------------------------------------------------
# Gap: Impossible-Travel / context-aware OPA / session revocation (CAEP) are
#      design-only today (no code). This deploys ONLY the first, non-enforcing
#      phase: a detector that reads Keycloak login events and AUDITS suspected
#      impossible-travel logins. It does NOT block logins and does NOT revoke
#      sessions — by design, to avoid locking out legitimate users.
#
# Sub-commands:
#   status   show secret + analyzer + cronjob state
#   apply    deploy the shadow analyzer (ConfigMap + CronJob + egress CNP)
#   run      trigger one Job now and tail its audit output
#   revert   delete the analyzer (cronjob, configmap, CNP)
#
# Prereq: Secret `keycloak-admin` in ns security (KC_URL/KC_REALM/KC_USER/
#         KC_PASS). The script prints the exact create command if it's missing.
#
# Risk: LOW while shadow (read-only, audit-only). The ENFORCEMENT phase
#       (deny/step-up auth + CAEP back-channel logout) remains [Design] and is
#       intentionally NOT shipped here — turning it on touches the live auth
#       path and must be staged separately.
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="10-impossible-travel"
NS="security"
MANIFEST="$FIXES_DIR/manifests/10-impossible-travel-shadow.yaml"
SECRET="keycloak-admin"
CRON="impossible-travel-shadow"

_secret_ok() { "$KUBECTL" -n "$NS" get secret "$SECRET" >/dev/null 2>&1; }

_print_secret_help() {
  warn "Secret $NS/$SECRET missing. Create it (fill in real values):"
  cat <<EOF
  kubectl -n $NS create secret generic $SECRET \\
    --from-literal=KC_URL=https://keycloak.data.svc.cluster.local:8443 \\
    --from-literal=KC_REALM=job7189 \\
    --from-literal=KC_USER=<admin-user> \\
    --from-literal=KC_PASS=<admin-pass> \\
    --from-literal=KC_INSECURE=true
EOF
}

status() {
  need_kubectl
  _secret_ok && ok "secret $NS/$SECRET present" || _print_secret_help
  "$KUBECTL" -n "$NS" get cronjob "$CRON" >/dev/null 2>&1 \
    && ok "cronjob $CRON deployed" || log "cronjob $CRON not deployed yet"
}

apply() {
  need_kubectl
  [[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"
  _secret_ok || { _print_secret_help; die "create the $SECRET secret first, then re-run"; }
  confirm "Deploy SHADOW impossible-travel analyzer (audit-only, no enforcement)?"
  "$KUBECTL" apply -f "$MANIFEST"
  ok "shadow analyzer deployed (runs every 15m). Trigger now with: $0 run"
  log "It only AUDITS; it does not block logins or revoke sessions."
}

run() {
  need_kubectl
  "$KUBECTL" -n "$NS" get cronjob "$CRON" >/dev/null 2>&1 || die "deploy first: $0 apply"
  local job="it-shadow-$(date +%H%M%S)"
  "$KUBECTL" -n "$NS" create job "$job" --from="cronjob/$CRON"
  log "Job $job created — waiting for output..."
  for _ in $(seq 1 40); do
    if "$KUBECTL" -n "$NS" logs "job/$job" >/dev/null 2>&1; then break; fi
    sleep 3
  done
  "$KUBECTL" -n "$NS" logs "job/$job" -f 2>/dev/null || true
  log "Inspect later:  kubectl -n $NS logs job/$job"
  log "Clean job:      kubectl -n $NS delete job $job"
}

revert() {
  need_kubectl
  "$KUBECTL" delete -f "$MANIFEST" --ignore-not-found
  ok "shadow analyzer removed (secret $SECRET left in place)"
}

case "${1:-status}" in
  apply)  apply ;;
  run)    run ;;
  revert) revert ;;
  status) status ;;
  *) die "usage: $0 {status | apply | run | revert}" ;;
esac
