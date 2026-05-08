#!/bin/bash
# =============================================================================
# toggle-internal-ui.sh — Bat/tat giao dien quan tri noi bo
# 
# Su dung:
#   ./scripts/toggle-internal-ui.sh status              # Xem trang thai
#   ./scripts/toggle-internal-ui.sh off                  # Tat tat ca UI
#   ./scripts/toggle-internal-ui.sh on                   # Bat tat ca UI
#   ./scripts/toggle-internal-ui.sh on phpmyadmin        # Bat chi phpMyAdmin
#   ./scripts/toggle-internal-ui.sh off kibana grafana   # Tat Kibana + Grafana
# =============================================================================

set -euo pipefail

# Danh sach services co the toggle
# kafbat removed — Kafka UI is no longer deployed in this lab; the manifest
# in infras/k8s-yaml/03-kafka.yaml (Phần 2) is commented out. To re-enable,
# uncomment that block AND restore the [kafbat]= line below.
declare -A SERVICES=(
  [phpmyadmin]="management:deployment/phpmyadmin"
  # [kafbat]="management:deployment/kafbat"   # disabled (never used)
  [kibana]="monitoring:deployment/kibana"
  [grafana]="monitoring:deployment/grafana"
)

# Mau sac
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   Toggle Internal UI — ZTA job7189       ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo ""
}

get_replicas() {
  local ns="${1%%:*}"
  local resource="${1##*:}"
  kubectl get "$resource" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A"
}

get_ready() {
  local ns="${1%%:*}"
  local resource="${1##*:}"
  kubectl get "$resource" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0"
}

show_status() {
  print_header
  printf "%-15s %-14s %-10s %-10s %s\n" "SERVICE" "NAMESPACE" "REPLICAS" "READY" "STATUS"
  printf "%-15s %-14s %-10s %-10s %s\n" "-------" "---------" "--------" "-----" "------"
  
  local total_mem=0
  for name in "${!SERVICES[@]}"; do
    local ref="${SERVICES[$name]}"
    local ns="${ref%%:*}"
    local replicas=$(get_replicas "$ref")
    local ready=$(get_ready "$ref")
    
    local status_icon=""
    if [[ "$replicas" == "0" ]]; then
      status_icon="${YELLOW}OFF${NC}"
    elif [[ "$replicas" == "N/A" ]]; then
      status_icon="${RED}NOT FOUND${NC}"
    elif [[ "$ready" == "$replicas" ]]; then
      status_icon="${GREEN}ON${NC}"
    else
      status_icon="${YELLOW}STARTING${NC}"
    fi
    
    printf "%-15s %-14s %-10s %-10s " "$name" "$ns" "$replicas" "$ready"
    echo -e "$status_icon"
  done
  
  echo ""
  echo -e "${CYAN}Tip:${NC} Tat Kibana + Grafana + phpMyAdmin tiet kiem ~1.15Gi RAM"
  echo ""
}

scale_service() {
  local name="$1"
  local replicas="$2"
  
  if [[ -z "${SERVICES[$name]+x}" ]]; then
    echo -e "${RED}ERROR: Service '$name' khong ton tai.${NC}"
    echo "Services hop le: ${!SERVICES[*]}"
    return 1
  fi
  
  local ref="${SERVICES[$name]}"
  local ns="${ref%%:*}"
  local resource="${ref##*:}"
  
  local current=$(get_replicas "$ref")
  if [[ "$current" == "$replicas" ]]; then
    echo -e "  ${YELLOW}$name${NC} da o $replicas replicas — bo qua"
    return 0
  fi
  
  echo -ne "  ${CYAN}$name${NC} ($ns) → replicas=$replicas ... "
  if kubectl scale "$resource" -n "$ns" --replicas="$replicas" >/dev/null 2>&1; then
    if [[ "$replicas" == "0" ]]; then
      echo -e "${YELLOW}OFF${NC}"
    else
      echo -e "${GREEN}ON${NC}"
    fi
  else
    echo -e "${RED}FAILED${NC} (co the chua deploy)"
  fi
}

do_toggle() {
  local action="$1"
  shift
  local targets=("$@")
  
  local replicas=0
  [[ "$action" == "on" ]] && replicas=1
  
  print_header
  
  if [[ ${#targets[@]} -eq 0 ]]; then
    # Toggle tat ca
    echo -e "Action: ${CYAN}$action${NC} tat ca UI noi bo"
    echo ""
    for name in "${!SERVICES[@]}"; do
      scale_service "$name" "$replicas"
    done
  else
    # Toggle chi dinh
    echo -e "Action: ${CYAN}$action${NC} ${targets[*]}"
    echo ""
    for name in "${targets[@]}"; do
      scale_service "$name" "$replicas"
    done
  fi
  
  echo ""
  echo -e "${GREEN}Done!${NC} Chay './scripts/toggle-internal-ui.sh status' de xem trang thai."
  echo ""
}

# Main
case "${1:-status}" in
  status)
    show_status
    ;;
  on)
    shift
    do_toggle "on" "$@"
    ;;
  off)
    shift
    do_toggle "off" "$@"
    ;;
  *)
    echo "Su dung:"
    echo "  $0 status              Xem trang thai"
    echo "  $0 off                 Tat tat ca UI"
    echo "  $0 on                  Bat tat ca UI"
    echo "  $0 on phpmyadmin       Bat chi phpMyAdmin"
    echo "  $0 off kibana grafana  Tat Kibana + Grafana"
    echo ""
    echo "Services: ${!SERVICES[*]}"
    exit 1
    ;;
esac
