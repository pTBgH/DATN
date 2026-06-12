#!/bin/bash
# =============================================================================
# restore-ram-workloads.sh
# Restore (scale up) Kafka, Elasticsearch, and Prometheus back to 1 replica.
#
# Usage:
#   ./scripts/restore-ram-workloads.sh
# =============================================================================

set -euo pipefail

green='\033[0;32m'
cyan='\033[0;36m'
nc='\033[0m'

echo -e "${cyan}============================================================${nc}"
echo -e "${cyan} 🚀 Restoring heavy workloads (Kafka, Elasticsearch, Prometheus) ${nc}"
echo -e "${cyan}============================================================${nc}"

# 1) Scale up Kafka
echo -e "${cyan}[1/3] Restoring Kafka StatefulSet to 1 replica...${nc}"
if kubectl get sts kafka -n data >/dev/null 2>&1; then
  kubectl scale sts kafka -n data --replicas=1
else
  echo -e "      ⚠ StatefulSet 'kafka' not found in namespace 'data'."
fi

# 2) Scale up Elasticsearch
echo -e "${cyan}[2/3] Restoring Elasticsearch StatefulSet to 1 replica...${nc}"
if kubectl get sts es -n monitoring >/dev/null 2>&1; then
  kubectl scale sts es -n monitoring --replicas=1
else
  echo -e "      ⚠ StatefulSet 'es' not found in namespace 'monitoring'."
fi

# 3) Scale up Prometheus
echo -e "${cyan}[3/3] Restoring Prometheus Deployment to 1 replica...${nc}"
if kubectl get deploy prometheus -n monitoring >/dev/null 2>&1; then
  kubectl scale deploy prometheus -n monitoring --replicas=1
else
  echo -e "      ⚠ Deployment 'prometheus' not found in namespace 'monitoring'."
fi

echo ""
echo -e "${green}✓ Workloads restored. Run './scripts/toggle-internal-ui.sh status' or 'kubectl get pods -A' to monitor health.${nc}"
