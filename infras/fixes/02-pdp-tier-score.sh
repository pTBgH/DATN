#!/usr/bin/env bash
# =============================================================================
# FIX 02 (EASY) — Wire the `tier` label into the PDP trust score
# -----------------------------------------------------------------------------
# Gap: the PDP reads `zta.job7189/tier` as a required label but never uses it
#      in compute_score(). Trust score = labels + CVE only; criticality of the
#      workload does not influence the score.
#
# Fix: ship the updated controller (infras/k8s-yaml/pdp/20-configmap.yaml)
#      which adds a tier-weighted penalty. KEY SAFETY PROPERTY: the penalty
#      only applies when the pod ALREADY has a posture issue (missing label or
#      CVE). A fully-compliant, clean pod keeps score 100 regardless of tier,
#      so NO currently-healthy pod changes bucket on rollout. The tier weight
#      only "bites" the moment a critical-tier (T0/T1) pod acquires a CVE/drift.
#
# Risk: LOW–MEDIUM. Behaviour change is gated on posture_hit; verify the score
#       distribution before/after with `status`.
# Revert: re-apply the previous ConfigMap and restart the deployment.
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="02-pdp-tier-score"
NS="security"
DEPLOY="zta-pdp"
CM="zta-pdp-script"
REPO_CM="$FIXES_DIR/../k8s-yaml/pdp/20-configmap.yaml"

scores() {
  log "Current trust scores (annotation) per pod, all ZTA namespaces:"
  for ns in data vault security monitoring gateway management job7189-apps; do
    "$KUBECTL" -n "$ns" get pods \
      -o custom-columns="NS:.metadata.namespace,POD:.metadata.name,TIER:.metadata.labels.zta\.job7189/tier,SCORE:.metadata.annotations.zta\.job7189/trust-score,BUCKET:.metadata.labels.zta\.job7189/score-bucket" \
      --no-headers 2>/dev/null || true
  done
}

status() {
  need_kubectl
  log "Deployed ConfigMap contains tier logic?"
  if "$KUBECTL" -n "$NS" get cm "$CM" -o jsonpath='{.data.pdp_controller\.py}' 2>/dev/null \
       | grep -q "WEIGHT_TIER"; then
    ok "YES — tier logic already deployed"
  else
    warn "NO — running controller still on the 2-input formula"
  fi
  scores
}

apply() {
  need_kubectl
  [[ -f "$REPO_CM" ]] || die "repo ConfigMap not found: $REPO_CM"
  grep -q "WEIGHT_TIER" "$REPO_CM" || die "repo ConfigMap has no tier logic — wrong checkout?"

  local bdir; bdir="$(new_backup_dir "$FIX")"
  dump_obj "$NS" "cm/$CM"            "$bdir/configmap.yaml"
  dump_obj "$NS" "deploy/$DEPLOY"    "$bdir/deployment.yaml"

  log "Score distribution BEFORE:"; scores

  confirm "Apply tier-aware PDP ConfigMap and restart $NS/$DEPLOY?"
  "$KUBECTL" apply -f "$REPO_CM"
  "$KUBECTL" -n "$NS" rollout restart "deploy/$DEPLOY"
  "$KUBECTL" -n "$NS" rollout status  "deploy/$DEPLOY" --timeout=300s
  ok "Rolled out. Allow one reconcile period (~60s) before re-checking scores."
  ok "Backup at: $bdir"
}

revert() {
  need_kubectl
  local bdir; bdir="$(resolve_revert_dir "$FIX" "${1:-}")"
  [[ -f "$bdir/configmap.yaml" ]] || die "no configmap backup in $bdir"
  log "Reverting PDP ConfigMap from $bdir"
  "$KUBECTL" apply -f "$bdir/configmap.yaml"
  "$KUBECTL" -n "$NS" rollout restart "deploy/$DEPLOY"
  "$KUBECTL" -n "$NS" rollout status  "deploy/$DEPLOY" --timeout=300s
  ok "Reverted to previous controller"
}

case "${1:-status}" in
  apply)  apply ;;
  revert) revert "${2:-}" ;;
  status|scores) status ;;
  *) die "usage: $0 {apply|revert [backup-dir]|status}" ;;
esac
