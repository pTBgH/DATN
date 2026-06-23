#!/usr/bin/env bash
# =============================================================================
# FIX 04 (MEDIUM) — Enforce readOnlyRootFilesystem on a workload
# -----------------------------------------------------------------------------
# Gap: some app workloads (e.g. hiring-service in job7189-apps) run with a
#      writable root filesystem, so an attacker who lands code execution can
#      drop tools/persist on disk. Tetragon observed writes in KB4.
#
# Fix: patch ONE deployment to set readOnlyRootFilesystem=true on a container
#      and mount a small emptyDir at /tmp (most apps need a writable temp dir).
#      Operates per-deployment with an AUTO-ROLLBACK: if the new ReplicaSet
#      does not become Ready within the timeout, the script restores the
#      backed-up spec automatically.
#
# Risk: MEDIUM. An app that writes outside /tmp will CrashLoop; auto-rollback
#       protects you, and you can add more writable mounts via WRITABLE_PATHS.
# Revert: restore the backed-up deployment spec.
#
# Usage:
#   ./04-readonly-rootfs.sh status   <ns>
#   ./04-readonly-rootfs.sh apply    <ns> <deployment> [container]
#   ./04-readonly-rootfs.sh revert   <ns> <deployment> [backup-dir]
# Env: WRITABLE_PATHS="/tmp /var/run"  (space-separated extra emptyDir mounts)
#      ROLLOUT_TIMEOUT=180s
# =============================================================================
source "$(dirname "$0")/lib-common.sh"

FIX="04-readonly-rootfs"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"
WRITABLE_PATHS="${WRITABLE_PATHS:-/tmp}"

status() {
  need_kubectl
  local ns="${1:?usage: $0 status <ns>}"
  printf '%-32s %-24s %s\n' DEPLOYMENT CONTAINER readOnlyRootFS
  "$KUBECTL" -n "$ns" get deploy -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
for item in d.get("items",[]):
    name=item["metadata"]["name"]
    for c in item["spec"]["template"]["spec"].get("containers",[]):
        ro=(c.get("securityContext") or {}).get("readOnlyRootFilesystem","<unset>")
        cname=c["name"]
        print(f"{name:<32} {cname:<24} {ro}")
'
}

_build_patch() {
  # args: container-name ; reads WRITABLE_PATHS
  local c="$1"
  python3 - "$c" "$WRITABLE_PATHS" <<'PY'
import json,sys
c=sys.argv[1]; paths=sys.argv[2].split()
vols=[]; mounts=[]
for i,p in enumerate(paths):
    n=f"rw-{i}"
    vols.append({"name":n,"emptyDir":{}})
    mounts.append({"name":n,"mountPath":p})
patch={"spec":{"template":{"spec":{
    "volumes":vols,
    "containers":[{"name":c,
        "securityContext":{"readOnlyRootFilesystem":True},
        "volumeMounts":mounts}]
}}}}
print(json.dumps(patch))
PY
}

apply() {
  need_kubectl
  local ns="${1:?ns}" dep="${2:?deployment}" c="${3:-}"
  "$KUBECTL" -n "$ns" get deploy "$dep" >/dev/null 2>&1 || die "deploy $ns/$dep not found"
  if [[ -z "$c" ]]; then
    c="$("$KUBECTL" -n "$ns" get deploy "$dep" -o jsonpath='{.spec.template.spec.containers[0].name}')"
    log "container not given — defaulting to first: $c"
  fi

  local bdir; bdir="$(new_backup_dir "$FIX")"
  "$KUBECTL" -n "$ns" get deploy "$dep" -o yaml > "$bdir/$dep.yaml"
  ok "backed up $ns/$dep -> $bdir/$dep.yaml"

  local patch; patch="$(_build_patch "$c")"
  log "patch: $patch"
  confirm "Set readOnlyRootFilesystem=true on $ns/$dep [$c] (+emptyDir: $WRITABLE_PATHS)?"

  "$KUBECTL" -n "$ns" patch deploy "$dep" --type=strategic -p "$patch"
  if "$KUBECTL" -n "$ns" rollout status deploy/"$dep" --timeout="$ROLLOUT_TIMEOUT"; then
    ok "Rollout healthy. readOnlyRootFilesystem enforced on $ns/$dep [$c]."
    ok "Backup: $bdir"
  else
    warn "Rollout did NOT become ready in $ROLLOUT_TIMEOUT — AUTO-ROLLBACK"
    "$KUBECTL" apply -f "$bdir/$dep.yaml"
    "$KUBECTL" -n "$ns" rollout status deploy/"$dep" --timeout="$ROLLOUT_TIMEOUT" || true
    die "rolled back. The app likely writes outside [$WRITABLE_PATHS]; inspect logs and re-run with WRITABLE_PATHS adjusted."
  fi
}

revert() {
  need_kubectl
  local ns="${1:?ns}" dep="${2:?deployment}" bdir="${3:-}"
  bdir="$(resolve_revert_dir "$FIX" "$bdir")"
  [[ -f "$bdir/$dep.yaml" ]] || die "no backup for $dep in $bdir"
  "$KUBECTL" apply -f "$bdir/$dep.yaml"
  "$KUBECTL" -n "$ns" rollout status deploy/"$dep" --timeout="$ROLLOUT_TIMEOUT" || true
  ok "Reverted $ns/$dep from $bdir"
}

case "${1:-}" in
  status) shift; status "$@" ;;
  apply)  shift; apply "$@" ;;
  revert) shift; revert "$@" ;;
  *) die "usage: $0 {status <ns> | apply <ns> <deploy> [container] | revert <ns> <deploy> [backup-dir]}" ;;
esac
