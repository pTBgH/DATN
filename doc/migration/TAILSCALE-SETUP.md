# Tailscale setup — từ A tới Z

> Bạn nói "Mình chưa hiểu cái này, hướng dẫn qua file .md nhé" — đây
> là hướng dẫn step-by-step để có:
>
> 1. Tailnet domain (`<your-name>.ts.net`)
> 2. Auth key reusable với tag `tag:zta-cluster`
> 3. ACL cho phép user `ptb` SSH qua Tailscale (optional)
> 4. Tailscale chạy trên Ubuntu host + 4 VM
>
> Hoàn thành file này → có đủ giá trị để fill vào `config.env`.

---

## 0. Tailscale là gì? Tại sao cần?

**Tailscale** = mesh VPN dựa trên WireGuard, tự động NAT-traversal,
quản lý qua web console.

Trong setup multi-VM của bạn:
- **Vấn đề**: 3 VM trên Windows host (192.168.171.0/24 NAT) và 1 VM trên
  Ubuntu host (192.168.122.0/24 NAT) **KHÔNG tự nói chuyện được với
  nhau** vì khác mạng VMware NAT.
- **Giải pháp**: cài Tailscale lên cả 4 VM → Tailscale gán mỗi VM một
  IP `100.64.x.y` (CGNAT). Tất cả pod K8s/etcd/apiserver/Cilium VXLAN
  bind vào IP Tailscale → cross-host traffic auto-encrypt qua WireGuard.

Free tier Tailscale cho 100 device — quá đủ cho 4 VM + 1 admin laptop +
1 Ubuntu host = 6 device.

---

## 1. Đăng ký tài khoản Tailscale

1. Mở https://login.tailscale.com/start
2. Chọn provider OIDC để login: **Google** (dễ nhất, dùng tài khoản
   Gmail của bạn). Hoặc Microsoft, GitHub, Okta đều OK.
3. Sau khi login lần đầu, Tailscale tự tạo cho bạn một **tailnet** với
   tên dạng `tail-xyz12.ts.net` (auto-generated).
4. Lúc này bạn là **owner** của tailnet — có quyền admin tất cả.

---

## 2. Lấy tên tailnet (= TAILNET_DOMAIN)

1. Vào https://login.tailscale.com/admin/dns
2. Phần "Tailnet name" hiển thị tên dạng `tail-xyz12.ts.net`. Đây là
   `TAILNET_DOMAIN` của bạn.
3. (Optional) Nếu muốn đổi sang tên đẹp hơn (ví dụ `bpt-zta.ts.net`):
   - Click "Rename tailnet"
   - Gõ tên mới (chỉ khi còn available; chỉ đổi được 1 lần / 6 tháng)
   - Confirm

→ Note tên này, sẽ dùng cho:
- `config.env`: `TAILNET_DOMAIN="tail-xyz12.ts.net"`
- SSH: `ssh ptb@7189srv01.tail-xyz12.ts.net`
- certSANs trong `kubeadm-config.yaml` (script tự render)

---

## 3. Tạo auth key reusable

Auth key cho phép VM tự động join tailnet mà không cần login OIDC từng
máy một. Bạn cần 1 key reusable.

1. Vào https://login.tailscale.com/admin/settings/keys
2. Click **"Generate auth key..."**
3. Cấu hình:

| Trường | Giá trị | Lý do |
|--------|---------|-------|
| **Reusable** | ☑️ ON | Để dùng cùng key cho 4 VM (không cần tạo 4 key) |
| **Ephemeral** | ☐ OFF | Ephemeral = node biến mất khi offline. Bạn muốn 4 VM persistent. |
| **Pre-approved** | ☑️ ON | (Nếu tailnet bật device approval) auto-approve VM, không cần admin click duyệt |
| **Tags** | `tag:zta-cluster` | Bắt buộc. Script `01-host-prep.sh` dùng `--advertise-tags=tag:zta-cluster` |
| **Expiration** | 90 days | Mặc định OK. Có thể chọn None (không expire) cho lab. |
| **Description** | `zta-cluster reusable key` | Để tự nhớ |

4. **Trước khi click "Generate"**, Tailscale yêu cầu bạn DEFINE
   `tag:zta-cluster` trong ACL. Nếu chưa có → đi qua bước 4 (ACL) trước,
   rồi quay lại bước này.

5. Click "Generate auth key" → output dạng `tskey-auth-XXXXXXXXXXXX-YYYYYYYYYYYYYYYYYYYY`.
   **COPY NGAY** — Tailscale chỉ show 1 lần. Lưu vào nơi an toàn (1Password,
   Bitwarden, GPG file).

→ Note key này, sẽ dùng cho:
- `config.env`: `TS_AUTHKEY="tskey-auth-XXXX..."`
- (KHÔNG commit vào git! `config.env.example` không chứa key thật.)

---

## 4. Cấu hình ACL (`tag:zta-cluster`)

ACL trên Tailscale là JSON-with-comments controlling ai-được-nói-chuyện-với-ai.

1. Vào https://login.tailscale.com/admin/acls/file
2. Editor mở ra với nội dung default. Edit thành:

```jsonc
{
  // Ai sở hữu (apply) tag nào
  "tagOwners": {
    "tag:zta-cluster": ["autogroup:admin"]
  },

  // Ai nói chuyện được với ai
  "acls": [
    // Mọi node trong tailnet có thể nói chuyện với nhau (lab convenience)
    {
      "action": "accept",
      "src":    ["*"],
      "dst":    ["*:*"]
    }
  ],

  // (Optional) Tailscale SSH — cho phép user 'ptb' SSH vào tag:zta-cluster
  // Bỏ "ssh" block này nếu không dùng `tailscale up --ssh`
  "ssh": [
    {
      "action": "accept",
      "src":    ["autogroup:admin"],
      "dst":    ["tag:zta-cluster"],
      "users":  ["ptb", "root"]
    }
  ]
}
```

3. Click **"Save"** → Tailscale validate JSON, nếu syntax ok thì áp dụng.

> **Note**: ACL `acls: ["*:*"]` là wide-open (lab-grade). Trong production
> bạn sẽ siết lại theo nguyên tắc least-privilege. Cho thesis lab,
> wide-open chấp nhận được vì đã có Cilium NetworkPolicy + Tetragon
> TracingPolicy làm L4-L7 enforcement bên trong cluster.

> **`users`: `["ptb"]`** — đây là user Linux thực tế trên VM. Khi bạn
> ssh `ptb@7189srv01.tail-xyz.ts.net` qua Tailscale SSH, ACL này cho
> phép. Đổi sang `["debian"]` hoặc `["7189"]` nếu bạn dùng tên khác.

→ Sau khi save ACL: quay lại **bước 3** generate auth key (nếu chưa có).

---

## 5. Cài Tailscale trên Ubuntu host

Đây là máy vật lý 8 GB chạy VM srv04. Cần Tailscale ở host (KHÔNG ở VM)
để host làm Docker registry server.

```bash
# Trên Ubuntu HOST (KHÔNG trong VM)
curl -fsSL https://tailscale.com/install.sh | sh

# Auth lần đầu (KHÔNG dùng auth key — host chỉ cần là device cá nhân)
sudo tailscale up --hostname=ubuntu-host --accept-dns=true
# Tailscale in ra URL → mở trên browser → login → "Connect"

# Verify
tailscale ip -4
# Expected: 100.64.x.y (số tùy)

tailscale status
# Expected: list các device khác trong tailnet
```

→ Note Tailscale IP của Ubuntu host → dùng cho registry
(`REGISTRY_DECISION.md` bước 1).

---

## 6. Cài Tailscale trên 4 VM (qua script `01-host-prep.sh`)

Script `01-host-prep.sh` đã tự cài + auth nếu bạn cung cấp `TS_AUTHKEY`
trong `config.env`.

### 6a. Edit `config.env`

```bash
cd ~/DATN
cp doc/migration/scripts/config.env.example doc/migration/scripts/config.env
nano doc/migration/scripts/config.env
```

Sửa 2 dòng quan trọng:
```bash
TAILNET_DOMAIN="tail-xyz12.ts.net"        # từ bước 2
TS_AUTHKEY="tskey-auth-XXXXX..."          # từ bước 3
```

(Không cần thêm gì khác cho lần chạy đầu.)

> **Bảo mật**: `config.env` chứa auth key. KHÔNG commit vào git.
> File `.gitignore` (đã/sẽ có) phải include `config.env`.

### 6b. Chạy 01-host-prep.sh trên mỗi VM

```bash
# Trên srv01:
sudo HOSTNAME_OVERRIDE=7189srv01 -E bash doc/migration/scripts/01-host-prep.sh

# Trên srv02:
sudo HOSTNAME_OVERRIDE=7189srv02 -E bash doc/migration/scripts/01-host-prep.sh

# Trên srv03/04 tương tự...
```

Script sẽ:
1. apt-get install tailscale
2. `tailscale up --auth-key=$TS_AUTHKEY --advertise-tags=tag:zta-cluster --hostname=$(hostname)`
3. Verify `tailscale ip -4` returns IP

### 6c. Verify

```bash
# Trên admin laptop hoặc Ubuntu host:
tailscale status

# Expected output dạng:
# 100.64.10.1   7189srv01            ptb@         linux   active; relay "sin", tx 1234 rx 5678
# 100.64.10.2   7189srv02            ptb@         linux   active
# 100.64.10.3   7189srv03            ptb@         linux   active
# 100.64.10.4   7189srv04            ptb@         linux   active
# 100.64.10.5   ubuntu-host          you@         linux   active
# 100.64.10.6   admin-laptop         you@         linux   active

# Ping cross-host:
tailscale ping 7189srv01
# Expected: "pong from 7189srv01 ... via DERP <region>"
```

---

## 7. Làm rõ thuật ngữ

| Thuật ngữ | Ý nghĩa | Ví dụ |
|-----------|--------|-------|
| **Tailnet** | Mạng riêng trong Tailscale (= VPN của bạn) | `tail-xyz12.ts.net` |
| **Tailnet domain** | DNS suffix Tailscale tự gán | `<vm-name>.tail-xyz12.ts.net` |
| **Tailscale IP** | IP CGNAT 100.64.0.0/10 mỗi device được gán | `100.64.10.1` |
| **MagicDNS** | Tailscale tự resolve `<hostname>.ts.net` | `ssh 7189srv01` ⇒ resolves to `100.64.10.1` |
| **Tag** | Nhãn gán cho device, dùng trong ACL | `tag:zta-cluster` |
| **Auth key** | Token để device join tailnet không cần OIDC | `tskey-auth-XXXX` |
| **ACL** | JSON ruleset điều khiển traffic giữa node | `acls: [{action: accept, src: ..., dst: ...}]` |
| **DERP** | Tailscale's relay server (fallback khi NAT cứng đầu) | "via DERP sin" |

---

## 8. Troubleshooting

### "tailscale up: failed: invalid auth key"

- Auth key sai hoặc đã expire / đã bị revoke
- Solution: regenerate ở https://login.tailscale.com/admin/settings/keys

### "could not advertise tag — tag:zta-cluster not authorized"

- ACL chưa define `tagOwners["tag:zta-cluster"]`
- Solution: bước 4 ACL

### `tailscale status` không thấy device khác

- Có thể device kia chưa connect hoặc bị admin block
- Vào https://login.tailscale.com/admin/machines kiểm tra

### `ping 7189srv02` từ srv01 fail nhưng `tailscale ping` OK

- DNS chưa resolve. Check `/etc/resolv.conf` có IP của Tailscale
  (100.100.100.100):
  ```bash
  cat /etc/resolv.conf
  # Phải có dòng: nameserver 100.100.100.100
  ```
- Nếu thiếu: `sudo tailscale up --accept-dns=true`

### Cluster pod không nói chuyện được sau khi join

- Cilium VXLAN dùng UDP port 8472 — Tailscale ACL phải allow
- Kiểm tra ACL có `acls: [{action: accept, src: ["*"], dst: ["*:*"]}]`
- Nếu siết hơn, phải allow port 8472 UDP giữa các tag:zta-cluster node

### Muốn revoke 1 VM khỏi tailnet

- Vào https://login.tailscale.com/admin/machines
- Click VM → "Remove"
- Trên VM đó: `sudo tailscale logout`

### Auth key bị leak

- IMMEDIATELY revoke ở https://login.tailscale.com/admin/settings/keys
- Generate key mới, update `config.env` trên 4 VM, re-run
  `01-host-prep.sh` (idempotent — sẽ chỉ re-auth không cài lại từ đầu)

---

## 9. Checklist sau khi xong

- [ ] Có `TAILNET_DOMAIN` (vd `tail-xyz12.ts.net`)
- [ ] Có `TS_AUTHKEY` (`tskey-auth-...`) lưu trong password manager
- [ ] ACL có `tagOwners: {"tag:zta-cluster": ["autogroup:admin"]}`
- [ ] ACL có `ssh` block với `users: ["ptb"]` (nếu dùng Tailscale SSH)
- [ ] Ubuntu host đã `tailscale up`, `tailscale ip -4` trả IP
- [ ] `config.env` đã fill (KHÔNG commit)
- [ ] `01-host-prep.sh` đã chạy trên 4 VM, mỗi VM có IP Tailscale
- [ ] `tailscale status` từ admin laptop thấy đủ 6 device

→ Nếu tất cả PASS, sẵn sàng chạy `02-control-plane-init.sh`.

---

## 10. Tóm tắt cho lazy reading

```
1. login.tailscale.com → Sign up qua Google
2. /admin/dns → copy "Tailnet name" → set TAILNET_DOMAIN
3. /admin/acls/file → save ACL với tag:zta-cluster + ssh users: [ptb]
4. /admin/settings/keys → Generate reusable, pre-approved, tag:zta-cluster
                       → copy "tskey-auth-..." → set TS_AUTHKEY
5. Cài tailscale trên Ubuntu host (sudo tailscale up; OIDC login)
6. Edit config.env với TAILNET_DOMAIN + TS_AUTHKEY
7. sudo bash 01-host-prep.sh trên 4 VM
8. tailscale status → verify 6 device active
```

Free tier 100 device — không lo limit.
