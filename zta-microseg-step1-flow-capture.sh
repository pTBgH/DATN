#!/usr/bin/env bash
# =============================================================================
# zta-microseg-step1-flow-capture.sh
#
# Bước 1 của quy trình microsegmentation: XÁC ĐỊNH FLOW giữa TẤT CẢ pod.
# 100% read-only, không động chạm cluster.
#
# Output:
#   ~/zta-microseg/<TIMESTAMP>/
#     00-pods.txt              kubectl get pod -A -o wide (IP↔pod ref)
#     01-services.txt          kubectl get svc -A -o wide
#     02-cnp.yaml              CiliumNetworkPolicy hiện tại
#     03-ccnp.yaml             CiliumClusterwideNetworkPolicy
#     04-netpol.yaml           NetworkPolicy (k8s native)
#     05-nodes.txt             kubectl get node -o wide
#     06-ip-pod-map.json       IP → {ns, pod, labels}
#     07-flows.jsonl           Hubble flow stream (raw JSON, 1 dòng/flow)
#     08-unique-flows.csv      Bảng flow dedup: src/dst/port/verdict
#     09-dropped-flows.csv     Chỉ DROPPED
#     10-forwarded-flows.csv   Chỉ FORWARDED
#     11-flows-by-src-ns.md    Markdown report nhóm theo source namespace
#     12-summary.md            Tổng kết: ns nào chưa có policy / flow nào bất thường
#
# Cách chạy:
#   bash zta-microseg-step1-flow-capture.sh                 # capture 10 phút
#   CAPTURE_MIN=20 bash zta-microseg-step1-flow-capture.sh  # custom thời lượng
# =============================================================================
set -uo pipefail

CAPTURE_MIN="${CAPTURE_MIN:-10}"
OUT_DIR="$HOME/zta-microseg/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

log()  { printf '\n=== %s ===\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ⚠  %s\n' "$*" >&2; }

# --------------------------------------------------------------------------
log "0/4 Pre-flight check"
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERR: kubectl không reachable. Export KUBECONFIG trước."
  exit 1
fi

CILIUM_POD=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$CILIUM_POD" ]; then
  echo "ERR: Không tìm thấy cilium pod trong kube-system."
  exit 1
fi
ok "Sẽ dùng cilium pod để chạy hubble: $CILIUM_POD"

HUBBLE_RELAY=$(kubectl -n kube-system get pod -l k8s-app=hubble-relay --no-headers 2>/dev/null | grep -c Running)
RELAY_POD_IP=""
RELAY_PORT="4245"
if [ "$HUBBLE_RELAY" -ge 1 ]; then
  # cilium pod chạy hostNetwork=true → KHÔNG resolve được *.svc.cluster.local.
  # Dùng podIP trực tiếp + port container (4245).
  RELAY_POD_IP=$(kubectl -n kube-system get pod -l k8s-app=hubble-relay \
    -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)
  if [ -n "$RELAY_POD_IP" ]; then
    ok "Hubble relay reachable qua $RELAY_POD_IP:$RELAY_PORT (multi-node)"
  else
    warn "hubble-relay Running nhưng không lấy được podIP — fallback local socket"
  fi
else
  warn "hubble-relay không Running — flow sẽ chỉ từ 1 node (cilium pod hiện tại)"
fi

echo "  Output dir: $OUT_DIR"
echo "  Thời lượng capture: $CAPTURE_MIN phút"

# --------------------------------------------------------------------------
log "1/4 Snapshot tài nguyên (pod / svc / policy / ns)"
kubectl get pod  -A -o wide                              > "$OUT_DIR/00-pods.txt"
kubectl get svc  -A -o wide                              > "$OUT_DIR/01-services.txt"
kubectl get cnp  -A -o yaml                              > "$OUT_DIR/02-cnp.yaml"           2>/dev/null
kubectl get ccnp -o yaml                                 > "$OUT_DIR/03-ccnp.yaml"          2>/dev/null
kubectl get netpol -A -o yaml                            > "$OUT_DIR/04-netpol.yaml"        2>/dev/null
kubectl get node -o wide                                 > "$OUT_DIR/05-nodes.txt"

python3 - "$OUT_DIR/06-ip-pod-map.json" << 'PYEOF'
import json, subprocess, sys
out_file = sys.argv[1]
data = json.loads(subprocess.check_output(["kubectl","get","pod","-A","-o","json"]))
m = {}
for p in data["items"]:
    ip = (p.get("status") or {}).get("podIP")
    if ip:
        m[ip] = {
            "ns":     p["metadata"]["namespace"],
            "pod":    p["metadata"]["name"],
            "node":   (p.get("spec") or {}).get("nodeName",""),
            "labels": p["metadata"].get("labels", {}),
        }
json.dump(m, open(out_file,"w"), indent=2)
print(f"  IP-pod map: {len(m)} entries")
PYEOF
ok "Snapshot xong"

# --------------------------------------------------------------------------
log "2/4 Hubble flow capture (${CAPTURE_MIN} phút)"
echo "  Đang capture flow từ Hubble relay (nếu có) hoặc từ cilium pod $CILIUM_POD..."

HUBBLE_CMD="hubble observe --follow --output json"
if [ -n "$RELAY_POD_IP" ]; then
  # Multi-node qua hubble-relay (dùng podIP vì cilium hostNetwork không resolve DNS svc)
  kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- sh -c \
    "$HUBBLE_CMD --server=${RELAY_POD_IP}:${RELAY_PORT}" \
    > "$OUT_DIR/07-flows.jsonl" 2> "$OUT_DIR/07-flows.err" &
else
  # Fallback: hubble local trong cilium pod (single-node view)
  kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- sh -c "$HUBBLE_CMD" \
    > "$OUT_DIR/07-flows.jsonl" 2> "$OUT_DIR/07-flows.err" &
fi
HUBBLE_PID=$!

SECS=$((CAPTURE_MIN * 60))
echo "  Capture PID=$HUBBLE_PID, đợi ${SECS}s..."
sleep "$SECS"
kill "$HUBBLE_PID" 2>/dev/null
wait "$HUBBLE_PID" 2>/dev/null

LINES=$(wc -l < "$OUT_DIR/07-flows.jsonl")
ok "Captured $LINES flow events"

# --------------------------------------------------------------------------
log "3/4 Parse flow → CSV + Markdown"
# Parser lives in scripts/zta-microseg-parse-flows.py (auto-locate next to this
# script). Inline heredoc bị bỏ vì Hubble flow JSON có labels là list[str],
# parser cũ assume list[dict] → AttributeError 'str' object has no attribute 'get'.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER=""
for cand in \
    "$SCRIPT_DIR/scripts/zta-microseg-parse-flows.py" \
    "$SCRIPT_DIR/zta-microseg-parse-flows.py" \
    "$(dirname "$SCRIPT_DIR")/scripts/zta-microseg-parse-flows.py"; do
    if [ -f "$cand" ]; then PARSER="$cand"; break; fi
done
if [ -z "$PARSER" ]; then
    err "Không tìm thấy zta-microseg-parse-flows.py (đã tìm cạnh script)"
    err "  Bạn có thể chạy tay: python3 scripts/zta-microseg-parse-flows.py $OUT_DIR"
else
    python3 "$PARSER" "$OUT_DIR" || err "Parser failed (xem stderr)"
fi
ok "Phân tích xong"

# --------------------------------------------------------------------------
log "4/4 Hoàn tất"
echo
echo "  Output dir: $OUT_DIR"
ls -la "$OUT_DIR"
echo
echo "  Đọc 2 file quan trọng nhất:"
echo "    cat $OUT_DIR/12-summary.md"
echo "    less $OUT_DIR/11-flows-by-src-ns.md"
echo
echo "  Gửi 2 file đó về cho mình để mình sinh CNP allowlist."
