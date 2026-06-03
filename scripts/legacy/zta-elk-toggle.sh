#!/usr/bin/env bash
# zta-elk-toggle.sh — bật/tắt nhanh ELK stack (Elasticsearch + Kibana + Filebeat).
# Manifest đã apply sẵn → script chỉ scale workload + (filebeat) patch nodeSelector.
#
# Usage:
#   bash zta-elk-toggle.sh up        # scale lên + (re-)enable filebeat DS
#   bash zta-elk-toggle.sh down      # scale 0 + disable filebeat DS (giữ data)
#   bash zta-elk-toggle.sh status    # show pod status
#
# Lưu ý:
#   - DaemonSet không có 'replicas'. Để "tắt" filebeat: patch nodeSelector
#     đến label không tồn tại; để bật lại: gỡ patch đó.
#   - ES dùng PVC (volumeClaimTemplates), scale 0 KHÔNG mất dữ liệu cũ.

set -uo pipefail

NS="${NS:-monitoring}"
ES_STS="${ES_STS:-es}"
KIBANA_DEPLOY="${KIBANA_DEPLOY:-kibana}"
FB_DS="${FB_DS:-filebeat}"
FB_DISABLE_LABEL_KEY="${FB_DISABLE_LABEL_KEY:-job7189.io/filebeat-disabled}"

action="${1:-status}"

bar() { echo; echo "──────────────────────────────────────────────────────────────────"; }
say() { echo "  · $*"; }
ok() { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*"; }

status() {
  bar; echo "  $NS WORKLOADS"; bar
  kubectl -n "$NS" get sts,deploy,ds,pod 2>/dev/null || warn "ns=$NS không tồn tại"

  bar; echo "  $NS RESOURCE USE"; bar
  kubectl -n "$NS" top pod 2>/dev/null || say "metric-server chưa sẵn sàng"

  bar; echo "  ES INDICES (nếu reachable)"; bar
  # port-forward ngắn
  ( kubectl -n "$NS" port-forward svc/elasticsearch 19200:9200 >/dev/null 2>&1 ) &
  PF=$!
  sleep 2
  curl -sS --max-time 3 http://localhost:19200/_cat/indices?v 2>/dev/null | head -20 \
    || warn "Không gọi được ES (chưa Ready hoặc service tên khác)"
  kill "$PF" 2>/dev/null || true
}

up() {
  bar; echo "  SCALING UP ELK"; bar

  say "Elasticsearch StatefulSet → 1"
  kubectl -n "$NS" scale sts/"$ES_STS" --replicas=1 && ok "scale OK" || warn "scale fail"

  say "Đợi ES Ready (≤300s)..."
  if kubectl -n "$NS" wait pod -l app=elasticsearch --for=condition=Ready --timeout=300s 2>/dev/null; then
    ok "Elasticsearch Ready"
  else
    warn "ES CHƯA ready sau 300s — mô tả pod:"
    kubectl -n "$NS" describe pod -l app=elasticsearch 2>/dev/null | tail -25
    return 2
  fi

  say "Kibana Deployment → 1"
  kubectl -n "$NS" scale deploy/"$KIBANA_DEPLOY" --replicas=1 && ok "scale OK" || warn "scale fail"

  say "Filebeat DaemonSet: gỡ nodeSelector disable (nếu có)"
  # nếu key tồn tại → set None → effectively remove
  kubectl -n "$NS" patch ds "$FB_DS" --type=json -p \
    "[{\"op\":\"remove\",\"path\":\"/spec/template/spec/nodeSelector/${FB_DISABLE_LABEL_KEY//\//~1}\"}]" \
    2>/dev/null && ok "đã gỡ nodeSelector" || say "(không có nodeSelector disable trước đây — OK)"

  say "Đợi Kibana Ready (≤300s)..."
  kubectl -n "$NS" wait pod -l app=kibana --for=condition=Ready --timeout=300s 2>/dev/null \
    && ok "Kibana Ready" || warn "Kibana chưa Ready"

  say "Đợi Filebeat DaemonSet rollout (≤180s)..."
  kubectl -n "$NS" rollout status ds/"$FB_DS" --timeout=180s 2>/dev/null \
    && ok "Filebeat rolled out" || warn "Filebeat chưa Ready"

  bar; echo "  ACCESS"; bar
  cat <<EOF
  · Kibana (NodePort 30601):
      curl -sI http://<any-node-ip>:30601
      (hoặc port-forward: kubectl -n $NS port-forward svc/kibana 5601:80)
  · Discover index pattern: filebeat-*
  · Sample query:
      kubernetes.namespace : "job7189-apps" and message : "401"
EOF
}

down() {
  bar; echo "  SCALING DOWN ELK"; bar

  say "Disable Filebeat DaemonSet (patch nodeSelector → 'true')"
  kubectl -n "$NS" patch ds "$FB_DS" --type=json -p \
    "[{\"op\":\"add\",\"path\":\"/spec/template/spec/nodeSelector/${FB_DISABLE_LABEL_KEY//\//~1}\",\"value\":\"true\"}]" \
    2>/dev/null && ok "patched" || warn "patch fail (DS chưa tồn tại hoặc đã patch rồi)"
  # rolling delete pods → DaemonSet sẽ không sinh pod mới vì nodeSelector mismatch
  kubectl -n "$NS" delete pod -l k8s-app=filebeat --ignore-not-found 2>/dev/null \
    && ok "đã xoá filebeat pods (DS sẽ KHÔNG tái tạo)" \
    || say "(không có pod filebeat đang chạy)"

  say "Kibana Deployment → 0"
  kubectl -n "$NS" scale deploy/"$KIBANA_DEPLOY" --replicas=0 && ok "scaled" || warn "scale fail"

  say "Elasticsearch StatefulSet → 0 (PVC giữ nguyên data)"
  kubectl -n "$NS" scale sts/"$ES_STS" --replicas=0 && ok "scaled" || warn "scale fail"

  ok "ELK đã DOWN (PVC vẫn lưu data — uplại sẽ thấy index cũ)"
}

case "$action" in
  up) up; bar; status ;;
  down) down; bar; status ;;
  status|"") status ;;
  *) echo "Usage: $0 {up|down|status}"; exit 1 ;;
esac
