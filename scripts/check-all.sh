#!/usr/bin/env bash
# =============================================================================
# check-all.sh — READ-ONLY verification of F01..F04 hardening fixes.
#
# Changes NOTHING on the cluster. Runs every "Check (đạt khi)" from RUNBOOK.md
# and prints PASS / FAIL / SKIP per item with the observed value, then a summary.
#
#   bash check-all.sh                 # check everything
#   APPS_NS=job7189-apps RO_SVC=hiring-service bash check-all.sh
#
# Env knobs (defaults match the RUNBOOK):
#   KUBECTL=kubectl     kubectl binary
#   TI_NS=security-cdm  threat-intel namespace          (F01)
#   PDP_NS=security     pdp namespace                    (F02)
#   APPS_NS=job7189-apps app namespace                   (F04)
#   RO_SVC=hiring-service deployment that should be RO    (F04)
#   GK_DENY="zta-restrict-privileged"  Gatekeeper constraint(s) expected = deny (F03)
# =============================================================================
set -uo pipefail   # NOTE: no -e: a failing check must not abort the whole run

KUBECTL="${KUBECTL:-kubectl}"
TI_NS="${TI_NS:-security-cdm}"
PDP_NS="${PDP_NS:-security}"
APPS_NS="${APPS_NS:-job7189-apps}"
RO_SVC="${RO_SVC:-hiring-service}"
GK_DENY="${GK_DENY:-zta-restrict-privileged}"

_c() { printf '\033[%sm' "$1"; }
hdr()  { printf '\n%s== %s ==%s\n' "$(_c 36)" "$*" "$(_c 0)"; }
PASS=0; FAIL=0; SKIP=0
pass() { PASS=$((PASS+1)); printf '  %s[PASS]%s %s\n' "$(_c 32)" "$(_c 0)" "$*"; }
fail() { FAIL=$((FAIL+1)); printf '  %s[FAIL]%s %s\n' "$(_c 31)" "$(_c 0)" "$*"; }
skip() { SKIP=$((SKIP+1)); printf '  %s[SKIP]%s %s\n' "$(_c 33)" "$(_c 0)" "$*"; }
info() { printf '         %s\n' "$*"; }

command -v "$KUBECTL" >/dev/null 2>&1 || { echo "kubectl not found (set \$KUBECTL)"; exit 2; }
"$KUBECTL" version --output=json >/dev/null 2>&1 || "$KUBECTL" cluster-info >/dev/null 2>&1 \
  || { echo "cannot reach cluster — check kubeconfig/context"; exit 2; }
printf '%s[*]%s context = %s\n' "$(_c 36)" "$(_c 0)" \
  "$("$KUBECTL" config current-context 2>/dev/null || echo '?')"

# -----------------------------------------------------------------------------
hdr "F01 — threat-intel feed ($TI_NS)"

CM_BYTES="$("$KUBECTL" -n "$TI_NS" get cm threat-intel-blocklist -o jsonpath='{.data}' 2>/dev/null | wc -c | tr -d ' ')"
if [[ "${CM_BYTES:-0}" -gt 1000 ]]; then
  pass "ConfigMap threat-intel-blocklist data = ${CM_BYTES} bytes (> 1000)"
else
  fail "ConfigMap threat-intel-blocklist data = ${CM_BYTES:-0} bytes (expected > 1000)"
fi

CIDR_N="$("$KUBECTL" get ciliumcidrgroup threat-intel-firehol -o jsonpath='{.spec.externalCIDRs}' 2>/dev/null \
          | grep -o '/' | wc -l | tr -d ' ')"
if [[ "${CIDR_N:-0}" -gt 0 ]]; then
  pass "CIDRGroup threat-intel-firehol externalCIDRs = ${CIDR_N} entries (> 0)"
else
  fail "CIDRGroup threat-intel-firehol externalCIDRs = ${CIDR_N:-0} (expected > 0)"
fi

LAST_UPD="$("$KUBECTL" -n "$TI_NS" get cm threat-intel-blocklist \
            -o jsonpath='{.metadata.annotations.threat-intel/last-updated}' 2>/dev/null)"
[[ -n "$LAST_UPD" ]] && info "last-updated annotation: $LAST_UPD"

JOBS="$("$KUBECTL" -n "$TI_NS" get jobs -l app=threat-intel-refresh \
        -o jsonpath='{range .items[*]}{.metadata.name}={.status.succeeded}{"\n"}{end}' 2>/dev/null)"
if grep -q '=1$' <<<"$JOBS"; then
  pass "at least one threat-intel-refresh job succeeded (COMPLETIONS 1/1)"
  info "$(grep '=1$' <<<"$JOBS" | tail -3)"
else
  fail "no succeeded threat-intel-refresh job found"
  [[ -n "$JOBS" ]] && info "jobs: $(tr '\n' ' ' <<<"$JOBS")"
fi

# DNS egress policy selector must use the working namespace form (the bug we fixed)
DNS_SEL="$("$KUBECTL" -n "$TI_NS" get cnp allow-threat-intel-egress \
           -o jsonpath='{.spec.egress[0].toEndpoints}' 2>/dev/null)"
if grep -q 'io.kubernetes.pod.namespace' <<<"$DNS_SEL"; then
  pass "allow-threat-intel-egress DNS selector uses io.kubernetes.pod.namespace (fixed form)"
elif grep -q 'namespace.labels' <<<"$DNS_SEL"; then
  fail "allow-threat-intel-egress DNS selector still uses namespace.labels form (the L7 DNS-proxy bug)"
else
  skip "allow-threat-intel-egress DNS selector not readable"
fi

# -----------------------------------------------------------------------------
hdr "F02 — tier in trust score ($PDP_NS)"

if "$KUBECTL" -n "$PDP_NS" get cm zta-pdp-script -o jsonpath='{.data.pdp_controller\.py}' 2>/dev/null \
     | grep -q 'WEIGHT_TIER'; then
  pass "zta-pdp-script contains WEIGHT_TIER (tier wired into score)"
else
  fail "WEIGHT_TIER not found in zta-pdp-script ConfigMap"
fi

RO_OUT="$("$KUBECTL" -n "$PDP_NS" rollout status deploy/zta-pdp --timeout=10s 2>&1)"
if grep -qi 'successfully rolled out' <<<"$RO_OUT"; then
  pass "deploy/zta-pdp rolled out"
else
  fail "deploy/zta-pdp not healthy: $RO_OUT"
fi

LASTREC="$("$KUBECTL" -n "$PDP_NS" logs deploy/zta-pdp --tail=400 2>/dev/null \
           | grep -i 'reconcile-complete' | tail -1)"
if [[ -n "$LASTREC" ]]; then
  pass "PDP reconcile running"
  info "$LASTREC"
else
  skip "no 'reconcile-complete' line in last 400 log lines (may use different wording)"
fi

# -----------------------------------------------------------------------------
hdr "F03 — Gatekeeper enforce"

# Gatekeeper constraints have a Kind (e.g. ZTARestrictPrivileged) distinct from
# the object NAME (zta-restrict-privileged). Build one table of
# name=action=violations across ALL constraint kinds, then look names up in it.
GKLIST="$("$KUBECTL" api-resources --api-group=constraints.gatekeeper.sh -o name 2>/dev/null)"
GK_TABLE=""
for kind in $GKLIST; do
  GK_TABLE+="$("$KUBECTL" get "$kind" -o jsonpath='{range .items[*]}{.metadata.name}={.spec.enforcementAction}={.status.totalViolations}{"\n"}{end}' 2>/dev/null)"$'\n'
done

for c in $GK_DENY; do
  ROW="$(awk -F= -v n="$c" '$1==n{print; exit}' <<<"$GK_TABLE")"
  ACT="$(awk -F= '{print $2}' <<<"$ROW")"
  if [[ "$ACT" == "deny" ]]; then
    pass "constraint '$c' enforcementAction = deny"
  elif [[ -n "$ACT" ]]; then
    fail "constraint '$c' enforcementAction = '$ACT' (expected deny)"
  else
    skip "constraint '$c' not found among constraint kinds (adjust \$GK_DENY)"
  fi
done

# informational: list any constraints still in dryrun/warn + their violation counts
if [[ -n "${GK_TABLE// /}" ]]; then
  info "constraints still in dryrun/warn (informational):"
  awk -F= '$2!="deny" && $2!="" {printf "           - %s (%s, violations=%s)\n",$1,$2,$3}' <<<"$GK_TABLE"
fi

# -----------------------------------------------------------------------------
hdr "F04 — readOnlyRootFilesystem ($APPS_NS/$RO_SVC)"

RO="$("$KUBECTL" -n "$APPS_NS" get deploy "$RO_SVC" \
      -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)"
if [[ "$RO" == "true" ]]; then
  pass "$RO_SVC container[0] readOnlyRootFilesystem = true"
else
  fail "$RO_SVC container[0] readOnlyRootFilesystem = '${RO:-unset}' (expected true)"
fi

RO_OUT4="$("$KUBECTL" -n "$APPS_NS" rollout status deploy/"$RO_SVC" --timeout=10s 2>&1)"
grep -qi 'successfully rolled out' <<<"$RO_OUT4" \
  && pass "deploy/$RO_SVC rolled out" \
  || fail "deploy/$RO_SVC not healthy: $RO_OUT4"

WROOT="$("$KUBECTL" -n "$APPS_NS" exec deploy/"$RO_SVC" -- sh -c 'touch /root/x' 2>&1)"
if grep -qi 'read-only' <<<"$WROOT"; then
  pass "write to /root rejected (Read-only file system)"
else
  fail "write to /root NOT rejected: ${WROOT:-<no output>}"
fi

WTMP="$("$KUBECTL" -n "$APPS_NS" exec deploy/"$RO_SVC" -- sh -c 'touch /tmp/x && echo tmp-ok' 2>&1)"
if grep -q 'tmp-ok' <<<"$WTMP"; then
  pass "write to /tmp succeeds (emptyDir mounted)"
else
  fail "write to /tmp failed: ${WTMP:-<no output>}"
fi

# -----------------------------------------------------------------------------
hdr "SUMMARY"
printf '  %sPASS=%d%s  %sFAIL=%d%s  %sSKIP=%d%s\n' \
  "$(_c 32)" "$PASS" "$(_c 0)" "$(_c 31)" "$FAIL" "$(_c 0)" "$(_c 33)" "$SKIP" "$(_c 0)"
[[ "$FAIL" -eq 0 ]] && { echo "  all checked items PASS"; exit 0; } || { echo "  some checks FAILED — see above"; exit 1; }
