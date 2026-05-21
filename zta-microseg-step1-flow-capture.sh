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
if [ "$HUBBLE_RELAY" -lt 1 ]; then
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
if [ "$HUBBLE_RELAY" -ge 1 ]; then
  # Dùng hubble relay (multi-node) — exec qua cilium pod (đã có hubble CLI built-in)
  kubectl -n kube-system exec "$CILIUM_POD" -- sh -c \
    "$HUBBLE_CMD --server=hubble-relay.kube-system.svc:80" \
    > "$OUT_DIR/07-flows.jsonl" 2> "$OUT_DIR/07-flows.err" &
else
  # Fallback: hubble local trong cilium pod (single-node view)
  kubectl -n kube-system exec "$CILIUM_POD" -- sh -c "$HUBBLE_CMD" \
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
python3 - "$OUT_DIR" << 'PYEOF'
import json, csv, sys, collections, os
out_dir = sys.argv[1]
src_file = os.path.join(out_dir,"07-flows.jsonl")

flows = []
parse_err = 0
with open(src_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            j = json.loads(line)
        except Exception:
            parse_err += 1
            continue
        # Hubble JSON format: {"flow": {...}} hoặc bare flow dict
        fl = j.get("flow", j)
        src = fl.get("source", {}) or {}
        dst = fl.get("destination", {}) or {}
        l4  = fl.get("l4", {}) or {}
        port, proto = "", ""
        if "TCP" in l4:
            proto = "TCP";  port = l4["TCP"].get("destination_port","")
        elif "UDP" in l4:
            proto = "UDP";  port = l4["UDP"].get("destination_port","")
        elif "ICMPv4" in l4:
            proto = "ICMPv4"
        verdict = fl.get("verdict","UNKNOWN")
        flow_type = fl.get("Type", fl.get("type",""))
        flows.append({
            "src_ns":   src.get("namespace","") or src.get("labels",[{}])[0].get("key","") if src.get("labels") else "",
            "src_pod":  src.get("pod_name","") or src.get("identity_name",""),
            "src_id":   str(src.get("identity","")),
            "dst_ns":   dst.get("namespace",""),
            "dst_pod":  dst.get("pod_name","") or dst.get("identity_name",""),
            "dst_id":   str(dst.get("identity","")),
            "port":     str(port),
            "proto":    proto,
            "verdict":  verdict,
            "type":     flow_type,
        })
print(f"  Parsed flows: {len(flows)} (parse_err={parse_err})")

# Dedup
keys = set()
unique = []
for fl in flows:
    k = (fl["src_ns"], fl["src_pod"], fl["dst_ns"], fl["dst_pod"], fl["port"], fl["proto"], fl["verdict"])
    if k in keys: continue
    keys.add(k)
    unique.append(fl)
print(f"  Unique flows: {len(unique)}")

# CSVs
fields = ["src_ns","src_pod","dst_ns","dst_pod","port","proto","verdict","type"]

def dump_csv(name, rows):
    p = os.path.join(out_dir, name)
    with open(p,"w") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader(); w.writerows(rows)
    return p

dump_csv("08-unique-flows.csv", unique)
dropped   = [f for f in unique if f["verdict"]=="DROPPED"]
forwarded = [f for f in unique if f["verdict"]=="FORWARDED"]
dump_csv("09-dropped-flows.csv",   dropped)
dump_csv("10-forwarded-flows.csv", forwarded)
print(f"  DROPPED: {len(dropped)} | FORWARDED: {len(forwarded)}")

# Markdown report grouped by src ns
by_src = collections.defaultdict(list)
for fl in unique:
    by_src[fl["src_ns"] or "(WORLD/HOST)"].append(fl)
md = ["# Flows by Source Namespace\n",
      f"_Captured at {out_dir}_\n"]
for ns in sorted(by_src.keys()):
    md.append(f"\n## src_ns: `{ns}`  ({len(by_src[ns])} unique flows)\n")
    md.append("| dst_ns | dst_pod | port | proto | verdict | type |")
    md.append("|---|---|---|---|---|---|")
    for fl in sorted(by_src[ns], key=lambda x:(x["dst_ns"],x["dst_pod"],x["port"])):
        md.append(f"| {fl['dst_ns']} | {fl['dst_pod']} | {fl['port']} | {fl['proto']} | **{fl['verdict']}** | {fl['type']} |")
with open(os.path.join(out_dir,"11-flows-by-src-ns.md"),"w") as f:
    f.write("\n".join(md))

# Summary
ns_set = set()
ns_with_cnp = set()
import yaml
try:
    cnp = list(yaml.safe_load_all(open(os.path.join(out_dir,"02-cnp.yaml"))))
    if cnp and cnp[0] and cnp[0].get("items"):
        for it in cnp[0]["items"]:
            ns_with_cnp.add(it["metadata"]["namespace"])
except Exception as e:
    print(f"  WARN: yaml parse cnp: {e}")

ns_with_drops = collections.Counter()
for fl in dropped:
    ns_with_drops[fl["src_ns"] or "(WORLD/HOST)"] += 1
    ns_with_drops[fl["dst_ns"] or "(WORLD/HOST)"] += 1

with open(os.path.join(out_dir,"00-pods.txt")) as f:
    next(f, None)
    for line in f:
        cols = line.split()
        if cols: ns_set.add(cols[0])

sm = ["# Microsegmentation Step 1 — Summary\n",
      f"- Total namespaces có pod: **{len(ns_set)}**",
      f"- Namespaces có CiliumNetworkPolicy: **{len(ns_with_cnp)}** ({sorted(ns_with_cnp)})",
      f"- Namespaces CHƯA có CNP: **{len(ns_set - ns_with_cnp)}** ({sorted(ns_set - ns_with_cnp)})",
      f"- Unique flow đã capture: **{len(unique)}**",
      f"- Flow DROPPED: **{len(dropped)}**",
      f"- Flow FORWARDED: **{len(forwarded)}**",
      "",
      "## Top namespaces có nhiều DROPPED flow (cần điều tra)",
      "| ns | drop count |",
      "|---|---|"]
for ns, n in ns_with_drops.most_common(20):
    sm.append(f"| {ns} | {n} |")

sm += ["", "## Đề xuất bước tiếp",
       "1. Đọc `11-flows-by-src-ns.md` để hiểu luồng thực tế của từng ns.",
       "2. Đối chiếu với `doc/20-5w1h-policy-matrix.md` — flow nào hợp pháp nhưng chưa có policy?",
       "3. Sinh CNP default-deny + allowlist cho từng ns chưa có policy.",
       "4. Apply theo thứ tự: ns ít flow → ns nhiều flow (để giảm rủi ro)."]
with open(os.path.join(out_dir,"12-summary.md"),"w") as f:
    f.write("\n".join(sm))
print(f"  Wrote summary: {os.path.join(out_dir,'12-summary.md')}")
PYEOF
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
