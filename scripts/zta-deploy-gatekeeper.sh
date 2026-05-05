#!/usr/bin/env bash
# scripts/zta-deploy-gatekeeper.sh
#
# Install OPA Gatekeeper + apply ZTA Constraint Templates and Constraints.
# Idempotent. Skips reinstall if Gatekeeper helm release already healthy.
#
# Usage:
#   bash scripts/zta-deploy-gatekeeper.sh                # install + apply
#   bash scripts/zta-deploy-gatekeeper.sh --uninstall    # remove all
#   bash scripts/zta-deploy-gatekeeper.sh --constraints-only  # skip helm
#
# Prerequisites:
#   - kubectl, helm
#   - PR #9 labels applied (else dry-run violations rất nhiều — đã chấp nhận
#     trên audit-only mode)
#
# After install:
#   kubectl get constrainttemplate
#   kubectl get constraints
#   kubectl get ztarequiredlabels.constraints.gatekeeper.sh \
#     zta-labels-required -o jsonpath='{.status.violations}' | jq
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/utils/zta-common.sh
source "$SCRIPT_DIR/scripts/utils/zta-common.sh"

GK_NS="gatekeeper-system"
GK_VERSION="${GATEKEEPER_VERSION:-3.16.3}"
GK_CHART_REPO="https://open-policy-agent.github.io/gatekeeper/charts"
CONSTRAINT_DIR="$SCRIPT_DIR/infras/k8s-yaml/opa-gatekeeper"

UNINSTALL=0
CONSTRAINTS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    --constraints-only) CONSTRAINTS_ONLY=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Step 2.3.5 — OPA Gatekeeper (PEP Admission)"
blue " Mode: $([ "$UNINSTALL" -eq 1 ] && echo UNINSTALL || ([ "$CONSTRAINTS_ONLY" -eq 1 ] && echo APPLY-CONSTRAINTS || echo INSTALL+APPLY))"
blue "============================================================"

# ---------------------------------------------------------------
# UNINSTALL path
# ---------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  yellow "[1/3] Removing constraints..."
  for f in "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-*.yaml; do
    [[ "$(basename "$f")" == *constraint-template* ]] && continue
    kubectl delete -f "$f" --ignore-not-found 2>&1 | sed 's/^/    /' || true
  done

  yellow "[2/3] Removing constraint templates..."
  for f in "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-template-*.yaml; do
    kubectl delete -f "$f" --ignore-not-found 2>&1 | sed 's/^/    /' || true
  done

  yellow "[3/3] Uninstalling Gatekeeper helm release..."
  if helm list -n "$GK_NS" 2>/dev/null | grep -q gatekeeper; then
    helm uninstall gatekeeper -n "$GK_NS" || true
  fi
  kubectl delete ns "$GK_NS" --ignore-not-found

  green "✓ Gatekeeper + ZTA constraints removed"
  exit 0
fi

# ---------------------------------------------------------------
# INSTALL path
# ---------------------------------------------------------------
if [ "$CONSTRAINTS_ONLY" -ne 1 ]; then
  # -------------------------------------------------------------
  # Pre-flight: host RAM, apiserver responsiveness, host load.
  #
  # Observed failures:
  #   2026-05-05 rebuild_20260505_092417 — "Error: INSTALLATION FAILED:
  #     failed to install CRD crds/syncset-customresourcedefinition.yaml:
  #     Timeout: request did not complete within requested timeout -
  #     context deadline exceeded".
  #     Root cause: apiserver overloaded (host load avg 190+ on 12 GiB
  #     lab VM); CRD POST exceeded the apiserver's 60s request timeout.
  #   2026-05-05 rebuild_20260505_142433 — step TIMEOUT after 1501s.
  #     Root cause: helm install hung on the post-install probeWebhook
  #     curl Job (gatekeeper-probe-webhook-post-install) which waits for
  #     gatekeeper-webhook-service to answer; on an overloaded cluster
  #     the controller-manager pod cannot be scheduled (resource quota
  #     evaluation timed out) so the webhook never becomes Ready and the
  #     hook hangs until the rebuild step's 25-min budget is killed —
  #     and the host VM crashes from the OOM cascade.
  # Fix:
  #   1. Refuse to run if host has < ${MIN_FREE_MIB} MiB available.
  #      Avoids walking into the death-spiral the operator already saw.
  #   2. Wait for /readyz before helm install.
  #   3. Disable post-install probeWebhook hook + use --no-hooks so helm
  #      can never block on a curl-probe Job (we verify rollout ourselves).
  #   4. Retry install up to 2 times with 30s backoff (was 3) so total
  #      wall-clock fits the orchestrator's 1500s step budget.
  # -------------------------------------------------------------
  MIN_FREE_MIB="${MIN_FREE_MIB:-1500}"
  blue "[0a/4] Pre-flight: host RAM (need ≥ ${MIN_FREE_MIB} MiB available)..."
  if [ -r /proc/meminfo ]; then
    _avail=$(awk '/MemAvailable:/ {printf "%d\n", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
    _total=$(awk '/MemTotal:/    {printf "%d\n", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
    echo "    host MemAvailable: ${_avail} MiB / MemTotal: ${_total} MiB"
    if [ "${_avail:-0}" -lt "$MIN_FREE_MIB" ]; then
      red "    ✗ host has only ${_avail} MiB available (need ≥ ${MIN_FREE_MIB} MiB)."
      red "      Refusing to install — overcommit cascade WILL crash the VM"
      red "      (already happened in rebuild_20260505_142433: cluster ended with 0 pods)."
      red "      Free RAM first, e.g.:"
      red "        kubectl -n monitoring scale deploy/grafana --replicas=0"
      red "        kubectl -n logging  scale deploy/kibana  --replicas=0"
      red "        kubectl -n logging  scale sts/elasticsearch --replicas=1"
      red "      then retry: bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes"
      red "      Or override (NOT RECOMMENDED): MIN_FREE_MIB=0 bash scripts/zta-deploy-gatekeeper.sh"
      exit 1
    fi
    green "    ✓ ${_avail} MiB available — proceeding"
  else
    yellow "    /proc/meminfo not readable — skipping RAM pre-flight (untested host)"
  fi

  blue "[0b/4] Pre-flight: waiting for apiserver /readyz (up to 180s)..."
  if ! kubectl wait --for=condition=Ready --timeout=5s node --all >/dev/null 2>&1; then
    red "    ✗ not all nodes Ready — refusing to install into an unhealthy cluster"
    kubectl get nodes
    exit 1
  fi
  _api_ready=0
  for i in 1 2 3 4 5 6; do
    if kubectl get --raw=/readyz --request-timeout=10s >/dev/null 2>&1; then
      _api_ready=1; break
    fi
    yellow "    apiserver /readyz not responding (attempt $i/6) — sleeping 30s..."
    sleep 30
  done
  if [ "$_api_ready" -ne 1 ]; then
    red "    ✗ apiserver still unhealthy after 180s — aborting to avoid orphan resources"
    exit 1
  fi
  green "    ✓ apiserver healthy"

  # Host-load handling. Gatekeeper CRD install hammers etcd and the
  # controller-manager itself needs CPU to compile each ConstraintTemplate's
  # Rego and POST a dynamically-generated CRD. On a CPU-starved host the
  # CRD never reaches `Established` (rebuild_20260505_152348: load=66 →
  # CRD wait timed out at 120s in [3/4]; old behaviour was just a 30s
  # warn-and-proceed which is useless when load > 50). Strategy:
  #   load > LOAD_HARD_FAIL (default 100) — abort, host can't take it.
  #   load > LOAD_WAIT_THRESHOLD (default 20) — poll until it drops
  #       below LOAD_OK_THRESHOLD (default 30) or LOAD_WAIT_MAX_S elapses.
  #   else — proceed immediately.
  LOAD_WAIT_THRESHOLD="${LOAD_WAIT_THRESHOLD:-20}"
  LOAD_OK_THRESHOLD="${LOAD_OK_THRESHOLD:-30}"
  LOAD_HARD_FAIL="${LOAD_HARD_FAIL:-100}"
  LOAD_WAIT_MAX_S="${LOAD_WAIT_MAX_S:-300}"
  if [ -r /proc/loadavg ]; then
    _load1=$(awk '{printf "%.0f", $1}' /proc/loadavg 2>/dev/null || echo 0)
    if [ "${_load1:-0}" -gt "$LOAD_HARD_FAIL" ]; then
      red "    ✗ host 1-min load average is $_load1 (> ${LOAD_HARD_FAIL}) — way too high to install Gatekeeper."
      red "      The controller-manager will be CPU-throttled and ConstraintTemplate CRDs"
      red "      will never reach Established. Free CPU (scale down ELK/Grafana/Tetragon),"
      red "      wait for load < ${LOAD_OK_THRESHOLD}, then retry:"
      red "        bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes"
      red "      Override (NOT RECOMMENDED): LOAD_HARD_FAIL=999 bash scripts/zta-deploy-gatekeeper.sh"
      exit 1
    fi
    if [ "${_load1:-0}" -gt "$LOAD_WAIT_THRESHOLD" ]; then
      yellow "    ⚠ host 1-min load average is $_load1 — polling for it to drop below ${LOAD_OK_THRESHOLD} (max ${LOAD_WAIT_MAX_S}s)..."
      _waited=0
      while [ "$_waited" -lt "$LOAD_WAIT_MAX_S" ]; do
        sleep 30
        _waited=$(( _waited + 30 ))
        _load1=$(awk '{printf "%.0f", $1}' /proc/loadavg 2>/dev/null || echo 0)
        if [ "${_load1:-0}" -le "$LOAD_OK_THRESHOLD" ]; then
          green "    ✓ load dropped to $_load1 after ${_waited}s — proceeding"
          break
        fi
        yellow "    load=$_load1 after ${_waited}s, still > ${LOAD_OK_THRESHOLD}, waiting..."
      done
      if [ "${_load1:-0}" -gt "$LOAD_OK_THRESHOLD" ]; then
        yellow "    ⚠ load still $_load1 after ${LOAD_WAIT_MAX_S}s — proceeding anyway, but step may time out."
      fi
    fi
  fi

  blue "[1/4] Installing OPA Gatekeeper $GK_VERSION via helm..."

  # Common helm --set flags. Why each one matters:
  #   replicas=1 / audit.replicas=1
  #     The chart default is replicas=3 which over-allocates on a 4-node Kind.
  #   controllerManager/audit resources
  #     Sized for the 12 GiB lab VM. See doc/incident-falco-tetragon-ram-overcommit.md.
  #   postInstall.labelNamespace.enabled=false / postUpgrade.labelNamespace.enabled=false
  #     The PSA-labelling Job runs `kubectl label ns gatekeeper-system pod-security.*`
  #     and isn't needed in this lab.
  #   postInstall.probeWebhook.enabled=false   ★ NEW
  #     The chart's default post-install hook is a curl Job that probes
  #     gatekeeper-webhook-service for up to 60 s. On an overloaded cluster
  #     the gatekeeper-controller-manager pod can't be scheduled inside that
  #     window (resource quota admission evaluation times out) → curl exits 7
  #     → helm install fails. Worse, helm WAITS on the hook so the rebuild
  #     step burns its entire 1500 s budget while the host VM dies from
  #     overcommit (rebuild_20260505_142433: cluster ended Total pods=0).
  #     We disable the chart's probe and run our own rollout-status check
  #     after the install instead.
  # We also pass --no-hooks to helm install as belt-and-suspenders: even if
  # someone re-enables the chart hook in values, helm itself will skip ALL
  # hooks. The chart's hooks are only for cosmetic pod-security labels +
  # the broken curl probe; none are required for correctness.
  HELM_SET_ARGS=(
    --set replicas=1
    --set audit.replicas=1
    --set controllerManager.resources.limits.memory=384Mi
    --set controllerManager.resources.requests.memory=192Mi
    --set controllerManager.resources.limits.cpu=500m
    --set controllerManager.resources.requests.cpu=100m
    --set audit.resources.limits.memory=384Mi
    --set audit.resources.requests.memory=192Mi
    --set postInstall.labelNamespace.enabled=false
    --set postUpgrade.labelNamespace.enabled=false
    --set postInstall.probeWebhook.enabled=false
  )

  if helm list -n "$GK_NS" 2>/dev/null | grep -q gatekeeper; then
    yellow "    helm release 'gatekeeper' already present — running upgrade"
    helm repo add gatekeeper "$GK_CHART_REPO" >/dev/null 2>&1 || true
    wait_for_dns open-policy-agent.github.io
    helm_repo_update_retry gatekeeper
    helm upgrade gatekeeper gatekeeper/gatekeeper \
      -n "$GK_NS" \
      --version "$GK_VERSION" \
      --timeout 10m \
      --no-hooks \
      --reuse-values
  else
    helm repo add gatekeeper "$GK_CHART_REPO" >/dev/null 2>&1 || true
    wait_for_dns open-policy-agent.github.io
    helm_repo_update_retry gatekeeper
    kubectl create ns "$GK_NS" --dry-run=client -o yaml | kubectl apply -f -
    # Retry wrapper: helm fails fast (~50s) when apiserver returns 504 on
    # CRD install. 2 attempts with 30s backoff (was 3) so the total
    # wall-clock fits the orchestrator's 1500s step budget. On each retry
    # we re-check apiserver health and wipe any ghost release left over
    # from the prior failed attempt ("namespace/gatekeeper-system created"
    # + no release but CRDs half-installed is a known helm failure mode).
    _helm_ok=0
    for attempt in 1 2; do
      blue "    helm install attempt ${attempt}/2 (timeout 10m, --no-hooks)..."
      if helm install gatekeeper gatekeeper/gatekeeper \
          -n "$GK_NS" \
          --version "$GK_VERSION" \
          --timeout 10m \
          --no-hooks \
          "${HELM_SET_ARGS[@]}"; then
        _helm_ok=1; break
      fi
      yellow "    ✗ helm install attempt ${attempt} failed — cleaning orphaned CRDs/release before retry"
      helm uninstall gatekeeper -n "$GK_NS" 2>/dev/null || true
      kubectl get crd -o name 2>/dev/null \
        | grep -E 'gatekeeper\.sh$' \
        | xargs -r -n 1 kubectl delete --ignore-not-found 2>/dev/null || true
      if [ "$attempt" -lt 2 ]; then
        yellow "    sleeping 30s, re-checking apiserver, then retrying..."
        sleep 30
        kubectl get --raw=/readyz --request-timeout=10s >/dev/null 2>&1 || {
          red "    ✗ apiserver unhealthy at retry — aborting"
          exit 1
        }
      fi
    done
    if [ "$_helm_ok" -ne 1 ]; then
      red "    ✗ helm install failed 2 times — aborting"
      red "      Most common root cause on this lab: apiserver overload."
      red "      Fix: free host RAM / reduce load, then:"
      red "        bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes"
      exit 1
    fi
  fi

  blue "[2/4] Waiting for Gatekeeper controller-manager rollout..."
  # We disabled the chart's post-install probeWebhook curl Job, so this
  # rollout-status is now the SOLE gate that the webhook is up. If it
  # fails we surface the real reason (sick pods / events) instead of a
  # cryptic curl exit 7.
  if ! kubectl -n "$GK_NS" rollout status deploy/gatekeeper-controller-manager --timeout=300s; then
    red "    ✗ controller-manager rollout failed (300s budget)"
    kubectl -n "$GK_NS" get pod
    kubectl -n "$GK_NS" get events --sort-by=.lastTimestamp | tail -20
    exit 1
  fi
  # gatekeeper-audit isn't on the critical path for ConstraintTemplate CRD
  # generation — only controller-manager is. Don't block the install for
  # the audit Deployment; cap at 120s so we don't burn step budget here.
  kubectl -n "$GK_NS" rollout status deploy/gatekeeper-audit --timeout=120s || true

  # Manual webhook probe (replaces the chart's curl Job). We hit the apiserver
  # routing layer to gatekeeper-webhook-service from inside the cluster — this
  # is exactly what the disabled post-install hook used to do, but as a
  # short-lived `kubectl run` so a hang here can't block helm install.
  blue "    probing gatekeeper-webhook-service (replaces chart's post-install hook)..."
  _probe_ok=0
  for i in 1 2 3 4 5 6; do
    if kubectl -n "$GK_NS" get endpoints gatekeeper-webhook-service \
         -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | grep -q '\.'; then
      _probe_ok=1; break
    fi
    yellow "    webhook endpoints not populated yet (attempt $i/6) — sleeping 10s..."
    sleep 10
  done
  if [ "$_probe_ok" -ne 1 ]; then
    red "    ✗ gatekeeper-webhook-service has no endpoints after 60s — webhook not Ready"
    kubectl -n "$GK_NS" describe svc gatekeeper-webhook-service | head -40
    exit 1
  fi

  # Settle. The Deployment becoming Available != the controller-manager
  # leader-election + ConstraintTemplate reconciler is up. On a CPU-throttled
  # host the readiness probe can flap (rebuild_20260505_152348 events showed
  # readiness 'connection refused' even after the rollout returned), and the
  # FIRST ConstraintTemplate apply lands before the controller has finished
  # warming up its caches — which is why its dynamic CRD never reaches
  # Established within 120s. Wait for 30 consecutive seconds of Ready=True
  # before we start applying templates.
  blue "    waiting for controller-manager to be stable Ready for 30s..."
  _stable=0; _settle_max=180
  while [ "$_stable" -lt 30 ] && [ "$_settle_max" -gt 0 ]; do
    if kubectl -n "$GK_NS" get pod \
         -l control-plane=controller-manager \
         -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
         | grep -qw True; then
      _stable=$(( _stable + 5 ))
    else
      _stable=0
    fi
    sleep 5
    _settle_max=$(( _settle_max - 5 ))
  done
  if [ "$_stable" -lt 30 ]; then
    yellow "    ⚠ controller-manager Ready not stable after 180s — proceeding anyway, but [3/4] may fail"
  else
    green "    ✓ controller-manager stable Ready for 30s"
  fi
  green "    ✓ Gatekeeper running"
fi

# ---------------------------------------------------------------
# APPLY constraints
# ---------------------------------------------------------------
blue "[3/4] Applying ConstraintTemplates (sequentially, with CRD wait)..."
# Apply each template ONE at a time and wait for its generated CRD to be
# Established before moving to the next. Gatekeeper's controller-manager
# generates a `<kind>.constraints.gatekeeper.sh` CRD per ConstraintTemplate;
# on a busy cluster (ours: 76+ pods, control-plane under load) the
# controller-manager can be CPU-throttled or restart during a batch apply,
# silently dropping CRD generation for the later templates. Sequential
# apply gives the controller breathing room and surfaces failures cleanly.
declare -A TEMPLATE_TO_CRD=(
  [01-constraint-template-required-zta-labels.yaml]=ztarequiredlabels
  [03-constraint-template-block-host-mounts.yaml]=ztablockhostmounts
  [05-constraint-template-restrict-privileged.yaml]=ztarestrictprivileged
  [07-constraint-template-image-digest-required.yaml]=k8simagedigestrequired
  [09-constraint-template-block-latest-tag.yaml]=k8sblocklatesttag
  [11-constraint-template-signed-image-annotation.yaml]=k8ssignedimageannotation
)
# Iterate in numerically-sorted filename order so we match the on-disk numbering.
# CRD-wait budget per template:
#   First template: 300s. The controller-manager has just started, so the
#     reconciler cold-start (loading caches, leader-election, opening the
#     webhook server, compiling its first Rego template) can take 60-180s
#     on a CPU-throttled host (rebuild_20260505_152348: load=66 made the
#     old 120s budget too tight; the CRD never reached Established).
#   Subsequent templates: 120s. Once the controller has generated one CRD
#     successfully it stays warm; subsequent templates compile in seconds.
CRD_WAIT_FIRST="${CRD_WAIT_FIRST:-300s}"
CRD_WAIT_REST="${CRD_WAIT_REST:-120s}"
_first_template=1
for f in $(ls "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-template-*.yaml | sort); do
  base=$(basename "$f")
  crd_kind="${TEMPLATE_TO_CRD[$base]:-}"
  if [ -z "$crd_kind" ]; then
    red "    ✗ unknown template $base — add to TEMPLATE_TO_CRD map"
    exit 1
  fi
  if [ "$_first_template" -eq 1 ]; then
    _wait="$CRD_WAIT_FIRST"
    _first_template=0
  else
    _wait="$CRD_WAIT_REST"
  fi
  echo "    + $base"
  kubectl apply -f "$f"
  echo "      waiting for crd/${crd_kind}.constraints.gatekeeper.sh to be Established (up to ${_wait})..."
  if ! kubectl wait --for=condition=Established "crd/${crd_kind}.constraints.gatekeeper.sh" --timeout="$_wait" 2>/dev/null; then
    red "    ✗ CRD ${crd_kind}.constraints.gatekeeper.sh never reached Established within ${_wait}"
    red "      Likely cause: ConstraintTemplate Rego compile error, or Gatekeeper controller-manager"
    red "      OOM/CPU-throttled. Inspect:"
    red "        kubectl describe constrainttemplate $crd_kind"
    red "        kubectl -n $GK_NS logs deploy/gatekeeper-controller-manager --tail=80"
    red "        uptime    # if 1-min load > 30 the controller is CPU-starved — free CPU and retry"
    exit 1
  fi
  green "      ✓ ${crd_kind} CRD Established"
done
green "    ✓ all ConstraintTemplate CRDs registered"

blue "[4/4] Applying Constraints..."
for f in "$CONSTRAINT_DIR"/[0-9][0-9]-constraint-*.yaml; do
  if [[ "$(basename "$f")" == *constraint-template* ]]; then
    continue
  fi
  echo "    + $(basename "$f")"
  kubectl apply -f "$f"
done

# Brief wait for first audit pass
sleep 5

green "============================================================"
green " ✓ Gatekeeper + ZTA constraints applied"
green "============================================================"
echo
echo "Constraints status (audit-only by default):"
kubectl get constrainttemplate 2>&1 | head -10
echo
echo "Active constraints:"
kubectl get ztarequiredlabels,ztablockhostmounts,ztarestrictprivileged 2>&1 | head -20
echo
yellow "Next steps:"
echo "  - Inspect violations:"
echo "      kubectl get ztarequiredlabels.constraints.gatekeeper.sh \\"
echo "        zta-labels-required -o jsonpath='{.status.violations}' | jq"
echo "  - When 0 violations, switch enforcementAction: dryrun → deny in"
echo "    02-constraint-zta-labels.yaml + re-apply."
