# Hướng dẫn lắp bằng chứng vào Chương 4

Tài liệu này KHÔNG phải là một phần của bản LaTeX cuối. Mục đích duy nhất:
nói rõ **bằng chứng nào** lấy ở **file nào, đoạn nào**, **trình bày ra sao**
trong từng tiểu mục của Chương 4 — và **chụp ảnh gì** nếu muốn bổ trợ trực
quan. Mọi số liệu trong Chương 4 phải truy xuất ngược được tới một dòng cụ
thể trong các file dưới đây hoặc các file `evidence/*.txt` đã commit từ
trước.

Phạm vi:

- 6 kịch bản đã có bằng chứng thật → viết đầy đủ (setup / tấn công / cơ chế
  chặn / bằng chứng).
- 2 hạng mục chưa có bằng chứng end-to-end (OPA decision log, threat-intel
  feed) → ghi vào §4.6 *Giới hạn & hướng phát triển*, KHÔNG dựng demo giả.

Quy ước thư mục:

| Thư mục | Vai trò |
|---|---|
| `evidence/chapter4/` | Output script `zta-chapter4-evidence.sh` (8 file/run, có timestamp). Dùng cho phần lớn dẫn chứng. |
| `evidence/` (cũ) | Snapshot CNP/Hubble/Pod đã có từ trước. Dùng cho bảng conformance L4 và đối chiếu trạng thái. |
| `doc/40-zta-system-snapshot-20260527.md` | Snapshot 27/05. Dùng cho phần mô tả môi trường & ghi nhận trạng thái rollout. |

Quy ước tên file chứa bằng chứng (theo lần chạy 27/05 23:47):
`scenario-XX-<name>-20260527-234714.txt` (lần 1) và
`scenario-XX-<name>-20260527-234755.txt` (lần 2, có `CONFIRM_REVOKE` &
`CONFIRM_PDP_SIM`). Mỗi đoạn dưới ghi rõ nên dùng file nào.

---

## 1. §4.2 Môi trường thử nghiệm

**Mục tiêu trình bày:** mô tả phần cứng / phần mềm + đặc tính ZTA đang
active. Phần này KHÔNG demo bất cứ thứ gì, chỉ là bảng + đoạn văn ngắn.

**Lấy từ:** `evidence/chapter4/scenario-00-diagnostics-*.txt`.

**Bảng cần có (1 cái duy nhất):**

| Hạng mục | Giá trị | Lấy từ dòng nào |
|---|---|---|
| Số node | 4 (1 control-plane, 3 worker) | `kubectl get nodes -o wide` |
| Kernel | 6.12.86 (Debian 13) trên 3 node, 6.8.0-117 (Ubuntu 24.04) trên 1 node | output `kubectl get nodes -o wide` cột KERNEL-VERSION |
| Container runtime | containerd 2.2.3 | cùng output |
| Kubernetes | client/server v1.30.0 | `kubectl version` |
| Cilium namespace policy (CNP) | 11 CNP trong `job7189-apps` (default-deny-all + 10 allow-* L3/L4/L7) | `kubectl get cnp -A` đếm dòng namespace=job7189-apps |
| Cilium cluster-wide policy (CCNP) | 1 — `cnp-threat-intel-egress-deny` | `kubectl get ccnp` |
| CIDR group | 1 — `threat-intel-firehol` | `kubectl get ciliumcidrgroup` |
| TracingPolicy | 1 cluster (`monitor-kernel-module-load`) + 4 namespaced (`block-suspicious-exec` ở 4 ns, `monitor-sensitive-files` ở job7189-apps) | `kubectl get tracingpolicy,tracingpolicynamespaced -A` |
| ClusterImagePolicy (Cosign) | 3 — `zta-job7189-apps-signed`, `zta-keyless-trust-job7189`, `zta-system-passthrough` | `kubectl get clusterimagepolicy` |
| ClusterSPIFFEID | 10 — 3 tier (`zta-default-workload-identity`, `zta-tier1-extended-ttl`, `zta-tier3-short-ttl`) + 7 spike/oidc | `kubectl get clusterspiffeid` |
| Pod nghiệp vụ | 7 service (4/4 container/pod) + 7 Redis (1/1) chạy ổn định | `kubectl -n job7189-apps get pod` |
| Cilium ServiceMesh mTLS | **TẮT** (`mesh-auth-enabled=false`) — Tailscale lo L3 encryption | `kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.mesh-auth-enabled}'` |
| WireGuard | Không bật trong Cilium (cell trống) | `…enable-wireguard` |

**Cách trình bày trong LaTeX:** 1 `\begin{table}` `tabularx` 2 cột (Hạng
mục / Giá trị). Caption: *"Cấu hình hệ thống tại thời điểm thử nghiệm
(snapshot 27/05/2026)"*. KHÔNG paste raw kubectl output vào chương.

**Screenshot bổ trợ (tuỳ chọn, không bắt buộc):**

- `images/ch4_kubectl_get_nodes.png` — terminal screenshot `kubectl get nodes -o wide`. Maximize terminal, font ≥ 14 (Ctrl+Shift+=). Chỉ cap đủ 5 dòng (header + 4 node).

---

## 2. §4.3.1 Microsegmentation L3/L4 (default-deny)

**NIST tenet:** 4 (mọi tài nguyên đều phải xác thực + phân quyền), 5 (giám sát toàn bộ).

**Setup cần mô tả:**

- Namespace `job7189-apps` có `CiliumNetworkPolicy default-deny-all` với
  `endpointSelector: {}` (bắt mọi pod trong namespace) và 1 `umbrella-deny`
  marker label để workaround schema bắt buộc của Cilium ≥ 1.14.
- Cùng namespace có 10 CNP `allow-*` mở từng đường tường minh.

**Tấn công mô phỏng:**

- Script `01-lateral-movement` đã thử tạo pod attacker (busybox nc-probe).
- *Lưu ý*: lần chạy 27/05 23:47, pod attacker không tạo được vì underscore
  trong tên (đã fix ở v2 script). Tuy nhiên Hubble vẫn ghi nhận **traffic
  production thật bị block**: `hiring-service` cố mở TCP/3306 tới
  `mysql.data` (PHP queue worker) — đây là minh chứng còn mạnh hơn pod
  giả vì nó là behaviour thực, không dàn dựng.

**Cơ chế chặn:**

- Lấy YAML `default-deny-all` (rút gọn còn 12–15 dòng) từ
  `scenario-01-lateral-movement-20260527-234714.txt`, đoạn `$ kubectl ... default-deny-all -o yaml | head -40`. **CHỈ in phần
  `spec:`** (bỏ `metadata.annotations`, `status`, `resourceVersion` cho gọn).
- Câu giải thích umbrella-deny: pod nào không có label
  `cilium.zta/marker=umbrella-deny` (= mọi pod thực) đều bị deny mặc định.

**Bằng chứng:**

- Lấy 4–6 dòng Hubble drop liên tiếp từ cùng file, đoạn `$ kubectl ... hubble observe --since 2m --verdict DROPPED ...`. Ví dụ:
  ```
  May 27 16:45:31.251: job7189-apps/hiring-service-...:51998 (ID:23446)
    <> data/mysql-...:3306 (ID:10323)
    Policy denied DROPPED (TCP Flags: SYN)
  ```
  Cô đọng còn 2 dòng/event; in liên tiếp ~5 event để cho thấy nhịp drop ổn định.

**Cách trình bày trong LaTeX:**

1. 1 đoạn văn 4–5 câu mô tả setup + tấn công.
2. `\begin{listing}[H]` minted `yaml` show `spec:` default-deny.
3. `\begin{listing}[H]` minted `text` show 5 dòng Hubble drop.
4. 1 câu chốt: *"Đối chiếu với conformance test ban đầu (xem §4.4), test N01 (random pod → MySQL) tiếp tục cho kết quả DENIED."*

**Screenshot bổ trợ (khuyến nghị):**

- `images/ch4_hubble_ui_drops.png` — Hubble UI (port-forward `cilium-cli hubble ui`), filter namespace=job7189-apps, verdict=DROPPED, khoảng thời gian 30 phút. Cap full window 1920×1080; chỉ rõ trên ảnh đường mũi tên đỏ giữa `hiring-service` và `mysql`.
- Có thể thay bằng `images/ch4_kibana_drop_filebeat.png` — Kibana query `kubernetes.namespace:"job7189-apps" AND event.outcome:"DROPPED"` trong index `filebeat-hubble-*`.

---

## 3. §4.3.2 Microsegmentation L7 (HTTP verb/path)

**NIST tenet:** 4 (per-request authz).

**Setup:**

- CNP `allow-internal-job-to-workspace` cho phép `job-service → workspace-service:80`, **chỉ method GET** trên regex `/api/v1/internal/workspaces/.*`.
- Mọi method khác (POST/PUT/DELETE) phải bị từ chối.

**Tấn công mô phỏng:**

- Từ `scenario-02-api-abuse-20260527-234714.txt`, đoạn `$ kubectl ... exec ${JOB_POD} -- curl ... -X DELETE`. Pod thật: `job-service-65f9f7cfcb-ssnj6`. Lệnh:
  ```
  curl -X DELETE http://workspace-service.job7189-apps.svc.cluster.local/api/v1/internal/workspaces/42
  ```
- Kết quả: `curl: (28) Connection timed out after 8001 milliseconds`, `HTTP 000`.

**Cơ chế chặn:**

- In YAML rút gọn CNP `allow-internal-job-to-workspace` (~15 dòng) — bạn có thể dump nhanh:
  ```
  kubectl -n job7189-apps get cnp allow-internal-job-to-workspace -o yaml > /tmp/cnp.yaml
  ```
  rồi paste phần `spec:`.

**Bằng chứng:**

- Output curl HTTP 000 timeout 8s (in nguyên 3 dòng).
- **KHÔNG nói "Envoy trả 403"** — chứng cứ thật là drop ở L4 (curl timeout). Có thể giải thích: với policy chỉ allow GET, các verb khác bị Cilium policy reject trước khi connection được proxy redirect, do đó hành xử như một L4 drop từ góc nhìn client.
- *Optional*: chạy lại với GET trên cùng path để so sánh:
  ```
  kubectl -n job7189-apps exec job-service-... -c app -- \
    curl -sS -m 6 -o /dev/null -w 'HTTP %{http_code}\n' \
    http://workspace-service.job7189-apps:80/api/v1/internal/workspaces/42
  ```
  Nếu trả `HTTP 200/404/500` (chứ không phải 000) → chứng minh là phân biệt method, không phải mạng đứt.

**Cách trình bày LaTeX:**

- 1 listing minted `yaml` cho policy.
- 1 listing minted `text` cho curl output (2 lệnh: DELETE timeout vs GET trả mã thường).
- Bảng 2 cột: *Method | Kết quả*. Caption: *"Hành vi của Cilium L7 policy với cùng path nhưng khác HTTP method"*.

**Screenshot bổ trợ:**

- Không bắt buộc. Nếu muốn: `images/ch4_curl_delete_timeout.png` — terminal screenshot 2 lệnh side-by-side.

---

## 4. §4.3.3 Runtime observability (Tetragon)

**NIST tenet:** 6 (continuous monitoring), 7 (insight để cải thiện security posture).

**Setup:**

- `TracingPolicyNamespaced block-suspicious-exec` cài cho 4 namespace (data, job7189-apps, security, vault), hook `sys_execve`, theo dõi 7 binary `/bin/sh`, `/bin/bash`, `/usr/bin/curl`, `/usr/bin/wget`, `/usr/bin/nc`, `/usr/bin/ncat`, `/usr/bin/nmap`.
- **Action = `Post`** (audit-only) theo quyết định 2026-05-20 vì init container hợp lệ exec /bin/sh. Sigkill hoãn tới phase 5.E sau khi upgrade Tetragon v1.7.0.

**Tấn công mô phỏng:**

- `scenario-03-runtime-anomaly-...`, đoạn `$ kubectl ... exec identity-service-... -c app -- /bin/sh -c 'id; uname -a; cat /etc/passwd | head -3'`.
- Output: `uid=0(root)`, `Linux ... 6.12.86+deb13-amd64`, 3 dòng đầu /etc/passwd.

**Cơ chế chặn (= ghi nhận, không kill):**

- In `spec:` rút gọn của TracingPolicyNamespaced (kprobes, selectors). Lấy từ cùng file đoạn `$ kubectl ... get tracingpolicynamespaced -o yaml | head -60`.

**Bằng chứng:**

- 1 dòng JSON Tetragon kprobe event (process_kprobe). Format tối giản cho thesis (60–80 cột): chọn các field
  ```
  process.binary, process.arguments, process.pod.namespace, process.pod.name,
  process.pod.container.name, process.pod.pod_labels."zta.job7189/tier",
  start_time
  ```
- Lấy từ file scenario-03, dòng JSON đầu (đã có sẵn). **Format lại bằng `jq`** trước khi paste:
  ```
  grep block-suspicious-exec scenario-03-runtime-anomaly-*.txt | head -1 | \
    jq '{ns:.process_kprobe.process.pod.namespace,
          pod:.process_kprobe.process.pod.name,
          bin:.process_kprobe.process.binary,
          args:.process_kprobe.process.arguments,
          tier:.process_kprobe.process.pod.pod_labels["zta.job7189/tier"],
          score:.process_kprobe.process.pod.pod_labels["zta.job7189/score-bucket"]}'
  ```
  *(Lệnh này là gợi ý — bạn không phải chạy nếu lười; có thể paste raw JSON rồi viết câu chú thích từng field).*

**Lưu ý quan trọng (phải nói thẳng trong chương):**

- Event sample trong evidence là từ `hiring-service` chạy `php /var/www/artisan schedule:run` (cron app legit), KHÔNG phải lệnh tấn công ta vừa exec. Tetragon đang post **mọi** sys_execve trong namespace nên event của ta cũng có nhưng có thể bị truncate khỏi `tail -5`.
- Có thể chạy lệnh lọc chính xác hơn để đính kèm chương:
  ```
  kubectl -n kube-system logs <tetragon-pod> -c export-stdout --tail=2000 | \
    jq -c 'select(.process_kprobe.process.binary=="/bin/sh")' | tail -3
  ```

**Cách trình bày LaTeX:**

1. 1 listing minted `yaml` cho TracingPolicy spec.
2. 1 listing minted `text` cho lệnh exec (3 dòng input + 5 dòng output).
3. 1 listing minted `json` cho event (post `jq` format).
4. 1 đoạn 3–4 câu giải thích trade-off Post vs Sigkill, link tới phase 5.E future work.

**Screenshot bổ trợ:**

- `images/ch4_kibana_tetragon_event.png` — Kibana index `filebeat-tetragon-*`, query `process_kprobe.policy_name:"block-suspicious-exec"`, bung 1 document detail.
- *Optional*: `images/ch4_tetragon_grafana.png` — nếu có Grafana dashboard cho `tetragon_events_total`.

---

## 5. §4.3.4 Dynamic credential JIT (Vault)

**NIST tenet:** 1 (mọi nguồn tài nguyên là 1 resource), 5 (đo lường + log).

**Setup:**

- Vault chạy single replica `vault-0` (raft, dev mode disabled), `vault-agent-injector` deploy ở `vault` namespace.
- Mỗi pod nghiệp vụ inject 1 init container + 1 sidecar `vault-agent` để render dynamic DB creds vào tmpfs `/vault/secrets/`.
- TTL mặc định `default_ttl=1h, max_ttl=24h`; auth qua Kubernetes ServiceAccount JWT.

**Bằng chứng (lấy từ `scenario-04-credential-reuse-20260527-234714.txt` + lần `-234755` cho phần revoke):**

1. **Pattern tên user JIT** (chứng minh creds thay đổi mỗi lease, không phải static):
   ```
   $ kubectl -n job7189-apps exec job-service-... -- ls -l /vault/secrets/
   total 0
   DB_USERNAME="v-kubernetes-job-servic-JgHKN8PN"
   DB_PASSWORD=***REDACTED***
   ```
   Tiền tố `v-kubernetes-` + tên role rút gọn + suffix 8 chữ random là pattern Vault MySQL database engine tự sinh.

2. **Renewal log** (chứng minh agent tự renew, không cần app restart):
   ```
   2026-05-27T14:02:00.362Z [INFO]  agent.auth.handler: starting renewal process
   2026-05-27T14:02:00.782Z [INFO]  agent: (runner) rendered "(dynamic)" => "/vault/secrets/.env.db.lease"
   2026-05-27T14:02:00.786Z [INFO]  agent: (runner) rendered "(dynamic)" => "/vault/secrets/.env.db"
   2026-05-27T14:45:29.826Z [INFO]  agent.auth.handler: renewed auth token
   2026-05-27T15:28:58.980Z [INFO]  agent.auth.handler: renewed auth token
   2026-05-27T16:12:28.310Z [INFO]  agent.auth.handler: renewed auth token
   ```
   3 lần renewed ~43 phút/lần (TTL 1h, renew khi còn 1/3 thời lượng).

3. **Cấu hình role (lấy từ doc/03-secret-management.md hoặc helm values)** — KHÔNG có trong evidence runtime, lấy từ kho config:
   ```
   vault write database/roles/job-service \
     db_name=mysql-job7189 \
     creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; \
                          GRANT SELECT,INSERT,UPDATE,DELETE ON job7189_job.* TO '{{name}}'@'%';" \
     default_ttl=1h max_ttl=24h
   ```

**KHÔNG ĐƯA VÀO chương 4:** demo `vault lease revoke -prefix` — lần chạy 27/05 23:48 bị 403 (token policy không có `sys/leases/revoke-prefix`). Ghi vào §4.6 là *"Demo revoke end-to-end yêu cầu một root token hoặc policy admin chưa cấp cho session test — sẽ bổ sung khi rotation policy AppRole hoàn thiện trong phase 5.G."*

**Cách trình bày LaTeX:**

- 1 đoạn văn 5–6 câu mô tả lifecycle.
- 1 listing minted `bash` cho lệnh `vault write database/roles/...`.
- 1 listing minted `text` cho 2 đoạn output (username + agent log).
- 1 đoạn 2 câu kết: TTL ngắn → blast radius nhỏ; revoke demo nằm trong limitations.

**Screenshot bổ trợ (khuyến nghị mạnh):**

- `images/ch4_vault_ui_leases.png` — Vault UI (port-forward 8200, login UI), trang **Access → Leases → database/creds**. Cap thấy ≥ 3 lease đang active với TTL countdown.
- Hoặc `images/ch4_vault_cli_leases.png` — terminal `vault list sys/leases/lookup/database/creds/job-service` với 3-5 lease ID hiện tại.

---

## 6. §4.3.5 Image admission (Cosign + Gatekeeper)

**NIST tenet:** 1, 7.

**Setup:**

- Sigstore policy-controller webhook 1/1 Running ở `cosign-system`.
- 3 ClusterImagePolicy:
  - `zta-job7189-apps-signed` (yêu cầu chữ ký zta-platform-team) — áp cho 7 service nhà.
  - `zta-keyless-trust-job7189` (verify keyless qua Sigstore TUF).
  - `zta-system-passthrough` (cho phép system image).
- OPA Gatekeeper bổ sung 3 ConstraintTemplate + Constraint `block-latest-tag` (deny), `image-digest-required` (audit) — chốt thêm policy về tag/digest.

**Bằng chứng (lấy từ `scenario-08-adaptive-trust-loop-20260527-234755.txt`):**

Lệnh `kubectl annotate pod` vô tình trigger webhook revalidate toàn bộ image trong pod hiện hữu → sinh ra chuỗi `Warning:`:

```
Warning: failed policy: zta-job7189-apps-signed: spec.containers[2].image
Warning: 100.74.189.43:5000/job7189/identity-service@sha256:b908...
  signature key validation failed for authority zta-cosign-key:
  Get "https://100.74.189.43:5000/v2/":
  http: server gave HTTP response to HTTPS client
Warning: failed policy: zta-job7189-apps-signed: spec.containers[3].image, ...
Warning: index.docker.io/hashicorp/vault:1.21.2@sha256:eb0b...
  signature key validation failed: no signatures found
Warning: index.docker.io/library/alpine:3.18@sha256:de0e...
  signature key validation failed: no signatures found
Warning: index.docker.io/library/busybox:1.36@sha256:73aa...
  signature key validation failed: no signatures found
pod/identity-service-769b979c65-nzt5f annotated
```

**Phải nói thẳng trong chương:** webhook đang ở **WARN mode** (không phải
ENFORCE) — vì vậy annotate vẫn thành công kèm Warning. Điều này hợp lệ về
mặt thiết kế (giai đoạn rollout: phát hiện trước, enforce sau khi đã ký
image upstream).

**Quan sát "ngoài kế hoạch" đáng đưa vào chương:**

1. `http: server gave HTTP response to HTTPS client` → registry nội bộ
   `100.74.189.43:5000` đang serve HTTP, Cosign muốn HTTPS. Đưa vào §4.6
   limitations: hoặc cấu hình registry TLS, hoặc thêm `--allow-http-registry`
   trong policy-controller flags.
2. Vault/Alpine/Busybox: `no signatures found` → policy `zta-job7189-apps-signed`
   áp blanket cho toàn pod, nhưng các image upstream không ký theo chữ ký
   của team. Cần: hoặc thêm authority `static` riêng cho từng image upstream,
   hoặc dùng keyless verifier để Sigstore TUF lookup chính thức.

**Cách trình bày LaTeX:**

1. 1 đoạn văn 4 câu mô tả setup 3 CIP + 2 Gatekeeper Constraint.
2. 1 listing minted `text` cho 6 dòng Warning (cắt còn ~10 dòng).
3. 1 bảng 3 cột: *Image | Policy | Verdict* — 4 hàng cho 4 image (identity-service, vault, alpine, busybox).
4. 1 đoạn 3 câu kết: ý nghĩa kết quả + bước tiếp (chuyển từ WARN → ENFORCE).

**Screenshot bổ trợ (khuyến nghị):**

- `images/ch4_kubectl_describe_pod_warnings.png` — terminal `kubectl -n job7189-apps describe pod identity-service-...` cap phần *Events:* hiển thị các Warning.

---

## 7. §4.3.6 PDP adaptive trust (foundation only)

**NIST tenet:** 3 (kết nối được cấp theo phiên + điều kiện), 6.

**Setup:**

- Deployment `zta-pdp` trong `security` namespace, image `python:3.11-slim`, 1/1 replica.
- `PDP_CVE_INPUT=false` (rollout pending — snapshot 27/05).
- 45 Trivy `VulnerabilityReport` CR đã thu thập sẵn (xem `kubectl get vulnerabilityreport -A`).

**Bằng chứng (lấy từ `scenario-08-adaptive-trust-loop-20260527-234755.txt`):**

1. **PDP đang chạy ổn định, reconcile loop định kỳ:**
   ```
   {"ts":"2026-05-27T16:16:18Z","lvl":"INFO","comp":"pdp","event":"reconcile-complete","namespaces":7}
   {"ts":"2026-05-27T16:17:55Z","lvl":"INFO","comp":"pdp","event":"reconcile-complete","namespaces":7}
   ...
   ```
   Mỗi ~90s 1 lần, 7 namespace (job7189-apps + 6 datastore/security).

2. **Annotate giả lập CVE critical → 70s sau bucket không đổi (đúng như thiết kế hiện tại):**
   ```
   $ kubectl annotate pod identity-service-... zta.job7189/simulated-cve-critical=true
   pod/identity-service-769b979c65-nzt5f annotated
   ...
   $ kubectl get pod identity-service-... -o jsonpath='...bucket={...score-bucket}  score={...trust-score}'
   identity-service-769b979c65-nzt5f  bucket=high  score=100
   ```

3. **CNP `cnp-block-low-trust-to-vault` chưa được apply:**
   ```
   $ kubectl get cnp cnp-block-low-trust-to-vault -o yaml
   [exit=0]   # ← không có output = resource không tồn tại
   ```

**Phải nói thẳng:** đây là **bằng chứng âm trung thực**. Cấu phần PDP +
input đầu vào (Trivy VR) đã sẵn sàng; chỉ chờ `PDP_CVE_INPUT=true` và
apply CNP `cnp-block-low-trust-to-vault` để vòng feedback đóng. Không
được nguỵ tạo dữ liệu kiểu *"sau 70s bucket chuyển sang low"*.

**Cách trình bày LaTeX:**

1. 1 sơ đồ TikZ (hoặc PNG) cho vòng feedback: `Trivy VR → PDP score → annotation+label → CNP enforce`. Có thể tận dụng hình đã vẽ trong `doc/architecture/`.
2. 1 đoạn 4–5 câu mô tả vòng lặp dự kiến.
3. 1 listing minted `json` cho 3–4 dòng PDP log reconcile.
4. 1 listing minted `text` cho lệnh annotate + kết quả bucket không đổi.
5. 1 đoạn kết 2 câu: liên kết tới §4.6 limitations (PDP_CVE_INPUT=false là quyết định rollout).

**Screenshot bổ trợ:**

- `images/ch4_grafana_pdp_score.png` — nếu có Grafana panel cho metric `pdp_trust_score` hoặc `pdp_reconcile_total`.
- *Optional*: `images/ch4_pdp_logs_kibana.png` — Kibana query `kubernetes.container.name:"pdp-controller" AND event:"reconcile-complete"`.

---

## 8. §4.4 Kết quả conformance test L3/L4

**Mục tiêu:** show bảng P (positive — phải allow) / N (negative — phải drop)
đã chạy trước đây, tham chiếu snapshot 27/05.

**Lấy từ:** snapshot 27/05 mục "Conformance test 88 cases (68 PASS / 1 FAIL / 19 WARN)" và `evidence/cilium-policies-20260527_212517.txt`.

**Cách trình bày LaTeX:**

- 1 bảng `tabularx` 4 cột: *ID | Mô tả | Kỳ vọng | Kết quả*.
- 6–8 hàng đại diện (3 P + 4 N), không liệt kê hết 88.
- Caption: *"Trích kết quả conformance L3/L4 đối chiếu 27/05/2026; danh sách đầy đủ trong Phụ lục A."*
- Liệt kê đầy đủ 88 test trong Phụ lục A (chương riêng), KHÔNG nhét vào Chương 4.

**Hàng FAIL duy nhất:** ghi tên test cụ thể, root cause (chính là một
trong các limitations §4.6), không che giấu.

---

## 9. §4.5 Phân tích & thảo luận

**Mục tiêu:** đối chiếu với 7 NIST tenet (SP 800-207); đánh giá tổng overhead;
nêu các "ngoài kế hoạch nhưng có ý nghĩa" đã thu được.

**Bảng tenet mapping (bắt buộc):**

| Tenet | Cơ chế cài đặt | Bằng chứng (kịch bản) |
|---|---|---|
| T1 — All resources = data sources | Cosign + ServiceAccount + Vault | §4.3.4, §4.3.5 |
| T2 — Secure all communications | Tailscale L3 + Cilium L4/L7 + Kong TLS | §4.3.1, §4.3.2 |
| T3 — Per-session access | JWT + OPA + Vault dynamic | §4.3.2, §4.3.4 |
| T4 — Dynamic policy | CNP + Tetragon Post + PDP foundation | §4.3.1, §4.3.2, §4.3.3, §4.3.6 |
| T5 — Continuous monitoring | EFK + Hubble + Tetragon export | §4.3.1, §4.3.3 |
| T6 — Continuous authn/authz | Vault renew + Tetragon kprobe + PDP reconcile | §4.3.3, §4.3.4, §4.3.6 |
| T7 — Posture for security improvement | Trivy + PDP scoring + audit log | §4.3.5, §4.3.6 |

**Overhead (chưa có số đo end-to-end thật):** chỉ nêu định tính ("Kong+OPA
warm-path < 5ms theo doc/24" — nếu có file đó), KHÔNG bịa số P50/P95/P99.

---

## 10. §4.6 Giới hạn & hướng phát triển (BẢNG bắt buộc)

| Hạng mục | Trạng thái 27/05 | Hướng xử lý |
|---|---|---|
| OPA decision log | Chưa cấu hình `decision_logs`; chỉ có pod 2/2 Running | Bật `--set decisionLogs.console=true` hoặc sidecar collector; demo `opa eval` offline trong Phụ lục B |
| Threat-intel feed CronJob | `threat-intel-refresh` đã chạy nhưng `externalCIDRs:[]` rỗng | Debug template parsing trong CronJob; bổ sung test unit cho parser. Phase 5.G |
| Cosign mode | WARN (Warning sinh ra, không deny) | Sau khi ký Hashicorp/Alpine/Busybox bằng `static` authority → bật ENFORCE |
| Registry nội bộ TLS | Serve HTTP, Cosign từ chối HTTPS | Cấp cert qua cert-manager hoặc whitelist `--allow-http-registry` |
| Tetragon action | `Post` (audit-only) | Phase 5.E: upgrade v1.7.0 kernel 6.8 → bật `Sigkill` kèm `matchBinaries` whitelist (php-fpm, vault, supervisord) |
| Cilium ServiceMesh mTLS | `mesh-auth-enabled=false` — Tailscale lo L3 | Phase 5.F: bật sidecarless mTLS sau khi xác minh SPIRE-Cilium integration không break |
| PDP CVE input | `PDP_CVE_INPUT=false`, CNP block-low-trust-to-vault chưa apply | Phase 5.D: bật flag sau khi backfill score cho 7 service và test rollback |
| Vault revoke demo | Token test không có policy `sys/leases/revoke-prefix` | Phase 5.G: tạo AppRole `zta-ops-revoker` với policy giới hạn |

---

## 11. Chương 3 — Cập nhật trước khi viết Chương 4

Trước khi viết Chương 4, Chương 3 cần khớp với snapshot 27/05. Các điểm
phải sửa (KHÔNG cần re-run script, chỉ đối chiếu evidence S0):

| Mục §3 | Sửa gì | Lý do |
|---|---|---|
| Identity / SPIRE | Ghi rõ 10 ClusterSPIFFEID hiện tại (3 zta-* + 7 spike/oidc); nêu thẳng `mesh-auth-enabled=false`, SPIRE phục vụ policy/audit, Tailscale lo L3 | Khớp `scenario-00` |
| Vault | Thay ví dụ chung chung bằng pattern thật `v-kubernetes-<service>-XXXXXX`; ghi TTL 1h/24h; nêu agent renew log hiện thực | Khớp `scenario-04` |
| Cilium policies | Liệt kê 11 CNP/job7189-apps + 1 CCNP + 1 CIDRGroup; in YAML `default-deny-all` (umbrella-deny marker) trực tiếp trong chương, không bắt người đọc mở repo | Khớp `scenario-00`, `scenario-01` |
| Tetragon | Nói thẳng action=Post (audit-only) + lý do quyết định 2026-05-20; liệt kê 7 binary; tham chiếu doc TETRAGON_UPGRADE.md cho phase 5.E (không trích file path repo, chỉ tên doc) | Khớp `scenario-00`, `scenario-03` |
| OPA + Kong | Mô tả luồng Lua → POST OPA → Rego (6 file, default aggregator + 5 resource); KHÔNG show decision log (chưa có decisionLogs); chú thích sẽ demo offline `opa eval` ở Phụ lục B | Khớp `scenario-00`, §4.6 |
| Cosign | 3 ClusterImagePolicy + webhook 1/1 Running; nói rõ đang ở WARN mode; 5 image upstream chưa ký được nêu ở Chương 4 §4.3.5 | Khớp `scenario-08` |
| PDP | Deployment Running, reconcile 90s, namespaces:7, `PDP_CVE_INPUT=false`, CNP block-low-trust-to-vault chưa apply (rollout pending) | Khớp `scenario-08` |
| **Style — bỏ tham chiếu file path repo trong văn bản** | Thay `infras/k8s-yaml/cilium-policies/00-default-deny.yaml` bằng `CiliumNetworkPolicy default-deny-all` (tên tài nguyên Kubernetes). Khi cần show YAML, in trực tiếp 8–15 dòng vào chương | Yêu cầu của người dùng |

---

## 12. Checklist trước khi viết LaTeX

- [ ] Đã đọc lại 8 file `evidence/chapter4/scenario-*-20260527-234714.txt` (và `-234755.txt`).
- [ ] Đã quyết định scope: 6 demo + 8 hàng limitations.
- [ ] Đã copy YAML rút gọn (8–15 dòng/policy) ra notebook tạm để paste vào chương.
- [ ] Đã `jq` format JSON Tetragon event xuống 6–8 field.
- [ ] (Tuỳ chọn) Đã cap 4–6 ảnh: Hubble UI drops, Kibana Tetragon, Vault leases, kubectl describe Warning. Đặt vào `documents/latex/images/` với tên `ch4_*.png`.
- [ ] Mở Chương 3 + Chương 4 cùng lúc, sửa Chương 3 trước (đối chiếu §11 ở trên), rồi viết Chương 4 từ trên xuống §4.1 → §4.6.
- [ ] KHÔNG bịa: bất kỳ con số/log nào không truy được trong `evidence/*` hoặc `doc/40-*` đều phải bị xoá hoặc chuyển sang §4.6 limitations.
- [ ] Build PDF (`docker compose run --rm latex`), sửa lint LaTeX, commit, mở PR.
