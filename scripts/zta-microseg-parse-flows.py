#!/usr/bin/env python3
"""Parse hubble flow JSONL → CSV + Markdown reports.

Usage: zta-microseg-parse-flows.py <out_dir>
Reads:  <out_dir>/07-flows.jsonl, <out_dir>/00-pods.txt, <out_dir>/02-cnp.yaml
Writes: 08-unique-flows.csv, 09-dropped-flows.csv, 10-forwarded-flows.csv,
        11-flows-by-src-ns.md, 12-summary.md

Notes on Hubble flow JSON shape (Hubble 1.x):
- Top-level: {"flow": {...}}  OR  bare flow dict.
- source/destination.labels is a list[str] like ["reserved:host", "k8s:app=foo"]
  — NOT list[dict]. Old parser assumed list[dict] and crashed with
  `AttributeError: 'str' object has no attribute 'get'`.
- source/destination.namespace may be empty (host / world / reserved identities).
- l4 dispatch: {"TCP": {"destination_port": N}} or {"UDP": ...}
"""
import collections
import csv
import json
import os
import re
import sys

NS_LABEL_KEY = "k8s:io.kubernetes.pod.namespace"


def labels_to_dict(labels):
    """Hubble labels → dict. Accepts list[str] (modern) or list[dict] (legacy)."""
    if not labels:
        return {}
    if isinstance(labels[0], dict):
        return {lab.get("key", ""): lab.get("value", "") for lab in labels}
    out = {}
    for lab in labels:
        if "=" in lab:
            k, v = lab.split("=", 1)
            out[k] = v
        else:
            out[lab] = ""
    return out


def get_ns(endpoint):
    """Extract namespace from a Hubble endpoint. Falls back to label lookup."""
    if not endpoint:
        return ""
    ns = endpoint.get("namespace", "")
    if ns:
        return ns
    labs = labels_to_dict(endpoint.get("labels", []))
    if NS_LABEL_KEY in labs:
        return labs[NS_LABEL_KEY]
    return ""


def get_identity(endpoint):
    """Reserved identity label (host / world / kube-apiserver / remote-node)."""
    if not endpoint:
        return ""
    for lab in endpoint.get("labels", []) or []:
        if isinstance(lab, str) and lab.startswith("reserved:"):
            return lab
        if isinstance(lab, dict) and lab.get("key", "").startswith("reserved:"):
            return lab["key"]
    return ""


def main(out_dir):
    src_file = os.path.join(out_dir, "07-flows.jsonl")
    flows = []
    parse_err = 0
    with open(src_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                j = json.loads(line)
            except Exception:
                parse_err += 1
                continue
            fl = j.get("flow", j)
            src = fl.get("source") or {}
            dst = fl.get("destination") or {}
            l4 = fl.get("l4") or {}
            port, proto = "", ""
            if "TCP" in l4:
                proto = "TCP"
                port = l4["TCP"].get("destination_port", "")
            elif "UDP" in l4:
                proto = "UDP"
                port = l4["UDP"].get("destination_port", "")
            elif "ICMPv4" in l4:
                proto = "ICMPv4"
            elif "ICMPv6" in l4:
                proto = "ICMPv6"
            flows.append({
                "src_ns":   get_ns(src) or get_identity(src) or "(unknown)",
                "src_pod":  src.get("pod_name", "") or "",
                "src_id":   str(src.get("identity", "")),
                "dst_ns":   get_ns(dst) or get_identity(dst) or "(unknown)",
                "dst_pod":  dst.get("pod_name", "") or "",
                "dst_id":   str(dst.get("identity", "")),
                "port":     str(port),
                "proto":    proto,
                "verdict":  fl.get("verdict", "UNKNOWN"),
                "type":     fl.get("Type", fl.get("type", "")),
                "direction": fl.get("traffic_direction", ""),
            })
    print(f"  Parsed flows: {len(flows)} (parse_err={parse_err})")

    keys = set()
    unique = []
    for fl in flows:
        k = (fl["src_ns"], fl["src_pod"], fl["dst_ns"], fl["dst_pod"],
             fl["port"], fl["proto"], fl["verdict"])
        if k in keys:
            continue
        keys.add(k)
        unique.append(fl)
    print(f"  Unique flows: {len(unique)}")

    fields = ["src_ns", "src_pod", "src_id", "dst_ns", "dst_pod", "dst_id",
              "port", "proto", "verdict", "type", "direction"]

    def dump_csv(name, rows):
        p = os.path.join(out_dir, name)
        with open(p, "w") as f:
            w = csv.DictWriter(f, fieldnames=fields)
            w.writeheader()
            w.writerows(rows)

    dump_csv("08-unique-flows.csv", unique)
    dropped = [f for f in unique if f["verdict"] == "DROPPED"]
    forwarded = [f for f in unique if f["verdict"] == "FORWARDED"]
    dump_csv("09-dropped-flows.csv", dropped)
    dump_csv("10-forwarded-flows.csv", forwarded)
    print(f"  DROPPED: {len(dropped)} | FORWARDED: {len(forwarded)}")

    by_src = collections.defaultdict(list)
    for fl in unique:
        by_src[fl["src_ns"] or "(WORLD/HOST)"].append(fl)
    md = ["# Flows by Source Namespace\n",
          f"_Captured at {out_dir}_\n"]
    for ns in sorted(by_src.keys()):
        md.append(f"\n## src_ns: `{ns}`  ({len(by_src[ns])} unique flows)\n")
        md.append("| dst_ns | dst_pod | port | proto | verdict | type |")
        md.append("|---|---|---|---|---|---|")
        for fl in sorted(by_src[ns], key=lambda x: (x["dst_ns"], x["dst_pod"], str(x["port"]))):
            md.append(f"| {fl['dst_ns']} | {fl['dst_pod']} | {fl['port']} | "
                      f"{fl['proto']} | **{fl['verdict']}** | {fl['type']} |")
    with open(os.path.join(out_dir, "11-flows-by-src-ns.md"), "w") as f:
        f.write("\n".join(md))

    ns_with_cnp = set()
    try:
        import yaml
        cnp = list(yaml.safe_load_all(open(os.path.join(out_dir, "02-cnp.yaml"))))
        if cnp and cnp[0] and cnp[0].get("items"):
            for it in cnp[0]["items"]:
                ns_with_cnp.add(it["metadata"]["namespace"])
    except Exception as e:
        print(f"  WARN: yaml parse cnp: {e}")

    ns_set = set()
    pods_path = os.path.join(out_dir, "00-pods.txt")
    if os.path.exists(pods_path):
        with open(pods_path) as f:
            next(f, None)
            for line in f:
                cols = line.split()
                if cols:
                    ns_set.add(cols[0])

    ns_with_drops = collections.Counter()
    for fl in dropped:
        ns_with_drops[fl["src_ns"] or "(WORLD/HOST)"] += 1
        ns_with_drops[fl["dst_ns"] or "(WORLD/HOST)"] += 1

    sm = [
        "# Microsegmentation Step 1 — Summary\n",
        f"- Total namespaces có pod: **{len(ns_set)}**",
        f"- Namespaces có CiliumNetworkPolicy: **{len(ns_with_cnp)}** ({sorted(ns_with_cnp)})",
        f"- Namespaces CHƯA có CNP: **{len(ns_set - ns_with_cnp)}** ({sorted(ns_set - ns_with_cnp)})",
        f"- Unique flow đã capture: **{len(unique)}**",
        f"- Flow DROPPED: **{len(dropped)}**",
        f"- Flow FORWARDED: **{len(forwarded)}**",
        "",
        "## Top namespaces có nhiều DROPPED flow (cần điều tra)",
        "| ns | drop count |",
        "|---|---|",
    ]
    for ns, n in ns_with_drops.most_common(20):
        sm.append(f"| {ns} | {n} |")
    sm += ["",
           "## Đề xuất bước tiếp",
           "1. Đọc `11-flows-by-src-ns.md` để hiểu luồng thực tế của từng ns.",
           "2. Đối chiếu với `knowledge-base/20-5w1h-policy-matrix.md` — flow nào hợp pháp nhưng chưa có policy?",
           "3. Sinh CNP default-deny + allowlist cho từng ns chưa có policy.",
           "4. Apply theo thứ tự: ns ít flow → ns nhiều flow (để giảm rủi ro)."]
    with open(os.path.join(out_dir, "12-summary.md"), "w") as f:
        f.write("\n".join(sm))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: zta-microseg-parse-flows.py <out_dir>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
