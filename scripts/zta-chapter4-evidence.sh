#!/usr/bin/env bash
# =============================================================================
# zta-chapter4-evidence.sh
# Mục đích: thu thập bằng chứng thực tế từ cluster cho 8 kịch bản Chương 4.
# Đặc tính:
#   - set +e: mỗi section độc lập; section fail KHÔNG dừng các section khác.
#   - Mỗi network/exec call có `timeout` (10–25s).
#   - Output: evidence/chapter4/scenario-XX-<name>.txt + 00-diagnostics.txt
# Yêu cầu:
#   - kubectl context trỏ vào cluster ZTA job7189.
#   - Có thể read pods/exec/logs ở các namespace job7189-apps, vault, security,
#     monitoring, cosign-system, kube-system.
#   - (Tuỳ chọn) biến môi trường:
#       KEYCLOAK_MEMBER_USER  (mặc định: member1)
#       KEYCLOAK_MEMBER_PASS  (BẮT BUỘC cho scenario 5; nếu rỗng → skip 5)
#       KONG_URL              (vd: http://api.job7189.com; nếu rỗng → port-forward)
# Cách chạy:
#   bash scripts/zta-chapter4-evidence.sh
# =============================================================================
 
set +e
set -u
set -o pipefail
 
OUT="evidence/chapter4"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
 
# Wrapper: log header + tee output ra file riêng từng scenario.
section() {
  local id="$1"; shift
  local name="$1"; shift
  local out="$OUT/scenario-${id}-${name}-${TS}.txt"
  {
    echo "=============================================================="
    echo "  SCENARIO ${id}: ${name}"
    echo "  ${TS}"
    echo "=============================================================="
  } | tee "$out"
  SECTION_OUT="$out"
}
 
# Wrapper run command với timeout + ghi cả lệnh và output (kèm exit code).
run() {
  local t="$1"; shift
  echo
  echo "$ $*" | tee -a "$SECTION_OUT"
  timeout --foreground "$t" bash -c "$*" 2>&1 | tee -a "$SECTION_OUT"
  local ec=${PIPESTATUS[0]}
  echo "[exit=${ec}]" | tee -a "$SECTION_OUT"
}
 
# Lấy Cilium pod (để chạy hubble observe — KHÔNG cần hubble CLI trên host).
CILIUM_POD="$(kubectl -n kube-system get pod -l k8s-app=cilium \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
 
# =============================================================================
# 0. DIAGNOSTICS — chụp trạng thái hệ thống tại thời điểm thử nghiệm.
# =============================================================================
section "00" "diagnostics"
 
run 15 "kubectl version --short || kubectl version"
run 10 "kubectl get nodes -o wide"
run 10 "kubectl get ns"
run 15 "kubectl get cnp -A"
run 15 "kubectl get ccnp"
run 15 "kubectl get ciliumcidrgroup"
run 10 "kubectl get tracingpolicy,tracingpolicynamespaced -A"
run 10 "kubectl get clusterimagepolicy"
run 10 "kubectl get clusterspiffeid 2>/dev/null"
run 15 "kubectl -n job7189-apps get pod -o wide"
run 10 "kubectl -n security get pod -o wide"
run 10 "kubectl -n vault get pod -o wide"
run 15 "kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.mesh-auth-enabled}'; echo"
run 15 "kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}'; echo"
 
# =============================================================================
# 1. LATERAL MOVEMENT — pod vô danh thử TCP-connect sang data/vault.
# =============================================================================
section "01" "lateral-movement"
 
# 1a. Show default-deny + một policy egress dữ liệu hiện hành.
run 10 "kubectl -n job7189-apps get cnp default-deny-all -o yaml | head -40"
run 10 "kubectl -n job7189-apps get cnp -o name"
 
# 1b. Tạo pod attacker chạy busybox, thử 4 dest. Pod TỰ XOÁ sau khi xong.
run 60 "kubectl -n job7189-apps run lateral-attacker-${TS} \
  --image=busybox:1.37.0 --restart=Never --rm -i --quiet \
  --labels='zta.test/role=attacker' --command -- \
  sh -c 'for d in mysql.data:3306 mysql.data:6379 kafka.data:9092 vault.vault:8200; do \
    echo \"--- probe \$d\"; nc -zvw5 \${d%:*} \${d#*:} 2>&1; done'"
 
# 1c. Trích hubble flow ngay tại Cilium pod (không cần hubble CLI trên host).
run 20 "kubectl -n kube-system exec ${CILIUM_POD} -c cilium-agent -- \
  hubble observe --since 2m --verdict DROPPED \
  --from-namespace job7189-apps --output compact 2>/dev/null | head -40"
 
# =============================================================================
# 2. API ABUSE — JWT giả + HTTP verb sai L7 policy.
# =============================================================================
section "02" "api-abuse"
 
# 2a. JWT bịa → 401.
run 15 "kubectl -n job7189-apps run jwt-probe-${TS} \
  --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet --command -- \
  curl -sS -m 8 -o /dev/null -w 'HTTP %{http_code}\\n' \
    -H 'Authorization: Bearer not-a-real-jwt' \
    http://kong-gateway.gateway.svc.cluster.local/api/recruiters/profile"
 
# 2b. Bên trong pod job-service, thử DELETE workspace (L7 chỉ allow GET).
JOB_POD="$(kubectl -n job7189-apps get pod -l app=job-service \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
run 5 "echo 'JOB_POD=${JOB_POD:-<none>}'"
if [[ -n "${JOB_POD:-}" ]]; then
  run 15 "kubectl -n job7189-apps exec ${JOB_POD} -c app -- \
    curl -sS -m 8 -o /dev/null -w 'HTTP %{http_code}\\n' -X DELETE \
    http://workspace-service.job7189-apps.svc.cluster.local/api/v1/internal/workspaces/42"
fi
 
# 2c. Hubble L7 verdict cho job7189-apps.
run 20 "kubectl -n kube-system exec ${CILIUM_POD} -c cilium-agent -- \
  hubble observe --since 2m --type l7 --namespace job7189-apps \
  --output compact 2>/dev/null | head -30"
 
# =============================================================================
# 3. RUNTIME ANOMALY — exec /bin/sh trong identity-service → Tetragon event.
# =============================================================================
section "03" "runtime-anomaly"
 
ID_POD="$(kubectl -n job7189-apps get pod -l app=identity-service \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
run 5 "echo 'ID_POD=${ID_POD:-<none>}'"
 
# 3a. Show TracingPolicy hiện hành.
run 10 "kubectl -n job7189-apps get tracingpolicynamespaced -o yaml | head -60"
 
# 3b. Trigger event: exec /bin/sh.
if [[ -n "${ID_POD:-}" ]]; then
  run 15 "kubectl -n job7189-apps exec ${ID_POD} -c app -- \
    /bin/sh -c 'id; uname -a; cat /etc/passwd | head -3'"
fi
 
# 3c. Đọc 30 dòng log tetragon-export-stdout gần nhất (json).
TETRAGON_POD="$(kubectl -n kube-system get pod -l app.kubernetes.io/name=tetragon \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
run 5 "echo 'TETRAGON_POD=${TETRAGON_POD:-<none>}'"
if [[ -n "${TETRAGON_POD:-}" ]]; then
  run 15 "kubectl -n kube-system logs ${TETRAGON_POD} -c export-stdout --tail=200 \
    2>/dev/null | grep -F 'block-suspicious-exec' | tail -5"
fi
 
# =============================================================================
# 4. CREDENTIAL REUSE — Vault dynamic creds + revoke.
# =============================================================================
section "04" "credential-reuse"
 
# 4a. Đếm lease database/ đang hoạt động.
run 20 "kubectl -n vault exec vault-0 -- sh -c \
  'vault login -no-print \$VAULT_TOKEN 2>/dev/null || true; \
   vault list -format=json sys/leases/lookup/database/creds 2>/dev/null | head -40'"
 
# 4b. Xem credential JIT mà sidecar vault-agent đã render vào tmpfs.
JOB_POD2="$(kubectl -n job7189-apps get pod -l app=job-service \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
run 5 "echo 'JOB_POD2=${JOB_POD2:-<none>}'"
if [[ -n "${JOB_POD2:-}" ]]; then
  run 15 "kubectl -n job7189-apps exec ${JOB_POD2} -c app -- \
    sh -c 'ls -l /vault/secrets/ 2>/dev/null; \
           head -3 /vault/secrets/.env.db 2>/dev/null | sed s/PASSWORD=.*/PASSWORD=***REDACTED***/'"
fi
 
# 4c. Trích log vault-agent (renew lease) — bằng chứng app không downtime.
if [[ -n "${JOB_POD2:-}" ]]; then
  run 15 "kubectl -n job7189-apps logs ${JOB_POD2} -c vault-agent --tail=30 2>/dev/null | grep -E 'rendered|renewer|renewal' | tail -10"
fi
 
# 4d. (Tuỳ chọn) revoke 1 lease — chỉ chạy nếu biến CONFIRM_REVOKE=1.
if [[ "${CONFIRM_REVOKE:-0}" == "1" ]]; then
  run 20 "kubectl -n vault exec vault-0 -- vault lease revoke -prefix database/creds/job-service"
  run 10 "sleep 5"
  if [[ -n "${JOB_POD2:-}" ]]; then
    run 15 "kubectl -n job7189-apps logs ${JOB_POD2} -c vault-agent --tail=10 2>/dev/null"
  fi
else
  echo "[skip] revoke (set CONFIRM_REVOKE=1 nếu muốn chạy thật)" | tee -a "$SECTION_OUT"
fi
 
# =============================================================================
# 5. OPA CONTEXT-AWARE — member1 POST /api/jobs phải bị 403.
# =============================================================================
section "05" "opa-context-aware"
 
KC_USER="${KEYCLOAK_MEMBER_USER:-member1}"
KC_PASS="${KEYCLOAK_MEMBER_PASS:-}"
if [[ -z "$KC_PASS" ]]; then
  echo "[skip] Không có KEYCLOAK_MEMBER_PASS — bỏ qua scenario 5." | tee -a "$SECTION_OUT"
  echo "       Re-run với: KEYCLOAK_MEMBER_PASS='...' bash $0" | tee -a "$SECTION_OUT"
else
  # 5a. Lấy token member1.
  run 20 "kubectl -n job7189-apps run kc-token-${TS} \
    --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet --command -- \
    sh -c 'curl -sS -m 15 -X POST \
      http://keycloak.security.svc.cluster.local:8080/realms/job7189/protocol/openid-connect/token \
      -d grant_type=password -d client_id=thesis-e2e \
      -d username=${KC_USER} -d password=${KC_PASS} \
      | head -c 400; echo'"
  # 5b. Lưu ý: scenario này realistically cần token thật → ghi câu lệnh nguyên văn
  #     vào file để bạn copy chạy thủ công nếu output ở 5a không decode JWT được.
  cat >> "$SECTION_OUT" <<EOF
 
[note] Script trên chỉ in 400 byte đầu của response token endpoint.
Để demo end-to-end (POST /api/jobs → 403), thực hiện thủ công 2 lệnh sau,
copy access_token vào biến và chạy lệnh thứ 2:
 
  MEM_JWT="<dán access_token>"
  kubectl -n job7189-apps run mem-attack \\
    --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet --command -- \\
    curl -sS -m 10 -w '\\nHTTP %{http_code}\\n' -X POST \\
      http://kong-gateway.gateway.svc.cluster.local/api/jobs \\
      -H "Authorization: Bearer \$MEM_JWT" \\
      -H 'Content-Type: application/json' \\
      -d '{"title":"deny-this"}'
EOF
fi
 
# 5c. Log OPA gần nhất (có request POST /v1/data/zta/authz/allow).
OPA_POD="$(kubectl -n security get pod -l app=opa \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
run 5 "echo 'OPA_POD=${OPA_POD:-<none>}'"
if [[ -n "${OPA_POD:-}" ]]; then
  run 15 "kubectl -n security logs ${OPA_POD} --tail=200 2>/dev/null \
    | grep -E 'allow|decision_id|/v1/data/zta/authz' | tail -8"
fi
 
# =============================================================================
# 6. THREAT-INTEL EGRESS — FireHOL CIDR + URLhaus FQDN.
# =============================================================================
section "06" "threat-intel-egress"
 
# 6a. Show CCNP + CIDRGroup đang active.
run 10 "kubectl get ccnp cnp-threat-intel-egress-deny -o yaml 2>/dev/null | head -40"
run 10 "kubectl get ciliumcidrgroup threat-intel-firehol -o yaml 2>/dev/null | head -15"
run 10 "kubectl -n kube-system get cm coredns-sinkhole -o jsonpath='{.metadata.annotations}' 2>/dev/null; echo"
 
# 6b. Lấy 1 IP có thật trong CIDR group để probe.
SAMPLE_CIDR="$(kubectl get ciliumcidrgroup threat-intel-firehol \
  -o jsonpath='{.spec.externalCIDRs[0]}' 2>/dev/null)"
SAMPLE_IP="${SAMPLE_CIDR%%/*}"
run 5 "echo 'SAMPLE_CIDR=${SAMPLE_CIDR:-<none>} → SAMPLE_IP=${SAMPLE_IP:-<none>}'"
 
# 6c. Curl tới IP đó (kỳ vọng: timeout = bị drop).
if [[ -n "${SAMPLE_IP:-}" ]]; then
  run 20 "kubectl -n job7189-apps run egress-probe-${TS} \
    --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet --command -- \
    curl -sS -m 8 -o /dev/null -w 'HTTP %{http_code}\\n' http://${SAMPLE_IP}/"
fi
 
# 6d. Dig 1 FQDN trong sinkhole (lấy mẫu đầu tiên trong CM).
SINK_FQDN="$(kubectl -n kube-system get cm coredns-sinkhole \
  -o jsonpath='{.data.hosts}' 2>/dev/null | awk '$1=="0.0.0.0"{print $2; exit}')"
run 5 "echo 'SINK_FQDN=${SINK_FQDN:-<none>}'"
if [[ -n "${SINK_FQDN:-}" ]]; then
  run 15 "kubectl -n job7189-apps run dig-probe-${TS} \
    --image=busybox:1.37.0 --restart=Never --rm -i --quiet --command -- \
    nslookup ${SINK_FQDN}"
fi
 
# 6e. Hubble drop verdict cho 2 hành vi trên.
run 20 "kubectl -n kube-system exec ${CILIUM_POD} -c cilium-agent -- \
  hubble observe --since 2m --verdict DROPPED --from-namespace job7189-apps \
  --output compact 2>/dev/null | head -20"
 
# =============================================================================
# 7. COSIGN ADMISSION — apply image không ký → admission deny.
# =============================================================================
section "07" "cosign-admission"
 
run 10 "kubectl get clusterimagepolicy"
run 10 "kubectl -n cosign-system get pod"
 
# Manifest tạm cho pod sử dụng image không ký (chạy attack).
TMP_YAML="$(mktemp /tmp/unsigned-attacker-XXXXXX.yaml)"
cat > "$TMP_YAML" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-attacker-${TS}
  namespace: job7189-apps
  labels: { zta.test/role: unsigned }
spec:
  restartPolicy: Never
  containers:
  - name: c
    image: ghcr.io/job7189/identity-service:malicious-tag
    command: ["sh","-c","sleep 30"]
EOF
echo "[manifest] ${TMP_YAML}" | tee -a "$SECTION_OUT"
run 15 "cat ${TMP_YAML}"
 
# Apply → kỳ vọng: server reject từ admission webhook.
run 20 "kubectl apply -f ${TMP_YAML} 2>&1; \
        kubectl -n job7189-apps delete pod unsigned-attacker-${TS} --ignore-not-found 2>/dev/null"
rm -f "$TMP_YAML"
 
# =============================================================================
# 8. ADAPTIVE TRUST LOOP — PDP score-bucket → CNP block-low-trust-to-vault.
# =============================================================================
section "08" "adaptive-trust-loop"
 
# 8a. PDP controller state.
run 10 "kubectl -n security get deploy zta-pdp -o wide 2>/dev/null"
run 15 "kubectl -n security logs deploy/zta-pdp --tail=20 2>/dev/null"
 
# 8b. CNP block-low-trust-to-vault có tồn tại?
run 10 "kubectl -n job7189-apps get cnp cnp-block-low-trust-to-vault -o yaml 2>/dev/null | head -25"
 
# 8c. Pod state hiện tại: có label score-bucket / annotation trust-score?
run 15 "kubectl -n job7189-apps get pod -l app=identity-service \
  -o jsonpath='{range .items[*]}{.metadata.name}{\"  bucket=\"}{.metadata.labels.zta\\.job7189/score-bucket}{\"  score=\"}{.metadata.annotations.zta\\.job7189/trust-score}{\"\\n\"}{end}'"
 
# 8d. (Tuỳ chọn) mô phỏng degrade — chỉ chạy nếu CONFIRM_PDP_SIM=1.
if [[ "${CONFIRM_PDP_SIM:-0}" == "1" && -n "${ID_POD:-}" ]]; then
  run 10 "kubectl -n job7189-apps annotate pod ${ID_POD} \
    zta.job7189/simulated-cve-critical=true --overwrite"
  run 5  "echo 'sleep 70s chờ PDP reconcile...'"
  run 75 "sleep 70"
  run 15 "kubectl -n job7189-apps get pod ${ID_POD} \
    -o jsonpath='{.metadata.name}  bucket={.metadata.labels.zta\\.job7189/score-bucket}  score={.metadata.annotations.zta\\.job7189/trust-score}'; echo"
  run 20 "kubectl -n job7189-apps exec ${ID_POD} -c app -- \
    curl -sS -m 6 -o /dev/null -w 'HTTP %{http_code}\\n' http://vault.vault:8200/v1/sys/health"
  run 15 "kubectl -n job7189-apps annotate pod ${ID_POD} \
    zta.job7189/simulated-cve-critical- 2>/dev/null"
else
  echo "[skip] PDP simulate (set CONFIRM_PDP_SIM=1 nếu PDP đã live)" | tee -a "$SECTION_OUT"
fi
 
# =============================================================================
# DONE
# =============================================================================
echo
echo "=== DONE — output tại: $OUT/scenario-*-${TS}.txt ==="
ls -la "$OUT"/*"${TS}"*.txt 2>/dev/null
 
