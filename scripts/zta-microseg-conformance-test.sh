#!/usr/bin/env bash
# =============================================================================
# zta-microseg-conformance-test.sh — synthetic L4 conformance test
#
# Validates that the deployed Cilium L4 microsegmentation policies enforce
# the expected ALLOW/DROP behaviour for every (src_ns, dst_host, dst_port)
# pair in `scripts/zta-microseg-conformance-matrix.csv`.
#
# Replaces the "watch hubble for 24h and hope" pattern with a deterministic,
# repeatable test that closes Phase 2C: if every row passes, the L4
# microsegmentation baseline is considered closed.
#
# Output:
#   evidence/microseg-conformance-<ts>.csv  — full per-row result (machine-readable)
#   evidence/microseg-conformance-<ts>.log  — verbose run log
#   evidence/microseg-conformance-<ts>.md   — human-readable summary + failures
#
# Modes:
#   (default)         Run the matrix (skipping anomaly rows beginning with `A`).
#   --anomaly         Also run anomaly-injection rows (commented-out by default
#                     in the matrix — uncomment the `A*` rows to activate).
#   --dry-run         Print the matrix as parsed without spawning any pods.
#   --keep-pods       Don't delete test pods after the run (for debugging).
#   --filter <regex>  Only run matrix rows whose id matches the regex (eg
#                     `--filter '^N0'` to run only negative cases).
#   -h | --help       Show this header and exit.
#
# Exit codes:
#   0 — all rows passed
#   1 — one or more rows failed
#   2 — invalid invocation / missing pre-requisites
#
# Pre-req: kubectl with cluster-admin (or namespace-scoped exec/create on
# the source namespaces listed in the matrix), a running cluster with
# Cilium 1.x and the ZTA CNPs already applied.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX_FILE="${ZTA_MATRIX_FILE:-$SCRIPT_DIR/scripts/zta-microseg-conformance-matrix.csv}"
BUSYBOX_IMAGE="${ZTA_BUSYBOX_IMAGE:-busybox:1.37.0}"
PROBE_TIMEOUT="${ZTA_PROBE_TIMEOUT:-5}"           # nc -w seconds
POD_TIMEOUT="${ZTA_POD_TIMEOUT:-60}"              # kubectl run --timeout

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
MODE_ANOMALY=0
MODE_DRY=0
MODE_KEEP=0
FILTER_RE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --anomaly)    MODE_ANOMALY=1 ;;
    --dry-run)    MODE_DRY=1 ;;
    --keep-pods)  MODE_KEEP=1 ;;
    --filter)     shift; FILTER_RE="${1:-}" ;;
    -h|--help)    sed -n '2,40p' "$0"; exit 0 ;;
    *)            red "Unknown flag: $1"; exit 2 ;;
  esac
  shift || true
done

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if [ ! -f "$MATRIX_FILE" ]; then
  red "ERR: matrix file not found at $MATRIX_FILE"; exit 2
fi
# kubectl + cluster reachability are only required when we actually spawn pods.
if [ "$MODE_DRY" -ne 1 ]; then
  if ! command -v kubectl >/dev/null 2>&1; then
    red "ERR: kubectl not in PATH"; exit 2
  fi
  if ! kubectl cluster-info >/dev/null 2>&1; then
    red "ERR: kubectl cannot reach a cluster"; exit 2
  fi
fi

EVIDENCE_DIR="$SCRIPT_DIR/evidence"
mkdir -p "$EVIDENCE_DIR"
RUN_TS=$(date -u +"%Y%m%d_%H%M%S")
RESULTS_CSV="$EVIDENCE_DIR/microseg-conformance-${RUN_TS}.csv"
RUN_LOG="$EVIDENCE_DIR/microseg-conformance-${RUN_TS}.log"
SUMMARY_MD="$EVIDENCE_DIR/microseg-conformance-${RUN_TS}.md"

exec > >(tee -a "$RUN_LOG") 2>&1
echo "[$(date -u +%FT%TZ)] Run log: $RUN_LOG"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
SPAWNED_PODS=()        # "ns/name" entries
cleanup() {
  if [ "$MODE_KEEP" -eq 1 ]; then
    yellow "  --keep-pods: leaving ${#SPAWNED_PODS[@]} test pod(s) in place"
    for p in "${SPAWNED_PODS[@]:-}"; do echo "    $p"; done
    return
  fi
  if [ ${#SPAWNED_PODS[@]} -gt 0 ]; then
    blue "Cleaning up ${#SPAWNED_PODS[@]} test pod(s)..."
    for p in "${SPAWNED_PODS[@]}"; do
      ns="${p%%/*}"; name="${p##*/}"
      kubectl -n "$ns" delete pod "$name" \
        --grace-period=0 --force --ignore-not-found \
        --timeout=15s >/dev/null 2>&1 || true
    done
  fi
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# CSV write helper
# ---------------------------------------------------------------------------
echo "id,src_ns,src_labels,dst_host,dst_port,protocol,expected,observed,result,duration_s,cnp_ref,description,err" \
  > "$RESULTS_CSV"

emit_row() {
  # quote any field with comma → wrap in dquotes
  local out=""
  local first=1
  for f in "$@"; do
    if [ $first -eq 1 ]; then first=0; else out+=","; fi
    case "$f" in
      *,*|*\"*) out+="\"$(printf '%s' "$f" | sed 's/"/""/g')\"" ;;
      *)        out+="$f" ;;
    esac
  done
  echo "$out" >> "$RESULTS_CSV"
}

# ---------------------------------------------------------------------------
# Per-row probe
# ---------------------------------------------------------------------------
PASS=0; FAIL=0; SKIP=0
FAILURES=()    # human-readable strings

probe_row() {
  local id="$1" src_ns="$2" src_labels="$3" dst_host="$4" dst_port="$5"
  local proto="$6" expected="$7" cnp_ref="$8" desc="$9"

  # ICMP / EXEC / UDP probes need different tooling — skip with a marker
  # row in the CSV so the matrix author knows the test wasn't run.
  case "$proto" in
    TCP)  ;;  # handled below
    UDP)
      yellow "  [$id] SKIP — UDP probes not implemented in v1 ($desc)"
      emit_row "$id" "$src_ns" "$src_labels" "$dst_host" "$dst_port" \
        "$proto" "$expected" "n/a" "SKIP" 0 "$cnp_ref" "$desc" "udp-not-impl"
      SKIP=$((SKIP+1))
      return
      ;;
    EXEC|ICMP*)
      yellow "  [$id] SKIP — non-L4 probe type '$proto' not implemented ($desc)"
      emit_row "$id" "$src_ns" "$src_labels" "$dst_host" "$dst_port" \
        "$proto" "$expected" "n/a" "SKIP" 0 "$cnp_ref" "$desc" "proto-not-impl"
      SKIP=$((SKIP+1))
      return
      ;;
  esac

  # Spawn pod.
  # Pod names must be DNS-1123 (lowercase alphanumeric + '-' only). The
  # session timestamp contains a `_` so we use a deterministic
  # `<pid>-<row-counter>` suffix instead — guarantees uniqueness for
  # parallel runs without smuggling invalid characters into the name.
  local pod_name="zta-conf-${id,,}-${$}-${ROW_NO}"
  local label_args=""
  if [ -n "$src_labels" ]; then
    label_args="--labels=zta.conformance/test=true,zta.conformance/id=${id,,},$src_labels"
  else
    label_args="--labels=zta.conformance/test=true,zta.conformance/id=${id,,}"
  fi

  blue "  [$id] $expected: $src_ns → $dst_host:$dst_port  ($desc)"

  # `kubectl run --command -- nc -zvw5 host port` returns the exit code of
  # nc directly via the Job-style runner (Restart=Never + --attach + --wait).
  # Use --rm=false so we control deletion via SPAWNED_PODS for cleanup.
  #
  # Duration in whole seconds. We originally used `date +%s%3N` but the
  # `%3N` format produced inconsistent output on at least one operator's
  # GNU coreutils build (mixing 13-digit ms timestamps with 19-digit ns
  # timestamps), yielding meaningless huge / negative durations in the
  # CSV. Second-precision is enough to spot a 5 s `nc` timeout vs. an
  # immediate handshake.
  local start_s=$(date +%s)
  local probe_out=""
  local probe_rc=0
  # NB: shellcheck word-splitting on $label_args is intentional.
  # shellcheck disable=SC2086
  if probe_out=$(kubectl -n "$src_ns" run "$pod_name" \
        --image="$BUSYBOX_IMAGE" --restart=Never \
        --pod-running-timeout="${POD_TIMEOUT}s" \
        --attach --quiet \
        $label_args \
        --command -- \
        nc -zvw"$PROBE_TIMEOUT" "$dst_host" "$dst_port" 2>&1); then
    probe_rc=0
  else
    probe_rc=$?
  fi
  local end_s=$(date +%s)
  local dur=$((end_s - start_s))
  SPAWNED_PODS+=("${src_ns}/${pod_name}")

  # nc exit code semantics (busybox 1.37):
  #   0    — TCP handshake succeeded
  #   1    — connection refused / unreachable (Cilium DROP looks like timeout
  #          OR connection reset depending on policy verdict)
  # `kubectl run` exit codes:
  #   0    — pod ran and command exit 0
  #   1    — pod ran and command exit non-zero
  #   137  — pod evicted / OOM / killed
  #   Other — kubectl/transport error
  local observed=""
  if [ "$probe_rc" -eq 0 ]; then
    observed="ALLOW"
  else
    observed="DROP"
  fi

  local result=""
  if [ "$observed" = "$expected" ]; then
    result="PASS"
    PASS=$((PASS+1))
    green "       PASS  (observed=$observed, ${dur}s)"
  else
    result="FAIL"
    FAIL=$((FAIL+1))
    red   "       FAIL  expected=$expected observed=$observed (${dur}s)"
    FAILURES+=("[$id] $src_ns → $dst_host:$dst_port  expected=$expected observed=$observed  ref=$cnp_ref")
    # nc -v emits the probe error string to stderr — embed first 120 chars
    # in the CSV for triage without dumping log binaries.
    err_excerpt=$(printf '%s' "$probe_out" | tr '\n' ' ' | cut -c1-120)
    emit_row "$id" "$src_ns" "$src_labels" "$dst_host" "$dst_port" \
      "$proto" "$expected" "$observed" "$result" "$dur" "$cnp_ref" "$desc" \
      "$err_excerpt"
    return
  fi
  emit_row "$id" "$src_ns" "$src_labels" "$dst_host" "$dst_port" \
    "$proto" "$expected" "$observed" "$result" "$dur" "$cnp_ref" "$desc" ""
}

# ---------------------------------------------------------------------------
# Matrix dispatcher
# ---------------------------------------------------------------------------
bold "=================================================================="
bold " ZTA L4 Microsegmentation Conformance Test (PR-microseg-conformance)"
bold "=================================================================="
echo "Matrix: $MATRIX_FILE"
echo "Mode:   $( [ $MODE_ANOMALY -eq 1 ] && echo 'anomaly+positive+negative' || echo 'positive+negative (default)' )"
[ -n "$FILTER_RE" ] && echo "Filter: $FILTER_RE"
echo

# Read matrix line-by-line. CSV parsing intentionally simple — quoted
# commas not required for the v1 matrix (no field contains a comma).
ROW_NO=0
while IFS=, read -r id src_ns src_labels dst_host dst_port proto expected cnp_ref description; do
  ROW_NO=$((ROW_NO+1))
  # Skip header + comment rows
  [ "$id" = "id" ] && continue
  [ -z "$id" ] && continue
  case "$id" in \#*) continue ;; esac

  # Anomaly rows opt-in only
  case "$id" in
    A*) [ "$MODE_ANOMALY" -ne 1 ] && continue ;;
  esac

  # Filter
  if [ -n "$FILTER_RE" ] && ! echo "$id" | grep -qE "$FILTER_RE"; then
    continue
  fi

  if [ "$MODE_DRY" -eq 1 ]; then
    echo "  [DRY] $id  $src_ns → $dst_host:$dst_port  expected=$expected"
    continue
  fi
  probe_row "$id" "$src_ns" "$src_labels" "$dst_host" "$dst_port" \
    "$proto" "$expected" "$cnp_ref" "$description"
done < "$MATRIX_FILE"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
bold "------------------------------------------------------------------"
bold " Summary"
bold "------------------------------------------------------------------"
TOTAL=$((PASS + FAIL + SKIP))
echo "  Total:  $TOTAL"
green "  PASS:   $PASS"
[ "$FAIL" -gt 0 ] && red "  FAIL:   $FAIL" || echo "  FAIL:   $FAIL"
[ "$SKIP" -gt 0 ] && yellow "  SKIP:   $SKIP" || echo "  SKIP:   $SKIP"
echo
echo "  CSV:    $RESULTS_CSV"
echo "  Log:    $RUN_LOG"
echo "  Report: $SUMMARY_MD"

# Markdown summary for thesis / PR evidence
{
  echo "# ZTA L4 Microsegmentation Conformance — ${RUN_TS}"
  echo
  echo "| Metric | Count |"
  echo "|---|---|"
  echo "| Total | $TOTAL |"
  echo "| Pass  | $PASS |"
  echo "| Fail  | $FAIL |"
  echo "| Skip  | $SKIP |"
  echo
  if [ "$FAIL" -gt 0 ]; then
    echo "## Failures"
    echo
    for f in "${FAILURES[@]}"; do
      echo "- $f"
    done
    echo
  fi
  echo "## Inputs"
  echo "- Matrix: \`$(realpath --relative-to="$SCRIPT_DIR" "$MATRIX_FILE")\`"
  echo "- Mode: $( [ $MODE_ANOMALY -eq 1 ] && echo 'anomaly+positive+negative' || echo 'positive+negative' )"
  echo
  echo "## Acceptance Criteria"
  echo "- L4 microsegmentation is considered closed when PASS == TOTAL (FAIL == 0, SKIP == 0)."
  echo "- A non-zero SKIP is acceptable in v1 only for non-TCP rows (UDP/EXEC) —"
  echo "  these will be exercised in PR-microseg-conformance-v2 (Phase 2D, L7)."
} > "$SUMMARY_MD"

if [ "$FAIL" -gt 0 ]; then
  red "L4 microsegmentation conformance: FAIL ($FAIL/$TOTAL)"
  exit 1
fi
green "L4 microsegmentation conformance: PASS ($PASS/$TOTAL pure ALLOW/DROP, $SKIP non-L4 skipped)"
exit 0
