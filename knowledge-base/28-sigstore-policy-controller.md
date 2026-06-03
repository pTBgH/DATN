# 28. sigstore policy-controller — Real Cosign signature verification at admission

PR #19 — Step 2.3.9, ZTA Devices/Applications: Advanced+ → **Optimal**.

## 1. Bối cảnh

PR #16 (Image Provenance & Supply-Chain Trust) đã triển khai Cosign signing và 3 Gatekeeper ConstraintTemplates. **Tuy nhiên các constraint chỉ kiểm sự tồn tại của annotation** `image.zta/signed-by` chứ không thực sự verify chữ ký mật mã (cryptographic verify). Nếu attacker chèn annotation tay vào manifest, constraint vẫn pass.

PR #19 đóng đúng gap này bằng cách bổ sung **sigstore policy-controller** (admission webhook) — một controller riêng biệt do dự án sigstore.dev maintain — để verify chữ ký Cosign **thực sự** trên container image manifest tại thời điểm pod admission.

| Layer | Cơ chế | Verify gì |
|---|---|---|
| PR #16 Gatekeeper image-trust | Rego policies | annotation key/value present (không xác thực mật mã) |
| **PR #19 policy-controller** | Sigstore admission webhook | **Cosign signature** trên image digest, fetch từ registry, verify bằng public key |
| PR #17 SPIRE | Workload identity | Pod's SVID (workload identity, không liên quan image trust) |

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ kube-apiserver (admission chain)                                     │
│                                                                      │
│   1. Validating webhook: policy.sigstore.dev                         │
│      - intercepts CREATE pod (any ns labeled                         │
│        policy.sigstore.dev/include=true)                             │
│      - per image in pod spec:                                        │
│         a. resolve image -> digest                                   │
│         b. fetch <image>@sha256:....sig signature object             │
│         c. verify Cosign signature against public key in CIP         │
│         d. allow / deny / warn (based on CIP mode)                   │
└──────────────────────────────────────────────────────────────────────┘
                            ▲
                            │ webhook callback
┌──────────────────────────────────────────────────────────────────────┐
│ ns: cosign-system                                                    │
│   ┌────────────────────────────┐  ┌──────────────────────────────┐  │
│   │ policy-controller-webhook  │  │ policy-controller-controller │  │
│   │ Deployment, replicas=1     │  │ Deployment, replicas=1       │  │
│   │ exposes :443 webhook svc   │  │ reconciles ClusterImagePolicy│  │
│   └────────────────────────────┘  └──────────────────────────────┘  │
│                                                                      │
│   ┌────────────────────────────┐                                    │
│   │ policy-controller-tuf      │  caches Sigstore root of trust    │
│   │ Deployment                 │  (Fulcio, Rekor) for offline use   │
│   └────────────────────────────┘                                    │
└──────────────────────────────────────────────────────────────────────┘

ClusterImagePolicy (CRD policy.sigstore.dev/v1beta1):
  ┌────────────────────────────────┐
  │ zta-system-passthrough         │  glob: registry.k8s.io/**, etc.
  │ static action: pass            │  (allow-list cluster infra)
  ├────────────────────────────────┤
  │ zta-job7189-apps-signed        │  glob: ** (in opted-in ns only)
  │ key.data: -----BEGIN PUBLIC--- │  (real Cosign verify)
  │ mode: warn                     │
  ├────────────────────────────────┤
  │ zta-keyless-trust-job7189      │  glob: ghcr.io/ptbgh/**
  │ keyless: Fulcio + GHA OIDC     │  (future: GHA-built images)
  │ mode: warn                     │
  └────────────────────────────────┘
```

## 3. Threat model — gì PR #19 chặn

| Attack | PR #16 | PR #19 |
|---|---|---|
| Attacker push tampered image lên registry, swap digest trong manifest | ❌ pass (annotation vẫn có) | ✅ **deny** (signature không verify) |
| Attacker copy annotation từ deploy đã sign sang deploy mới | ❌ pass (annotation match) | ✅ **deny** (signature không match digest mới) |
| Tag mutability (`:latest` → image mới) | ⚠️ partial (block-latest constraint) | ✅ **deny** (verify tại admission, không lookup tag) |
| Insider commits manifest có annotation giả | ❌ pass | ✅ **deny** (cần private key thật để sign) |
| Compromise registry (signature object replace) | ❌ pass | ⚠️ chỉ deny nếu có Rekor transparency log lookup (cần internet) |

## 4. ClusterImagePolicy explained

### 4.1 zta-system-passthrough (allow-list infra)

```yaml
spec:
  images:
  - glob: "registry.k8s.io/**"
  - glob: "quay.io/cilium/**"
  - ...
  authorities:
  - static:
      action: pass    # always allow regardless of signature
  mode: warn
```

Lý do: ta không build/sign images cluster-infra (kube-proxy, cilium, gatekeeper, vault). Nếu policy-controller deny chúng → cluster brick. `static.action=pass` cho phép qua.

### 4.2 zta-job7189-apps-signed (require Cosign verify)

```yaml
spec:
  images:
  - glob: "**"   # match mọi image trong ns đã opt-in
  authorities:
  - name: zta-cosign-key
    key:
      data: |
        -----BEGIN PUBLIC KEY-----
        <PEM, đọc từ ConfigMap security/zta-cosign-public-key tại deploy time>
        -----END PUBLIC KEY-----
  mode: warn
```

`scripts/zta-deploy-policy-controller.sh` đọc cosign public key từ ConfigMap đã publish ở PR #16, patch inline vào CIP YAML, rồi `kubectl apply`. Lý do không hardcode: keypair có thể rotate qua `scripts/zta-cosign-keygen.sh`.

### 4.3 zta-keyless-trust-job7189 (Fulcio keyless, future)

```yaml
authorities:
- name: keyless-gha
  keyless:
    url: https://fulcio.sigstore.dev
    identities:
    - issuer: https://token.actions.githubusercontent.com
      subjectRegExp: "^https://github.com/pTBgH/.+$"
```

Cho tương lai khi project chuyển sang GitHub Actions build & sign image. policy-controller verify Sigstore transparency log thay vì static public key.

## 5. Triển khai

```bash
# Đảm bảo PR #16 đã apply (cosign keygen tạo ConfigMap)
ls infras/cosign-keys/zta.pub                         # local
kubectl get cm -n security zta-cosign-public-key      # in-cluster

# Cài policy-controller
bash scripts/zta-deploy-policy-controller.sh

# Verify
kubectl -n cosign-system get pod
kubectl get clusterimagepolicy
kubectl get ns job7189-apps -o jsonpath='{.metadata.labels}' | tr ',' '\n' | grep sigstore
```

## 6. Test workflow (warn mode)

```bash
# Deploy unsigned image vào ns đã opt-in
kubectl -n job7189-apps run unsigned --image=nginx:1.25 --restart=Never

# Mong đợi: pod được admit (mode=warn) nhưng có warning event
kubectl -n job7189-apps get events --sort-by='.lastTimestamp' | tail -5
# Expected:
# Warning policy.sigstore.dev/...  no matching authority found for image nginx:1.25
```

## 7. Switch sang enforce mode (production)

```bash
# Bước 1: Sign tất cả images với cosign push lên registry
cosign sign --key infras/cosign-keys/zta.key registry.example.com/myapp@sha256:...

# Bước 2: Switch CIP từ warn → enforce
kubectl patch clusterimagepolicy zta-job7189-apps-signed --type=merge \
  -p '{"spec":{"mode":"enforce"}}'

# Bước 3: Verify enforce (unsigned pod sẽ bị deny ngay tại admission)
kubectl -n job7189-apps run unsigned-block --image=nginx:1.26 --restart=Never
# Error from server (BadRequest): admission webhook "policy.sigstore.dev"
#   denied the request: validation failed: no matching signatures
```

## 7a. Webhook scope — vì sao chỉ validate CREATE

`policy.sigstore.dev` mặc định bind cả `CREATE` và `UPDATE` cho resource
`pods` / `pods/ephemeralcontainers`. Nghĩa là **mỗi lần** một controller
khác (kopf, kube-controller-manager, kubectl edit, kubectl label, …) cập
nhật pod hiện có, webhook lại re-validate **toàn bộ** spec.

Khi triển khai Phase 5.B.1 (PDP Controller — `knowledge-base/25-pdp-controller.md`),
chúng tôi gặp đúng trường hợp này:

1. PDP `kubectl patch` annotation `zta.job7189/trust-score` lên pod.
2. Webhook re-validate pod, thấy sidecar Vault Agent (`hashicorp/vault:1.21.2`)
   chưa được pin về digest → reject với `"must be an image digest"`.
3. 4 pod bị Vault Agent inject (`storage-service`, `workspace-service` + 2
   Redis sidecar) **không nhận** trust-score, mặc dù chúng đã pass admission
   tại CREATE-time hoàn toàn bình thường.

### Quyết định

**Hẹp scope webhook về CREATE.** Lý do:

| Câu hỏi | Trả lời |
|---|---|
| Cosign verify đảm bảo điều gì? | Image trong spec đã được sign bằng khoá ta tin tưởng → **supply-chain trust** tại điểm pod được admit vào cluster. |
| UPDATE trên pod hiện có có thể thay container image không? | Không — `pod.spec.containers[*].image` là **immutable field** sau khi pod được tạo (chỉ ephemeral debug container và pod recreate mới thay). |
| Vậy re-validate UPDATE chặn được attack gì? | Chỉ chặn ephemeralContainer mới chèn vào pod đã chạy. |
| Pattern industry khác làm gì? | Kyverno / OPA Gatekeeper image-trust policy đều bind CREATE-only mặc định. Cosign policy-controller chuyển sang CREATE+UPDATE từ v0.9 chủ yếu để cover ephemeralcontainer. |

→ **Trade-off đã chấp nhận**: ta narrow xuống CREATE-only cho **cả 3 rule** của
webhook (`pods+pods/ephemeralcontainers`, `apps/*`, `batch/*`). Hệ quả là attacker
có quyền `pods/ephemeralcontainers/attach` có thể chèn debug container chạy unsigned
image mà webhook **không** verify lúc UPDATE. Bù lại, Tetragon TracingPolicy (Step
2.3.4) đã chặn `process_exec` từ container lạ, và Gatekeeper ConstraintTemplates
(PR #16) chặn pod CREATE với annotation thiếu — nên vẫn còn 2 lớp phòng thủ
trước khi attacker tới được runtime. Nếu muốn ép lại CREATE+UPDATE cho riêng
`pods/ephemeralcontainers`, cần tách thành webhook rule riêng (chart chưa hỗ trợ
trực tiếp; phải post-patch JSON `/webhooks/0/rules/-`).

### Áp dụng

Lệnh patch trực tiếp `ValidatingWebhookConfiguration` (đã chạy 2026-05 trên
cluster `kind-job7189`):

```bash
kubectl get validatingwebhookconfiguration policy.sigstore.dev \
  -o yaml > /tmp/policy-webhook-backup-$(date +%s).yaml

kubectl patch validatingwebhookconfiguration policy.sigstore.dev --type='json' -p='[
  {"op": "replace", "path": "/webhooks/0/rules/0/operations", "value": ["CREATE"]},
  {"op": "replace", "path": "/webhooks/0/rules/1/operations", "value": ["CREATE"]},
  {"op": "replace", "path": "/webhooks/0/rules/2/operations", "value": ["CREATE"]}
]'
```

Patch này được **tự động áp lại** ở step `[5.5/5]` của
`scripts/zta-deploy-policy-controller.sh` sau mỗi lần helm install/upgrade,
nên cluster mới sẽ có ngay trạng thái CREATE-only mà không cần can thiệp tay.

### Rollback

Nếu cần khôi phục về CREATE+UPDATE (ví dụ muốn block ephemeralcontainer
chèn unsigned image runtime):

```bash
kubectl apply -f /tmp/policy-webhook-backup-<ts>.yaml
# hoặc:
helm upgrade --install policy-controller sigstore/policy-controller \
  -n cosign-system -f infras/k8s-yaml/policy-controller/values.yaml
```

## 8. Resource budget

| Component | RAM req/limit | Replicas | Total |
|---|---|---|---|
| policy-controller-webhook | 96 / 192 Mi | 1 | 96-192 Mi |
| policy-controller-controller | 64 / 128 Mi | 1 | 64-128 Mi |
| policy-controller-tuf | 32 / 64 Mi | 1 | 32-64 Mi |
| **Total** |  |  | **~150-300 Mi** |

So với SPIRE (~800Mi-1.7Gi), Falco (~800Mi), policy-controller rẻ nhất nhưng đóng đúng gap PR #16.

> **Cập nhật PR #24 — recovery & operational hardening:**
>
> - Pre-flight cluster: `scripts/zta-deploy-policy-controller.sh` từ chối install
>   nếu node nào có <200Mi free RAM. Bypass: `ZTA_RAM_CHECK_FATAL=0` hoặc set
>   `PC_REQUIRED_NODE_MI=100`.
> - Helm install dùng `--cleanup-on-fail` để failed install không để lại orphan.
> - `--reset` flag: detect "deployed-but-broken" (webhook pod restart ≥5) và tự
>   xoá `policy.sigstore.dev` ValidatingWebhookConfiguration +
>   MutatingWebhookConfiguration cluster-scoped trước khi reinstall — tránh lỗi
>   `conflict with "webhook" using admissionregistration.k8s.io/v1:
>   .webhooks[name="policy.sigstore.dev"].namespaceSelector` (do webhook pod
>   đang chạy SSA-update field này).
> - `--uninstall` flag mới đầy đủ: helm uninstall + xoá CIP + un-label namespace
>   + nuke webhook configs cluster-scoped + force-delete orphan pods + xoá ns.
>
> Recovery flow chi tiết: xem `32-deploy-script-troubleshooting.md` § 3.

## 9. CISA ZTMM Mapping

| Pillar | Trước (PR #16) | Sau (PR #19) |
|---|---|---|
| **Devices** | Advanced (SPIRE) | Advanced |
| **Applications** | Advanced+ (annotation check, real CT) | **Optimal** (real cryptographic verify at admission) |
| **Networks** | Advanced+ | Advanced+ |
| **Identity** | Optimal (PDP) | Optimal |
| **Data** | Advanced | Advanced |

## 10. Limitations & roadmap

- **PR #19 chỉ deploy infra**: chưa có image nào trong cluster đã được Cosign-signed real. Mode `warn` cho phép pass; cần PR #20+ build pipeline để sign images.
- **Rekor transparency log**: chưa enabled (cần outbound internet đến rekor.sigstore.dev). Để tự khép kín, có thể chạy private Rekor instance.
- **Image mutation**: nếu deployment dùng `:tag` thay vì `@sha256:...`, signature có thể không match khi tag được push lại. Khuyến nghị PR #16 constraint `image-digest-required` enforce sha256 pinning trước khi switch `enforce`.
- **No CNP cho cosign-system ns yet**: tương tự `kube-system`, treat như infrastructure. Future PR có thể thêm default-deny.

## 11. Roadmap

- **PR #20**: GitHub Actions build pipeline → push container image → cosign sign --keyless → policy-controller verify keyless
- **PR #21**: Switch zta-job7189-apps-signed mode `warn` → `enforce` sau khi tất cả images đã sign
- **PR #22**: Private Rekor instance trong cluster cho fully air-gapped verify
