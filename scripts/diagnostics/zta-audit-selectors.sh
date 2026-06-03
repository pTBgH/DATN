#!/usr/bin/env bash
# zta-audit-selectors.sh — cross-check pod labels vs YAML selectors cho 6 ns
# còn lại của Phase 2C + network sanity check.
#
# Usage: bash zta-audit-selectors.sh
# Output: /tmp/zta-audit-<ts>.log

set -u
TS=$(date +%Y%m%d-%H%M%S)
LOG=/tmp/zta-audit-$TS.log
exec > >(tee -a "$LOG") 2>&1

REPO="${HOME}/projects/DATN"
YAMLS_DIR="$REPO/infras/k8s-yaml/cilium-policies/namespaces"

hdr() { echo; echo "========== $* =========="; }

hdr "0/3 NETWORK SANITY"
echo "- ping 8.8.8.8 (3 pkts, timeout 3s):"
ping -c 3 -W 3 8.8.8.8 | tail -3 || echo "  ping 8.8.8.8 FAILED"
echo
echo "- DNS resolve google.com (timeout 5s):"
timeout 5 getent hosts google.com || echo "  DNS FAILED"
echo
echo "- HTTPS reach google.com (curl -I, timeout 5s):"
curl -s -o /dev/null -w "  HTTP %{http_code} in %{time_total}s\n" --max-time 5 https://www.google.com || echo "  HTTPS FAILED"
echo
echo "- k8s apiserver healthz từ host (kubectl --raw, timeout 5s):"
timeout 5 kubectl get --raw=/healthz 2>&1 | head -3
echo
echo "- k8s apiserver healthz từ trong cluster (busybox in default ns):"
kubectl run zta-net-test --image=busybox:1.37.0 --restart=Never --rm -i --timeout=20s \
  --command -- sh -c 'wget -qO- --timeout=5 https://kubernetes.default.svc:443/healthz --no-check-certificate 2>&1 || echo "wget FAILED"; echo; echo "DNS test:"; nslookup kubernetes.default.svc 2>&1 | head -5' \
  2>&1 | grep -v "^pod default/zta-net-test" || true

declare -A NS_TO_YAML=(
  [cert-manager]=17-cert-manager.yaml
  [cosign-system]=18-cosign-system.yaml
  [gatekeeper-system]=19-gatekeeper-system.yaml
  [ingress-nginx]=20-ingress-nginx.yaml
  [local-path-storage]=22-local-path-storage.yaml
  [trivy-system]=24-trivy-system.yaml
)

hdr "1/3 POD LABELS (key=value cho mỗi pod)"
for ns in "${!NS_TO_YAML[@]}"; do
  echo "--- ns=$ns ---"
  kubectl -n "$ns" get pod --show-labels --no-headers 2>/dev/null | \
    awk '{ n=$1; lab=$NF; gsub(",", "\n   ", lab); print "  " n ":\n   " lab }'
done

hdr "2/3 YAML selectors (endpointSelector.matchLabels.*)"
for ns in "${!NS_TO_YAML[@]}"; do
  yaml="$YAMLS_DIR/${NS_TO_YAML[$ns]}"
  echo "--- ns=$ns ($yaml) ---"
  if [ ! -f "$yaml" ]; then
    echo "  MISSING file"; continue
  fi
  awk '
    /^---/ { in_meta=0; in_sel=0; rule="" }
    /^metadata:/ { in_meta=1 }
    in_meta && /^  name:/ { rule=$2; in_meta=0 }
    /endpointSelector:/ { in_sel=1; depth=0; next }
    in_sel && /^[^[:space:]]/ { in_sel=0 }
    in_sel && /matchLabels:/ { depth=1; next }
    in_sel && depth==1 && /^      [a-z]/ {
      lbl=$0; sub(/^      /, "", lbl)
      print "  [" rule "]   " lbl
    }
  ' "$yaml"
done

hdr "3/3 CNP đang LIVE trong cluster + số endpoint match"
for ns in "${!NS_TO_YAML[@]}"; do
  echo "--- ns=$ns ---"
  CNP_LIST=$(kubectl -n "$ns" get cnp -o name 2>/dev/null)
  if [ -z "$CNP_LIST" ]; then
    echo "  (chưa có CNP nào trong ns này)"
    continue
  fi
  for cnp in $CNP_LIST; do
    name="${cnp##*/}"
    valid=$(kubectl -n "$ns" get "$cnp" -o jsonpath='{.status.conditions[?(@.type=="Valid")].status}' 2>/dev/null)
    sel=$(kubectl -n "$ns" get "$cnp" -o jsonpath='{.spec.endpointSelector.matchLabels}' 2>/dev/null)
    echo "  $name  VALID=$valid  selector=$sel"
  done
done

hdr "KẾT LUẬN"
echo "Log: $LOG"
echo
echo "Đọc giúp mình:"
echo " 1) Mục 0/3 — có gói nào FAIL không (ping, DNS, HTTPS, apiserver)?"
echo " 2) Mục 1/3 vs 2/3 — selector trong YAML có khớp pod label thật không?"
echo "    Ví dụ: nếu YAML chọn 'app.kubernetes.io/name: cert-manager' nhưng pod"
echo "    có label 'app.kubernetes.io/name: cert-manager-webhook' thì SAI."
