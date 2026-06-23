# RUNBOOK — thứ tự chạy & cách kiểm tra

Chạy trên máy **có quyền vào cụm**. Làm **tuần tự**, mỗi bước kiểm xong mới sang bước sau.

## Bước 0 — Tiền kiểm (preflight)
```bash
cd infras/fixes
kubectl config current-context          # đúng cụm chưa?
kubectl get nodes                        # cụm sống chưa?
git rev-parse --abbrev-ref HEAD          # đang ở nhánh có code mới
```
Mỗi script đều tự kiểm kubectl + cluster trước khi đổi; nếu không vào được cụm nó dừng.

---

## Bước 1 — F01: threat-intel feed  (DỄ, làm trước)
```bash
./01-threat-intel-feed.sh status         # trước: suspend=true, configmap ~0 byte
./01-threat-intel-feed.sh apply          # un-suspend + chạy job, chờ tối đa 10'
```
**Check (đạt khi):**
```bash
kubectl -n security-cdm get cm threat-intel-blocklist -o jsonpath='{.data}' | wc -c   # > vài nghìn
kubectl get ciliumcidrgroup -o yaml | grep -c '\.'                                     # > 0
kubectl -n security-cdm get jobs -l app=threat-intel-refresh                           # COMPLETIONS 1/1
```
**Hỏng thì:** `./01-threat-intel-feed.sh revert` (suspend lại).

---

## Bước 2 — F02: tier vào trust score  (DỄ)
```bash
./02-pdp-tier-score.sh status            # ghi lại điểm/bucket TRƯỚC
./02-pdp-tier-score.sh apply             # apply cm + rollout restart zta-pdp
sleep 75                                  # chờ 1 chu kỳ reconcile (~60s)
./02-pdp-tier-score.sh status            # SAU: mọi pod sạch vẫn 'high'
```
**Check (đạt khi):**
```bash
kubectl -n security get cm zta-pdp-script -o jsonpath='{.data.pdp_controller\.py}' | grep WEIGHT_TIER   # có
kubectl -n security rollout status deploy/zta-pdp                                                        # ok
kubectl -n security logs deploy/zta-pdp | grep reconcile-complete | tail -1                              # mới chạy
# QUAN TRỌNG: số pod 'high' SAU == TRƯỚC (không pod khoẻ nào tụt bucket)
```
**Hỏng thì:** `./02-pdp-tier-score.sh revert` (apply lại cm cũ + restart).

---

## Bước 3 — F03: Gatekeeper dryrun→deny  (TB — nâng từng cái)
```bash
./03-gatekeeper-enforce.sh status                          # xem ACTION + VIOLATIONS
# chỉ nâng cái có VIOLATIONS = 0, theo thứ tự an toàn:
./03-gatekeeper-enforce.sh apply zta-restrict-privileged   # 1) an toàn nhất
# sau khi mọi image đã pin digest:
./03-gatekeeper-enforce.sh apply image-digest-required     # 2)
# sau khi hết tag :latest:
./03-gatekeeper-enforce.sh apply block-latest-tag          # 3)
```
**Check (đạt khi):**
```bash
kubectl get ZTARestrictPrivileged zta-restrict-privileged -o jsonpath='{.spec.enforcementAction}'   # deny
# thử admission (phải bị TỪ CHỐI):
kubectl -n job7189-apps run t --image=busybox --overrides='{"spec":{"containers":[{"name":"t","image":"busybox","securityContext":{"privileged":true}}]}}' --restart=Never -it --rm -- true
```
**Hỏng / chặn nhầm:** `./03-gatekeeper-enforce.sh revert <tên>` (về dryrun ngay).
Lưu ý: script **từ chối** nâng nếu còn vi phạm (dùng `FORCE=1` để ép, không khuyến nghị).

---

## Bước 4 — F04: readOnlyRootFilesystem  (TB — từng service)
```bash
./04-readonly-rootfs.sh status job7189-apps                 # liệt kê deploy + RO hiện tại
./04-readonly-rootfs.sh apply  job7189-apps hiring-service  # patch + emptyDir /tmp, tự rollback nếu crash
# nếu app cần thư mục ghi khác:
WRITABLE_PATHS="/tmp /var/run /var/cache" ./04-readonly-rootfs.sh apply job7189-apps hiring-service
```
**Check (đạt khi):**
```bash
kubectl -n job7189-apps get deploy hiring-service -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'   # true
kubectl -n job7189-apps rollout status deploy/hiring-service                                                                                 # ok
kubectl -n job7189-apps exec deploy/hiring-service -- sh -c 'touch /root/x' 2>&1                                                             # "Read-only file system"
kubectl -n job7189-apps exec deploy/hiring-service -- sh -c 'touch /tmp/x && echo tmp-ok'                                                    # tmp-ok
```
**Hỏng thì:** script **tự rollback** nếu pod không Ready. Hoặc tay:
`./04-readonly-rootfs.sh revert job7189-apps hiring-service`.

---

# PHẦN 2 — F05→F10 (KHÓ, làm sau khi F01–F04 xanh)

> Tất cả script PHẦN 2 phải đặt trong `infras/fixes/` (chúng `source lib-common.sh`
> + dùng đường dẫn tương đối `../pdp`, `../k8s-yaml`, `manifests/`). KHÔNG chạy từ
> `scripts/`. File code `pdp_controller.py` thay vào `infras/pdp/`.
> Mỗi script vẫn theo khuôn `status → apply → revert` + tự backup.

## Bước 5 — F05: Cosign warn → enforce  (RỦI RO CAO)
```bash
./05-cosign-enforce.sh status                 # xem mode từng CIP + đếm cảnh báo unsigned
# CHỈ enforce khi cửa sổ warn = 0 cảnh báo VÀ mọi image đã ký:
./05-cosign-enforce.sh apply                  # mặc định CIP=zta-job7189-apps-signed
```
**Check:** deploy 1 image CHƯA ký vào `job7189-apps` → bị từ chối; image đã ký → pass.
**Hỏng/chặn nhầm:** `./05-cosign-enforce.sh revert` (về warn ngay).
Script **từ chối** enforce nếu webhook còn log cảnh báo unsigned (ép: `FORCE=1`).

## Bước 6 — F06: trục Exploitability (CISA KEV) vào PDP  (RỦI RO THẤP)
```bash
./06-pdp-kev-score.sh status                  # xem code/catalog/weight
./06-pdp-kev-score.sh apply                   # deploy controller có KEV (vẫn INERT, weight=0)
./06-pdp-kev-score.sh catalog                 # tải CISA KEV → ConfigMap security/kev-catalog
# quan sát vài chu kỳ rồi mới KÍCH HOẠT:
./06-pdp-kev-score.sh weight 40               # set PDP_WEIGHT_KEV=40 (pod dính CVE-KEV tụt sâu hơn)
```
**Check:** `kubectl -n security get cm kev-catalog -o jsonpath='{.data.kev\.txt}' | grep -c CVE-` > 0;
pod sạch vẫn `high`; pod có CVE thuộc KEV tụt bucket sâu hơn pod CVE thường.
**Revert:** `./06-pdp-kev-score.sh revert` (khôi phục controller cũ + weight=0).

## Bước 7 — F07: chứng minh đóng vòng CVE → cô lập (DEMO)
```bash
./07-cve-isolation-demo.sh status
./07-cve-isolation-demo.sh apply              # demo an toàn: pod low bị chặn khỏi Vault, pod high thì không
# (tuỳ chọn) e2e thật bằng image dính CVE — chỉ chạy trên lab:
./07-cve-isolation-demo.sh vuln
./07-cve-isolation-demo.sh revert             # xoá namespace zta-demo
```
**Check:** dòng `RESULT low=blocked high=reachable`. Verdict trực tiếp:
`hubble observe --namespace zta-demo --to-namespace vault --verdict DROPPED`.

## Bước 8 — F08: ma trận phản hồi đa-CNP theo bucket  (RỦI RO TB)
```bash
./08-multi-cnp-matrix.sh status               # phải thấy medium=0 low=0 (apply lúc này là vô hại)
./08-multi-cnp-matrix.sh apply                # 2 CCNP: medium→chặn Vault, low→chặn Vault/Data/Management
```
**Check:** `kubectl get ccnp | grep trust`; khi PDP hạ 1 pod xuống medium/low,
`hubble observe --verdict DROPPED` thấy E-W tới vault/data/management bị cắt; pod high không đổi.
**Revert:** `./08-multi-cnp-matrix.sh revert` (xoá 2 CCNP).

## Bước 9 — F09: GitOps tự phục hồi (ArgoCD)  (RỦI RO CAO)
```bash
./09-argocd-gitops.sh install                 # cài ArgoCD bản ghim (v2.13.3) vào ns argocd
./09-argocd-gitops.sh apply                   # Application: selfHeal=true, prune=FALSE, path hẹp
```
**Check:** xoá thủ công 1 CNP trong `infras/k8s-yaml/cilium-policies/namespaces` trên cụm →
ArgoCD tự apply lại sau vài phút. `./09-argocd-gitops.sh status` xem sync/health.
**Revert:** `./09-argocd-gitops.sh revert` (xoá Application) hoặc `uninstall` (gỡ hẳn ArgoCD).
Bắt đầu `prune=false` + path hẹp; mở rộng sau khi quan sát ổn.

## Bước 10 — F10: Impossible-Travel — SHADOW/AUDIT (RỦI RO THẤP khi shadow)
```bash
# tạo secret keycloak-admin trước (script in sẵn lệnh nếu thiếu):
./10-impossible-travel.sh status
./10-impossible-travel.sh apply               # deploy analyzer shadow (CronJob 15')
./10-impossible-travel.sh run                 # chạy 1 lần ngay + xem log audit
```
**Check:** log có `impossible-travel-suspected ... action=audit-only` và `scan-complete`.
**KHÔNG cưỡng chế:** chỉ audit, không chặn login, không thu hồi phiên (CAEP) — phần enforce
vẫn [Thiết kế], cố ý chưa bật để không khoá nhầm người dùng.
**Revert:** `./10-impossible-travel.sh revert`.

---

## Quy tắc chung khi kiểm
- Mỗi bước: `status` (trước) → `apply` → check → mới sang bước sau.
- Backup tự lưu ở `backups/<fix>/<timestamp>/`; revert lấy bản mới nhất, hoặc:
  `./NN-...sh revert <đường-dẫn-backup-cụ-thể>`.
- Bỏ hỏi xác nhận (chạy hàng loạt): `ASSUME_YES=1 ./NN-...sh apply`.
- Nếu bất kỳ check nào KHÔNG đạt → revert ngay bước đó, đừng chạy bước sau.

## Thứ tự revert (nếu cần lùi toàn bộ — ngược lại lúc apply)
```bash
./10-impossible-travel.sh revert
./09-argocd-gitops.sh revert          # hoặc uninstall để gỡ hẳn ArgoCD
./08-multi-cnp-matrix.sh revert
./07-cve-isolation-demo.sh revert
./06-pdp-kev-score.sh revert
./05-cosign-enforce.sh revert
./04-readonly-rootfs.sh revert job7189-apps hiring-service
./03-gatekeeper-enforce.sh revert block-latest-tag
./03-gatekeeper-enforce.sh revert image-digest-required
./03-gatekeeper-enforce.sh revert zta-restrict-privileged
./02-pdp-tier-score.sh revert
./01-threat-intel-feed.sh revert
```
