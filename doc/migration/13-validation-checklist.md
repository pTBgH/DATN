# 13. Validation Checklist — verify migration thành công

> Chạy lần lượt 7 nhóm. Mỗi check: PASS / FAIL kèm hành động khi FAIL.

## 1. Hạ tầng host + Tailscale

| # | Check | Lệnh | Expected | FAIL → |
|---|-------|------|----------|--------|
| 1.1 | 4 VM lên đủ | `tailscale status` (admin laptop) | 4 host: 7189srv01..04 | Power on VM thiếu |
| 1.2 | MagicDNS resolve | `nslookup 7189srv01` | 100.64.10.1 | Bật MagicDNS trong tailnet |
| 1.3 | Cross-host ping | `tailscale ping 7189srv04` (từ 7189srv01) | direct hoặc DERP | Reset tailscaled |
| 1.4 | Clock sync | `for v in 7189srv01 7189srv02 7189srv03 7189srv04; do ssh debian@$v.<dom> "date"; done` | skew ≤ 2s | `sudo timedatectl set-ntp true` |
| 1.5 | Containerd active | `for v in ...; do ssh ...'systemctl is-active containerd'; done` | active × 4 | `systemctl restart containerd` |
| 1.6 | Kubelet active | `for v in ...; do ssh ...'systemctl is-active kubelet'; done` | active × 4 | `systemctl restart kubelet` |

## 2. Kubernetes cluster sức khỏe

| # | Check | Lệnh | Expected |
|---|-------|------|----------|
| 2.1 | API healthz | `kubectl get --raw=/healthz` | `ok` |
| 2.2 | 4 nodes Ready | `kubectl get nodes` | 4 × Ready |
| 2.3 | nodeIP đúng Tailscale | `kubectl get nodes -o wide \| awk '{print $1, $6}'` | INTERNAL-IP = 100.64.10.X |
| 2.4 | Always-on label | `kubectl get nodes --show-labels \| grep always-on` | `7189srv04` có label `zta.workload.always-on=true` |
| 2.5 | Static pods 7189srv01 | `kubectl -n kube-system get pod -o wide \| grep 7189srv01` | etcd, apiserver, controller, scheduler đều Running |
| 2.6 | metrics-server | `kubectl top nodes` | hiển thị CPU/RAM 4 node |
| 2.7 | DNS in-cluster | `kubectl run test-dns --image=alpine:3.19 --rm -it -- nslookup kubernetes.default` | resolved to 10.96.0.1 |

## 3. Cilium + connectivity

| # | Check | Lệnh | Expected |
|---|-------|------|----------|
| 3.1 | DS Ready | `kubectl -n kube-system get ds cilium` | DESIRED=4, READY=4 |
| 3.2 | Operator Running | `kubectl -n kube-system get deploy cilium-operator` | 1/1 Available |
| 3.3 | Cilium status | `cilium status` (CLI) | Cluster healthy, Encryption: disabled (đúng — Tailscale) |
| 3.4 | Hubble Relay + UI | `kubectl -n kube-system get pod -l k8s-app=hubble-relay` | Running |
| 3.5 | VXLAN tunnel | `kubectl -n kube-system exec ds/cilium -- cilium status \| grep -A1 Datapath` | Tunnel: vxlan, Encapsulation: vxlan |
| 3.6 | Pod-to-pod cross-node | `cilium connectivity test` | All except external pass |
| 3.7 | KubeProxyReplacement | `kubectl -n kube-system exec ds/cilium -- cilium status \| grep KubeProxyReplacement` | True |

## 4. Storage + registry

| # | Check | Lệnh | Expected |
|---|-------|------|----------|
| 4.1 | StorageClass `standard` default | `kubectl get sc` | (default) standard |
| 4.2 | local-path-provisioner Running | `kubectl -n local-path-storage get pod` | Running |
| 4.3 | PVC create + bind | (smoke test trong 09 §8) | Pod nginx Ready với volume |
| 4.4 | Registry Service Reachable | `curl -s http://7189srv04.<dom>:30005/v2/_catalog` | JSON `{"repositories": [...]}` |
| 4.5 | Containerd hosts.toml present | `for v in ...; do ssh ...'ls /etc/containerd/certs.d/'; done` | 4 dirs với hosts.toml |

## 5. ZTA stack — phase 1 (base, sau `02-infra` + `03-microservices`)

| # | Check | Lệnh | Expected |
|---|-------|------|----------|
| 5.1 | MySQL on 7189srv04 | `kubectl -n data get pod -o wide` | mysql-0 trên 7189srv04 |
| 5.2 | Vault initialized | `kubectl -n vault exec vault-0 -- vault status` | Initialized: true (Sealed: true sau restart là OK) |
| 5.3 | Keycloak realm `job7189` | `curl -s http://keycloak.security:8080/realms/job7189` | JSON realm |
| 5.4 | 7 Laravel pod Running | `kubectl -n job7189-apps get pod` | 7 deployment, mỗi deploy ≥ 1 Running |
| 5.5 | Kong DB-less Ready | `kubectl -n gateway get pod -l app=kong` | Running |
| 5.6 | Ingress reachable | `curl -k https://<any-worker>.<dom>:30001/` | HTTP 200 hoặc 404 (không 5xx) |

## 6. ZTA stack — phase 2 (full enforcement, sau `08-harden`+`10-tetragon`)

| # | Check | Lệnh | Expected |
|---|-------|------|----------|
| 6.1 | mesh-auth enabled | `kubectl -n kube-system exec ds/cilium -- cilium status \| grep -i mutual` | Mutual auth: enabled |
| 6.2 | WireGuard disabled (ext) | `kubectl -n kube-system exec ds/cilium -- cilium status \| grep -i encryption` | Encryption: disabled (Tailscale handles) |
| 6.3 | Tetragon DS Ready | `kubectl -n kube-system get ds tetragon` | 4/4 Ready |
| 6.4 | TracingPolicy applied | `kubectl get tracingpolicy` | ≥ 1 policy |
| 6.5 | SPIRE server Ready | `kubectl -n spire get pod` | spire-server-0 Running, agents 4/4 |
| 6.6 | SPIRE workload registration | `kubectl -n spire exec spire-server-0 -- /opt/spire/bin/spire-server entry show -socketPath /tmp/spire-server/private/api.sock \| head` | ≥ 5 entries |
| 6.7 | Gatekeeper constraints | `kubectl get constraints -A` | ≥ 5 constraints |
| 6.8 | Cosign policy enforced | `kubectl describe clusterpolicy required-image-signatures` | Active |
| 6.9 | Hubble export running | `kubectl -n kube-system get pod -l app=hubble-export-shipper` | Running |
| 6.10 | Cilium Network Policies | `kubectl get cnp -A` | ≥ 10 policies |

## 7. Demo scenarios (xem `doc/architecture/ZTA_DEMO_SCENARIOS.md`)

| # | Demo | Lệnh | Expected |
|---|------|------|----------|
| 7.1 | Default-deny | `kubectl run untrusted --image=alpine:3.19 -n default --command -- wget -qO- mysql.data:3306` | timeout |
| 7.2 | mTLS required | (xem chap 28) | Connect from non-SPIFFE pod fail |
| 7.3 | Tetragon kill suspicious | `kubectl exec -it <pod> -- /tmp/exploit` | TracingPolicy KillProcess fires |
| 7.4 | Vault JIT secret | `kubectl exec -it identity-svc-0 -- cat /vault/secrets/db-creds` | Token ngắn hạn (TTL 15m) |
| 7.5 | Hubble drop count | `hubble observe --verdict DROPPED -n 50` | ≥ 5 drops từ test 7.1 |
| 7.6 | Threat intel block | `curl http://malicious-ip` từ pod | denied + log |
| 7.7 | Image signature gate | `kubectl run unsigned --image=docker.io/test:latest` | denied bởi Cosign policy |

## 8. Resource posture

| # | Check | Lệnh | Expected |
|---|-------|------|----------|
| 8.1 | RAM utilization < 90% mỗi node | `kubectl top node` | mỗi node < 90% |
| 8.2 | Không có OOMKilled trong 1h | `kubectl get pod -A \| awk '$4 ~ /OOMKilled/'` | empty |
| 8.3 | etcd healthy | `kubectl -n kube-system exec etcd-7189srv01 -- etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint health` | healthy |
| 8.4 | apiserver request latency p99 | `kubectl get --raw '/metrics' \| grep apiserver_request_duration_seconds_bucket\|tail` | p99 < 1s |
| 8.5 | Disk usage < 80% | `for v in ...; do ssh ...'df -h /'; done` | mỗi VM < 80% |

## 9. Báo cáo (cho thesis)

Sau khi pass tất cả checks, sinh evidence:

```bash
mkdir -p evidence/migration-final-$(date +%F)
cd evidence/migration-final-$(date +%F)

# 1. Cluster snapshot
kubectl get nodes -o wide > 01-nodes.txt
kubectl get pod -A -o wide > 02-pods.txt
kubectl top nodes > 03-top-nodes.txt
kubectl top pod -A > 04-top-pods.txt

# 2. ZTA verify
bash ../../09-verify-zta.sh > 05-verify.txt 2>&1
cp -r ../../evidence/$(ls -t ../../evidence | head -1) 06-verify-bundle/

# 3. Hubble flows last hour
hubble observe --since 1h > 07-hubble.jsonl

# 4. Tailscale state
for v in 7189srv01 7189srv02 7189srv03 7189srv04; do
  ssh debian@$v.<tailnet>.ts.net 'tailscale status; tailscale ip -4'
done > 08-tailscale.txt

# 5. SPIRE entries
kubectl -n spire exec spire-server-0 -- /opt/spire/bin/spire-server entry show -socketPath /tmp/spire-server/private/api.sock > 09-spire.txt

# 6. Cilium status
cilium status --verbose > 10-cilium.txt

# Tar lại để gửi advisor
cd ..
tar czf migration-final-evidence-$(date +%F).tar.gz migration-final-$(date +%F)/
```

## 10. Kết luận

Nếu §1-§8 PASS hết:
- ✅ Migration thành công
- Cluster đã isolate kernel pressure → 3 incident OOM cũ không còn khả năng
  xảy ra dưới điều kiện ZTA-stack đầy đủ
- Có thể chạy `--full-enforcement` mà không sợ apiserver 504 (nhờ
  `7189srv01` kernel riêng, không bị Tetragon DS / Gatekeeper webhook làm
  sa lầy)

Nếu §6 hoặc §7 fail rải rác → quay lại `12-runbook-recovery.md` cho từng case.
