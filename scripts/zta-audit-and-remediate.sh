#!/usr/bin/env bash
#==============================================================================
# zta-audit-and-remediate.sh
#
# Audits and (optionally) remediates the high-priority items from
# knowledge-base/47-next-tasks.md:
#   1. Legacy namespace label selectors in live CiliumNetworkPolicies
#   2. PDP Controller deployment status (pdp-system)
#   3. Trivy Operator namespace placement + stuck scan pods
#   5. oauth2-proxy policy legacy labels (12-security.yaml)
#   6. Namespaces missing CNP coverage
#   7. SPIRE workload attestation (SVID issuance) end-to-end
#
# Usage:
#   ./zta-audit-and-remediate.sh            # audit only (read-only, safe)
#   ./zta-audit-and-remediate.sh --apply    # audit + apply safe remediations
#
# Run on the control plane (7189srv01) or any host with kubectl configured.
# Idempotent: safe to re-run. Exit codes: 0=OK, 1=audit findings, 2=preflight fail.
#==============================================================================
set -uo pipefail

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CILIUM_POLICY_DIR="$REPO_ROOT/infras/k8s-yaml/cilium-policies"
LEGACY_LABEL="io.kubernetes.pod.namespace"
KUBECTL_TIMEOUT="--request-timeout=30s"
FINDINGS=0
TS="$(date +%Y%m%d-%H%M%S)"
REPORT="/tmp/zta-audit-${TS}.log"

log()  { echo "[$(date +%H:%M:%S)] $*" | tee -a "$REPORT"; }
ok()   { log "  OK: $*"; }
warn() { log "  FINDING: $*"; FINDINGS=$((FINDINGS+1)); }
fail() { log "FATAL: $*"; exit 2; }

#------------------------------------------------------------------------------
# PRE-FLIGHT CHECKS
#------------------------------------------------------------------------------
log "=== PRE-FLIGHT CHECKS ==="

command -v kubectl >/dev/null 2>&1 || fail "kubectl not found in PATH"

timeout 20 kubectl version $KUBECTL_TIMEOUT >/dev/null 2>&1 \
  || fail "kubectl cannot reach the API server (check kubeconfig / cluster up?)"

# Node readiness
NOT_READY=$(kubectl get nodes $KUBECTL_TIMEOUT --no-headers 2>/dev/null | awk '$2!="Ready"{print $1}')
[[ -n "$NOT_READY" ]] && warn "Nodes not Ready: $NOT_READY" || ok "All nodes Ready"

# Memory pressure on nodes (avoid remediation on a starved cluster)
LOW_MEM_NODES=0
while read -r node mem_pct; do
  if [[ -n "$mem_pct" && "${mem_pct%\%}" -ge 90 ]]; then
    warn "Node $node memory usage ${mem_pct} >= 90% — remediation may evict pods"
    LOW_MEM_NODES=$((LOW_MEM_NODES+1))
  fi
done < <(timeout 20 kubectl top nodes --no-headers 2>/dev/null | awk '{print $1, $5}')

# Disk pressure conditions
DISK_PRESSURE=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.conditions[?(@.type=="DiskPressure")]}{.status}{end}{"\n"}{end}' 2>/dev/null | awk '$2=="True"{print $1}')
[[ -n "$DISK_PRESSURE" ]] && warn "Nodes with DiskPressure: $DISK_PRESSURE" || ok "No disk pressure"

# Cilium agent health — required before touching CNPs
CILIUM_NOT_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=cilium $KUBECTL_TIMEOUT --no-headers 2>/dev/null | awk '$3!="Running"{print $1}')
if [[ -n "$CILIUM_NOT_RUNNING" ]]; then
  fail "Cilium agents not all Running ($CILIUM_NOT_RUNNING) — fix CNI before policy changes"
fi
ok "Cilium agents Running"

if $APPLY; then
  [[ -d "$CILIUM_POLICY_DIR" ]] || fail "Policy dir not found: $CILIUM_POLICY_DIR (run from repo clone)"
  if [[ "$LOW_MEM_NODES" -gt 0 ]]; then
    fail "Refusing --apply with memory-starved nodes; free RAM first (see free-ram-for-*.sh)"
  fi
fi

#------------------------------------------------------------------------------
# TASK 1: Legacy namespace label selectors in live CNPs
#------------------------------------------------------------------------------
log "=== TASK 1: Legacy CNP namespace labels ==="
LIVE_LEGACY=$(timeout 60 kubectl get cnp -A -o yaml 2>/dev/null | grep -c "$LEGACY_LABEL" || true)
if [[ "$LIVE_LEGACY" -gt 0 ]]; then
  warn "$LIVE_LEGACY occurrences of legacy '$LEGACY_LABEL' in live CNPs"
  kubectl get cnp -A -o yaml 2>/dev/null | grep -n "$LEGACY_LABEL" | head -20 >> "$REPORT"
else
  ok "No legacy namespace labels in live CNPs"
fi

SRC_LEGACY_FILES=$(grep -rl "$LEGACY_LABEL" "$CILIUM_POLICY_DIR" 2>/dev/null || true)
if [[ -n "$SRC_LEGACY_FILES" ]]; then
  warn "Source files still using legacy label:"
  echo "$SRC_LEGACY_FILES" | tee -a "$REPORT"
else
  ok "No legacy labels in source policy files"
fi

if $APPLY && [[ -z "$SRC_LEGACY_FILES" && "$LIVE_LEGACY" -gt 0 ]]; then
  log "  Re-applying migrated policy files to converge live state..."
  timeout 180 kubectl apply -f "$CILIUM_POLICY_DIR/" 2>&1 | tee -a "$REPORT" \
    || warn "kubectl apply of top-level policies failed"
  timeout 180 kubectl apply -f "$CILIUM_POLICY_DIR/namespaces/" 2>&1 | tee -a "$REPORT" \
    || warn "kubectl apply of namespaces/ policies failed"
  REMAIN=$(timeout 60 kubectl get cnp -A -o yaml 2>/dev/null | grep -c "$LEGACY_LABEL" || true)
  log "  Legacy occurrences in live CNPs after apply: $REMAIN"
fi

#------------------------------------------------------------------------------
# TASK 2: PDP Controller deployment
#------------------------------------------------------------------------------
log "=== TASK 2: PDP Controller ==="
# PDP may run in pdp-system (per plan) or security (current zta-pdp deployment)
PDP_NS=""
for ns in pdp-system security; do
  CNT=$(kubectl get pods -n "$ns" $KUBECTL_TIMEOUT --no-headers 2>/dev/null | grep -E "pdp" | grep -c Running || true)
  if [[ "$CNT" -gt 0 ]]; then PDP_NS="$ns"; PDP_PODS="$CNT"; break; fi
done
if [[ -z "$PDP_NS" ]]; then
  warn "No Running PDP pods in pdp-system or security — Adaptive Loop is open (NIST S() process broken)"
  if $APPLY && [[ -x "$REPO_ROOT/scripts/zta-deploy-pdp.sh" ]]; then
    log "  Deploying PDP controller..."
    timeout 600 bash "$REPO_ROOT/scripts/zta-deploy-pdp.sh" 2>&1 | tee -a "$REPORT" \
      || warn "zta-deploy-pdp.sh failed (see $REPORT)"
  fi
else
  ok "PDP controller Running in namespace '$PDP_NS' ($PDP_PODS pod(s))"
  [[ "$PDP_NS" != "pdp-system" ]] && log "  NOTE: plan (47-next-tasks) expects pdp-system; actual=$PDP_NS — update docs or migrate"
  log "  Score-bucket labels on app pods:"
  LABELS=$(kubectl get pods -n job7189-apps -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.labels.zta\.job7189/score-bucket}{"\n"}{end}' 2>/dev/null)
  echo "$LABELS" | tee -a "$REPORT"
  UNLABELED=$(echo "$LABELS" | grep -vc ": ." || true)
  [[ "$UNLABELED" -gt 0 ]] && warn "$UNLABELED app pods missing zta.job7189/score-bucket label — PDP loop not labeling"
fi

#------------------------------------------------------------------------------
# TASK 3: Trivy Operator namespace + stuck scans
#------------------------------------------------------------------------------
log "=== TASK 3: Trivy Operator ==="
TRIVY_NS=$(kubectl get pods -A -l app.kubernetes.io/name=trivy-operator --no-headers 2>/dev/null | awk '{print $1}' | sort -u)
if [[ -z "$TRIVY_NS" ]]; then
  warn "Trivy operator not found in any namespace"
else
  log "  Trivy operator namespace(s): $TRIVY_NS"
  [[ "$TRIVY_NS" != "trivy-system" ]] && warn "Trivy in '$TRIVY_NS', plan expects 'trivy-system' (45-upgrade-and-rollback-plan.md Tier 11)"
fi
VR_COUNT=$(kubectl get vulnerabilityreport -A --no-headers 2>/dev/null | wc -l)
log "  VulnerabilityReports present: $VR_COUNT"
[[ "$VR_COUNT" -eq 0 ]] && warn "No VulnerabilityReports — PDP CVE input has no data source"
STUCK_SCANS=$(kubectl get pods -A --no-headers 2>/dev/null | grep "scan-vulnerabilityreport" | grep -c "Init:" || true)
if [[ "$STUCK_SCANS" -gt 0 ]]; then
  warn "$STUCK_SCANS scan pods stuck in Init — describe output appended to report"
  kubectl get pods -A --no-headers 2>/dev/null | grep "scan-vulnerabilityreport" | grep "Init:" | head -5 >> "$REPORT"
fi

#------------------------------------------------------------------------------
# TASK 5: oauth2-proxy legacy labels
#------------------------------------------------------------------------------
log "=== TASK 5: oauth2-proxy policy labels (12-security.yaml) ==="
SEC_FILE="$CILIUM_POLICY_DIR/namespaces/12-security.yaml"
if [[ -f "$SEC_FILE" ]]; then
  if grep -q "$LEGACY_LABEL" "$SEC_FILE"; then
    warn "12-security.yaml still contains legacy labels (lines: $(grep -n "$LEGACY_LABEL" "$SEC_FILE" | cut -d: -f1 | paste -sd,))"
    log "  Manual edit required (label value mapping is context-dependent); then re-run with --apply"
  else
    ok "12-security.yaml migrated"
    if $APPLY; then
      timeout 60 kubectl apply -f "$SEC_FILE" 2>&1 | tee -a "$REPORT" || warn "apply 12-security.yaml failed"
    fi
  fi
else
  warn "12-security.yaml not found at $SEC_FILE"
fi

#------------------------------------------------------------------------------
# TASK 6: Namespaces missing CNP coverage
#------------------------------------------------------------------------------
log "=== TASK 6: CNP coverage per namespace ==="
for ns in data monitoring management vault security job7189-apps gateway; do
  CNT=$(kubectl get cnp -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [[ "$CNT" -eq 0 ]]; then
    warn "Namespace '$ns' has 0 CiliumNetworkPolicies"
  else
    ok "Namespace '$ns': $CNT CNP(s)"
  fi
done

#------------------------------------------------------------------------------
# TASK 7: SPIRE SVID issuance end-to-end
#------------------------------------------------------------------------------
log "=== TASK 7: SPIRE workload attestation ==="
if kubectl get pods -n spire spire-server-0 $KUBECTL_TIMEOUT >/dev/null 2>&1; then
  ENTRIES=$(timeout 60 kubectl exec -n spire spire-server-0 -c spire-server -- \
    /opt/spire/bin/spire-server entry show 2>/dev/null | grep -c "Entry ID" || true)
  if [[ "$ENTRIES" -gt 0 ]]; then
    ok "spire-server has $ENTRIES registration entries"
  else
    warn "spire-server has no registration entries — ClusterSPIFFEID reconciliation broken?"
  fi
  SVID_PATH=""
  for p in /run/spiffe /run/spire/sockets /spiffe-workload-api /run/secrets/workload-spiffe-uds; do
    SVID_LS=$(timeout 60 kubectl exec -n job7189-apps deployment/identity-service -c app -- \
      ls "$p" 2>/dev/null || true)
    [[ -n "$SVID_LS" ]] && { SVID_PATH="$p"; break; }
  done
  if [[ -n "$SVID_PATH" ]]; then
    ok "identity-service has SPIFFE socket/certs at $SVID_PATH: $SVID_LS"
  else
    MOUNTS=$(kubectl get deployment -n job7189-apps identity-service -o jsonpath='{.spec.template.spec.volumes[*].name}' 2>/dev/null)
    warn "identity-service: no SPIFFE socket found in known paths — volumes present: [$MOUNTS]; check spiffe-csi-driver mount"
  fi
else
  warn "spire-server-0 not found in namespace spire"
fi

#------------------------------------------------------------------------------
# SUMMARY
#------------------------------------------------------------------------------
log "=== SUMMARY ==="
log "Findings: $FINDINGS | Full report: $REPORT"
if [[ "$FINDINGS" -gt 0 ]]; then
  log "Re-run with --apply (after fixing manual items) to remediate safe items."
  exit 1
fi
log "All audited items healthy."
exit 0
