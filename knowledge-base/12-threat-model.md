# Threat Model — Attack Paths & MITRE ATT&CK

> **Cảnh báo drift:** trạng thái cluster chuẩn mới nhất xem
> `00-SYSTEM-SNAPSHOT.md` (2026-06-20). Dòng Tetragon/mTLS cũ đã được reconcile.

## Be mat tan cong Microservices

| Dac diem | Mo ta | Bien phap ZTA |
|----------|-------|---------------|
| Khung hoang dinh danh | 7 service giao tiep noi bo, IP khong co dinh | SPIFFE SVID + Vault K8s Auth |
| Secrets Sprawl | Mat khau DB, API keys de bi bo quen trong .env | Vault JIT, TTL 1h, tmpfs |
| Ha tang dung chung | Nhieu container chung 1 node | Microseg + resource isolation |

## Bang de doa va doi pho

| De doa | Mo ta | Co che ZTA | Trang thai |
|--------|-------|------------|------------|
| Credential Theft | Danh cap mat khau tu file .env | Vault JIT: credential tam thoi, TTL 1h | ✅ |
| Token Theft / AiTM | Danh cap JWT qua Adversary-in-the-Middle | CAEP + Device Binding | ❌ Chua co |
| Living off the Land | Lam dung cong cu he thong (curl, sh, bash) | Tetragon eBPF chặn syscall | ✅ Sigkill enforce |
| Lateral Movement | Di chuyen ngang sau khi chiem 1 service | Cilium Default Deny + microseg | ✅ |
| Privilege Escalation | Leo thang tu role thap len admin | ABAC + xac thuc lai lien tuc | ⚠️ Partial |
| Data Exfiltration | Day du lieu ra Internet | Egress Filtering tai kernel | ✅ |

## MITRE ATT&CK Mapping cho Kubernetes

| Giai doan | Ky thuat K8s | Lop ZTA phong thu | Trang thai |
|-----------|-------------|-------------------|------------|
| Initial Access | Tai khoan hop le bi lo (T1078), API cong khai | PEP Bien: Kong JWT + MFA | ✅ |
| Execution | Chay ma doc trong container (T1609) | PEP Runtime: Tetragon chan syscall | ✅ Sigkill enforce |
| Persistence | Ghi de hostPath, tao CronJob (T1053) | CDM + Read-only filesystem | ⚠️ |
| Lateral Movement | Quet service noi bo, cong dang mo | PEP Mang: Cilium L3/L4/L7 + SPIFFE | ✅ |
| Exfiltration | Gui du lieu ra server ngoai | Egress Filtering | ✅ |

## Attack Path Matrix — Truoc/Sau ZTA

| Attack Vector | Blast Radius (Truoc) | Muc do | Sau ZTA |
|---------------|---------------------|--------|---------|
| .env credential leak | Toan bo MySQL databases | Nghiem trong | Vault JIT: het han 1h, chi 1 DB |
| Pod compromise (RCE) | Lateral movement moi service | Nghiem trong | Cilium Deny: Pod co lap |
| API khong xac thuc | Truy cap trai phep du lieu | Cao | Kong JWT: route nham cam yeu cau token |
| No network segmentation | Quet toan bo internal network | Cao | CiliumNetworkPolicy L3/L4/L7 |
| No runtime monitoring | Persistent backdoor | Cao | EFK + Hubble ghi lai moi flow |

## Khoang trong bao mat con lai

1. **CAEP**: JWT chi xac thuc 1 lan, chua thu hoi giua phien → xem `knowledge-base/15-encryption-mtls-spiffe.md`
2. **EDR/MDM**: Chua kiem tra thiet bi end-user
3. ~~**mTLS E-W**: Traffic noi bo chua ma hoa~~ → ✅ DA FIX: Cilium mesh-auth mTLS bật; Cilium WireGuard tắt vì Tailscale lo L3
4. **Tetragon Runtime**: ✅ Đã deploy v1.7.0 và enforce `Sigkill` ở 4 namespace → xem `knowledge-base/14-tetragon-runtime.md`
5. **SOAR**: Chua co tu dong phan ung (detect → terminate)
6. **Kafka**: Plaintext, chua SASL/SSL
7. **OPA server**: Logic tuong duong qua Kong+Cilium, chua deploy rieng
