#!/bin/bash
# ==========================================================================
# ZTA Phase 4 / Step 2.3.1 — Observability Baseline (Hoàn thiện khả năng quan sát)
# --------------------------------------------------------------------------
# Mirrors thesis Mục 2.3.1 / 3.4.1: capture a complete East-West + North-South
# traffic baseline BEFORE applying additional microsegmentation policies.
#
# Output:
#   evidence/baseline-<timestamp>/
#     ├── 01-pods.txt              -- pod inventory (all namespaces, with labels)
#     ├── 02-services.txt          -- service inventory
#     ├── 03-cilium-endpoints.txt  -- Cilium endpoint identities
#     ├── 04-cilium-identities.txt -- Cilium security identity → labels
#     ├── 05-existing-cnp.yaml     -- current CiliumNetworkPolicies (full YAML)
#     ├── 06-existing-tracing-policies.yaml -- TracingPolicies (Tetragon)
#     ├── 10-hubble-flows-forwarded.json  -- ~5000 most recent FORWARDED flows
#     ├── 11-hubble-flows-dropped.json    -- ~5000 most recent DROPPED flows
#     ├── 12-hubble-flow-summary.txt      -- src_ns/dst_ns aggregation
#     ├── 13-hubble-l7.json               -- L7 (HTTP/gRPC) flows
#     └── SUMMARY.md                      -- human-readable summary + DAAS prep
#
# Safe to run repeatedly. Does NOT modify the cluster.
# ==========================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_DIR="${REPO_ROOT}/evidence/baseline-${TIMESTAMP}"
SAMPLE_LAST="${HUBBLE_FLOWS_LAST:-5000}"  # số flow tối đa lấy mỗi loại

mkdir -p "$OUT_DIR"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[36m%s\033[0m\n' "$*"; }

blue "============================================================"
blue " ZTA Step 2.3.1 — Observability Baseline"
blue " Output: $OUT_DIR"
blue "============================================================"

# --------------------------------------------------------------------------
# 0) Pre-flight
# --------------------------------------------------------------------------
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  red "kubectl không kết nối được API server. Bỏ qua."
  exit 1
fi

# --------------------------------------------------------------------------
# 1) Inventory: pods, services, identities
# --------------------------------------------------------------------------
blue "[1/5] Kê khai workload và identity..."
kubectl get pods -A -o wide --show-labels > "$OUT_DIR/01-pods.txt" 2>&1 || true
kubectl get svc -A -o wide                 > "$OUT_DIR/02-services.txt" 2>&1 || true

CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o name 2>/dev/null | head -n1 | sed 's|pod/||' || true)
if [ -n "${CILIUM_POD:-}" ]; then
  kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium endpoint list \
    > "$OUT_DIR/03-cilium-endpoints.txt" 2>&1 || true
  kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium identity list \
    > "$OUT_DIR/04-cilium-identities.txt" 2>&1 || true
else
  yellow "  ⚠ không thấy cilium agent pod — bỏ qua endpoint/identity dump"
fi

# --------------------------------------------------------------------------
# 2) Snapshot policy hiện có
# --------------------------------------------------------------------------
blue "[2/5] Snapshot policy hiện có..."
kubectl get ciliumnetworkpolicies -A -o yaml \
  > "$OUT_DIR/05-existing-cnp.yaml" 2>&1 || true
kubectl get ciliumclusterwidenetworkpolicies -o yaml \
  >> "$OUT_DIR/05-existing-cnp.yaml" 2>&1 || true
kubectl get tracingpolicies,tracingpoliciesnamespaced -A -o yaml \
  > "$OUT_DIR/06-existing-tracing-policies.yaml" 2>&1 || true

CNP_COUNT=$(kubectl get ciliumnetworkpolicies -A --no-headers 2>/dev/null | wc -l || echo 0)
TP_COUNT=$(kubectl get tracingpolicies,tracingpoliciesnamespaced -A --no-headers 2>/dev/null | wc -l || echo 0)

# --------------------------------------------------------------------------
# 3) Hubble flow capture (East-West + North-South)
# --------------------------------------------------------------------------
blue "[3/5] Thu thập Hubble flows (last $SAMPLE_LAST mỗi loại)..."

# Hubble CLI is bundled in the cilium-agent container. Connect to hubble-relay
# service for cluster-wide flows; fallback to local socket if relay unavailable.
HUBBLE_RELAY_SVC="hubble-relay.kube-system.svc.cluster.local:4245"

hubble_observe() {
  # forward all args to `hubble observe`, prefer hubble-relay (cluster-wide)
  if [ -z "${CILIUM_POD:-}" ]; then
    return 1
  fi
  kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- \
    hubble observe --server "$HUBBLE_RELAY_SVC" "$@" 2>/dev/null \
    || kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- \
       hubble observe "$@" 2>/dev/null
}

if hubble_observe --last 1 --output json >/dev/null 2>&1; then
  hubble_observe --last "$SAMPLE_LAST" --verdict FORWARDED --output json \
    > "$OUT_DIR/10-hubble-flows-forwarded.json" || true
  hubble_observe --last "$SAMPLE_LAST" --verdict DROPPED --output json \
    > "$OUT_DIR/11-hubble-flows-dropped.json" || true
  hubble_observe --last "$SAMPLE_LAST" --type l7 --output json \
    > "$OUT_DIR/13-hubble-l7.json" || true
  green "  ✔ Hubble flows captured"
else
  yellow "  ⚠ Hubble không available — bỏ qua capture flows"
fi

# --------------------------------------------------------------------------
# 4) Aggregate flows by (src_ns, dst_ns) for DAAS prep
# --------------------------------------------------------------------------
blue "[4/5] Tổng hợp flow theo (src_ns -> dst_ns)..."
{
  echo "Aggregation of FORWARDED flows by (src_namespace -> dst_namespace, dst_port)"
  echo "----------------------------------------------------------------------"
  if [ -s "$OUT_DIR/10-hubble-flows-forwarded.json" ]; then
    python3 - <<'PY' "$OUT_DIR/10-hubble-flows-forwarded.json"
import json, sys, collections
counter = collections.Counter()
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        flow = ev.get("flow") or ev
        src_ns = (flow.get("source") or {}).get("namespace") or "-"
        dst_ns = (flow.get("destination") or {}).get("namespace") or "-"
        l4 = flow.get("l4") or {}
        tcp = l4.get("TCP") or {}
        udp = l4.get("UDP") or {}
        port = tcp.get("destination_port") or udp.get("destination_port") or "-"
        proto = "TCP" if tcp else ("UDP" if udp else "-")
        counter[(src_ns, dst_ns, proto, port)] += 1
for (s, d, proto, port), c in counter.most_common():
    print(f"  {c:>6}  {s:<20} -> {d:<20} {proto}/{port}")
PY
  else
    echo "  (no forwarded flow data)"
  fi
} > "$OUT_DIR/12-hubble-flow-summary.txt"

# --------------------------------------------------------------------------
# 5) SUMMARY.md
# --------------------------------------------------------------------------
blue "[5/5] Tạo SUMMARY.md..."
NS_LIST=$(kubectl get ns -o name 2>/dev/null | sed 's|namespace/||' | sort | tr '\n' ' ')

cat > "$OUT_DIR/SUMMARY.md" <<EOF
# Observability Baseline — $TIMESTAMP

Reference: Đồ án 1, Mục 2.3.1 (Hoàn thiện khả năng quan sát) / 3.4.1.

## Cluster scope at capture time

- Namespaces: ${NS_LIST}
- CiliumNetworkPolicies in cluster: ${CNP_COUNT}
- TracingPolicies (Tetragon) in cluster: ${TP_COUNT}
- Cilium agent pod sampled: \`${CILIUM_POD:-N/A}\`
- Hubble relay service: \`${HUBBLE_RELAY_SVC}\`

## Files

| File | Mục đích |
|------|----------|
| 01-pods.txt | Kê khai pod (xác định owner workload, label hiện tại) |
| 02-services.txt | Bản đồ Service (port, ClusterIP) |
| 03-cilium-endpoints.txt | Cilium endpoint với security identity |
| 04-cilium-identities.txt | Bảng identity → labels (nguyên liệu PIP 2) |
| 05-existing-cnp.yaml | Toàn bộ CNP hiện hành (so sánh trước/sau khi mở rộng default-deny) |
| 06-existing-tracing-policies.yaml | TracingPolicy / TracingPolicyNamespaced hiện hành (Tetragon → PIP/SI-4) |
| 10-hubble-flows-forwarded.json | Mẫu flow ALLOWED — đầu vào cho DAAS (ai đang nói chuyện với ai) |
| 11-hubble-flows-dropped.json | Mẫu flow DENIED — phát hiện nỗ lực truy cập trái phép |
| 12-hubble-flow-summary.txt | Aggregation theo (src_ns -> dst_ns, port) — bảng cho DAAS |
| 13-hubble-l7.json | Flow L7 (HTTP/gRPC method+path) — đầu vào cho 5W1H "What" |

## Cách dùng

1. Mở \`12-hubble-flow-summary.txt\` để có cái nhìn tổng quan luồng East-West thực tế.
2. So với \`02-services.txt\` để biết flow nào là **mong muốn** vs **bất ngờ**.
3. Phân loại các flow bất ngờ theo nguyên tắc DAAS — ghi vào \`doc/18-daas-classification.md\` (sẽ tạo ở PR #8).
4. Nếu thấy flow lạ ngay từ baseline → ghi nhận và đưa vào kịch bản tấn công (Mục 3.3 thesis).

## Mapping sang PIP framework

| PIP | Đóng góp từ baseline này |
|-----|--------------------------|
| PIP 2 — Workload Identity | \`04-cilium-identities.txt\` cung cấp identity ↔ label mapping |
| PIP 7 — Observability | Flow snapshots (10/11/13) là input cho PE — phát hiện anomaly |
| PIP 4 — CDM (proxy) | \`05-existing-cnp.yaml\` mô tả "trạng thái compliance" hiện tại của microsegmentation |

## Next step

Sau khi review baseline này, tiếp tục với **PR #8** — DAAS classification + default-deny mọi namespace.
EOF

green "✔ Done. Outputs in: $OUT_DIR"
echo ""
echo "Quick stats:"
echo "  - CNPs:          $CNP_COUNT"
echo "  - TracingPols:   $TP_COUNT"
echo "  - Forwarded fl.: $(wc -l < "$OUT_DIR/10-hubble-flows-forwarded.json" 2>/dev/null || echo 0)"
echo "  - Dropped fl.:   $(wc -l < "$OUT_DIR/11-hubble-flows-dropped.json" 2>/dev/null || echo 0)"
echo "  - L7 flows:      $(wc -l < "$OUT_DIR/13-hubble-l7.json" 2>/dev/null || echo 0)"
echo ""
echo "Mở $OUT_DIR/SUMMARY.md để bắt đầu phân tích."
