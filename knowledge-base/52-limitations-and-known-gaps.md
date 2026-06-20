# 52 — Hạn chế & khoảng trống đã biết (Limitations & Known Gaps)

> **Nguồn đối chiếu:** log `zta-conflict-check-20260620_173336` chạy trực tiếp trên
> cluster `job7189` (4 node) ngày **2026-06-20**. Tài liệu này là **trạng thái mới nhất,
> có thẩm quyền cao nhất** về phần "Giới hạn" của luận văn (Chương 4 §4.6 / Kết luận).
> Khi mâu thuẫn với file KB cũ hơn, lấy file này làm chuẩn.

Mục đích: tách bạch rõ **(A) cái đã làm và đã kiểm chứng**, **(B) cái còn hạn chế thật**,
và **(C) cái loại trừ có chủ đích khỏi phạm vi** — để tránh tự mâu thuẫn giữa "lý thuyết
ở Chương 1/2" và "thực nghiệm ở Chương 3/4".

---

## A. Đã triển khai & kiểm chứng trên cluster (KHÔNG còn là hạn chế)

Đây là các điểm mà báo cáo/snapshot cũ từng ghi là "thiết kế", "pending" hoặc "tắt"
nhưng cluster 2026-06-20 xác nhận đã hoạt động:

| Hạng mục | Trạng thái thật (2026-06-20) | Bằng chứng (lệnh) |
|---|---|---|
| **mTLS sidecarless (Cilium mesh-auth)** | ✅ BẬT — `mesh-auth-enabled=true` | `kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.mesh-auth-enabled}'` → `true` |
| **Tetragon runtime enforcement** | ✅ Deployed v1.7.0 (DaemonSet 3/3); `block-suspicious-exec` chạy **`Sigkill` (enforce)** + `Post` (audit) ở 4 ns (data, job7189-apps, security, vault) | `kubectl get ds -A \| grep tetragon`; `kubectl get tracingpolicynamespaced -A -o yaml \| grep action:` |
| **Threat-Intel feed (FireHOL)** | ✅ Đã sync ~2000 CIDR; CronJob `threat-intel-refresh` active; CCNP `cnp-threat-intel-egress-deny` enforcing | `kubectl get ciliumcidrgroup threat-intel-firehol -o jsonpath='{.spec.externalCIDRs}'` |
| **PDP adaptive loop (thành phần)** | ✅ CNP `cnp-block-low-trust-to-vault` đã apply & enforcing (ns vault); `PDP_CVE_INPUT` không set → default `true` (CVE-gating BẬT) | `kubectl get cnp -A \| grep block-low-trust-to-vault` |
| **SPIRE/SPIFFE SVID** | ✅ 10 ClusterSPIFFEID; spire-server + 4 agent Running, SVID được cấp | `kubectl get clusterspiffeid`; `kubectl -n spire get pod` |
| **Vault dual-vault** | ✅ `vault-0` + `vault-dev` + agent-injector (Transit auto-unseal) | `kubectl -n vault get pod` |

> ⚠️ Hệ quả cho luận văn: **không còn được viết "Tetragon mới ở giai đoạn thiết kế"**
> hay "mTLS đang tắt" trong Kết luận — các câu đó mâu thuẫn trực tiếp với cluster.

---

## B. Hạn chế THẬT (vẫn còn, ghi vào §4.6 / Kết luận)

### B1. Cosign / image admission ở chế độ WARN (chưa ENFORCE)
- **Thực tế:** 3 ClusterImagePolicy (`zta-job7189-apps-signed`, `zta-keyless-trust-job7189`,
  `zta-system-passthrough`) đều `mode=warn`.
- **Hệ quả:** image không/không-đúng chữ ký vẫn được admit, chỉ sinh Warning — chưa
  thực sự chặn (deny) ở admission.
- **Lý do chấp nhận (PoC):** 5 image upstream (Hashicorp/Alpine/Busybox…) chưa ký được
  bằng `static` authority; bật ENFORCE sẽ chặn nhầm workload hợp lệ.
- **Hướng xử lý:** ký lại các image upstream → chuyển `mode=enforce`.
- **Hai tầng admission tách biệt (xác nhận 2026-06-20):**
  1. **Sigstore policy-controller** (kiểm *chữ ký* Cosign): 3 ClusterImagePolicy `mode=warn`.
  2. **Gatekeeper / OPA** (kiểm *chính sách* khác): **ĐÃ deploy**, 6 ConstraintTemplate +
     constraint — 3 về image (`k8sblocklatesttag`, `k8simagedigestrequired`,
     `k8ssignedimageannotation`) + 3 về pod-security ZTA (`ztablockhostmounts`,
     `ztarequiredlabels`, `ztarestrictprivileged`).
- **Còn cần chốt:** `enforcementAction` của từng constraint (audit/warn = không chặn,
  `deny`/trống = chặn thật). Kiểm bằng:
  ```
  for k in k8sblocklatesttag k8simagedigestrequired k8ssignedimageannotation \
           ztablockhostmounts ztarequiredlabels ztarestrictprivileged; do
    echo "== $k =="
    kubectl get $k -o jsonpath='{range .items[*]}{.metadata.name}{" enforcementAction="}{.spec.enforcementAction}{"\n"}{end}'
  done
  ```

### B2. Vòng adaptive PDP chưa có minh chứng end-to-end "đang chạy thật"
- **Thực tế:** đủ mảnh để đóng vòng (PDP chấm điểm → gán `score-bucket` → CNP chặn
  egress tới Vault), NHƯNG hiện **mọi pod `job7189-apps` đều `score-bucket=high`** và
  chỉ còn **5 `VulnerabilityReport`** (trước ~45). Không có pod `low` nào để CNP kích hoạt.
- **Hệ quả:** chưa có log "pod điểm thấp bị chặn truy cập Vault" ở trạng thái hiện tại.
- **Hướng xử lý (để demo):** chủ động đưa vào 1 image có CVE Critical/High (vd `library/redis`
  bản cũ) → quan sát PDP hạ score → pod bị CNP `cnp-block-low-trust-to-vault` chặn egress.

### B3. Kube-bench (CIS Benchmark) chưa chạy
- **Thực tế:** không có Job/Pod kube-bench nào trên cluster.
- **Hệ quả:** trụ cột *Devices / node health* của CISA ZTMM mới ở mức Initial.
- **Hướng xử lý:** chạy `kube-bench` job theo CIS, xuất report; đưa vào §4.6.

### B4. CAEP / thu hồi phiên giữa chừng chưa triển khai
- **Thực tế:** JWT TTL ngắn (Keycloak) nhưng **không có cơ chế thu hồi phiên đang hoạt
  động** (Continuous Access Evaluation). Đây là cấu hình Keycloak backchannel, không
  phải đối tượng Kubernetes nên script `zta-conflict-check` không đo được.
- **Hệ quả:** khoảng trống rõ nhất giữa lý thuyết (giới thiệu ở §1.3.1) và thực nghiệm.
- **CAEP là gì:** Continuous Access Evaluation Protocol (OpenID Shared Signals Framework).
  Thay vì tin JWT tới khi hết TTL, IdP (Keycloak) phát *security event* (session-revoked,
  credential-change, token-revoked) tới relying party (Kong/OPA) để **cắt quyền giữa
  phiên** gần thời gian thực. Hệ thống hiện chỉ có JWT TTL ngắn + Kong validate chữ
  ký/expiry cục bộ → token bị lộ vẫn dùng được tới khi hết hạn.
- **Cách kiểm (chứng minh GAP — không phải đối tượng K8s):**
  1. Login → lấy JWT (còn hạn).
  2. Keycloak admin: logout session hoặc disable user đó.
  3. Gọi ngay API bảo vệ bằng JWT cũ (vẫn còn hạn).
  4. Nếu request **vẫn đi qua** tới khi token hết hạn ⇒ CAEP/thu hồi CHƯA có (đúng là gap).
     Nếu bị chặn ngay ⇒ đã có thu hồi.
  - Kiểm cấu hình: Keycloak → Clients → (client của Kong) → field **Backchannel Logout URL**
    (trống = không có); và Kong dùng plugin `jwt` (chỉ validate cục bộ, không thu hồi) hay
    `oauth2-introspection` (gọi IdP mỗi request).
- **Hướng xử lý:** bật Keycloak backchannel logout / token introspection endpoint
  (`/protocol/openid-connect/token/introspect`) → Kong/OPA introspect mỗi request hoặc
  subscribe Shared Signals stream để invalidate token đang sống.

### B5. Mã hóa East-West: Cilium WireGuard tắt (mTLS đã bù phần authn/encrypt L7)
- **Thực tế:** Cilium `enable-wireguard=false`; lớp mã hóa L3 node-to-node do
  **Tailscale WireGuard** (mesh CGNAT 100.64.0.0/10) đảm nhận. mTLS mesh-auth (L7) đã bật.
- **Hệ quả:** không có double-encryption ở tầng Cilium; phụ thuộc Tailscale cho L3.
  Lưu ý: kịch bản KB4 (giả mạo IP) vẫn đúng vì **Cilium Identity hoạt động độc lập với
  mTLS/WireGuard** (định danh dựa trên label, không dựa IP).
- **Hướng xử lý (tùy chọn):** bật `enable-wireguard=true` nếu cần mã hóa L3 trong-cluster
  độc lập với Tailscale.

### B6. Vault Transit auto-unseal dùng dev-mode
- **Thực tế:** kiến trúc dual-vault (`vault-dev` + `vault-0`) với Transit auto-unseal,
  nhưng vault unseal-key/transit ở dev-mode.
- **Hệ quả:** không production-ready (key không HSM/KMS), nhưng acceptable với PoC.
- **Hướng xử lý:** chuyển Transit sang vault HA + seal bằng KMS/HSM thật.

### B7. ArgoCD / GitOps chưa triển khai
- **Thực tế:** deploy hiện thủ công qua Helmfile/script; chưa có ArgoCD trên cluster.
- **Hệ quả:** chưa có reconcile liên tục/declarative drift-detection.
- **Hướng xử lý:** cài ArgoCD, trỏ vào repo infra.

### B8. Quan sát bất thường vận hành (cần theo dõi)
- **SPIRE pod restart cao:** `spiffe-csi-driver` (100+), `spire-agent` (36–71 restart) —
  bất ổn nhẹ, nên điều tra (OOM? node pressure?) trước khi defend.
- **OPA decision log:** chưa bật `decision_logs` (không có sidecar collector) — demo
  `opa eval` offline ở Phụ lục B thay vì log runtime.

---

## C. Loại trừ có chủ đích khỏi phạm vi (KHÔNG phải "thiếu sót")

| Hạng mục | Lý do loại trừ | Ghi chú cho luận văn |
|---|---|---|
| **Device Posture (MDM/EDR)** | Phạm vi đề án = bảo mật **workload** trong cluster, KHÔNG quản **client device** của end-user | Nguyên lý 5 NIST SP 800-207; nói rõ đây là loại trừ chủ đích, không phải bỏ sót |
| **DLP / phân loại dữ liệu tự động** | Ngoài trọng tâm (đề án tập trung secret-management động qua Vault) | Trụ cột Data đạt Advanced, gap classification ghi nhận |
| **UEBA / SOAR auto-response** | Ngoài phạm vi PoC (cần data lake + ML pipeline) | Visibility/Automation ghi nhận gap |

---

## D. Bản đồ "câu cần sửa" trong luận văn

| Vị trí (báo cáo cũ) | Câu SAI cần bỏ/sửa | Sửa thành |
|---|---|---|
| Kết luận | "Tetragon TracingPolicy mới ở giai đoạn thiết kế, chưa triển khai" | Tetragon v1.7.0 đã deploy & enforce Sigkill (4 ns) + Post audit |
| Hạn chế C4 / §4.6 | "mTLS đang tắt" | mTLS (mesh-auth) đã BẬT; chỉ Cilium WireGuard tắt (Tailscale lo L3) |
| Hạn chế C4 / §4.6 | "threat-intel feed chưa đồng bộ" | Feed đã sync ~2000 CIDR, CCNP enforcing |
| PDP / §4.6 | "PDP chỉ tính điểm, chưa cắt quyền (CNP pending)" | CNP block-low-trust-to-vault đã apply & enforcing; còn thiếu pod low-trust để demo end-to-end |
| Hạn chế C4 | (thiếu) lý do loại trừ Device Posture | Bổ sung: loại trừ có chủ đích — phạm vi là workload, không phải client device |

---

## Xem thêm
- `chapter4_evidence_guide.md` §4.6 (bảng giới hạn đã cập nhật cột "hiện tại")
- `11-cisa-ztmm-assessment.md` (đánh giá ZTMM đã cập nhật Tetragon/WireGuard/Trivy)
- `15-encryption-mtls-spiffe.md` (mTLS mesh-auth=true)
- `25-pdp-controller.md` (trạng thái vòng adaptive)
- `47-next-tasks.md` (status tracker)
