#!/bin/bash
# =============================================================================
# free-ram-for-trivy.sh
# Temporarily scale down memory-heavy components (Kafka, Elasticsearch, Prometheus)
# to free up host and cluster RAM for the Trivy Operator scanning process.
#
# Usage:
#   ./scripts/free-ram-for-trivy.sh
# =============================================================================

set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
cyan='\033[0;36m'
nc='\033[0m'

avail_mi() { free -m | awk '/^Mem:/ {print $7}'; }

echo -e "${cyan}============================================================${nc}"
echo -e "${cyan} 🧹 Scaling down heavy components to free RAM for Trivy ${nc}"
echo -e "${cyan}============================================================${nc}"

echo -e "Current available host memory: ${yellow}$(avail_mi) MiB${nc}"

# 1) Scale down Kafka in namespace 'data'
echo ""
echo -e "${cyan}[1/3] Scaling down Kafka StatefulSet in 'data' namespace...${nc}"
if kubectl get sts kafka -n data >/dev/null 2>&1; then
  CURRENT_REPLICAS=$(kubectl get sts kafka -n data -o jsonpath='{.spec.replicas}')
  if [ "$CURRENT_REPLICAS" -gt 0 ]; then
    echo -e "      Current replicas: $CURRENT_REPLICAS. Scaling down to 0..."
    kubectl scale sts kafka -n data --replicas=0
  else
    echo -e "      ✓ Kafka is already scaled to 0."
  fi
else
  echo -e "      ⚠ StatefulSet 'kafka' not found in namespace 'data'."
fi

# 2) Scale down Elasticsearch in namespace 'monitoring'
echo ""
echo -e "${cyan}[2/3] Scaling down Elasticsearch StatefulSet in 'monitoring' namespace...${nc}"
if kubectl get sts es -n monitoring >/dev/null 2>&1; then
  CURRENT_REPLICAS=$(kubectl get sts es -n monitoring -o jsonpath='{.spec.replicas}')
  if [ "$CURRENT_REPLICAS" -gt 0 ]; then
    echo -e "      Current replicas: $CURRENT_REPLICAS. Scaling down to 0..."
    kubectl scale sts es -n monitoring --replicas=0
  else
    echo -e "      ✓ Elasticsearch is already scaled to 0."
  fi
else
  echo -e "      ⚠ StatefulSet 'es' not found in namespace 'monitoring'."
fi

# 3) Scale down Prometheus in namespace 'monitoring'
echo ""
echo -e "${cyan}[3/3] Scaling down Prometheus Deployment in 'monitoring' namespace...${nc}"
if kubectl get deploy prometheus -n monitoring >/dev/null 2>&1; then
  CURRENT_REPLICAS=$(kubectl get deploy prometheus -n monitoring -o jsonpath='{.spec.replicas}')
  if [ "$CURRENT_REPLICAS" -gt 0 ]; then
    echo -e "      Current replicas: $CURRENT_REPLICAS. Scaling down to 0..."
    kubectl scale deploy prometheus -n monitoring --replicas=0
  else
    echo -e "      ✓ Prometheus is already scaled to 0."
  fi
else
  echo -e "      ⚠ Deployment 'prometheus' not found in namespace 'monitoring'."
fi

echo ""
echo -e "${yellow}Waiting 10s for pods to terminate...${nc}"
sleep 10

echo -e "Final available host memory: ${green}$(avail_mi) MiB${nc}"
echo -e "${green}✓ RAM cleanup done. You can now deploy or run Trivy scans.${nc}"
