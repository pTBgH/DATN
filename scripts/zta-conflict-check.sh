#!/usr/bin/env bash
#
# zta-conflict-check.sh — KIỂM CHỨNG (READ-ONLY) các điểm mâu thuẫn giữa
# knowledge-base và trạng thái thật của cluster.
#
# An toàn: chỉ chạy 'kubectl get / jsonpath / exec ... status'. KHÔNG apply,
# KHÔNG delete, KHÔNG sửa gì. Chạy xong sẽ tạo 1 file log; gửi lại file đó.
#
# Cách dùng:
#   bash zta-conflict-check.sh            # dùng kubeconfig mặc định
#   KUBECONFIG=/path/config bash zta-conflict-check.sh
#
set +e
export LC_ALL=C

TS="$(date +%Y%m%d_%H%M%S)"
LOG="zta-conflict-check-${TS}.log"

# Ghi đồng thời ra màn hình + file log
exec > >(tee "$LOG") 2>&1

KUBECTL="${KUBECTL:-kubectl}"

hr()   { printf '%s\n' "------------------------------------------------------------"; }
h()    { echo; hr; echo "## $*"; hr; }
kb()   { echo "   [KB nói]      : $*"; }
note() { echo "   [Ghi chú]     : $*"; }
run()  { echo "   \$ $*"; eval "$@" 2>&1 | sed 's/^/     /'; }

echo "=============================================================="
echo " ZTA CONFLICT CHECK — $(date)"
echo " Host: $(hostname 2>/dev/null)   Log: $LOG"
echo "=============================================================="

# --- 0. Tiền đề -------------------------------------------------------------
h "0. Kết nối cluster"
if ! $KUBECTL version --request-timeout=10s >/dev/null 2>&1; then
  echo "   !! Không kết nối được cluster bằng '$KUBECTL'. Kiểm tra KUBECONFIG rồi chạy lại."
fi
run "$KUBECTL get nodes -o wide"

# ===========================================================================
# CONFLICT #1 — mTLS / WireGuard (Cilium mesh-auth)
#   KB 15-encryption (06-03): mesh-auth=false, WireGuard=false  -> TẮT
#   KB 11-cisa (04-25), 16-pip (04-25), 51-nist (06-12): "đã bật"
# ===========================================================================
h "CONFLICT #1 — Cilium mTLS (mesh-auth) & WireGuard"
kb "15-encryption: TẮT (mesh-auth-enabled=false, enable-wireguard=false)"
kb "11-cisa / 16-pip / 51-nist: ĐÃ BẬT  <-- mâu thuẫn"
MESH=$($KUBECTL -n kube-system get cm cilium-config -o jsonpath='{.data.mesh-auth-enabled}' 2>/dev/null)
WG=$($KUBECTL -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}' 2>/dev/null)
ENC=$($KUBECTL -n kube-system get cm cilium-config -o jsonpath='{.data.enable-ipsec}' 2>/dev/null)
echo "   mesh-auth-enabled = '${MESH:-<trống/không có>}'"
echo "   enable-wireguard  = '${WG:-<trống/không có>}'"
echo "   enable-ipsec      = '${ENC:-<trống/không có>}'"
note "Kết quả đúng = giá trị thực tế ở trên. (Tham khảo thêm 'cilium encrypt status' nếu có cilium-cli.)"
run "cilium encrypt status"
echo
case "$MESH" in
  true)  echo "   >>> mTLS ĐANG BẬT  -> file 15-encryption SAI, file 51/11/16 đúng." ;;
  false) echo "   >>> mTLS ĐANG TẮT  -> file 15-encryption đúng, file 51/11/16 SAI (cần sửa)." ;;
  *)     echo "   >>> Không đọc được mesh-auth-enabled (config map khác tên?). Kiểm tra tay." ;;
esac

# ===========================================================================
# CONFLICT #2 — Tetragon: đã deploy chưa? chế độ Post (audit) hay Sigkill?
#   KB 11-cisa (04-25): "dự kiến, chưa deploy"
#   KB 14-tetragon (05-24): đã deploy 3/3, 5 policy
#   KB chapter4 (quyết định 05-20): action = Post (audit-only)
#   KB 47-next-tasks (06-12): "Running v1.7.0, Sigkill verified"
# ===========================================================================
h "CONFLICT #2 — Tetragon: deploy + chế độ enforcement"
kb "11-cisa: CHƯA deploy | 14: đã deploy | chapter4: Post(audit) | 47: Sigkill verified"
run "$KUBECTL get ds -A -o wide | grep -i tetragon"
echo "   -- image (version) --"
run "$KUBECTL get ds -A -l app.kubernetes.io/name=tetragon -o jsonpath='{range .items[*]}{.metadata.namespace}{\"/\"}{.metadata.name}{\" \"}{.spec.template.spec.containers[*].image}{\"\\n\"}{end}'"
echo "   -- TracingPolicy (cluster + namespaced) --"
run "$KUBECTL get tracingpolicy,tracingpolicynamespaced -A"
echo "   -- Các action đang khai báo trong policy (Post = audit, Sigkill/Override = enforce) --"
run "$KUBECTL get tracingpolicynamespaced,tracingpolicy -A -o yaml | grep -E 'name:|action:' | grep -iE 'Post|Sigkill|Override|name:' | grep -ivE 'generation|managedFields'"
echo
ACT=$($KUBECTL get tracingpolicynamespaced,tracingpolicy -A -o yaml 2>/dev/null | grep -ioE 'action:[[:space:]]*(Post|Sigkill|Override)' | sort -u | tr '\n' ' ')
echo "   >>> Các action thực tế trên cluster: ${ACT:-<không thấy policy/action>}"
note "Nếu chỉ thấy 'Post' => đang audit-only (chapter4 đúng). Nếu có 'Sigkill' => đang enforce (47 đúng)."
echo "   -- (Tuỳ chọn) thử exec /bin/sh trong 1 pod để xem có bị kill (exit 137) không --"
echo "      Bỏ comment dòng dưới nếu muốn test chủ động (KHÔNG bắt buộc):"
echo "      # $KUBECTL -n job7189-apps exec deploy/identity-service -c app -- /bin/sh -c 'echo hi'; echo exit=\$?"

# ===========================================================================
# CONFLICT #3 — PDP adaptive loop: đã đóng vòng (cắt quyền) chưa?
#   KB chapter4/25: PDP_CVE_INPUT=false, cnp-block-low-trust-to-vault CHƯA apply
# ===========================================================================
h "CONFLICT #3 — PDP loop (đóng vòng end-to-end?)"
kb "chapter4/25: PDP_CVE_INPUT=false & cnp-block-low-trust-to-vault CHƯA apply (vòng chưa đóng)"
echo "   -- PDP pod --"
run "$KUBECTL -n security get pod -l app=zta-pdp -o wide"
echo "   -- ENV PDP_CVE_INPUT trên Deployment (rỗng = mặc định 'true' trong code) --"
run "$KUBECTL -n security get deploy zta-pdp -o jsonpath='{range .spec.template.spec.containers[*].env[*]}{.name}{\"=\"}{.value}{\"\\n\"}{end}'"
echo "   -- CNP cnp-block-low-trust-to-vault có tồn tại không? (tìm mọi namespace) --"
run "$KUBECTL get cnp -A 2>/dev/null | grep -i block-low-trust-to-vault || echo 'KHÔNG TÌM THẤY (=> chưa apply)'"
echo "   -- Nhãn score-bucket PDP gán cho pod --"
run "$KUBECTL -n job7189-apps get pods -L zta.job7189/score-bucket -L zta.job7189/trust-score 2>/dev/null | head -20"
CVE=$($KUBECTL -n security get deploy zta-pdp -o jsonpath='{range .spec.template.spec.containers[*].env[*]}{.name}={.value} {end}' 2>/dev/null | tr ' ' '\n' | grep PDP_CVE_INPUT)
HASCNP=$($KUBECTL get cnp -A 2>/dev/null | grep -c block-low-trust-to-vault)
echo
echo "   >>> PDP_CVE_INPUT (env set tường minh?): ${CVE:-<KHÔNG set -> code mặc định true>}"
echo "   >>> cnp-block-low-trust-to-vault: $([ "${HASCNP:-0}" -gt 0 ] && echo 'ĐÃ apply (vòng có thể đóng)' || echo 'CHƯA apply (vòng CHƯA đóng -> chapter4 đúng)')"

# ===========================================================================
# CONFLICT #4 — Threat Intel feed (FireHOL) đã đồng bộ CIDR thật chưa?
#   KB chapter4 (06-03): externalCIDRs:[] rỗng (chưa sync)
#   KB 47-next-tasks (06-12): "CronJob active"
# ===========================================================================
h "CONFLICT #4 — Threat Intel / FireHOL feed"
kb "chapter4: externalCIDRs RỖNG (chưa sync) | 47: CronJob active"
echo "   -- CronJob threat-intel --"
run "$KUBECTL get cronjob -A 2>/dev/null | grep -i threat || echo 'không có cronjob threat-intel'"
echo "   -- CiliumCIDRGroup threat-intel-firehol: ĐẾM số CIDR thật --"
run "$KUBECTL get ciliumcidrgroup threat-intel-firehol -o jsonpath='{.spec.externalCIDRs}' 2>/dev/null; echo"
NC=$($KUBECTL get ciliumcidrgroup threat-intel-firehol -o jsonpath='{.spec.externalCIDRs}' 2>/dev/null | grep -o ',' | wc -l)
RAW=$($KUBECTL get ciliumcidrgroup threat-intel-firehol -o jsonpath='{.spec.externalCIDRs}' 2>/dev/null)
echo "   -- CCNP egress-deny --"
run "$KUBECTL get ccnp 2>/dev/null | grep -i threat || echo 'không có ccnp threat-intel'"
echo
if [ -z "$RAW" ] || [ "$RAW" = "[]" ] || [ "$RAW" = "null" ]; then
  echo "   >>> externalCIDRs RỖNG => feed CHƯA sync (chapter4 đúng), 'CronJob active' chỉ là job chạy chứ chưa nạp data."
else
  echo "   >>> externalCIDRs CÓ dữ liệu (~$((NC+1)) entry) => feed ĐÃ sync (47 đúng)."
fi

# ===========================================================================
# CONFLICT #5 — Cosign / Gatekeeper: WARN (audit) hay ENFORCE (deny)?
#   KB chapter4/26: WARN mode + dryrun
# ===========================================================================
h "CONFLICT #5 — Cosign ClusterImagePolicy + Gatekeeper enforcementAction"
kb "chapter4/26: Cosign WARN mode, Gatekeeper constraint dryrun (audit), chưa ENFORCE"
echo "   -- ClusterImagePolicy (Sigstore) --"
run "$KUBECTL get clusterimagepolicy 2>/dev/null || echo 'không có CRD clusterimagepolicy'"
echo "   -- ClusterImagePolicy mode (warn/enforce) --"
run "$KUBECTL get clusterimagepolicy -o jsonpath='{range .items[*]}{.metadata.name}{\" mode=\"}{.spec.mode}{\"\\n\"}{end}' 2>/dev/null"
echo "   -- Gatekeeper constraints: enforcementAction (dryrun/warn=audit, deny=enforce) --"
for ct in $($KUBECTL get constrainttemplate -o jsonpath='{range .items[*]}{.spec.crd.spec.names.kind}{\"\\n\"}{end}' 2>/dev/null); do
  $KUBECTL get "$ct" -o jsonpath="{range .items[*]}     ${ct}/{.metadata.name} enforcementAction={.spec.enforcementAction}{\"\\n\"}{end}" 2>/dev/null
done
echo
note "Nếu mode=warn và enforcementAction=dryrun/warn => audit-only (KB đúng). Nếu enforce/deny => đã siết."

# ===========================================================================
# CONFLICT #6 — Kube-bench (CIS) đã chạy thật chưa?
#   KB 16-pip/11-cisa: "chưa deploy" (chỉ lý thuyết)
# ===========================================================================
h "CONFLICT #6 — Kube-bench (CIS benchmark)"
kb "16-pip/11-cisa: CHƯA deploy (lý thuyết)"
run "$KUBECTL get jobs,pods -A 2>/dev/null | grep -i kube-bench || echo 'KHÔNG có kube-bench (=> KB đúng: chưa chạy)'"

# ===========================================================================
# PHỤ — các thành phần để xác nhận trạng thái (không phải conflict gắt)
# ===========================================================================
h "PHỤ A — SPIRE / SPIFFE (SVID có được cấp không?)"
run "$KUBECTL get clusterspiffeid 2>/dev/null | head; echo '(đếm:)'; $KUBECTL get clusterspiffeid --no-headers 2>/dev/null | wc -l"
run "$KUBECTL -n spire get pod 2>/dev/null"

h "PHỤ B — Vault (dev-mode / Transit auto-unseal)"
run "$KUBECTL -n vault get pod -o wide 2>/dev/null"
note "Nếu thấy 2 pod vault-dev + vault-prod => kiến trúc dual-vault (Transit auto-unseal) như KB migration."

h "PHỤ C — Trivy Operator (VulnerabilityReport)"
run "$KUBECTL get vulnerabilityreport -A --no-headers 2>/dev/null | wc -l"

# ===========================================================================
echo
echo "=============================================================="
echo " HOÀN TẤT. Vui lòng gửi lại file log: $LOG"
echo "=============================================================="
