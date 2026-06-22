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

## Quy tắc chung khi kiểm
- Mỗi bước: `status` (trước) → `apply` → check → mới sang bước sau.
- Backup tự lưu ở `backups/<fix>/<timestamp>/`; revert lấy bản mới nhất, hoặc:
  `./NN-...sh revert <đường-dẫn-backup-cụ-thể>`.
- Bỏ hỏi xác nhận (chạy hàng loạt): `ASSUME_YES=1 ./NN-...sh apply`.
- Nếu bất kỳ check nào KHÔNG đạt → revert ngay bước đó, đừng chạy bước sau.

## Thứ tự revert (nếu cần lùi toàn bộ — ngược lại lúc apply)
```bash
./04-readonly-rootfs.sh revert job7189-apps hiring-service
./03-gatekeeper-enforce.sh revert block-latest-tag
./03-gatekeeper-enforce.sh revert image-digest-required
./03-gatekeeper-enforce.sh revert zta-restrict-privileged
./02-pdp-tier-score.sh revert
./01-threat-intel-feed.sh revert
```
