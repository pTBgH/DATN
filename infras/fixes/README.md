# infras/fixes — script hoàn thiện ZTA (an toàn, có revert)

Script tự động hoá cho lộ trình ở `documents/roadmap-hoan-thien-he-thong.md`,
sắp **dễ → khó**. Chạy trên máy **có quyền vào cụm** (cần `kubectl`).

## Nguyên tắc an toàn
- Mỗi script **sao lưu trạng thái live trước khi đổi** vào `backups/<fix>/<timestamp>/`.
- Mỗi script có lệnh con `revert` (khôi phục từ backup mới nhất hoặc thư mục chỉ định).
- `status` chỉ xem, không đổi gì. Luôn chạy `status` trước.

## Cách dùng
```bash
./01-threat-intel-feed.sh status
./01-threat-intel-feed.sh apply
./01-threat-intel-feed.sh revert            # nếu cần

ASSUME_YES=1 ./02-pdp-tier-score.sh apply   # bỏ hỏi xác nhận
KUBECTL=/path/to/kubectl ./03-... status    # đổi binary
```

| Script | Hạng mục | Mức | Rủi ro |
|--------|----------|-----|--------|
| `01-threat-intel-feed.sh` | Kích hoạt feed FireHOL/URLhaus | Dễ | Thấp |
| `02-pdp-tier-score.sh` | `tier` vào trust score | Dễ | Thấp–TB |
| `03-gatekeeper-enforce.sh` | `dryrun → deny` (có chốt audit) | TB | TB |
| `04-readonly-rootfs.sh` | `readOnlyRootFilesystem` (auto-rollback) | TB | TB |

F05–F10 (Cosign enforce, KEV/EPSS, đóng vòng CVE, đa-CNP, ArgoCD, CAEP) hướng dẫn
chi tiết trong roadmap — chưa script hoá vì phụ thuộc tiền đề/hạ tầng mới.

`lib-common.sh` chứa helper dùng chung (backup, confirm, kubectl check). Không chạy trực tiếp.
`backups/` do script tạo lúc chạy — không commit (đã `.gitignore`).
