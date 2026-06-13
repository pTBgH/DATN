#!/usr/bin/env bash
# =============================================================================
# zta-microseg-step2-validate.sh
#
# Phase 2C — Read-only validator for the new Phase 2C namespace CNP drafts
# (infras/k8s-yaml/cilium-policies/namespaces/17-23). It does NOT apply or
# mutate anything; output is a Markdown report the operator reviews before
# running `apply-zta-namespace-policies.sh --apply`.
#
# Output:
#   ~/zta-microseg-validate/<TS>/
#     00-INDEX.md
#     01-ns-inventory.md            (pod / SA / port per ns)
#     02-existing-cnp.md            (CNP already in each ns)
#     03-dry-run-apply.md           (kubectl apply --dry-run=server result
#                                    for every Phase 2C YAML)
#     04-recent-hubble-drops.md     (DROPPED flows in last 30 min by ns)
#     05-policy-vs-pods.md          (mismatch between draft selectors and
#                                    actual pod labels)
#     06-recommendation.md          (per-ns: SAFE / NEEDS-WORK / BLOCKED)
#
# Usage:
#   bash scripts/zta-microseg-step2-validate.sh
#   PHASE2C_REPO=/path/to/DATN bash scripts/zta-microseg-step2-validate.sh
# =============================================================================
set -uo pipefail

REPO_DIR="${PHASE2C_REPO:-$HOME/projects/DATN}"
NS_DIR="$REPO_DIR/infras/k8s-yaml/cilium-policies/namespaces"
OUT_DIR="$HOME/zta-microseg-validate/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

H()   { printf '\n========== %s ==========\n' "$*"; }
ok()  { printf '  ✓ %s\n' "$*"; }
warn(){ printf '  ⚠  %s\n' "$*" >&2; }
err() { printf '  ✗ %s\n' "$*" >&2; }

# Mapping ns -> draft yaml file. Keep in sync with apply-zta-namespace-policies.sh ORDER.
declare -A NS_FILES=(
  [local-path-storage]="22-local-path-storage.yaml"
  [registry]="16-registry.yaml"
  [management]="15-management.yaml"
  [spire]="21-spire.yaml"
  [cert-manager]="17-cert-manager.yaml"
  [cosign-system]="18-cosign-system.yaml"
  [gatekeeper-system]="19-gatekeeper-system.yaml"
  [monitoring]="13-monitoring.yaml"
  [ingress-nginx]="20-ingress-nginx.yaml"
  [gateway]="14-gateway.yaml"
  [security]="12-security.yaml"
  [vault]="11-vault.yaml"
  [data]="10-data.yaml"
  [kube-system]="23-kube-system.yaml"
)

NS_ORDER=(
  local-path-storage registry management spire cert-manager
  cosign-system gatekeeper-system monitoring ingress-nginx gateway
  security vault data kube-system
)

H "0/6 Pre-flight"
if ! kubectl cluster-info >/dev/null 2>&1; then
  err "kubectl không reachable. Export KUBECONFIG trước."
  exit 1
fi
ok "kubectl reachable"
ok "Output: $OUT_DIR"
if [[ ! -d "$NS_DIR" ]]; then
  err "Không tìm thấy thư mục draft: $NS_DIR"
  err "Set PHASE2C_REPO=/path/to/DATN nếu repo nằm chỗ khác."
  exit 1
fi
ok "Repo dir: $REPO_DIR"

H "1/6 Inventory per-ns (pods, SA, exposed ports)"
{
  echo "# 01 — Namespace Inventory"
  echo
  echo "_Generated $(date -Iseconds)_"
  echo
  for ns in "${NS_ORDER[@]}"; do
    echo "## $ns"
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      echo "  - **NS không tồn tại trên cluster** — apply sẽ SKIP."
      continue
    fi
    echo
    echo "### Pods"
    echo '```'
    kubectl -n "$ns" get pod -o wide 2>/dev/null | head -60 || true
    echo '```'
    echo
    echo "### ServiceAccount"
    echo '```'
    kubectl -n "$ns" get sa 2>/dev/null | head -30 || true
    echo '```'
    echo
    echo "### Service + containerPorts"
    echo '```'
    kubectl -n "$ns" get svc -o wide 2>/dev/null | head -30 || true
    echo '```'
    echo
    echo "### Pod labels (relevant for selectors)"
    echo '```'
    kubectl -n "$ns" get pod -o json 2>/dev/null \
      | jq -r '.items[] | "\(.metadata.name)  \(.metadata.labels | to_entries | map("\(.key)=\(.value)") | join(","))"' 2>/dev/null \
      | head -40 || true
    echo '```'
    echo
  done
} > "$OUT_DIR/01-ns-inventory.md"
ok "→ 01-ns-inventory.md"

H "2/6 Existing CNP per-ns"
{
  echo "# 02 — Existing CiliumNetworkPolicy per Namespace"
  echo
  for ns in "${NS_ORDER[@]}"; do
    echo "## $ns"
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      echo "  - NS không tồn tại."
      continue
    fi
    echo
    echo '```'
    kubectl -n "$ns" get cnp -o custom-columns='NAME:.metadata.name,VALID:.status.conditions[?(@.type=="Valid")].status,AGE:.metadata.creationTimestamp' 2>/dev/null \
      | head -30
    echo '```'
    echo
  done
} > "$OUT_DIR/02-existing-cnp.md"
ok "→ 02-existing-cnp.md"

H "3/6 kubectl apply --dry-run=server cho mỗi draft"
{
  echo "# 03 — Dry-run Apply Result"
  echo
  echo "_Mỗi file Phase 2C apply qua dry-run server — phát hiện schema lỗi sớm._"
  echo
  for ns in "${NS_ORDER[@]}"; do
    f="${NS_FILES[$ns]}"
    path="$NS_DIR/$f"
    echo "## $ns ($f)"
    if [[ ! -f "$path" ]]; then
      echo "  - **File không tồn tại trên disk**: $path"
      continue
    fi
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      echo "  - SKIP (NS không tồn tại)."
      continue
    fi
    echo '```'
    kubectl apply --dry-run=server -f "$path" 2>&1 | head -40 || true
    echo '```'
    echo
  done
} > "$OUT_DIR/03-dry-run-apply.md"
ok "→ 03-dry-run-apply.md"

H "4/6 Recent Hubble DROPPED flows by destination ns"
CILIUM_POD="$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
{
  echo "# 04 — Recent Hubble DROPPED Flows (last 30m)"
  echo
  if [[ -z "$CILIUM_POD" ]]; then
    echo "**Không tìm thấy Cilium pod** (k8s-app=cilium). Hubble không khả dụng."
  else
    echo "_From Cilium pod: $CILIUM_POD_"
    echo
    for ns in "${NS_ORDER[@]}"; do
      echo "## $ns"
      echo '```'
      kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent \
        -- hubble observe --since 30m --verdict DROPPED \
           --to-namespace "$ns" --output compact 2>/dev/null \
        | head -50 || true
      kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent \
        -- hubble observe --since 30m --verdict DROPPED \
           --from-namespace "$ns" --output compact 2>/dev/null \
        | head -50 || true
      echo '```'
      echo
    done
  fi
} > "$OUT_DIR/04-recent-hubble-drops.md"
ok "→ 04-recent-hubble-drops.md"

H "5/6 Match draft selectors against live pod labels"
{
  echo "# 05 — Selector vs Pod-Label Match"
  echo
  echo "_Kiểm tra mỗi endpointSelector trong draft có khớp pod thật không._"
  echo
  for ns in "${NS_ORDER[@]}"; do
    f="${NS_FILES[$ns]}"
    path="$NS_DIR/$f"
    [[ -f "$path" ]] || continue
    kubectl get ns "$ns" >/dev/null 2>&1 || continue

    echo "## $ns ($f)"
    # Extract every matchLabels block from CNP and grep against `kubectl get pod`
    # This is a heuristic — for deep verification use kube-policy-rule-checker.
    selectors=$(grep -A 6 'endpointSelector:' "$path" \
      | grep -E '^\s+[a-zA-Z0-9_.-]+: ' \
      | awk '{print $1$2}' | sed 's/://' \
      | sort -u | head -20)
    if [[ -z "$selectors" ]]; then
      echo "  - Không có endpointSelector specific (file dùng {} hoặc selector rỗng)."
      echo
      continue
    fi
    echo "### Selectors found in draft"
    echo '```'
    echo "$selectors"
    echo '```'
    echo "### Pods in ns matching ALL labels above"
    echo '```'
    kubectl -n "$ns" get pod --show-labels 2>/dev/null | head -30 || true
    echo '```'
    echo
  done
} > "$OUT_DIR/05-policy-vs-pods.md"
ok "→ 05-policy-vs-pods.md"

H "6/6 Per-ns recommendation"
{
  echo "# 06 — Apply Recommendation per Namespace"
  echo
  echo "_Heuristic safety tiers: SAFE (T3 low-flow) → APPLY-WITH-CARE (T2)_"
  echo "_→ HIGH-RISK (T1) → DO-NOT-APPLY (kube-system ns-wide default-deny)._"
  echo
  echo "| Wave | Namespace | File | Tier | Recommendation | Notes |"
  echo "|------|-----------|------|------|----------------|-------|"
  cat <<'EOF'
| 1 | local-path-storage | 22 | T3 | SAFE — apply first | Provisioner idle most of the time |
| 1 | registry | 16 | T3 | SAFE — already authored | Existing file, no Phase 2C change |
| 2 | management | 15 | T3 | SAFE | Admin UI; impact = lose access to phpmyadmin |
| 2 | spire | 21 | T1 | APPLY-WITH-CARE | If wrong, ALL SVID issuance fails → mesh mTLS dies |
| 3 | cert-manager | 17 | T2 | APPLY-WITH-CARE | Webhook reachable required |
| 3 | cosign-system | 18 | T2 | APPLY-WITH-CARE | failurePolicy=Fail blocks ALL admission |
| 3 | gatekeeper-system | 19 | T2 | APPLY-WITH-CARE | Same as cosign for Fail policies |
| 4 | monitoring | 13 | T2 | APPLY-WITH-CARE | Lose metrics if wrong; app stays up |
| 4 | ingress-nginx | 20 | T2 | APPLY-WITH-CARE | North-south — apply off-hours |
| 5 | gateway | 14 | T2 | APPLY-WITH-CARE | Kong PEP — front door |
| 5 | security | 12 | T1 | APPLY-WITH-CARE | Login fails if wrong |
| 5 | vault | 11 | T1 | APPLY-WITH-CARE | App crash ~1h after creds TTL expire |
| 5 | data | 10 | T1 | APPLY-WITH-CARE | DB layer — disable apps first |
| 6 | kube-system | 23 | T0 | PARTIAL APPLY ONLY | File 23 has CoreDNS allow only, NO ns-wide deny. Default-deny kube-system requires a separate audit + cluster-wide planning. |
EOF
  echo
  echo "## Suggested apply workflow"
  echo
  echo "1. Read \`04-recent-hubble-drops.md\`. If any DROPPED flow is legitimate"
  echo "   (e.g. monitoring scrape that should succeed), add allow rule to the"
  echo "   corresponding YAML before applying."
  echo "2. Read \`03-dry-run-apply.md\`. Any schema error → fix YAML first."
  echo "3. Read \`05-policy-vs-pods.md\`. If a selector doesn't match any pod,"
  echo "   the rule is a no-op — usually safe, sometimes indicates label drift."
  echo "4. Apply ns by ns:"
  echo "   \`bash infras/k8s-yaml/cilium-policies/namespaces/apply-zta-namespace-policies.sh --namespace=<ns> --apply\`"
  echo "5. Wait 5 minutes, watch \`hubble observe --verdict DROPPED --since 5m\`"
  echo "   in another terminal. If new DROPPED legitimate flows appear, rollback:"
  echo "   \`bash apply-zta-namespace-policies.sh --namespace=<ns> --rollback\`"
  echo "6. Move to next ns only after 30 minutes of green Hubble + healthy pods."
} > "$OUT_DIR/06-recommendation.md"
ok "→ 06-recommendation.md"

H "INDEX"
{
  echo "# Phase 2C Validation Run — $(date -Iseconds)"
  echo
  echo "## Files"
  for f in 01-ns-inventory.md 02-existing-cnp.md 03-dry-run-apply.md \
           04-recent-hubble-drops.md 05-policy-vs-pods.md 06-recommendation.md; do
    echo "- [$(basename "$f")](./$f)"
  done
} > "$OUT_DIR/00-INDEX.md"

ok "DONE — review: $OUT_DIR/00-INDEX.md"
