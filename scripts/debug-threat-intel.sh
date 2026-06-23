#!/usr/bin/env bash
# =============================================================================
# debug-threat-intel.sh — capture the EXACT reason the feed job fails.
#
# The CronJob deletes its pods on failure (backoffLimit), so `kubectl logs
# job/...` returns nothing after the fact. This script runs ONE fresh attempt
# and streams the container logs LIVE so you see which command exits non-zero.
#
# It changes nothing permanent: it only creates a throwaway Job (and cleans it
# up at the end unless KEEP=1).
#
# Usage:
#   ./debug-threat-intel.sh
#   KEEP=1 ./debug-threat-intel.sh      # keep the debug job/pod afterwards
# =============================================================================
set -uo pipefail
KUBECTL="${KUBECTL:-kubectl}"
NS="security-cdm"
CRONJOB="threat-intel-refresh"
JOB="ti-debug-$(date -u +%H%M%S)"

echo "[*] context = $($KUBECTL config current-context 2>/dev/null)"

# 0) Quick precondition checks (these are the usual culprits) --------------
echo "=== precondition checks ==="
echo -n "coredns-sinkhole CM in kube-system: "
$KUBECTL -n kube-system get cm coredns-sinkhole >/dev/null 2>&1 \
  && echo "EXISTS" || echo ">>> MISSING <<<  (this alone makes the job fail at the sinkhole-patch step)"
echo -n "ciliumcidrgroup threat-intel-firehol: "
$KUBECTL get ciliumcidrgroup threat-intel-firehol >/dev/null 2>&1 && echo "EXISTS" || echo ">>> MISSING <<<"
echo -n "SA can patch coredns-sinkhole: "
$KUBECTL auth can-i patch cm/coredns-sinkhole -n kube-system \
  --as=system:serviceaccount:security-cdm:threat-intel-updater 2>/dev/null || echo "?"

# 1) Run one fresh attempt and stream logs ---------------------------------
echo "=== running one debug job: $JOB ==="
$KUBECTL -n "$NS" patch cronjob "$CRONJOB" --type merge -p '{"spec":{"suspend":false}}' >/dev/null
$KUBECTL -n "$NS" create job "$JOB" --from="cronjob/$CRONJOB"

echo "[*] waiting for pod..."
POD=""
for _ in $(seq 1 60); do
  POD=$($KUBECTL -n "$NS" get pods --selector=job-name="$JOB" -o name 2>/dev/null | head -1)
  [[ -n "$POD" ]] && break
  sleep 2
done
[[ -n "$POD" ]] || { echo "[x] no pod appeared"; exit 1; }
echo "[*] pod = $POD"

# Stream a container's logs, but WAIT until it has actually started
# (init container image pull can take minutes) instead of erroring on
# PodInitializing. Polls until `logs` works, then follows to completion.
follow() { # $1 = container name
  local c="$1"
  echo "=== $c logs (waiting for container to start) ==="
  for _ in $(seq 1 180); do
    if $KUBECTL -n "$NS" logs "$POD" -c "$c" >/dev/null 2>&1; then
      $KUBECTL -n "$NS" logs -f "$POD" -c "$c" 2>&1 | sed "s/^/[$c] /"
      return 0
    fi
    local phase; phase=$($KUBECTL -n "$NS" get "$POD" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$phase" == "Failed" || "$phase" == "Succeeded" ]]; then
      $KUBECTL -n "$NS" logs "$POD" -c "$c" 2>&1 | sed "s/^/[$c] /"; return 0
    fi
    sleep 2
  done
  echo "[!] $c never produced logs (timeout)"
}

follow fetch-feeds
follow apply-configmap

echo "=== container exit codes / reasons ==="
$KUBECTL -n "$NS" get "$POD" -o jsonpath='{range .status.initContainerStatuses[*]}init {.name}: {.state}{"\n"}{end}{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}' 2>/dev/null
echo
$KUBECTL -n "$NS" describe "$POD" | sed -n '/Events/,$p' || true

# 2) cleanup (default: KEEP the job so logs survive for inspection) ---------
if [[ "${KEEP:-1}" != "1" ]]; then
  echo "[*] cleaning up debug job (KEEP=0 set)"
  $KUBECTL -n "$NS" delete job "$JOB" --ignore-not-found >/dev/null
else
  echo "[*] kept job $JOB — re-read logs with:"
  echo "    kubectl -n $NS logs $POD -c apply-configmap"
  echo "    kubectl -n $NS delete job $JOB   # when done"
fi
echo "[*] done. Re-suspend the cronjob if you don't want hourly runs:"
echo "    $KUBECTL -n $NS patch cronjob $CRONJOB --type merge -p '{\"spec\":{\"suspend\":true}}'"

