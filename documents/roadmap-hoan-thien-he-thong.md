# Lộ trình hoàn thiện hệ thống ZTA (job7189)

> Tài liệu này liệt kê các hạng mục còn thiếu giữa **thiết kế** và **trạng thái
> triển khai thật** trên cụm, sắp xếp **từ dễ đến khó**. Mỗi hạng mục gồm:
> mục tiêu, hiện trạng (kèm file minh chứng), cách triển khai, cách kiểm chứng,
> **cách revert**, mức rủi ro và script tự động hoá (nếu có).
>
> Các script nằm ở `infras/fixes/`. Nguyên tắc chung của mọi script:
> **sao lưu trạng thái live trước khi thay đổi** (vào `infras/fixes/backups/<fix>/<timestamp>/`)
> và luôn có lệnh con `revert`. Máy build tài liệu **không** có kubectl/cluster
> nên script được viết để **bạn chạy trên máy có quyền vào cụm**.

## Bảng tổng quan

| # | Hạng mục | Loại | Mức | Rủi ro | Tự động |
|---|----------|------|-----|--------|---------|
| F01 | Kích hoạt threat-intel feed | Cấu hình | Dễ | Thấp | `01-threat-intel-feed.sh` |
| F02 | Đưa `tier` vào trust score | Code | Dễ | Thấp–TB | `02-pdp-tier-score.sh` |
| F03 | Gatekeeper `dryrun → deny` | Cấu hình | TB | TB | `03-gatekeeper-enforce.sh` |
| F04 | `readOnlyRootFilesystem` | Cấu hình | TB | TB | `04-readonly-rootfs.sh` |
| F05 | Cosign `warn → enforce` | Cấu hình | Khó vừa | Cao | Hướng dẫn tay |
| F06 | Trục Exploitability (KEV/EPSS) | Code | Khó vừa | Thấp | Hướng dẫn + code |
| F07 | Đóng vòng CVE → cô lập (e2e) | Code+demo | Khó vừa | TB | Hướng dẫn + code |
| F08 | Ma trận phản hồi đa-CNP theo tier | Code/YAML | Khó vừa | TB | Hướng dẫn + YAML |
| F09 | GitOps tự phục hồi (ArgoCD) | Hạ tầng | Khó | Cao | Hướng dẫn tay |
| F10 | Impossible-Travel / CAEP thu hồi phiên | Hạ tầng+code | Khó | Cao | Hướng dẫn tay |

> Cách chạy chung: `./NN-name.sh status` (chỉ xem, không đổi) → `./NN-name.sh apply`
> → nếu cần `./NN-name.sh revert`. Đặt `ASSUME_YES=1` để bỏ bước hỏi xác nhận;
> `KUBECTL=...` để đổi binary.

---

## MỨC 1 — DỄ

### F01. Kích hoạt threat-intel feed

**Mục tiêu.** Cho feed FireHOL (IP) + URLhaus (FQDN) chạy thật để CiliumCIDRGroup
và sinkhole có dữ liệu, biến việc chặn egress từ "default-deny" thành "chặn theo
danh sách đen tình báo".

**Hiện trạng.** CronJob `threat-intel-refresh` (ns `security-cdm`) đang
`spec.suspend: true` → feed chưa từng chạy → `CiliumCIDRGroup.externalCIDRs: []`
và ConfigMap `threat-intel-blocklist` rỗng.
- `infras/k8s-yaml/threat-intel/02-cronjob.yaml` (`suspend: true`)
- `infras/k8s-yaml/threat-intel/05-cidrgroup.yaml` (`externalCIDRs: []`)

**Cách triển khai.**
```bash
cd infras/fixes
./01-threat-intel-feed.sh status      # xem suspend + kích thước configmap
./01-threat-intel-feed.sh apply       # un-suspend + chạy 1 job thủ công ngay
```
Script: un-suspend CronJob → `kubectl create job --from=cronjob/...` → chờ tối đa
10 phút → in lại kích thước ConfigMap đầu ra.

**Kiểm chứng.**
```bash
kubectl -n security-cdm get cm threat-intel-blocklist -o jsonpath='{.data}' | wc -c   # > vài KB
kubectl get ciliumcidrgroup -o yaml | grep -c '/'                                      # > 0 CIDR
```

**Revert.** `./01-threat-intel-feed.sh revert` → khôi phục spec CronJob ban đầu
(suspend lại). Xoá job thủ công: `kubectl -n security-cdm delete jobs -l app=threat-intel-refresh`.

**Rủi ro: THẤP** — feed chỉ thêm CIDR vào danh sách *chặn*, không mở thêm gì.

---

### F02. Đưa nhãn `tier` vào trust score của PDP

**Mục tiêu.** PDP đang đọc `zta.job7189/tier` như nhãn bắt buộc nhưng **không dùng**
trong `compute_score()`. Cho `tier` ảnh hưởng điểm: workload tầng tới hạn (T0/T1)
khi có vấn đề tư thế sẽ bị trừ điểm mạnh hơn tầng thấp (T3).

**Hiện trạng.** Công thức cũ chỉ 2 đầu vào (label + CVE):
`score = 100 - 30*(missing/6) - 50*has_critical - 20*has_high`.
- `infras/pdp/pdp_controller.py` (nguồn) và `infras/k8s-yaml/pdp/20-configmap.yaml`
  (bản đang chạy, mount read-only vào Deployment `zta-pdp` ns `security`).

**Thiết kế mới (đã viết sẵn trong repo).** Thêm hệ số `tier_penalty`:
```python
tier_factor = {"T0":1.0, "T1":0.8, "T2":0.5, "T3":0.2}
posture_hit = bool(missing) or has_critical or has_high
tier_penalty = round(WEIGHT_TIER * tier_factor[tier]) if posture_hit else 0   # WEIGHT_TIER=15
score = max(0, 100 - label_penalty - cve_penalty - tier_penalty)
```
**Tính chất an toàn then chốt:** `tier_penalty` chỉ áp dụng khi pod **đã có** vấn
đề (thiếu nhãn hoặc dính CVE). Pod sạch + đủ nhãn vẫn = 100 bất kể tier → **không
pod khoẻ nào đổi bucket khi rollout**. Tier chỉ "cắn" đúng lúc một pod T0/T1 dính
CVE/drift (lúc đó nó tụt nhanh hơn T3). Kiểm chứng đơn vị:
```
clean T0 = 100 (high)   |  T0 + critical CVE = 35 (low)
clean T3 = 100 (high)   |  T3 + critical CVE = 47 (low)   ← T0 tụt sâu hơn T3
```

**Cách triển khai.**
```bash
cd infras/fixes
./02-pdp-tier-score.sh status     # so điểm trước; kiểm tra cm đã có tier logic chưa
./02-pdp-tier-score.sh apply      # apply configmap mới + rollout restart zta-pdp
```

**Kiểm chứng.** Sau ~60s (1 chu kỳ reconcile):
```bash
kubectl -n security get cm zta-pdp-script -o jsonpath='{.data.pdp_controller\.py}' | grep WEIGHT_TIER
kubectl -n security logs deploy/zta-pdp | grep reconcile-complete | tail -1
./02-pdp-tier-score.sh status     # mọi pod sạch vẫn high
```

**Revert.** `./02-pdp-tier-score.sh revert` → apply lại ConfigMap đã sao lưu +
rollout restart. (Backup nằm trong `backups/02-pdp-tier-score/<timestamp>/`.)

**Rủi ro: THẤP–TB** — hành vi đổi chỉ khi pod đã có vấn đề; pod sạch không đổi.

---

## MỨC 2 — TRUNG BÌNH

### F03. Gatekeeper `dryrun → deny`

**Mục tiêu.** Hiện chỉ `block-host-mounts` = `deny`. 5 ràng buộc còn lại đang
`dryrun` (chỉ ghi log). Nâng dần các ràng buộc an toàn lên `deny`.

**Hiện trạng.** `infras/k8s-yaml/opa-gatekeeper/`:
- `deny`: `block-host-mounts`
- `dryrun`: `zta-restrict-privileged`, `image-digest-required`, `block-latest-tag`,
  `signed-image-annotation-required`, `zta-labels-required`.

**Thứ tự nâng đề xuất (ít → nhiều rủi ro).**
1. `zta-restrict-privileged` — cụm không có pod privileged hợp lệ → nâng trước, an toàn nhất.
2. `image-digest-required` — chỉ nâng **sau khi** mọi image đã pin theo digest.
3. `block-latest-tag` — chỉ nâng sau khi không còn tag `:latest`.
4. `signed-image-annotation-required` + `zta-labels-required` — để `dryrun` đến khi
   bật Cosign enforce (F05).

**Cách triển khai (có chốt an toàn).**
```bash
cd infras/fixes
./03-gatekeeper-enforce.sh status                         # liệt kê action + totalViolations
./03-gatekeeper-enforce.sh apply zta-restrict-privileged  # chỉ nâng khi violations = 0
```
Script **từ chối** nâng nếu ràng buộc còn vi phạm audit (`totalViolations > 0`),
trừ khi đặt `FORCE=1` — tránh việc bật `deny` rồi chặn luôn workload đang vi phạm.

**Kiểm chứng.**
```bash
kubectl get ZTARestrictPrivileged zta-restrict-privileged -o jsonpath='{.spec.enforcementAction}'  # deny
# thử tạo 1 pod privileged → bị admission từ chối
```

**Revert.** `./03-gatekeeper-enforce.sh revert <tên>` → quay lại `dryrun` tức thì,
không ảnh hưởng workload đang chạy.

**Rủi ro: TB** — `deny` từ chối admission của pod mới/đổi không tuân thủ. Nâng từng
cái, kiểm `totalViolations=0` trước.

---

### F04. Bật `readOnlyRootFilesystem`

**Mục tiêu.** Một số workload (vd `hiring-service` trong `job7189-apps`) chạy với
root filesystem ghi được → kẻ tấn công có thể thả tool/duy trì trên đĩa (KB4 quan
sát được ghi đĩa). Đặt `readOnlyRootFilesystem: true`.

**Hiện trạng.** Manifest app không nằm trong repo hạ tầng này → patch trực tiếp
Deployment trên cụm. Đa số app cần 1 thư mục ghi tạm (`/tmp`).

**Cách triển khai (patch từng Deployment, có auto-rollback).**
```bash
cd infras/fixes
./04-readonly-rootfs.sh status job7189-apps                  # liệt kê deploy + trạng thái RO
./04-readonly-rootfs.sh apply  job7189-apps hiring-service   # patch + mount emptyDir /tmp
# cần thêm thư mục ghi khác:
WRITABLE_PATHS="/tmp /var/run" ./04-readonly-rootfs.sh apply job7189-apps hiring-service
```
Script set `readOnlyRootFilesystem: true` + mount `emptyDir` cho `WRITABLE_PATHS`,
rồi chờ rollout. **Nếu pod không Ready trong thời gian chờ → tự khôi phục** spec cũ
(app ghi ngoài /tmp sẽ CrashLoop, auto-rollback bảo vệ bạn).

**Kiểm chứng.**
```bash
kubectl -n job7189-apps get deploy hiring-service \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'   # true
kubectl -n job7189-apps exec deploy/hiring-service -- sh -c 'touch /root/x' 2>&1   # Read-only file system
```

**Revert.** `./04-readonly-rootfs.sh revert job7189-apps hiring-service` → apply lại
spec đã sao lưu.

**Rủi ro: TB** — app ghi ngoài đường dẫn cho phép sẽ crash; auto-rollback + chỉnh
`WRITABLE_PATHS` xử lý được. Làm từng service một.

---

## MỨC 3 — KHÓ VỪA (cần code/审 cẩn thận, làm tay)

### F05. Cosign `warn → enforce`

**Mục tiêu.** Bắt buộc image phải có chữ ký hợp lệ mới được admit (chống image giả mạo).

**Hiện trạng.** `infras/k8s-yaml/policy-controller/cluster-image-policies.yaml`:
toàn bộ `mode: warn` (admit + cảnh báo). `chốt cứng` thật hiện chỉ là digest-pin.

**Tiền đề bắt buộc (không bỏ qua).**
1. Mọi image trong registry đã được ký bằng cosign (kể cả image hệ thống: kong,
   keycloak, vault, mysql... hoặc đưa chúng vào danh sách loại trừ theo namespace/registry).
2. Trên `warn`, kiểm log admission **0 cảnh báo unsigned** trong vài ngày.

**Cách triển khai.**
```bash
# ký toàn bộ image (ví dụ)
cosign sign --key <key> <registry>/<image>@<digest>
# backup trước
kubectl get clusterimagepolicy -o yaml > /tmp/cip-backup.yaml
# đổi mode warn -> enforce trong cluster-image-policies.yaml rồi apply
sed -i 's/mode: warn/mode: enforce/g' infras/k8s-yaml/policy-controller/cluster-image-policies.yaml
kubectl apply -f infras/k8s-yaml/policy-controller/cluster-image-policies.yaml
```

**Kiểm chứng.** Triển khai 1 image **chưa ký** → bị từ chối admission; image đã ký → pass.

**Revert.** `kubectl apply -f /tmp/cip-backup.yaml` (hoặc `sed` ngược enforce→warn rồi apply).

**Rủi ro: CAO** — nếu còn image chưa ký, enforce sẽ chặn deploy/khởi động lại pod.
Bắt buộc qua bước `warn` sạch trước. (Có thể viết script tương tự F03 sau khi xác nhận
tiền đề; hiện để tay vì phụ thuộc trạng thái ký của registry.)

---

### F06. Thêm trục Exploitability (CISA KEV / EPSS) vào PDP

**Mục tiêu.** Hiện điểm CVE chỉ đếm `criticalCount/highCount`. Một CVE "critical"
nhưng không có exploit công khai khác hẳn một CVE đang bị khai thác thực tế. Thêm
đầu vào **KEV (CISA Known Exploited Vulnerabilities)** và/hoặc **EPSS** để ưu tiên
"CVE đang bị khai thác".

**Hiện trạng.** `read_image_cve()` trong `pdp_controller.py` chỉ lấy
`summary.criticalCount/highCount` từ VulnerabilityReport của Trivy. Trivy có ID CVE
ở `.report.vulnerabilities[].vulnerabilityID` nhưng PDP chưa đọc.

**Cách triển khai (phác thảo code).**
1. CronJob tải KEV (`https://www.cisa.gov/.../known_exploited_vulnerabilities.json`)
   vào ConfigMap `kev-catalog` (giống cơ chế threat-intel F01).
2. Trong PDP, đọc danh sách `vulnerabilityID` từ VR, đối chiếu KEV:
   ```python
   has_kev = any(v in KEV_SET for v in vuln_ids)
   WEIGHT_KEV = int(os.environ.get("PDP_WEIGHT_KEV", "40"))
   score -= WEIGHT_KEV * (1 if has_kev else 0)
   ```
3. (Tuỳ chọn) EPSS: trừ điểm theo ngưỡng `epss >= 0.5`.

**Kiểm chứng.** Pod có CVE nằm trong KEV phải tụt điểm sâu hơn pod có CVE thường cùng mức.

**Revert.** Đặt `PDP_WEIGHT_KEV=0` (env trên Deployment) hoặc apply lại configmap cũ
+ rollout restart (như F02).

**Rủi ro: THẤP** — chỉ làm điểm "nhạy" hơn; pod sạch vẫn 100.

---

### F07. Đóng vòng CVE → cô lập (chứng minh end-to-end)

**Mục tiêu.** Vòng `Trivy → PDP → score-bucket → CNP` **đã có code** (reconcile_loop
patch `score-bucket`, CNP `cnp-block-low-trust-to-vault` đọc bucket). Nhưng vì mọi
image hiện sạch → mọi pod đều `high` → **chưa từng quan sát được** một pod tụt
`low` rồi bị cô lập. Cần một minh chứng e2e có kiểm soát.

**Cách triển khai (demo an toàn, KHÔNG đụng app thật).**
1. Tạo namespace demo `zta-demo` (thêm vào `ZTA_NAMESPACES` tạm thời) HOẶC dùng 1
   pod throwaway trong `job7189-apps`.
2. Deploy 1 image cố ý dính CVE critical (vd image cũ đã biết) để Trivy chấm điểm thấp,
   **hoặc** gán nhãn thiếu để hạ điểm mà không cần image dễ tổn thương.
3. Quan sát PDP patch `score-bucket=low` → CNP cô lập pod khỏi Vault/đường E-W.

**Kiểm chứng.**
```bash
kubectl -n zta-demo get pod <p> -o jsonpath='{.metadata.labels.zta\.job7189/score-bucket}'  # low
kubectl -n security logs deploy/zta-pdp | grep '"bucket":"low"'
# từ pod low: thử gọi Vault → bị drop (Hubble)
hubble observe --to-namespace vault --verdict DROPPED | grep <p>
```

**Revert.** Xoá pod/namespace demo; bỏ `zta-demo` khỏi `ZTA_NAMESPACES`.

**Rủi ro: TB** — đừng deploy image dễ tổn thương trong namespace prod; dùng namespace
demo cô lập. Đây là **demo minh chứng**, không phải thay đổi cấu hình prod.

---

### F08. Ma trận phản hồi đa-CNP theo tier

**Mục tiêu.** Hiện chỉ có **1** CNP phản ứng theo bucket (`cnp-block-low-trust-to-vault`).
Thiết kế đề ra ma trận T1/T3: khi điểm tụt thì **siết Đông–Tây** nhưng **giữ Bắc–Nam**
theo tier (vd vẫn cho frontend phục vụ user, chỉ cắt quyền gọi nội bộ nhạy cảm).

**Cách triển khai (YAML, làm tay).**
1. Thêm các CNP `endpointSelector` theo `score-bucket` + `tier`, ví dụ:
   - `cnp-medium-trust-restrict-ew`: bucket=medium → chỉ cho egress tới dịch vụ cùng tier.
   - `cnp-low-trust-quarantine`: bucket=low → chỉ giữ kết nối tới logging/DNS, cắt phần còn lại.
2. Áp `dryrun`/quan sát Hubble trước khi để default-deny thật cắt.

**Kiểm chứng.** Pod bucket=medium/low bị siết đúng theo ma trận (Hubble verdict),
pod high không đổi.

**Revert.** `kubectl delete cnp <tên>` từng policy (đã backup YAML trong git).

**Rủi ro: TB** — sai selector có thể cắt nhầm; thử ở namespace demo + Hubble trước.

---

## MỨC 4 — KHÓ (hạ tầng mới)

### F09. GitOps tự phục hồi (ArgoCD)

**Mục tiêu.** Khi ai đó sửa/xoá chính sách trên cụm (drift), tự động khôi phục từ
Git (Policy-as-Code). Hiện làm **thủ công** (apply lại từ repo).

**Cách triển khai (phác thảo).**
1. Cài ArgoCD: `kubectl create ns argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
   (ghim phiên bản cụ thể, không dùng `stable` cho prod).
2. Tạo `Application` trỏ vào `infras/k8s-yaml/` với `syncPolicy.automated.selfHeal: true`.
3. Bật prune cẩn thận (bắt đầu `selfHeal: true, prune: false`).

**Kiểm chứng.** Xoá thủ công 1 CNP → ArgoCD tự apply lại trong vài phút.

**Revert.** `kubectl delete -n argocd -f <install>.yaml` + xoá ns `argocd`. App khác
không phụ thuộc ArgoCD nên gỡ an toàn.

**Rủi ro: CAO** — `selfHeal`/`prune` cấu hình sai có thể ghi đè/xoá ngoài ý muốn.
Bắt đầu `prune: false`, phạm vi hẹp (chỉ thư mục chính sách).

---

### F10. Impossible-Travel / OPA context-aware / thu hồi phiên (CAEP)

**Mục tiêu.** Phát hiện đăng nhập bất thường (impossible travel), ra quyết định
theo ngữ cảnh ở OPA, và **thu hồi phiên** đang hoạt động (CAEP) — phần này hiện
hoàn toàn là **thiết kế**, chưa có code.

**Cách triển khai (phác thảo, nhiều giai đoạn).**
1. Thu thập sự kiện đăng nhập (Keycloak event / Kong log) vào một store.
2. Tính khoảng cách địa lý/thời gian giữa 2 lần đăng nhập liên tiếp → cờ impossible-travel.
3. Viết policy OPA/`AuthorizationPolicy` dùng cờ này để từ chối/nâng cấp xác thực.
4. Thu hồi phiên: tích hợp CAEP/back-channel logout của Keycloak để hủy token đang hoạt động.

**Kiểm chứng.** Mô phỏng 2 đăng nhập cách nhau bất khả thi → phiên bị nâng cấp xác
thực/hủy.

**Revert.** Gỡ policy OPA + tắt pipeline sự kiện; không đụng đường xác thực hiện có
nếu triển khai song song (shadow) trước.

**Rủi ro: CAO** — đụng trực tiếp luồng xác thực người dùng. Triển khai **shadow/audit**
trước khi cho ra quyết định thật, để tránh khoá nhầm người dùng hợp lệ.

---

## Ghi chú trung thực (để dùng khi bảo vệ)

- **F01–F04** có thể làm ngay, an toàn, revert dễ → nên đưa vào báo cáo như "đã
  triển khai/đã kiểm chứng".
- **F05–F08** là code/cấu hình khả thi nhưng cần tiền đề (ký image, namespace demo,
  audit sạch) → trình bày ở dạng "cơ chế đã thiết kế + minh chứng từng phần".
- **F09–F10** là hạ tầng/luồng mới → giữ ở mức **[Thiết kế]**: nêu rõ phạm vi PoC
  dừng ở thiết kế lý thuyết để không gián đoạn dịch vụ, tự động hoá hoàn toàn mở
  rộng trong tương lai.
