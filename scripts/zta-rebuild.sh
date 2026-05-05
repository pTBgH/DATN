#!/usr/bin/env bash
# scripts/zta-rebuild.sh
#
# End-to-end ZTA cluster rebuild orchestrator. Runs the entire pipeline from
# `kind delete` (phase 0) through `09-verify-zta.sh` (phase 90), capturing
# every step's stdout+stderr to a per-step log file. On any failure it dumps:
#   1. the failed step's full log file (or last N lines if
#      ZTA_REBUILD_DUMP_TAIL=N is set; default 0 = entire log)
#   2. `kubectl get pod -A` filtered to non-Running / restarting pods
#   3. `kubectl get events -A --sort-by=.lastTimestamp` last 20 entries
#   4. `kubectl describe` for any pod in CrashLoopBackOff / Error / Pending
#   5. recent kubelet/api server logs if relevant
# This gives concrete evidence of what went wrong instead of guesses.
#
# Usage:
#   bash scripts/zta-rebuild.sh                    # full rebuild from kind delete
#   bash scripts/zta-rebuild.sh --yes              # skip confirmation prompt
#   bash scripts/zta-rebuild.sh --skip-cluster     # keep existing cluster
#   bash scripts/zta-rebuild.sh --from=08-harden   # resume from step
#   bash scripts/zta-rebuild.sh --to=10-tetragon   # stop after step
#   bash scripts/zta-rebuild.sh --list             # print all steps + exit
#   bash scripts/zta-rebuild.sh --dry-run          # show plan, run nothing
#
# Env vars:
#   ZTA_REBUILD_HALT_ON_FAIL=0   # continue on step failure (default 1, halt)
#   ZTA_REBUILD_SKIP=             # comma-separated step names to skip
#                                 # e.g. ZTA_REBUILD_SKIP=27-pdp
#   COSIGN_TLOG_UPLOAD=true       # opt-in to public Rekor log upload
#                                 # (requires PR #4 merged; default false)
#   ZTA_MODULE_ROLLBACK=0         # disable automatic module rollback on steps
#                                 # 26-27 failure (default 1 = auto-rollback).
#                                 # Set =0 to leave failed release in place for
#                                 # manual inspection before retrying.
#
# Before re-running after a failure, ALWAYS check host + apiserver health:
#   uptime                                  # 1-min load < 10 recommended
#   free -m | head -2                       # available RAM > 1.5 GiB
#   time kubectl get --raw=/readyz          # < 1 s for a healthy cluster
# See doc/incident-gatekeeper-crd-timeout.md for the 504 CRD-install
# failure mode, doc/incident-gatekeeper-probe-webhook-stuck.md for the
# more recent probeWebhook hang that crashed the host VM, and
# doc/incident-falco-tetragon-ram-overcommit.md for the RAM overcommit
# incident that motivated the current Tetragon/Gatekeeper resource sizing.
#
# Steps 26-27 rollback / retry workflow (module-level, cluster preserved):
#   # If step fails, the orchestrator auto-runs do_module_rollback <step>.
#   # To inspect before retrying:
#   ZTA_MODULE_ROLLBACK=0 bash scripts/zta-rebuild.sh --from=26-gatekeeper \
#     --skip-cluster --yes
#   # After inspecting, retry:
#   bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes
#
# Logs (per run):
#   evidence/rebuild_<timestamp>/00-prep.log
#   evidence/rebuild_<timestamp>/01-cluster.log
#   ...
#   evidence/rebuild_<timestamp>/SUMMARY.md     # generated at end
#
set -uo pipefail   # NOT -e: each step's failure is handled by run_step

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER_NAME="${CLUSTER_NAME:-job7189}"
APPS_NS="${APPS_NS:-job7189-apps}"
# These are read by helper functions (do_preflight, do_harden_full,
# do_cosign_sign_workloads) which run inside `bash -c "..."` subshells via
# run_step. Subshells inherit only EXPORTED variables, so without these
# exports `$APPS_NS` was an empty string inside do_cosign_sign_workloads,
# causing `kubectl -n "" get deploy ...` to fail and EVERY service to be
# silently skipped via the `continue` branch (observed during the
# 2026-05-01 rebuild: 22-cosign-sign reported OK in 2s with all 7
# services showing <missing> annotations).
export CLUSTER_NAME APPS_NS REPO_ROOT
TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${REPO_ROOT}/evidence/rebuild_${TS}"
mkdir -p "$LOG_DIR"
SUMMARY_FILE="${LOG_DIR}/SUMMARY.md"

# How much of a failed step's log to print to console. 0 = entire log.
# The full log is always preserved on disk; this only controls how much we
# echo back to the operator. Set ZTA_REBUILD_DUMP_TAIL=200 to limit.
ZTA_REBUILD_DUMP_TAIL="${ZTA_REBUILD_DUMP_TAIL:-0}"

# Per-step timeout (seconds). If a step doesn't finish within this many
# seconds, we send SIGTERM (15s grace) then SIGKILL and treat it as a
# failure with exit code 124 (the convention used by GNU coreutils
# `timeout`). Default is 1800s = 30 minutes — generous because some
# steps (kind create + image pulls + Cilium install) can legitimately
# take 5-10 minutes on a cold machine.
#
# Specific steps with tighter expected wall-clock can be given a per-step
# override via STEP_TIMEOUTS["<step-id>"]=N below.
ZTA_REBUILD_STEP_TIMEOUT="${ZTA_REBUILD_STEP_TIMEOUT:-1800}"

declare -A STEP_TIMEOUTS=(
  # Cosign signs 7 small blobs locally; even with NTP skew it should
  # finish in well under a minute. A long hang here means cosign is
  # trying to reach Rekor (see scripts/zta-cosign-sign-deployment.sh
  # comment about --tlog-upload=false).
  [22-cosign-sign]=300
  # Cosign keygen is a single openssl-equivalent operation.
  [21-cosign-keygen]=60
  # Preflight is fast environment checks.
  [00-prep]=120
  # 25-falco removed from pipeline (Tetragon covers runtime detection).
  # Gatekeeper: helm install + ConstraintTemplate CRD registration
  # + Constraint apply. Worst-case wall-clock breakdown:
  #   pre-flight RAM check                                      :    5s
  #   pre-flight apiserver /readyz (max 180s)                   :  180s
  #   pre-flight load-wait poll (max 300s)                      :  300s
  #   helm install attempt 1 (--timeout 10m)                    :  600s
  #   30s backoff + apiserver re-check                          :   30s
  #   helm install attempt 2 (--timeout 10m)                    :  600s
  #   rollout-status deploy/gatekeeper-controller-manager (300s):  300s
  #   rollout-status deploy/gatekeeper-audit (120s, `|| true`)  :  120s
  #   webhook-endpoints poll (6 × 10s)                          :   60s
  #   controller-manager Ready-stable settle (max 180s)         :  180s
  #   CRD wait first template (300s, cold-start)                :  300s
  #   CRD wait remaining 5 templates (5 × 120s)                 :  600s
  #   constraints apply + 5s sleep                              :   30s
  #                                                       total : 3305s
  # We budget 3600s (60 min) to leave headroom over the 3305s math.
  # The MIN_FREE_MIB + load-wait pre-flight should keep most runs
  # well under 10 min, but the budget must cover the degenerate
  # case (host load > 30 + cold helm + cold controller-manager)
  # so the orchestrator doesn't kill a script that's genuinely
  # making progress.
  # See:
  #   doc/incident-gatekeeper-crd-timeout.md           — original 504
  #   doc/incident-gatekeeper-probe-webhook-stuck.md   — probeWebhook
  #     hang AND follow-on CPU-throttle CRD failure (rebuild
  #     20260505_152348: load=66, controller-manager couldn't
  #     generate ztarequiredlabels CRD within 120s).
  [26-gatekeeper]=3600
  # PDP: pip install inside python:3.11-slim init container can take 3-5 min.
  [27-pdp]=600
)

red()    { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n'   "$*"; }

# ============================================================================
# Step registry
# ============================================================================
# Format: "<id>|<title>|<command>"
# Steps run in array order. Each row's <command> is invoked via `bash -c`,
# so feel free to chain with && / set env vars / call helper functions.
STEPS=(
  "00-prep|Pre-flight checks (tools, host RAM, repo state)|do_preflight"
  "01-cluster|Setup Kind cluster + Cilium + cert-manager + ingress + metrics-server|bash 01-setup-cluster.sh"
  "02-infra|Deploy Vault + Keycloak + MySQL + Kafka + Kong + ELK + Prometheus + Grafana|bash 02-deploy-infrastructure.sh"
  "03-microservices|Deploy 7 Laravel microservices (builds images via 04 internally)|bash 03-deploy-microservices.sh"
  "05-seed|Seed MySQL databases|bash 05-seed-databases.sh"
  "07-monitoring|Deploy node-exporter + kube-state-metrics|bash 07-deploy-monitoring-exporters.sh"
  "08-harden|Enable Cilium mesh-auth + WireGuard + apply namespace CNPs + workload labels + L7|do_harden_full"
  "10-tetragon|Deploy Tetragon eBPF runtime security|bash 10-deploy-tetragon.sh"
  "20-spire|Deploy SPIRE workload attestation (server + agent + controller-manager)|bash scripts/zta-deploy-spire.sh"
  "21-cosign-keygen|Generate Cosign keypair + publish public key ConfigMap|bash scripts/zta-cosign-keygen.sh"
  "22-cosign-sign|Sign all 7 microservice Deployments with offline Cosign|do_cosign_sign_workloads"
  "23-policy-controller|Deploy sigstore policy-controller (image admission)|bash scripts/zta-deploy-policy-controller.sh"
  "24-hubble-export|Enable Hubble flow export to Elasticsearch|bash scripts/zta-deploy-hubble-export.sh --enable-cilium-export"
  # 25-falco was removed from the pipeline. Tetragon (10-tetragon) provides
  # equivalent eBPF runtime detection, and Falco's DS-per-node (~1 GiB total)
  # caused host RAM overcommit on the 12 GiB lab box (cascading OOMKills:
  # tetragon, metrics-server, cilium-operator, policy-controller-webhook).
  # The script scripts/zta-deploy-falco.sh and infras/k8s-yaml/falco/values.yaml
  # are kept on disk as future-work artifacts (e.g. multi-node lab) but are
  # not invoked by the rebuild orchestrator.
  "26-gatekeeper|Deploy OPA Gatekeeper + ZTA constraints|bash scripts/zta-deploy-gatekeeper.sh"
  "27-pdp|Deploy PDP Controller (adaptive loop)|bash scripts/zta-deploy-pdp.sh"
  "90-verify|Run 09-verify-zta.sh (final assessment)|bash 09-verify-zta.sh"
)

# ============================================================================
# CLI parsing
# ============================================================================
NO_PROMPT=0
SKIP_CLUSTER=0
FROM_STEP=""
TO_STEP=""
DRY_RUN=0
LIST_ONLY=0

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in
    --yes|-y)         NO_PROMPT=1 ;;
    --skip-cluster)   SKIP_CLUSTER=1 ;;
    --from=*)         FROM_STEP="${arg#--from=}" ;;
    --to=*)           TO_STEP="${arg#--to=}" ;;
    --dry-run)        DRY_RUN=1 ;;
    --list)           LIST_ONLY=1 ;;
    -h|--help)        usage 0 ;;
    *) red "Unknown flag: $arg"; usage 1 ;;
  esac
done

# Export CLI-derived flags so that exported helper functions (do_preflight,
# do_harden_full, do_cosign_sign_workloads) can read them when they run inside
# `bash -c "..."` subshells via run_step. Without export, variables are empty
# in subshells, causing `[ "$SKIP_CLUSTER" -eq 0 ]` to emit:
#   "environment: line 26: [: : integer expression expected"
export SKIP_CLUSTER NO_PROMPT DRY_RUN FROM_STEP TO_STEP

if [ "$LIST_ONLY" -eq 1 ]; then
  bold "Steps in execution order:"
  for entry in "${STEPS[@]}"; do
    IFS='|' read -r id title cmd <<<"$entry"
    printf "  %-22s  %s\n" "$id" "$title"
  done
  exit 0
fi

# Validate --from / --to step names
all_step_ids=()
for entry in "${STEPS[@]}"; do
  IFS='|' read -r id _ _ <<<"$entry"
  all_step_ids+=("$id")
done
validate_step() {
  local step=$1 label=$2
  [ -z "$step" ] && return 0
  for id in "${all_step_ids[@]}"; do
    [ "$id" = "$step" ] && return 0
  done
  red "Unknown $label step: $step"
  red "Valid steps: ${all_step_ids[*]}"
  exit 1
}
validate_step "$FROM_STEP" "--from"
validate_step "$TO_STEP" "--to"

IFS=',' read -r -a SKIP_LIST <<<"${ZTA_REBUILD_SKIP:-}"
should_skip_step() {
  local id=$1
  for s in "${SKIP_LIST[@]:-}"; do
    [ "$s" = "$id" ] && return 0
  done
  return 1
}

# ============================================================================
# Step helpers (defined in subshell scope, used by STEPS rows)
# ============================================================================

# do_preflight: cheap fail-fast checks before we even touch the cluster.
do_preflight() {
  echo "Tools required: docker, kind, kubectl, helm, jq, python3"
  for tool in docker kind kubectl helm jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      red "  MISSING: $tool not in PATH"
      return 2
    fi
    printf "  ✓ %-10s %s\n" "$tool" "$(command -v "$tool")"
  done
  echo
  echo "Host VM stats:"
  echo "  uname -a: $(uname -a)"
  echo "  CPU cores: $(nproc)"
  echo "  RAM (MiB): $(awk '/MemTotal/ {printf "%d\n", $2/1024}' /proc/meminfo)"
  echo "  Disk free / : $(df -h / | awk 'NR==2 {print $4}')"
  echo
  echo "Docker daemon:"
  docker info --format 'Containers={{.Containers}} Images={{.Images}} ServerVer={{.ServerVersion}}' 2>/dev/null || {
    red "  docker daemon not reachable"
    return 3
  }
  echo
  echo "Repo state:"
  echo "  pwd: $(pwd)"
  echo "  branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  echo "  HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo '?')"
  if [ "${SKIP_CLUSTER:-0}" -eq 0 ]; then
    if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
      yellow "  existing kind cluster '$CLUSTER_NAME' WILL BE DELETED by step 01"
    fi
  fi
}

# do_harden_full: 08-harden-security.sh only flips Cilium mesh-auth + WireGuard.
# The full ZTA enforcement (namespace default-deny, workload labels, L7 policies)
# lives in separate scripts that 08 doesn't call. We invoke them here so a
# single rebuild gets the full policy surface.
do_harden_full() {
  set -e
  echo "--- 08a. mesh-auth + WireGuard ---"
  bash 08-harden-security.sh

  echo "--- 08b. Foundational namespace CNPs (20-security-policies.yaml) ---"
  if [ -f infras/k8s-yaml/20-security-policies.yaml ]; then
    kubectl apply -f infras/k8s-yaml/20-security-policies.yaml
  else
    yellow "  20-security-policies.yaml missing — skipped"
  fi

  echo "--- 08c. job7189-apps microsegmentation (5 CNPs) ---"
  local microseg=infras/k8s-yaml/cilium-policies/apply-zta-microsegmentation.sh
  if [ -x "$microseg" ]; then
    bash "$microseg"
  else
    yellow "  $microseg missing — skipped"
  fi

  echo "--- 08d. Per-namespace CNPs (default-deny + per-flow allows) ---"
  local ns_apply=infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh
  if [ -x "$ns_apply" ]; then
    for ns in monitoring data vault security gateway management; do
      bash "$ns_apply" "--namespace=$ns" --apply
    done
  else
    yellow "  $ns_apply missing — skipped"
  fi

  echo "--- 08e. Workload labels (ZTA 5W1H schema) ---"
  if [ -x scripts/zta-apply-workload-labels.sh ]; then
    bash scripts/zta-apply-workload-labels.sh --apply
  else
    yellow "  scripts/zta-apply-workload-labels.sh missing — skipped"
  fi

  echo "--- 08f. L7 policies ---"
  if [ -x scripts/zta-apply-l7-policies.sh ]; then
    bash scripts/zta-apply-l7-policies.sh --apply
  else
    yellow "  scripts/zta-apply-l7-policies.sh missing — skipped"
  fi
}

# do_cosign_sign_workloads: live-export each Deployment, sign in place,
# re-apply with embedded annotations. Bypasses the helm template signing
# pitfall (templates contain {{ }} and are not valid YAML).
#
# Requires PR #4 merged so cosign sign-blob runs --tlog-upload=false by
# default; we set the env var here as belt-and-suspenders for older script
# versions that read it explicitly.
do_cosign_sign_workloads() {
  set -e
  export COSIGN_TLOG_UPLOAD="${COSIGN_TLOG_UPLOAD:-false}"
  export COSIGN_PASSWORD="${COSIGN_PASSWORD:-}"

  # Defensive: this function runs in a `bash -c` subshell via run_step, so
  # only EXPORTED variables from the parent reach it. APPS_NS is exported
  # at the top of zta-rebuild.sh. If we ever get an empty value here it
  # means someone changed that — fail loudly now instead of silently
  # skipping every service via the kubectl namespace check below.
  if [ -z "${APPS_NS:-}" ]; then
    red "ERROR: APPS_NS is empty inside do_cosign_sign_workloads"
    red "       (parent must export APPS_NS so 'bash -c' subshells inherit it)"
    return 1
  fi

  local sign_dir
  sign_dir="$(mktemp -d /tmp/zta-sign.XXXXXX)"
  echo "  staging dir: $sign_dir"

  local services=(
    candidate-service communication-service hiring-service identity-service
    job-service storage-service workspace-service
  )

  local skipped=0
  local signed=0
  for svc in "${services[@]}"; do
    echo "--- signing $svc ---"
    if ! kubectl -n "$APPS_NS" get deploy "$svc" >/dev/null 2>&1; then
      yellow "  deploy/$svc not present in ns $APPS_NS — skipping"
      skipped=$((skipped + 1))
      continue
    fi
    kubectl -n "$APPS_NS" get deploy "$svc" -o yaml > "$sign_dir/${svc}.yaml"
    bash scripts/zta-cosign-sign-deployment.sh "$sign_dir/${svc}.yaml"
    kubectl apply -f "$sign_dir/${svc}.yaml"
    signed=$((signed + 1))
  done

  echo
  echo "  signed-by annotations:"
  local missing=0
  for svc in "${services[@]}"; do
    local ann
    ann=$(kubectl -n "$APPS_NS" get deploy "$svc" \
            -o jsonpath='{.spec.template.metadata.annotations.image\.zta/signed-by}' 2>/dev/null || true)
    if [ -z "$ann" ]; then
      missing=$((missing + 1))
    fi
    printf "    %-25s %s\n" "$svc" "${ann:-<missing>}"
  done
  rm -rf "$sign_dir"

  echo
  echo "  summary: signed=$signed, skipped=$skipped, missing-annotation=$missing"

  # If we didn't actually sign anything (e.g. wrong namespace, kubeconfig
  # broken, every deployment missing) this used to silently report OK in
  # 2 seconds. Treat it as a failure so the orchestrator halts and the
  # operator gets a real diagnostic instead of having to spot the pattern
  # in the verification table.
  if [ "$signed" -eq 0 ]; then
    red "ERROR: do_cosign_sign_workloads signed 0 of ${#services[@]} services"
    red "       (check that namespace '$APPS_NS' contains the expected Deployments)"
    return 1
  fi
  if [ "$missing" -gt 0 ]; then
    red "ERROR: $missing service(s) finished without a signed-by annotation"
    red "       (cosign-sign-deployment.sh succeeded but kubectl apply did not"
    red "       persist the annotation? check API server admission webhooks)"
    return 1
  fi
}

export -f red green yellow blue bold do_preflight do_harden_full do_cosign_sign_workloads

# ============================================================================
# Module-level rollback helpers for steps 25-27
#
# Strategy: never wipe the whole cluster. Each helper tears out only the helm
# release / CRDs / namespace for the failing module so the pipeline can be
# retried with --from=<step> --skip-cluster --yes. The rest of the cluster
# (Vault, microservices, Tetragon, SPIRE, etc.) is untouched.
#
# Called automatically by dump_failure_context when ZTA_MODULE_ROLLBACK=1
# (default: 1). Set ZTA_MODULE_ROLLBACK=0 to disable automatic rollback and
# leave the failed release in place for manual inspection first.
#
# Usage (manual):
#   do_module_rollback 25-falco
#   do_module_rollback 26-gatekeeper
#   do_module_rollback 27-pdp
# ============================================================================
do_module_rollback() {
  local step_id=$1
  yellow "  [module-rollback] rolling back step '$step_id' (cluster preserved)..."
  case "$step_id" in
    25-falco)
      yellow "  [25-falco rollback] uninstalling helm release 'falco' from ns falco..."
      helm uninstall falco -n falco 2>/dev/null || true
      kubectl delete ns falco --ignore-not-found 2>/dev/null || true
      yellow "  [25-falco rollback] done. Retry: bash scripts/zta-rebuild.sh --from=25-falco --skip-cluster --yes"
      yellow "  [25-falco inspect]"
      echo "    kubectl -n falco get pod"
      echo "    kubectl -n falco logs ds/falco -c falco --tail=60"
      echo "    kubectl -n falco describe pod -l app.kubernetes.io/name=falco"
      echo "    # Check eBPF driver conflict with Tetragon:"
      echo "    kubectl -n kube-system get pod -l app.kubernetes.io/name=tetragon"
      echo "    kubectl -n kube-system top pod -l app.kubernetes.io/name=tetragon"
      ;;
    26-gatekeeper)
      yellow "  [26-gatekeeper rollback] removing constraints + helm release..."
      # Remove constraints before CRDs to avoid orphan finalizers.
      # Includes all 6 constraint kinds (3 ZTA + 3 image-supply-chain).
      kubectl delete ztarequiredlabels,ztablockhostmounts,ztarestrictprivileged \
        --all --ignore-not-found 2>/dev/null || true
      kubectl delete k8simagedigestrequired,k8sblocklatesttag,k8ssignedimageannotation \
        --all --ignore-not-found 2>/dev/null || true
      kubectl delete constrainttemplate --all --ignore-not-found 2>/dev/null || true
      helm uninstall gatekeeper -n gatekeeper-system 2>/dev/null || true
      kubectl delete ns gatekeeper-system --ignore-not-found 2>/dev/null || true
      yellow "  [26-gatekeeper rollback] done. Retry: bash scripts/zta-rebuild.sh --from=26-gatekeeper --skip-cluster --yes"
      yellow "  [26-gatekeeper inspect]"
      echo "    kubectl -n gatekeeper-system get pod"
      echo "    kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager --tail=60"
      echo "    kubectl get constrainttemplate"
      echo "    # Inspect violations after re-apply:"
      echo "    kubectl get ztarequiredlabels zta-labels-required -o jsonpath='{.status.violations}' | jq"
      ;;
    27-pdp)
      yellow "  [27-pdp rollback] removing PDP deployment + configmap + RBAC..."
      kubectl delete deployment zta-pdp -n security --ignore-not-found 2>/dev/null || true
      kubectl delete configmap  zta-pdp-script -n security --ignore-not-found 2>/dev/null || true
      kubectl delete clusterrolebinding zta-pdp --ignore-not-found 2>/dev/null || true
      kubectl delete clusterrole zta-pdp --ignore-not-found 2>/dev/null || true
      kubectl delete serviceaccount zta-pdp -n security --ignore-not-found 2>/dev/null || true
      kubectl delete cnp allow-pdp-controller-egress -n security --ignore-not-found 2>/dev/null || true
      yellow "  [27-pdp rollback] done. Retry: bash scripts/zta-rebuild.sh --from=27-pdp --skip-cluster --yes"
      yellow "  [27-pdp inspect]"
      echo "    kubectl -n security get pod -l app=zta-pdp"
      echo "    kubectl -n security logs -l app=zta-pdp --tail=60"
      echo "    kubectl -n security describe pod -l app=zta-pdp"
      echo "    # CNP egress check:"
      echo "    kubectl -n security get cnp allow-pdp-controller-egress -o yaml"
      ;;
    *)
      yellow "  [module-rollback] no specific rollback defined for '$step_id' — no action taken"
      ;;
  esac
}

# ============================================================================
# Failure diagnostics — dump everything we know about cluster state right now
# ============================================================================
dump_failure_context() {
  local step_id=$1
  local logfile=$2

  red "  ──── DIAGNOSTICS for failed step '$step_id' ────"
  if [ -s "$logfile" ]; then
    local total_lines
    total_lines=$(wc -l < "$logfile" 2>/dev/null || echo 0)
    if [ "${ZTA_REBUILD_DUMP_TAIL:-0}" -gt 0 ] && [ "$total_lines" -gt "$ZTA_REBUILD_DUMP_TAIL" ]; then
      red "  >>> last ${ZTA_REBUILD_DUMP_TAIL} of ${total_lines} lines of $logfile <<<"
      red "      (set ZTA_REBUILD_DUMP_TAIL=0 to print the entire log)"
      tail -n "$ZTA_REBUILD_DUMP_TAIL" "$logfile" | sed 's/^/    | /' >&2
    else
      red "  >>> full log (${total_lines} lines) of $logfile <<<"
      sed 's/^/    | /' "$logfile" >&2
    fi
  else
    red "  (log file empty — step failed with no output; check exit code or wrapper)"
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    return 0
  fi

  echo >&2
  red "  >>> non-Running / restarting pods <<<"
  kubectl get pod -A 2>/dev/null \
    | awk 'NR==1 || $4 != "Running" || $5+0 > 0 {print}' \
    | sed 's/^/    | /' >&2 || true

  echo >&2
  red "  >>> recent events (last 20, all namespaces) <<<"
  kubectl get events -A --sort-by=.lastTimestamp 2>/dev/null \
    | tail -20 \
    | sed 's/^/    | /' >&2 || true

  # Describe any pod that's NOT Running — capture exit codes, probe failures, image pull errors
  local sick_pods
  sick_pods=$(kubectl get pod -A --no-headers 2>/dev/null \
    | awk '$4 != "Running" && $4 != "Completed" {print $1"\t"$2}' \
    | head -5 || true)
  if [ -n "$sick_pods" ]; then
    echo >&2
    red "  >>> kubectl describe for sick pods (first 5) <<<"
    while IFS=$'\t' read -r ns name; do
      [ -z "$ns" ] && continue
      printf '    --- %s/%s ---\n' "$ns" "$name" >&2
      kubectl -n "$ns" describe pod "$name" 2>/dev/null \
        | sed -n '/Events:/,$p' | head -25 | sed 's/^/    | /' >&2 || true
    done <<<"$sick_pods"
  fi

  # Save the full describe output for offline review
  if [ -n "$sick_pods" ]; then
    {
      echo "# Failure diagnostic dump for step $step_id at $(date -u +%FT%TZ)"
      echo
      echo "## Sick pods"
      kubectl get pod -A 2>/dev/null | awk 'NR==1 || $4 != "Running" || $5+0 > 0'
      echo
      echo "## Events (last 50)"
      kubectl get events -A --sort-by=.lastTimestamp 2>/dev/null | tail -50
      echo
      echo "## Pod describe"
      while IFS=$'\t' read -r ns name; do
        [ -z "$ns" ] && continue
        echo
        echo "### $ns/$name"
        kubectl -n "$ns" describe pod "$name" 2>/dev/null || true
        echo
        echo "### $ns/$name logs (current)"
        kubectl -n "$ns" logs "$name" --all-containers --tail=80 2>/dev/null || true
        echo
        echo "### $ns/$name logs (--previous)"
        kubectl -n "$ns" logs "$name" --all-containers --previous --tail=80 2>/dev/null || true
      done <<<"$sick_pods"
    } > "$LOG_DIR/${step_id}.diag.txt" 2>&1 || true
    red "  Full diagnostic written to $LOG_DIR/${step_id}.diag.txt"
  fi

  # Module-level rollback for steps 26-27 — surgically remove the failed
  # release so a --from=<step> retry starts from a clean slate without
  # touching the rest of the cluster. Skip if ZTA_MODULE_ROLLBACK=0.
  # 25-falco is intentionally NOT in this list: Falco was removed from the
  # pipeline (Tetragon covers runtime detection on this 12 GiB host).
  # do_module_rollback still supports 25-falco as a manual teardown helper.
  if [ "${ZTA_MODULE_ROLLBACK:-1}" = "1" ]; then
    case "$step_id" in
      26-gatekeeper|27-pdp)
        do_module_rollback "$step_id"
        ;;
    esac
  else
    case "$step_id" in
      26-gatekeeper|27-pdp)
        yellow "  [module-rollback] ZTA_MODULE_ROLLBACK=0 — skipping automatic rollback."
        yellow "  Inspect manually, then run: do_module_rollback $step_id"
        ;;
    esac
  fi

  red "  ──── END DIAGNOSTICS ────"
}

# ============================================================================
# run_step: the try/catch wrapper
# ============================================================================
RESULTS=()  # "id|status|elapsed|logfile"
run_step() {
  local id=$1 title=$2 cmd=$3
  local logfile="$LOG_DIR/${id}.log"

  echo
  blue "════════════════════════════════════════════════════════"
  blue "▶ $id — $title"
  blue "  cmd: $cmd"
  blue "  log: $logfile"
  blue "════════════════════════════════════════════════════════"

  if [ "$DRY_RUN" -eq 1 ]; then
    yellow "  [dry-run] not executing"
    RESULTS+=("$id|DRY|0|-")
    return 0
  fi

  # Resolve per-step timeout. STEP_TIMEOUTS[<id>] overrides the global
  # ZTA_REBUILD_STEP_TIMEOUT. Set to 0 to disable timeout entirely (NOT
  # recommended — that's how phase 22-cosign-sign hung for 10+ minutes
  # waiting for Rekor before this protection existed).
  local step_timeout="${STEP_TIMEOUTS[$id]:-$ZTA_REBUILD_STEP_TIMEOUT}"
  blue "  timeout: ${step_timeout}s"

  local t0; t0=$(date +%s)
  # Use bash -c so multi-token commands and helper functions both work.
  # `set -o pipefail` keeps tee-style output if the user pipes inside cmd.
  #
  # IMPORTANT: capture $? BEFORE any other command. Bash's `if cmd; then ...; fi`
  # construct sets the if-statement's exit status to ZERO when the test fails
  # and there is no else branch (POSIX: "exit status of an if construct is the
  # exit status of the executed compound list, or zero if no condition tested
  # true"). So reading $? after `fi` reports 0 even if the test command failed,
  # which would falsely report exit=0 on every failed step. We avoid this by
  # running bash -c outside any `if`, capturing $? immediately, then branching
  # on the captured value.
  # Clear BASH_ENV/ENV so we don't drag the user's interactive shell init
  # (e.g. /etc/environment, ~/environment) into every step's subshell. We've
  # seen `environment: line 26: [: : integer expression expected` warnings
  # from one user's init file leak into 00-prep.log; harmless but noisy.
  #
  # `timeout --kill-after=15s` sends SIGTERM at the deadline, then SIGKILL
  # 15 seconds later if the process is still alive. Exit code 124 means the
  # process was terminated by SIGTERM at the deadline; exit code 137 means
  # SIGKILL was delivered (process ignored SIGTERM). Either way the operator
  # gets a clean halt instead of an indefinite hang.
  if [ "$step_timeout" -gt 0 ]; then
    timeout --kill-after=15s "$step_timeout" \
      env -u BASH_ENV -u ENV bash -c "set -o pipefail; $cmd" > "$logfile" 2>&1
  else
    env -u BASH_ENV -u ENV bash -c "set -o pipefail; $cmd" > "$logfile" 2>&1
  fi
  local exit_code=$?
  local dt=$(( $(date +%s) - t0 ))

  if [ "$exit_code" -eq 0 ]; then
    green "  ✓ $id OK (${dt}s)"
    RESULTS+=("$id|OK|$dt|$logfile")
    # Brief tail so the user sees something happened
    tail -5 "$logfile" 2>/dev/null | sed 's/^/    /'
    return 0
  fi

  # Exit codes 124/137 specifically indicate timeout — make this loud so
  # the operator doesn't waste time wondering whether the step's own logic
  # failed or whether we hit the wall clock.
  if [ "$exit_code" -eq 124 ] || [ "$exit_code" -eq 137 ]; then
    red "  ✗ $id TIMED OUT after ${dt}s (limit: ${step_timeout}s, exit=$exit_code)"
    red "    The step ran longer than its budget and was killed."
    red "    Common causes: network hang (cosign Rekor upload, helm chart download),"
    red "    pod stuck Pending (resource starvation, image pull), CrashLoopBackOff."
    echo "*** ZTA_REBUILD timeout: ${step_timeout}s exceeded ***" >> "$logfile"
    RESULTS+=("$id|TIMEOUT|$dt|$logfile")
  else
    red "  ✗ $id FAILED (exit=$exit_code, ${dt}s)"
    RESULTS+=("$id|FAIL($exit_code)|$dt|$logfile")
  fi
  dump_failure_context "$id" "$logfile"

  if [ "${ZTA_REBUILD_HALT_ON_FAIL:-1}" = "1" ]; then
    red "  Halting (ZTA_REBUILD_HALT_ON_FAIL=1; set =0 to continue past failures)."
    write_summary
    exit "$exit_code"
  fi
  return "$exit_code"
}

# ============================================================================
# Summary — one place to check what passed/failed
# ============================================================================
write_summary() {
  {
    echo "# ZTA Rebuild Summary — $TS"
    echo
    echo "Cluster: $(kubectl config current-context 2>/dev/null || echo '?')"
    echo "Started: $(date -d "@$T_START" -u +%FT%TZ 2>/dev/null || echo '?')"
    echo "Ended:   $(date -u +%FT%TZ)"
    echo "Total:   $(( $(date +%s) - T_START )) seconds"
    echo
    echo "| Step | Status | Elapsed | Log |"
    echo "|------|--------|---------|-----|"
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r id st dt log <<<"$r"
      echo "| $id | $st | ${dt}s | $(basename "$log") |"
    done
    echo
    if command -v kubectl >/dev/null 2>&1; then
      echo "## Cluster snapshot at end"
      echo
      echo '```'
      kubectl get pod -A --no-headers 2>/dev/null | wc -l | xargs -I{} echo "Total pods: {}"
      kubectl get pod -A --no-headers 2>/dev/null \
        | awk '$4 != "Running" || $5+0 > 0' | head -20 || true
      echo
      echo "Lease transitions (control-plane):"
      kubectl get lease -n kube-system kube-controller-manager kube-scheduler cilium-operator-resource-lock \
        -o custom-columns=NAME:.metadata.name,T:.spec.leaseTransitions 2>/dev/null || true
      echo '```'
    fi
  } > "$SUMMARY_FILE"
  green "  Summary written to $SUMMARY_FILE"
}

# ============================================================================
# Main loop
# ============================================================================
bold "============================================================"
bold " ZTA Rebuild Orchestrator"
bold " Cluster:   $CLUSTER_NAME"
bold " Apps NS:   $APPS_NS"
bold " Log dir:   $LOG_DIR"
bold " Halt:      ${ZTA_REBUILD_HALT_ON_FAIL:-1} (1=halt, 0=continue)"
bold " From:      ${FROM_STEP:-(start)}"
bold " To:        ${TO_STEP:-(end)}"
bold " Skip:      ${ZTA_REBUILD_SKIP:-(none)}"
bold " Dry-run:   $DRY_RUN"
bold "============================================================"

if [ "$SKIP_CLUSTER" -eq 1 ]; then
  yellow "  --skip-cluster: removing 01-cluster from plan"
fi

if [ "$NO_PROMPT" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  echo
  yellow "  This will DELETE kind cluster '$CLUSTER_NAME' and rebuild it from scratch (~30-50 min)."
  yellow "  All existing data in the cluster will be lost."
  read -r -p "  Continue? (yes/NO) " ans
  if [ "${ans,,}" != "yes" ]; then
    yellow "  Cancelled."
    exit 0
  fi
fi

T_START=$(date +%s)

# Compute which steps to run
in_window=0
[ -z "$FROM_STEP" ] && in_window=1

for entry in "${STEPS[@]}"; do
  IFS='|' read -r id title cmd <<<"$entry"

  # --from gate
  if [ "$in_window" -eq 0 ] && [ "$id" = "$FROM_STEP" ]; then
    in_window=1
  fi
  if [ "$in_window" -eq 0 ]; then
    yellow "  · skip (before --from): $id"
    continue
  fi

  # explicit skip via env or flag
  if [ "$SKIP_CLUSTER" -eq 1 ] && [ "$id" = "01-cluster" ]; then
    yellow "  · skip (--skip-cluster): $id"
    continue
  fi
  if should_skip_step "$id"; then
    yellow "  · skip (ZTA_REBUILD_SKIP): $id"
    continue
  fi

  run_step "$id" "$title" "$cmd"

  # --to gate (after running)
  if [ -n "$TO_STEP" ] && [ "$id" = "$TO_STEP" ]; then
    yellow "  Reached --to=$TO_STEP — stopping."
    break
  fi
done

write_summary

DT=$(( $(date +%s) - T_START ))
echo
green "============================================================"
green " ✅  Rebuild orchestrator finished in ${DT}s"
green "    Logs:    $LOG_DIR"
green "    Summary: $SUMMARY_FILE"
green "============================================================"

# Exit non-zero if any step failed (when halt=0 was used)
for r in "${RESULTS[@]}"; do
  if [[ "$r" == *"|FAIL"* ]]; then
    exit 1
  fi
done
