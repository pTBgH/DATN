#!/usr/bin/env bash
# scripts/zta-verify-labels.sh
#
# ZTA Step 2.3.3 — Verify mọi workload có đầy đủ 6 ZTA label.
#
# Liệt kê pod thiếu một trong các label bắt buộc:
#   - zta.job7189/role
#   - zta.job7189/tier
#   - zta.job7189/env
#   - zta.job7189/data-classification
#   - zta.job7189/exposure
#   - zta.job7189/team
#
# Exit 0 nếu tất cả pod (trong namespace user-managed) có đủ label.
# Exit 1 nếu thiếu — pod thiếu sẽ in ra.

set -euo pipefail

# Namespace yêu cầu label đầy đủ (mirror PR #8 DAAS)
export ZTA_NAMESPACES="data vault security monitoring gateway management job7189-apps"

echo "============================================================"
echo " ZTA Step 2.3.3 — Workload Label Verify"
echo "============================================================"

# Toàn bộ kiểm tra ủy quyền cho Python (dễ parse JSON, regex, set semantics)
python3 - <<'PYEOF'
import json
import os
import subprocess
import sys

ZTA_NAMESPACES = os.environ["ZTA_NAMESPACES"].split()

REQUIRED = [
    "zta.job7189/role",
    "zta.job7189/tier",
    "zta.job7189/env",
    "zta.job7189/data-classification",
    "zta.job7189/exposure",
    "zta.job7189/team",
]

VALID = {
    "zta.job7189/role": {"api", "worker", "cache", "db", "broker", "proxy", "sso", "secret-store", "ui", "monitoring", "scraper"},
    "zta.job7189/tier": {"T1", "T2", "T3"},
    "zta.job7189/env":  {"prod", "dev", "staging"},
    "zta.job7189/data-classification": {"confidential", "internal", "public", "none"},
    "zta.job7189/exposure": {"external", "internal", "cluster-only"},
    "zta.job7189/team": {"platform", "backend", "frontend", "data", "security"},
}

total_pods = 0
total_missing = 0
total_invalid = 0
ns_with_failures = 0

for ns in ZTA_NAMESPACES:
    # Check namespace exists
    chk = subprocess.run(["kubectl", "get", "ns", ns], capture_output=True, text=True)
    if chk.returncode != 0:
        print(f"\n--- Namespace: {ns} ---")
        print("  [SKIP] không tồn tại")
        continue

    print(f"\n--- Namespace: {ns} ---")
    res = subprocess.run(
        ["kubectl", "get", "pods", "-n", ns, "-o", "json"],
        capture_output=True, text=True, check=False
    )
    data = json.loads(res.stdout) if res.stdout.strip() else {"items": []}
    items = data.get("items", [])

    if not items:
        print("  (không có pod)")
        continue

    ns_pods = len(items)
    ns_missing = 0
    ns_invalid = 0

    for pod in items:
        name = pod["metadata"]["name"]
        labels = pod["metadata"].get("labels", {}) or {}

        missing = [k for k in REQUIRED if k not in labels]
        invalid = [(k, labels[k]) for k in REQUIRED if k in labels and labels[k] not in VALID[k]]

        flags = []
        if missing:
            flags.append(f"MISSING={','.join(missing)}")
            ns_missing += 1
        if invalid:
            flags.append("INVALID=" + ",".join(f"{k}={v}" for k, v in invalid))
            ns_invalid += 1
        if flags:
            print(f"  [FAIL] {name:50s}  " + " | ".join(flags))

    print(f"  -> {ns_pods} pods, missing-label={ns_missing}, invalid-value={ns_invalid}")
    total_pods += ns_pods
    total_missing += ns_missing
    total_invalid += ns_invalid
    if ns_missing or ns_invalid:
        ns_with_failures += 1

print()
print("============================================================")
print(f" Tổng: {total_pods} pods kiểm tra qua {len(ZTA_NAMESPACES)} namespace")
if ns_with_failures == 0:
    print(" ✔ PASS — mọi workload có đủ 6 ZTA label hợp lệ")
    print("============================================================")
    sys.exit(0)
else:
    print(f" ✘ FAIL — {ns_with_failures} namespace có pod thiếu/sai label")
    print(f"   missing-total={total_missing}, invalid-total={total_invalid}")
    print("   Chạy:  bash scripts/zta-apply-workload-labels.sh --apply")
    print("============================================================")
    sys.exit(1)
PYEOF
