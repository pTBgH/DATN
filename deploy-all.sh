#!/bin/bash
# Project DOAN2 - Full System Deployment Manager
# This is the main orchestrator that runs all 3 deployment phases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ==================== COLORS ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Project DOAN2 - Full System Deployment                 ║"
  echo "║  Automated Cluster & Microservices Setup                ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
}

print_menu() {
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Deployment Options                                      ║"
  echo "╠══════════════════════════════════════════════════════════╣"
  echo "║  1. Run all phases sequentially (01 → 02 → 03)          ║"
  echo "║  2. Run Phase 1 only (Cluster Setup)                    ║"
  echo "║  3. Run Phase 2 only (Infrastructure)                   ║"
  echo "║  4. Run Phase 3 only (Microservices)                    ║"
  echo "║  5. Run Phase 2 & 3 (Skip cluster setup)                ║"
  echo "║  6. Clean up and start over                             ║"
  echo "║  7. ZTA full teardown (kind delete + wipe data)         ║"
  echo "║  8. ZTA full rebuild (01 → 02 → 03 → 08 → ZTA → verify) ║"
  echo "║  0. Exit                                                 ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
}

verify_script_exists() {
  local script=$1
  if [ ! -f "$script" ]; then
    echo -e "${RED}❌ ERROR: $script not found${NC}"
    return 1
  fi
  if [ ! -x "$script" ]; then
    chmod +x "$script"
  fi
  return 0
}

run_phase() {
  local phase_num=$1
  local script_name=$2
  local phase_title=$3
  
  echo ""
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}Running PHASE $phase_num: $phase_title${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo ""
  
  if ! verify_script_exists "$script_name"; then
    return 1
  fi
  
  local START_TIME=$(date +%s)
  
  if bash "$script_name"; then
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    echo ""
    echo -e "${GREEN}✅ PHASE $phase_num COMPLETED (${DURATION}s)${NC}"
    echo ""
    return 0
  else
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    echo ""
    echo -e "${RED}❌ PHASE $phase_num FAILED (${DURATION}s)${NC}"
    echo ""
    return 1
  fi
}

cleanup_cluster() {
  echo ""
  read -p "🗑️  Delete Kind cluster 'job7189'? (yes/no): " answer
  if [ "$answer" != "yes" ]; then
    echo "Cleanup cancelled"
    return 0
  fi
  
  echo "Deleting cluster..."
  kind delete cluster --name job7189 2>/dev/null || true
  echo -e "${GREEN}✅ Cluster deleted${NC}"
}

# ==================== MAIN MENU ====================
print_header

# Check prerequisites
echo "📋 Checking prerequisites..."
MISSING=""
for cmd in kind kubectl helm; do
  if ! command -v $cmd &> /dev/null; then
    MISSING="$MISSING $cmd"
  fi
done

if [ -n "$MISSING" ]; then
  echo -e "${RED}❌ Missing required commands:$MISSING${NC}"
  echo "   Please install the required tools first"
  exit 1
fi
echo -e "${GREEN}✅ All prerequisites found${NC}"

# Main loop
while true; do
  print_menu
  read -p "Select option (0-6): " choice
  
  case $choice in
    1)
      echo -e "${YELLOW}Running all phases sequentially...${NC}"
      TOTAL_START=$(date +%s)
      
      run_phase 1 "01-setup-cluster.sh" "Cluster Setup" || {
        echo -e "${RED}Phase 1 failed. Stopping.${NC}"
        continue
      }
      
      echo -e "${YELLOW}Waiting 30 seconds before Phase 2...${NC}"
      sleep 30
      
      run_phase 2 "02-deploy-infrastructure.sh" "Infrastructure" || {
        echo -e "${RED}Phase 2 failed. You can retry or continue to Phase 3.${NC}"
        # read -p "Continue to Phase 3 anyway? (yes/no): " continue_choice
        # [ "$continue_choice" != "yes" ] && continue
      }
      
      echo -e "${YELLOW}Waiting 60 seconds before Phase 3...${NC}"
      sleep 60
      
      run_phase 3 "03-deploy-microservices.sh" "Microservices" || {
        echo -e "${RED}Phase 3 failed. Check logs above.${NC}"
      }
      
      TOTAL_END=$(date +%s)
      TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
      
      echo ""
      echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
      echo -e "${GREEN}🎉 FULL DEPLOYMENT COMPLETED IN ${TOTAL_DURATION}s${NC}"
      echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
      echo ""
      ;;
    
    2)
      run_phase 1 "01-setup-cluster.sh" "Cluster Setup"
      ;;
    
    3)
      run_phase 2 "02-deploy-infrastructure.sh" "Infrastructure"
      ;;
    
    4)
      run_phase 3 "03-deploy-microservices.sh" "Microservices"
      ;;
    
    5)
      TOTAL_START=$(date +%s)
      
      run_phase 2 "02-deploy-infrastructure.sh" "Infrastructure" || {
        echo -e "${RED}Phase 2 failed. Stopping.${NC}"
        continue
      }
      
      echo -e "${YELLOW}Waiting 60 seconds before Phase 3...${NC}"
      sleep 60
      
      run_phase 3 "03-deploy-microservices.sh" "Microservices" || {
        echo -e "${RED}Phase 3 failed. Check logs above.${NC}"
      }
      
      TOTAL_END=$(date +%s)
      TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
      
      echo ""
      echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
      echo -e "${GREEN}✅ PHASES 2 & 3 COMPLETED IN ${TOTAL_DURATION}s${NC}"
      echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
      ;;
    
    6)
      cleanup_cluster
      ;;

    7)
      bash scripts/zta-teardown.sh
      ;;

    8)
      bash scripts/zta-rebuild.sh
      ;;

    0)
      echo -e "${YELLOW}Goodbye!${NC}"
      exit 0
      ;;
    
    *)
      echo -e "${RED}Invalid option. Please select 0-8${NC}"
      ;;
  esac
done