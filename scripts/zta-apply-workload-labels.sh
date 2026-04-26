#!/usr/bin/env bash
# scripts/zta-apply-workload-labels.sh
#
# ZTA Step 2.3.3 — Áp 6 ZTA label cho mọi workload theo bảng trong
# doc/19-label-schema.md. Script idempotent: chạy nhiều lần không hại.
#
# Mặc định DRY-RUN (chỉ in lệnh sẽ chạy). Truyền --apply để áp thật.
#
# Cách hoạt động: dùng `kubectl label <resource>/<name> -n <ns> KEY=VALUE --overwrite`
# Không re-deploy, không restart pod. Label được lưu ở metadata.labels của workload
# resource (Deployment/StatefulSet/DaemonSet) VÀ spec.template.metadata.labels
# (qua kubectl patch) để pod replica mới sinh ra cũng có label.
#
# Usage:
#   bash scripts/zta-apply-workload-labels.sh           # dry-run
#   bash scripts/zta-apply-workload-labels.sh --apply   # apply
#
# Tham chiếu: doc/19-label-schema.md

set -euo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

run() {
  if [[ $APPLY -eq 1 ]]; then
    echo "+ $*"
    "$@" || echo "  ! command failed (continuing)"
  else
    echo "DRY: $*"
  fi
}

# Patch cả workload-level VÀ pod-template-level để pod mới có label
label_workload() {
  local kind=$1 name=$2 ns=$3 role=$4 tier=$5 env=$6 dc=$7 expo=$8 team=$9

  if ! kubectl get "$kind" "$name" -n "$ns" >/dev/null 2>&1; then
    echo "[SKIP] $kind/$name in ns=$ns không tồn tại"
    return 0
  fi

  # 1) Label trên workload metadata
  run kubectl label "$kind" "$name" -n "$ns" \
    "zta.job7189/role=$role" \
    "zta.job7189/tier=$tier" \
    "zta.job7189/env=$env" \
    "zta.job7189/data-classification=$dc" \
    "zta.job7189/exposure=$expo" \
    "zta.job7189/team=$team" \
    --overwrite

  # 2) Patch pod template để pod mới sinh ra có label
  #    (kubectl label trên Deployment KHÔNG truyền sang spec.template — phải patch riêng)
  local patch
  patch=$(cat <<JSON
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "zta.job7189/role": "$role",
          "zta.job7189/tier": "$tier",
          "zta.job7189/env": "$env",
          "zta.job7189/data-classification": "$dc",
          "zta.job7189/exposure": "$expo",
          "zta.job7189/team": "$team"
        }
      }
    }
  }
}
JSON
)
  run kubectl patch "$kind" "$name" -n "$ns" --type=strategic --patch "$patch"
}

echo "============================================================"
echo " ZTA Step 2.3.3 — Apply Workload Labels"
echo " Mode: $([[ $APPLY -eq 1 ]] && echo APPLY || echo DRY-RUN)"
echo "============================================================"

# ============ INFRASTRUCTURE ============
# Tham số: kind name namespace role tier env data-class exposure team

# data namespace
label_workload deployment mysql data \
  db T1 prod confidential cluster-only data
label_workload statefulset kafka data \
  broker T1 prod confidential cluster-only data
label_workload deployment minio data \
  db T2 prod internal cluster-only data || true   # nếu deploy ở registry/data tùy file

# management namespace
label_workload deployment phpmyadmin management \
  ui T3 prod internal internal platform
label_workload deployment kafbat management \
  ui T3 prod none internal data

# security namespace
label_workload deployment keycloak security \
  sso T1 prod confidential internal security
label_workload deployment oauth2-proxy security \
  proxy T1 prod confidential internal security

# gateway namespace
label_workload deployment kong-gateway gateway \
  proxy T2 prod none external platform

# vault namespace (vault-0 là StatefulSet)
label_workload statefulset vault vault \
  secret-store T1 prod confidential cluster-only security
label_workload deployment vault-dev vault \
  secret-store T1 dev internal cluster-only security
label_workload deployment vault-agent-agent-injector vault \
  proxy T1 prod confidential cluster-only security

# monitoring namespace
label_workload statefulset es monitoring \
  db T2 prod internal cluster-only platform
label_workload daemonset filebeat monitoring \
  scraper T2 prod none cluster-only platform
label_workload deployment kibana monitoring \
  ui T2 prod internal internal platform
label_workload deployment prometheus monitoring \
  monitoring T2 prod none cluster-only platform
label_workload deployment grafana monitoring \
  ui T2 prod internal internal platform
label_workload deployment kube-state-metrics monitoring \
  scraper T2 prod none cluster-only platform
label_workload daemonset node-exporter monitoring \
  scraper T2 prod none cluster-only platform

# registry namespace
label_workload deployment docker-registry registry \
  db T3 prod none cluster-only platform

# ============ MICROSERVICES (job7189-apps) ============
# Backend services (T2 trừ identity-service T1)
for svc in identity-service; do
  label_workload deployment "$svc" job7189-apps \
    api T1 prod confidential internal backend
done
for svc in hiring-service candidate-service job-service workspace-service communication-service storage-service; do
  label_workload deployment "$svc" job7189-apps \
    api T2 prod internal internal backend
done
# Per-service Redis — tier kế thừa từ parent service
label_workload deployment identity-service-redis job7189-apps \
  cache T1 prod confidential cluster-only backend
for svc in hiring-service candidate-service job-service workspace-service communication-service storage-service; do
  label_workload deployment "${svc}-redis" job7189-apps \
    cache T2 prod internal cluster-only backend
done
# Frontend (T3) — namespace=frontend (per helmfile.yaml)
for svc in fe-candidate fe-recruiter; do
  label_workload deployment "$svc" frontend \
    ui T3 prod public internal frontend
done

echo
echo "============================================================"
echo " Hoàn tất"
echo "============================================================"
if [[ $APPLY -eq 0 ]]; then
  echo "Đây là DRY-RUN. Để áp thật:"
  echo "  bash $0 --apply"
fi
echo
echo "Verify:"
echo "  bash scripts/zta-verify-labels.sh"
