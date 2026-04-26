# Observability Baseline — Step 2.3.1 (Hoàn thiện khả năng quan sát)

> **Mục đích:** Đặt nền móng quan sát đầy đủ trước khi triển khai các bước
> microsegmentation tiếp theo. Mirror đồ án 1, Mục 2.3.1 và 3.4.1.

## Tại sao bước này phải đi đầu

Đồ án 1, Mục 2.3.1, nhấn mạnh:
> "Đặc biệt chú trọng vào lưu lượng Đông-Tây, vì phần lớn lưu lượng trong
> trung tâm dữ liệu (75-90%) diễn ra theo hướng này, trong khi các tường lửa
> truyền thống chủ yếu giám sát lưu lượng Bắc-Nam."

Trước khi áp default-deny ở mọi namespace (PR #8), ta phải biết **luồng nào
là hợp lệ** — nếu không sẽ chặn nhầm và làm sập app. Baseline này là "ảnh
chụp" toàn bộ giao tiếp Đông-Tây ở thời điểm trước khi siết policy, đồng thời
là dữ liệu đầu vào cho:

| Bước thesis | Dữ liệu cần | Lấy từ baseline |
|-------------|-------------|------------------|
| 2.3.2 — DAAS | Bản đồ luồng giao dịch | `12-hubble-flow-summary.txt` |
| 2.3.3 — Labels | Identity ↔ workload mapping | `04-cilium-identities.txt` |
| 2.3.4 — 5W1H | Method/path L7 | `13-hubble-l7.json` |
| 2.3.5 — Adaptive | Drop pattern, anomaly | `11-hubble-flows-dropped.json` |

## Cách chạy

```bash
# Chạy ngay sau khi cluster + workload đã ổn (script 09 đã PASS)
bash scripts/zta-observability-baseline.sh
```

Script tạo thư mục `evidence/baseline-<timestamp>/` chứa snapshot. Có thể chạy
nhiều lần — mỗi lần tạo thư mục mới, không đụng cluster.

Tuỳ chọn môi trường:

| Biến | Mặc định | Ý nghĩa |
|------|----------|---------|
| `HUBBLE_FLOWS_LAST` | `5000` | Số flow tối đa lấy mỗi loại (FORWARDED / DROPPED / L7) |

## Đọc kết quả

### `12-hubble-flow-summary.txt`

Bảng aggregation theo (src_ns → dst_ns, proto/port). Mỗi dòng là một "kênh
giao tiếp" thực tế trong cluster. Đối chiếu với mong đợi:

- **Hợp lệ** → ghi vào DAAS (PR #8) thành allow rule.
- **Bất ngờ** → ghi nhận làm "shadow flow", có thể là cấu hình thừa hoặc dấu
  hiệu compromise. Phân loại trong DAAS để chặn ở PR #8.
- **Cross-namespace** → là ranh giới microperimeter cần policy explicit.

### `13-hubble-l7.json`

Chỉ chứa flow ở Layer 7 (HTTP/gRPC) — Cilium chỉ proxy L7 cho các pod đã có
CNP với `rules.http`. Hiện tại chỉ có 2 endpoint (`identity-service`,
`workspace-service`) đang ở L7 mode. PR #10 sẽ mở rộng L7 enforcement.

### `04-cilium-identities.txt`

Mỗi identity là một số nguyên (IDENTITY ID) + tập labels — đây chính là
**workload identity** mà Cilium dùng để áp policy. Khi PR #9 chuẩn hoá labels,
identity sẽ thay đổi (nhiều label mới) — so sánh trước/sau để verify.

## Mapping với PIP framework (NIST SP 800-207)

Baseline này khép kín gap PIP 7 (Observability) ở góc độ **manual snapshot**:

```
PIP 7 (Observability) — trước PR #7:
   ├─ Logs (filebeat → ES)        ✅
   ├─ Metrics (Prometheus)         ✅
   ├─ Network flows (Hubble)       ⚠ chỉ realtime, không persist
PIP 7 sau PR #7:
   ├─ Logs                         ✅
   ├─ Metrics                      ✅
   ├─ Network flows (Hubble)       ✅ snapshot lưu trữ trong evidence/
                                       (continuous indexing → PR sau)
```

Phần "continuous flow indexing" (Hubble export → Elasticsearch realtime)
được giữ lại cho một PR riêng vì cần đụng helm values của Cilium — sẽ làm
khi cluster đã ổn định qua PR #8 (default-deny mọi namespace).

## North-South vs East-West

Baseline phân tách hai chiều:

- **North-South**: client → ingress (kong / oauth2-proxy / ingress-nginx). Đã
  được PEP biên giám sát. Dữ liệu trong baseline: flow có `source.namespace`
  rỗng hoặc thuộc `ingress-nginx` / `gateway`.
- **East-West**: pod ↔ pod nội bộ. Là phần thesis nhấn mạnh và chính
  microsegmentation phải bảo vệ. Dữ liệu trong baseline: flow có cả hai
  `source.namespace` và `destination.namespace` đều thuộc cluster.

`12-hubble-flow-summary.txt` cho thấy phân bố ngay lập tức.

## Kiểm tra hợp lệ

Sau khi chạy script, kiểm tra:

```bash
# Có flow forwarded không (số > 0)
wc -l evidence/baseline-*/10-hubble-flows-forwarded.json | tail -1

# Có Cilium identity không (>= số namespace * 2)
grep -c '^[0-9]' evidence/baseline-*/04-cilium-identities.txt

# Có DROPPED không (cluster còn raw — trước PR #8 dự kiến rất ít)
wc -l evidence/baseline-*/11-hubble-flows-dropped.json
```

## Bước tiếp theo

Sau khi review baseline đầu tiên, mở **PR #8** với DAAS classification được
soạn dựa trên `12-hubble-flow-summary.txt`. Mỗi luồng trong summary phải
được phân loại Tier 1 / 2 / 3 theo Mục 3.4.2.
