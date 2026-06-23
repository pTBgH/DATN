#!/usr/bin/env bash
# =============================================================================
# diag-dns.sh — find WHY the threat-intel pod can't resolve DNS.
#
# Isolates the cause by comparing two throwaway pods in security-cdm:
#   A) "plain"   — no app label  -> only the namespace-wide L3 DNS allow
#                  (allow-dns-egress-security-cdm), NO L7 DNS proxy redirect
#   B) "labeled" — app=threat-intel-refresh -> matches allow-threat-intel-egress
#                  which has an L7 `rules.dns` block -> DNS goes through the
#                  Cilium DNS proxy + toFQDNs enforcement
#
# If A resolves but B does not  -> the L7 DNS proxy / toFQDNs rule is the cause.
# If neither resolves           -> L3 path to CoreDNS is broken (labels/CCNP).
# It also dumps Cilium drop events for pod B during its lookup.
#
# Read-only-ish: creates 2 temp pods, deletes them at the end (KEEP=1 to keep).
# =============================================================================
set -uo pipefail
KUBECTL="${KUBECTL:-kubectl}"
NS="security-cdm"
PLAIN="dnstest-plain"
LABELED="dnstest-ti"
IMG="curlimages/curl:8.5.0"
TARGET="raw.githubusercontent.com"

cleanup() {
  [[ "${KEEP:-0}" == "1" ]] && { echo "[*] KEEP=1 — leaving test pods"; return; }
  $KUBECTL -n "$NS" delete pod "$PLAIN" "$LABELED" --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

echo "=== 0) CoreDNS pod labels (the DNS allow selects k8s-app=kube-dns) ==="
$KUBECTL -n kube-system get pods -l k8s-app=kube-dns -o wide 2>/dev/null
echo "   (if the line above is EMPTY, CoreDNS is NOT labeled k8s-app=kube-dns -> DNS allow never matches)"
$KUBECTL -n kube-system get pods --show-labels 2>/dev/null | grep -i 'dns\|coredns' | head

echo "=== 1) creating test pods ==="
$KUBECTL -n "$NS" run "$PLAIN"   --image="$IMG" --restart=Never --command -- sleep 900 >/dev/null
$KUBECTL -n "$NS" run "$LABELED" --image="$IMG" --labels="app=threat-intel-refresh" --restart=Never --command -- sleep 900 >/dev/null
$KUBECTL -n "$NS" wait --for=condition=ready pod/"$PLAIN"   --timeout=90s
$KUBECTL -n "$NS" wait --for=condition=ready pod/"$LABELED" --timeout=90s

echo "=== 2a) PLAIN pod (no L7 DNS proxy) -> nslookup $TARGET ==="
$KUBECTL -n "$NS" exec "$PLAIN" -- sh -c "nslookup $TARGET 2>&1 | tail -6; echo exit=\$?"

echo "=== 2b) LABELED pod (L7 DNS proxy + toFQDNs) -> nslookup $TARGET ==="
# Start a Cilium drop+l7 monitor on the labeled pod's node in the background,
# then trigger the lookup so we capture the drop reason.
PODIP=$($KUBECTL -n "$NS" get pod "$LABELED" -o jsonpath='{.status.podIP}' 2>/dev/null)
NODE=$($KUBECTL -n "$NS" get pod "$LABELED" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
CIL=$($KUBECTL -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName="$NODE" -o name 2>/dev/null | head -1)
echo "   podIP=$PODIP node=$NODE cilium=$CIL"
MON=/tmp/diag-dns-monitor.txt; : > "$MON"
if [[ -n "$CIL" ]]; then
  ( $KUBECTL -n kube-system exec "$CIL" -- timeout 25 cilium monitor -t drop -t l7 2>/dev/null \
      | grep --line-buffered -E "$PODIP|DNS|dropped" > "$MON" ) &
  MONPID=$!
  sleep 3
fi
$KUBECTL -n "$NS" exec "$LABELED" -- sh -c "nslookup $TARGET 2>&1 | tail -6; echo exit=\$?"
$KUBECTL -n "$NS" exec "$LABELED" -- sh -c "nslookup $TARGET 10.96.0.10 2>&1 | tail -6; echo exit=\$?"
[[ -n "${MONPID:-}" ]] && wait "$MONPID" 2>/dev/null

echo "=== 3) Cilium drop / L7-DNS events for $PODIP (during the lookup) ==="
if [[ -s "$MON" ]]; then sed 's/^/[mon] /' "$MON" | head -40; else echo "   (no drop/l7 events captured)"; fi

echo "=== 4) endpoint policy summary for the labeled pod ==="
if [[ -n "$CIL" ]]; then
  EID=$($KUBECTL -n kube-system exec "$CIL" -- cilium endpoint list -o json 2>/dev/null \
        | grep -B5 "$PODIP" | grep -oE '"id": [0-9]+' | head -1 | grep -oE '[0-9]+')
  echo "   endpoint id=$EID"
  [[ -n "$EID" ]] && $KUBECTL -n kube-system exec "$CIL" -- cilium endpoint get "$EID" 2>/dev/null \
      | grep -iE 'dns|fqdn|egress|enforc' | head -20
fi
echo "[*] done. (set KEEP=1 to keep the test pods for manual poking)"
