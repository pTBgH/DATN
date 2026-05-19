# Phase 5.D Follow-Up TODO — danh sách công việc còn lại

**Branch:** `devin/1779203162-phase5d-honest-latency-and-tetragon-rootcause`
**Ngày tổng hợp:** 2026-05-18 (snapshot Enforced + Phase 5.B.2 OPA + Phase 5.C đã merge)
**Liên quan:** PR #4 (đã merge: `docs(chapter4): honest Phase 5.B.1+5.C evidence`)

---

## 0. TL;DR — 3 phát hiện quan trọng buổi diagnostic 2026-05-18

1. **CNP label fix** đã commit (commit `19a7615`): selector `cilium.zta/score-bucket` → `zta.job7189/score-bucket`. CNP `cnp-block-low-trust-to-vault` giờ `Enforcing=True` đúng kỳ vọng. ✅ Xong.

2. **Tetragon Sigkill root cause thực sự** = **kernel 6.8.12 không tương thích với `bpf_multi_kprobe_v61.o`** trong Tetragon v1.2.0 (object file compile cho kernel 6.1). Pod log:
   ```
   failed prog /var/lib/tetragon/bpf_multi_kprobe_v61.o
     kern_version 395276 loadInstance ...
     program generic_kprobe_event: load program: invalid argument
   ```
   → Không phải lỗi `matchArgs operator=Equal` như giả thuyết trong PR #4 §3.3 hiện tại. **Hypothesis cũ phải sửa.**

3. **Latency PR #4 §5.2 SAI** — toàn bộ số đo `hey -z 30s -c 20` (14.4 ms P50 cho `/api/health`, 14.3 ms P50 cho `/api/public/jobs`, 16.0 ms P50 cho `/api/jobs`, OPA delta +1.6-1.8 ms) thực ra **đo local uvicorn trên port 8000**, KHÔNG phải Kong. Bằng chứng: response header `server: uvicorn`, body `{"detail":"Not Found"}` (FastAPI style, không phải Kong `{"message":"no Route matched..."}`).

   Đo lại trên port 18000 → Kong (`server: kong/3.6.1`) cho path bị OPA deny anonymous:
   - `GET /api/admin/users` (403 OPA-deny): **P50=188 ms, P95=425 ms, P99=630 ms, ~97 req/s**
   - `GET /api/recruiters/profile` (403 OPA-deny): **P50=181 ms, P95=406 ms, P99=610 ms, ~103 req/s**

   → Kong+OPA pre-function thực tế ~**10x đắt hơn** số 14 ms uvicorn. Cần cập nhật §5.2 + §8 Discussion.

---

## 1. Việc đã hoàn thành (Phase 5.D pre-work)

| # | Việc | Bằng chứng | Trạng thái |
|---|------|-----------|------------|
| 1 | Fix CNP label namespace (`cilium.zta/*` → `zta.job7189/*`) | commit `19a7615` trên branch trước, `kubectl get cnp -n vault cnp-block-low-trust-to-vault` cho `VALID=True` | ✅ |
| 2 | Xác định Tetragon Sigkill root cause | Tetragon pod log có `bpf_multi_kprobe_v61.o ... invalid argument`. Kernel host = 6.8.12; Tetragon v1.2.0 ship object cho kernel 6.1 | ✅ (xác định) |
| 3 | Thử Option B (`--disable-kprobe-multi` qua helm upgrade) | Failed: Helm chart bug `nil pointer evaluating processAncestors.enabled`. DS đã rollback. | ❌ (bỏ) |
| 4 | Quyết định Tetragon Option A — document honest 5.D limitation | Không bump version Tetragon trong final phase (rủi ro break) | ✅ (đã chọn) |
| 5 | Confirm Kong + OPA đường đi đúng | `GET /pma/` → 403 với body `{"reason":"OPA denied user-authz"}`; `server: kong/3.6.1` | ✅ |
| 6 | Đo lại latency Kong+OPA thực | `hey -z 30s -c 20` trên `/api/admin/users` + `/api/recruiters/profile` qua port 18000 | ✅ |

---

## 2. Việc CÒN LẠI (cần làm tiếp / chưa làm được)

### 2.1 Cập nhật `chapter4.tex` (đang làm trong branch này)

| # | Mục | Việc | Trạng thái |
|---|-----|------|-----------|
| A | §3.3 caveat Sigkill | Thay hypothesis `matchArgs operator=Equal vs containerd-shim` bằng root cause thực: kernel 6.8.12 + `bpf_multi_kprobe_v61.o` (kernel 6.1). | ⏳ làm trong branch này |
| B | §5.2 Latency table | Xoá số liệu sai (14 ms uvicorn); thay bằng đo thực 188/425/630 ms cho 2 path 403 OPA-deny. Ghi rõ KHÔNG có measurement Kong-only-no-OPA (vì pre-function global) → KHÔNG tính được "OPA delta" như cũ. | ⏳ làm trong branch này |
| C | §5.2 đặc tả phép đo | Sửa câu "route trả 404 do hot-reload" (sai) → "test trước đo nhầm vào local uvicorn 8000; remeasure port 18000 cho thấy Kong+OPA fire 403 cho path require auth". | ⏳ làm trong branch này |
| D | §7 Limitations row Tetragon Sigkill | Đổi mô tả từ "matchArgs hypothesis" sang "kernel BPF object incompat" + hướng fix: upgrade Tetragon v1.4+ hoặc downgrade kernel 6.1. | ⏳ làm trong branch này |
| E | §7 Limitations row Kong route consistency | Sửa: Kong route THỰC RA work; vấn đề trước là test hit nhầm local uvicorn. Mở row mới: "upstream PHP-FPM hang cho `/api/health`, `/api/public/jobs`" (chưa xong). | ⏳ làm trong branch này |
| F | §8 Discussion latency paragraph | Sửa số "OPA delta 1.6-1.8 ms p50-p99" → con số mới + ghi chú cần Phase 5.E để đo end-to-end qua upstream khi service ready. | ⏳ làm trong branch này |
| G | §4.1 Test case 22-28 dag footnote | Update test 23/24 dag footnote: root cause kernel BPF (không phải matchArgs). | ⏳ làm trong branch này |

### 2.2 Cluster work CHƯA XONG (không làm trong branch này, để Phase 5.E sau khi bảo vệ)

| # | Việc | Lý do hoãn | Đánh dấu trong thesis |
|---|------|-----------|----------------------|
| H | **Tetragon end-to-end Sigkill** trên `/bin/sh -c "echo hello"` exit 137 | Cần upgrade Tetragon ≥ v1.4 (kernel 6.8 support) hoặc downgrade kernel host 6.8 → 6.1. Cả 2 đều rủi ro break trong final phase. | **(chưa xong)** — Phase 5.E |
| I | **Upstream `/api/health`, `/api/public/jobs` hang qua Kong** | Identity-service/job-service vừa restart (AGE 2m52s), có thể chưa init xong. Hoặc Cilium CNP `default-deny` trong `job7189-apps` chặn ingress từ `gateway` (Kong) tới `job7189-apps`. Cần check CNP ingress rules + readinessProbe. | **(chưa xong)** — Phase 5.E |
| J | **Latency end-to-end Baseline (không ZTA) vs Enforced (ZTA)** | Cần etcd snapshot restore Baseline + Kong route trả 200 OK qua upstream. Hai bước đều phụ thuộc vào (I). | **(chưa xong)** — Phase 5.E |
| K | **Local uvicorn port 8000 trên laptop dev** | Không quan trọng cho thesis. Chỉ là service FastAPI dev chiếm port 8000 trên `ptb@baosrc`, khiến `kubectl port-forward 8000:8000` bind silent fail. Workaround: dùng port 18000. | (không cần ghi thesis) |
| L | **Sigstore policy controller verify image trong cluster** | Đã có config, nhưng chưa verify event log "rejected by policy". | **(chưa xong)** — Phase 5.E |

### 2.3 Git / Process

| # | Việc | Trạng thái |
|---|------|-----------|
| M | Commit chapter4 đã sửa + doc này | ⏳ |
| N | Push branch `devin/1779203162-phase5d-honest-latency-and-tetragon-rootcause` | ⏳ |
| O | Tạo PR (chờ user merge) | ⏳ |

---

## 3. Bằng chứng chi tiết (để reviewer trace lại)

### 3.1 Tetragon kernel BPF incompat — log gốc
```
$ kubectl -n kube-system logs ds/tetragon -c tetragon --tail=200 | grep -E "load|prog|bpf_multi"
time="..." level=error msg="failed prog /var/lib/tetragon/bpf_multi_kprobe_v61.o
  kern_version 395276 loadInstance ... program generic_kprobe_event:
  load program: invalid argument"
```
- `kern_version 395276` = 0x60808 = kernel 6.8.8 (object compile cho kernel 6.1)
- Host kernel hiện tại: `uname -r` → `6.8.0-...-generic` Ubuntu 24.04
- Tetragon version: `quay.io/cilium/tetragon:v1.2.0`
- Tetragon v1.4+ thêm BPF object `bpf_multi_kprobe_v66.o`, `v612.o` cho kernel mới hơn

### 3.2 Kong+OPA latency — `hey` output gốc

```
GET /api/admin/users (Kong+OPA, 403 OPA-denied anonymous)
  Total: 30.14 secs   Average: 205 ms   Requests/sec: 97.02
  P50: 188.2 ms   P95: 424.8 ms   P99: 630.5 ms
  Slowest: 1037 ms   Fastest: 21.8 ms
  Status: 401 × 3, 403 × 2921

GET /api/recruiters/profile (Kong+OPA, 403 OPA-denied anonymous)
  Total: 30.17 secs   Average: 193 ms   Requests/sec: 103.14
  P50: 181.0 ms   P95: 405.7 ms   P99: 609.8 ms
  Slowest: 895.5 ms   Fastest: 17.5 ms
  Status: 403 × 3112
```

### 3.3 Smoking gun cho local uvicorn — header response

```
$ curl -sv http://localhost:8000/pma/
< HTTP/1.1 404 Not Found
< server: uvicorn         ← KHÔNG phải Kong
< content-type: application/json
{"detail":"Not Found"}    ← FastAPI body style
```

Trong khi đó qua port 18000 (port-forward đúng Kong):
```
$ curl -sv http://localhost:18000/pma/
< HTTP/1.1 403 Forbidden
< server: kong/3.6.1      ← Kong thật
{"user":"anonymous","reason":"OPA denied user-authz","message":"forbidden","roles":{}}
```

### 3.4 Routes Kong load đúng — admin API confirm

```
$ curl -s http://localhost:18001/routes | jq '.data | length'
35

$ curl -s http://localhost:18001/routes/phpmyadmin-route | jq '{name,paths,strip_path}'
{"name":"phpmyadmin-route","paths":["/pma/"],"strip_path":true}
```

→ Route config Kong đúng. Vấn đề upstream hang (`/api/health`, `/api/public/jobs`) độc lập với Kong layer.

---

## 4. Lưu ý cho bảo vệ thesis

- **Tránh** dùng số liệu 14 ms / 16 ms / 1.6-1.8 ms OPA delta từ PR #4 — đó là số uvicorn local, không phản ánh hệ thống thực.
- **Dùng** số mới 188-630 ms cho Kong+OPA 403-path. Đây là worst-case (cold + concurrent 20) và là số tin cậy.
- Khi bị hỏi "tại sao Tetragon không kill được /bin/sh", trả lời: **kernel 6.8 + Tetragon v1.2.0 BPF object mismatch**, không phải lỗi cấu hình TracingPolicy. Hướng fix: upgrade Tetragon hoặc downgrade kernel — cả hai đều rủi ro trong final phase nên defer.
- Khi bị hỏi "tại sao /api/health hang", trả lời: **upstream PHP-FPM (identity-service/job-service) vừa restart, chưa init xong, hoặc Cilium CNP default-deny trong job7189-apps chặn Kong→upstream**. Có thể fix nhanh nhưng chưa làm — defer Phase 5.E.
