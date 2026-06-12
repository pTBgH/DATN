#!/usr/bin/env bash
#==============================================================================
# zta-latency-benchmark.sh
#
# Measures end-to-end latency through the ZTA stack (Kong + OPA + Cilium)
# for thesis chapter4 §5.2 (47-next-tasks.md Task 4 / Phase 5.F Item J).
#
# Modes:
#   ./zta-latency-benchmark.sh enforced     # full ZTA path (default)
#   ./zta-latency-benchmark.sh baseline     # caller must have disabled
#                                           # enforcement beforehand; this
#                                           # script only verifies + measures
#
# Targets (per 47-next-tasks.md): P50 < 500ms, P99 < 2s in enforced mode.
# Requires: hey (https://github.com/rakyll/hey) or falls back to curl loop.
# Run from a host that can reach the Kong NodePort. Idempotent, read-only.
# Exit codes: 0=OK, 1=targets missed, 2=preflight fail.
#==============================================================================
set -uo pipefail

MODE="${1:-enforced}"
KONG_HOST="${KONG_HOST:-}"   # auto-detected from cluster if empty; override via env
KONG_PORT="${KONG_PORT:-}"   # auto-detected NodePort of gateway/kong-proxy if empty
DURATION="${DURATION:-60s}"
CONCURRENCY="${CONCURRENCY:-20}"
PATHS=("/api/health" "/api/public/jobs" "/api/jobs")
TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="/tmp/zta-latency-${MODE}-${TS}"
mkdir -p "$OUTDIR"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
fail() { log "FATAL: $*"; exit 2; }

#------------------------------------------------------------------------------
# PRE-FLIGHT CHECKS
#------------------------------------------------------------------------------
log "=== PRE-FLIGHT (mode: $MODE) ==="

command -v curl >/dev/null 2>&1 || fail "curl not found"
HAVE_HEY=true
command -v hey >/dev/null 2>&1 || { HAVE_HEY=false; log "WARN: 'hey' not found, falling back to curl sampling (less accurate)"; }

# Auto-detect Kong endpoint from the cluster if not provided
if command -v kubectl >/dev/null 2>&1 && timeout 15 kubectl version --request-timeout=10s >/dev/null 2>&1; then
  if [[ -z "$KONG_PORT" ]]; then
    KONG_PORT=$(kubectl get svc -n gateway kong-proxy -o jsonpath='{.spec.ports[?(@.name=="proxy")].nodePort}' 2>/dev/null || true)
    [[ -z "$KONG_PORT" ]] && KONG_PORT=$(kubectl get svc -n gateway kong-proxy -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)
  fi
  if [[ -z "$KONG_HOST" ]]; then
    KONG_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
  fi
fi
[[ -n "$KONG_HOST" && -n "$KONG_PORT" ]] || fail "Could not determine Kong endpoint; set KONG_HOST and KONG_PORT env vars"
log "Kong endpoint: ${KONG_HOST}:${KONG_PORT}"

# Reachability of Kong before generating load: require an actual HTTP response
HTTP_CODE=$(timeout 10 curl -s -o /dev/null -w '%{http_code}' "http://${KONG_HOST}:${KONG_PORT}/api/health" 2>/dev/null)
CURL_RC=$?
if [[ "$CURL_RC" -ne 0 || -z "$HTTP_CODE" || "$HTTP_CODE" == "000" ]]; then
  fail "Kong unreachable at ${KONG_HOST}:${KONG_PORT} (curl rc=$CURL_RC, code=${HTTP_CODE:-none}) — check NodePort/Tailscale, or set KONG_HOST/KONG_PORT"
fi
log "Kong reachable (HTTP $HTTP_CODE on /api/health)"

# If kubectl available, verify cluster state so results are attributable
if command -v kubectl >/dev/null 2>&1 && timeout 15 kubectl version --request-timeout=10s >/dev/null 2>&1; then
  NOT_READY_APPS=$(kubectl get pods -n job7189-apps --no-headers 2>/dev/null | grep -vc "Running" || true)
  [[ "$NOT_READY_APPS" -gt 0 ]] && fail "$NOT_READY_APPS app pods not Running — fix before benchmarking"
  log "All job7189-apps pods Running"

  # Node memory headroom: load test on a starved cluster produces garbage data
  while read -r node mem_pct; do
    [[ -n "$mem_pct" && "${mem_pct%\%}" -ge 90 ]] && fail "Node $node at ${mem_pct} memory — results would be invalid"
  done < <(timeout 20 kubectl top nodes --no-headers 2>/dev/null | awk '{print $1, $5}')
  log "Node memory headroom OK"

  CNP_COUNT=$(kubectl get cnp -n job7189-apps --no-headers 2>/dev/null | wc -l)
  if [[ "$MODE" == "enforced" && "$CNP_COUNT" -eq 0 ]]; then
    fail "Mode 'enforced' but 0 CNPs in job7189-apps — policies not applied"
  fi
  if [[ "$MODE" == "baseline" && "$CNP_COUNT" -gt 0 ]]; then
    fail "Mode 'baseline' but $CNP_COUNT CNPs still active — disable enforcement first"
  fi
  log "Policy state consistent with mode '$MODE' ($CNP_COUNT CNPs)"
else
  log "WARN: kubectl unavailable — cannot verify cluster state; results unattributed"
fi

#------------------------------------------------------------------------------
# BENCHMARK
#------------------------------------------------------------------------------
log "=== BENCHMARK: ${DURATION}, ${CONCURRENCY} concurrent, $((${#PATHS[@]})) paths ==="
OVERALL_FAIL=0

for path in "${PATHS[@]}"; do
  SAFE_NAME=$(echo "$path" | tr '/' '_')
  OUT="$OUTDIR/${SAFE_NAME}.txt"
  URL="http://${KONG_HOST}:${KONG_PORT}${path}"
  log "--- $URL ---"
  if $HAVE_HEY; then
    timeout 120 hey -z "$DURATION" -c "$CONCURRENCY" "$URL" > "$OUT" 2>&1 || { log "WARN: hey failed for $path"; OVERALL_FAIL=1; continue; }
    grep -E "50% in|99% in|requests/sec|Status code" -A2 "$OUT" | head -20
    P50=$(grep "50% in" "$OUT" | awk '{print $3}')
    P99=$(grep "99% in" "$OUT" | awk '{print $3}')
    if [[ -z "$P50" || -z "$P99" ]]; then
      log "ERROR: no successful responses for $path — endpoint not serving (see $OUT)"
      OVERALL_FAIL=1
      continue
    fi
    # targets: P50 < 0.5s, P99 < 2s
    awk -v p50="$P50" -v p99="$P99" 'BEGIN{exit !(p50<0.5 && p99<2)}' \
      || { log "TARGET MISSED on $path (P50=${P50}s P99=${P99}s)"; OVERALL_FAIL=1; }
  else
    for i in $(seq 1 50); do
      curl -s -o /dev/null -w '%{time_total}\n' "$URL" >> "$OUT"
    done
    sort -n "$OUT" > "$OUT.sorted"
    P50=$(sed -n '25p' "$OUT.sorted"); P99=$(sed -n '50p' "$OUT.sorted")
    log "curl sampling: P50=${P50}s P~99=${P99}s (50 samples)"
    awk -v p50="$P50" -v p99="$P99" 'BEGIN{exit !(p50<0.5 && p99<2)}' \
      || { log "TARGET MISSED on $path"; OVERALL_FAIL=1; }
  fi
done

log "=== DONE — raw outputs in $OUTDIR ==="
log "Record P50/P99 per path into chapter4.tex §5.2 (mode: $MODE)."
exit "$OVERALL_FAIL"
