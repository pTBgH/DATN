#!/usr/bin/env bash
# =============================================================================
# FIX 09 (HARD, new infra) — GitOps self-heal with ArgoCD
# -----------------------------------------------------------------------------
# Gap: policy drift (someone edits/deletes a CNP on the cluster) is repaired by
#      hand. We want Git to be the source of truth and auto-restore drift.
#
# Fix: install a PINNED ArgoCD release, then create an Application that watches
#      a NARROW policy path with selfHeal=true, prune=FALSE (so it re-applies
#      drift but never deletes anything not in Git — the safe starting point).
#
# Sub-commands:
#   status     show argocd install + Application state
#   install    install ArgoCD (pinned version) into ns argocd
#   apply      create/update the Application (policy path, selfHeal, no prune)
#   revert     delete the Application
#   uninstall  remove ArgoCD entirely (deletes ns argocd)
#
# Env:
#   ARGOCD_VERSION (default v2.13.3)   pinned release tag
#   REPO_URL       (default https://github.com/bpt12/DATN.git)
#   REPO_REV       (default main)
#   REPO_PATH      (default infras/k8s-yaml/cilium-policies/namespaces)
#
# Risk: HIGH. selfHeal/prune misconfig can overwrite/delete cluster objects.
#       We start with prune=false + a narrow path. Widen only after observing.
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="09-argocd-gitops"
ARGOCD_NS="argocd"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.13.3}"
INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
REPO_URL="${REPO_URL:-https://github.com/bpt12/DATN.git}"
REPO_REV="${REPO_REV:-main}"
REPO_PATH="${REPO_PATH:-infras/k8s-yaml/cilium-policies/namespaces}"
APP_NAME="${APP_NAME:-zta-policies}"

status() {
  need_kubectl
  if "$KUBECTL" get ns "$ARGOCD_NS" >/dev/null 2>&1; then
    ok "namespace $ARGOCD_NS exists"
    "$KUBECTL" -n "$ARGOCD_NS" get deploy 2>/dev/null | sed 's/^/   /'
  else
    warn "ArgoCD not installed (ns $ARGOCD_NS missing) — run: $0 install"
  fi
  if "$KUBECTL" -n "$ARGOCD_NS" get application "$APP_NAME" >/dev/null 2>&1; then
    "$KUBECTL" -n "$ARGOCD_NS" get application "$APP_NAME" \
      -o jsonpath='{.metadata.name}: sync={.status.sync.status} health={.status.health.status}{"\n"}' 2>/dev/null
  else
    log "Application $APP_NAME not created yet"
  fi
}

install() {
  need_kubectl
  log "Installing ArgoCD $ARGOCD_VERSION into ns $ARGOCD_NS"
  confirm "Create ns $ARGOCD_NS and apply pinned ArgoCD install manifest?"
  "$KUBECTL" get ns "$ARGOCD_NS" >/dev/null 2>&1 || "$KUBECTL" create ns "$ARGOCD_NS"
  "$KUBECTL" apply -n "$ARGOCD_NS" -f "$INSTALL_URL"
  log "Waiting for argocd-server + repo-server + application-controller..."
  "$KUBECTL" -n "$ARGOCD_NS" rollout status deploy/argocd-server --timeout=300s || true
  "$KUBECTL" -n "$ARGOCD_NS" rollout status deploy/argocd-repo-server --timeout=300s || true
  ok "ArgoCD installed. Admin password:"
  log "  kubectl -n $ARGOCD_NS get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
  log "Then create the Application: $0 apply"
}

apply() {
  need_kubectl
  "$KUBECTL" get ns "$ARGOCD_NS" >/dev/null 2>&1 || die "ArgoCD not installed — run: $0 install"
  local bdir; bdir="$(new_backup_dir "$FIX")"
  "$KUBECTL" -n "$ARGOCD_NS" get application "$APP_NAME" -o yaml > "$bdir/$APP_NAME.yaml" 2>/dev/null && ok "backed up existing Application" || true

  log "Application $APP_NAME -> $REPO_URL@$REPO_REV path=$REPO_PATH (selfHeal=true, prune=FALSE)"
  confirm "Create/update Application $APP_NAME?"
  "$KUBECTL" apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: $ARGOCD_NS
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: $REPO_REV
    path: $REPO_PATH
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      selfHeal: true
      prune: false        # SAFE start: re-apply drift, never delete
    syncOptions:
    - CreateNamespace=false
EOF
  ok "Application created. Test: delete a CNP in $REPO_PATH on the cluster -> ArgoCD re-applies it."
  ok "Backup at: $bdir"
}

revert() {
  need_kubectl
  "$KUBECTL" -n "$ARGOCD_NS" delete application "$APP_NAME" --ignore-not-found
  ok "Application $APP_NAME deleted (ArgoCD still installed; '$0 uninstall' to remove it)"
}

uninstall() {
  need_kubectl
  confirm "Remove ArgoCD entirely (delete ns $ARGOCD_NS)?"
  "$KUBECTL" delete -n "$ARGOCD_NS" -f "$INSTALL_URL" --ignore-not-found || true
  "$KUBECTL" delete ns "$ARGOCD_NS" --ignore-not-found
  ok "ArgoCD uninstalled"
}

case "${1:-status}" in
  install)   install ;;
  apply)     apply ;;
  revert)    revert ;;
  uninstall) uninstall ;;
  status)    status ;;
  *) die "usage: $0 {status | install | apply | revert | uninstall}" ;;
esac
