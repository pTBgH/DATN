# 00 — System Snapshot (Single Source of Truth)

> **Snapshot chuẩn:** cluster `job7189`, ngày **2026-06-20**.
> **Nguồn thẩm quyền:** `52-limitations-and-known-gaps.md` tại commit `e1fe3e6`
> (dựa trên log `zta-conflict-check-20260620_173336`) và 4 file đã reconcile trong
> cùng commit: `11-cisa-ztmm-assessment.md`, `15-encryption-mtls-spiffe.md`,
> `25-pdp-controller.md`, `chapter4_evidence_guide.md`.
>
> File này thay thế các snapshot rải rác trước đây. Khi KB cũ mâu thuẫn, lấy file
> này làm chuẩn. KB là tài liệu nội bộ, không `\input` vào báo cáo LaTeX.

## Trạng thái cluster đã xác nhận

| Hạng mục | Trạng thái chuẩn 2026-06-20 | Lệnh kiểm chứng |
|---|---|---|
| Node topology | 4 node: `7189srv01` control-plane, `7189srv02`/`7189srv03`/`7189srv05` worker | `kubectl get nodes -o wide` |
| OS srv01/02/03 | `7189srv01`/`7189srv02`/`7189srv03` = Debian GNU/Linux 13 (trixie), kernel `6.12.86+deb13-amd64` | `kubectl get nodes -o wide` |
| OS srv05 | `7189srv05` = Ubuntu 24.04.4 LTS, kernel `6.8.0-124-generic` | `kubectl get nodes -o wide` |
| Tetragon | v1.7.0, DaemonSet 3/3 trong `kube-system` | `kubectl -n kube-system get ds tetragon -o wide`; `kubectl -n kube-system get ds tetragon -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}'` |
| Tetragon policy | `block-suspicious-exec` enforce `Sigkill` + audit `Post` ở 4 namespace: `data`, `job7189-apps`, `security`, `vault` | `kubectl get tracingpolicynamespaced -A -o yaml | grep -E 'name: block-suspicious-exec|action: (Sigkill|Post)|namespace:'` |
| Cilium mTLS | `mesh-auth-enabled=true` | `kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.mesh-auth-enabled}'` |
| Cilium WireGuard | `enable-wireguard=false`; mã hóa L3 node-to-node do Tailscale WireGuard đảm nhận | `kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}'` |
| Tailscale underlay | Các node nối qua overlay `100.64.0.0/10`; L3 encrypted dưới Cilium | `kubectl get nodes -o wide`; trên node: `tailscale status` |
| Threat-intel feed | FireHOL đã sync đúng 2000 CIDR; CronJob `threat-intel-refresh` active | `kubectl get ciliumcidrgroup threat-intel-firehol -o jsonpath='{range .spec.externalCIDRs[*]}{.}{"\n"}{end}' | wc -l`; `kubectl -n security-cdm get cronjob threat-intel-refresh` |
| Threat-intel enforcement | CCNP `cnp-threat-intel-egress-deny` enforcing | `kubectl get ccnp cnp-threat-intel-egress-deny -o yaml` |
| Vault low-trust CNP | CNP `cnp-block-low-trust-to-vault` đã apply và enforcing trong namespace `vault` | `kubectl get cnp -A | grep cnp-block-low-trust-to-vault`; `kubectl -n vault get cnp cnp-block-low-trust-to-vault -o yaml` |
| PDP controller | Deployment `zta-pdp` chạy trong namespace `security`, không phải `pdp-system` | `kubectl -n security get deploy,pod,svc -l app=zta-pdp`; `kubectl get ns pdp-system` |
| PDP CVE input | `PDP_CVE_INPUT` không set tường minh, code default `true` nên CVE-gating bật | `kubectl -n security get deploy zta-pdp -o jsonpath='{.spec.template.spec.containers[0].env}'` |
| Trivy Operator | Active trong namespace `security-cdm`; tạo `VulnerabilityReport` cho input CDM/PDP | `kubectl -n security-cdm get deploy,pod | grep -i trivy`; `kubectl get vulnerabilityreport -A` |
| Cosign policy-controller | 3 `ClusterImagePolicy`, tất cả `mode=warn` (chưa enforce) | `kubectl get clusterimagepolicy -o jsonpath='{range .items[*]}{.metadata.name}{" mode="}{.spec.mode}{"\n"}{end}'` |
| Gatekeeper | Đã deploy ConstraintTemplate + constraints; image constraints ở `dryrun`, pod-security critical constraints enforce `deny` | `for k in k8sblocklatesttag k8simagedigestrequired k8ssignedimageannotation ztablockhostmounts ztarequiredlabels ztarestrictprivileged; do echo "== $k =="; kubectl get "$k" -o jsonpath='{range .items[*]}{.metadata.name}{" enforcementAction="}{.spec.enforcementAction}{"\n"}{end}'; done` |
| SPIRE/SPIFFE | 10 `ClusterSPIFFEID`; spire-server + 4 agent Running; SVID được cấp | `kubectl get clusterspiffeid`; `kubectl -n spire get pod` |
| Docker Registry | Registry chạy host-level trên máy `baosrc` qua HTTPS `https://100.74.189.43:5443`; không phải pod in-cluster. Namespace `registry` trong cluster rỗng. Catalog hiện có các image `job7189/*` | `REGISTRY_URL=https://100.74.189.43:5443 bash scripts/verify-system-snapshot-20260620.sh`; hoặc `curl -k https://100.74.189.43:5443/v2/_catalog` + `kubectl -n registry get pod,svc,deploy,sts,ds,job,cronjob` |
| MinIO object storage | Deployed trong namespace `data` dưới dạng `StatefulSet/minio`, PVC 10Gi, bucket `job7189-storage`; API nội bộ `minio.data.svc.cluster.local:9000`, frontend upload dùng presigned URL qua NodePort `http://100.108.231.127:30900` | `kubectl -n data get pod,svc,pvc,job -l 'app in (minio,minio-bucket-init)' -o wide`; gọi `storage-service` `/api/presigned-url` rồi `PUT` vào URL trả về |

## TODO còn lại chưa được bịa số liệu

Không còn TODO bắt buộc từ snapshot này. Nếu cần audit sâu hơn, có thể chạy SSH
`cat /etc/os-release` từng node để đối chiếu với `kubectl get nodes -o wide`, nhưng
KB hiện đã có đủ dữ liệu cluster-level.

## Gatekeeper enforcementAction đã chốt

| Constraint kind | Constraint | enforcementAction | Ý nghĩa |
|---|---|---|---|
| `k8sblocklatesttag` | `block-latest-tag` | `dryrun` | Audit-only |
| `k8simagedigestrequired` | `image-digest-required` | `dryrun` | Audit-only |
| `k8ssignedimageannotation` | `signed-image-annotation-required` | `dryrun` | Audit-only |
| `ztablockhostmounts` | `zta-block-host-mounts` | `deny` | Enforce |
| `ztarequiredlabels` | `zta-labels-required` | `dryrun` | Audit-only |
| `ztarestrictprivileged` | `zta-restrict-privileged` | `deny` | Enforce |

## Script kiểm chứng

Script đọc-only đã chuẩn bị sẵn để chạy khi cluster bật:

```bash
bash scripts/verify-system-snapshot-20260620.sh
```

Nếu muốn script thử SSH vào node để lấy `/etc/os-release`, đặt:

```bash
CHECK_NODE_OS=1 bash scripts/verify-system-snapshot-20260620.sh
```
