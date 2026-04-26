# 26. Image Provenance & Supply-Chain Trust (PR #16)

> **Status:** Step 2.3.7 — Phase 4 ZTA. Audit-only enforcement (dryrun).

## 1. Mục đích

Đóng nhánh **Supply-Chain Zero Trust** trong CISA ZTMM Applications pillar:
một workload chỉ được phép chạy nếu image **(a)** pin chặt bằng `sha256` digest
(immutable), **(b)** không dùng tag `:latest` mutable, và **(c)** đính kèm
provenance metadata (signed-by, signature, key-id, timestamp).

Mục tiêu: ngăn chặn _left-of-supply-chain attack_ (kẻ tấn công thay nội dung
image dưới cùng một tag mà cluster vẫn pull bình thường).

## 2. Threat model

| Threat | Mitigation | Layer |
|---|---|---|
| Mutable tag swap (`:latest`, `:v1`) | `K8sBlockLatestTag` + `K8sImageDigestRequired` | Admission |
| Tampered image content | Cosign signature + verification | Admission + offline audit |
| Lost private key | `cosign-keygen.sh --rotate` + re-sign all workloads | Operator |
| Replay attack with old signature | `image.zta/signed-at` timestamp + max-age policy (future) | Audit |
| Annotation spoofing | Future: sigstore policy-controller verifies signature against ConfigMap public key (PR #19+) | Admission |

## 3. Kiến trúc

```
┌──────────────────────────────────────────────────────────┐
│  Operator workstation                                    │
│  ┌───────────────────────────────────────────────────┐   │
│  │ 1. zta-cosign-keygen.sh → infras/cosign-keys/     │   │
│  │    zta.key (private, gitignored)                  │   │
│  │    zta.pub (public, committed + ConfigMap)        │   │
│  └───────────────────┬───────────────────────────────┘   │
│                      │                                    │
│  ┌───────────────────▼───────────────────────────────┐   │
│  │ 2. zta-cosign-sign-deployment.sh deploy.yaml      │   │
│  │    → cosign sign-blob deploy-canonical            │   │
│  │    → annotation:                                  │   │
│  │      image.zta/signed-by: zta-platform-team       │   │
│  │      image.zta/signature-algo: cosign-ecdsa-...   │   │
│  │      image.zta/signature: <base64>                │   │
│  │      image.zta/key-id: <sha256(pub)>              │   │
│  │      image.zta/signed-at: 2026-04-26T...Z         │   │
│  └───────────────────┬───────────────────────────────┘   │
│                      │ kubectl apply                     │
└──────────────────────┼──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│  Kubernetes API server                                   │
│  ┌────────────────────────────────────────────────┐     │
│  │ Gatekeeper admission webhook (PEP3)            │     │
│  │  - K8sImageDigestRequired   → all sha256?      │     │
│  │  - K8sBlockLatestTag        → no :latest?      │     │
│  │  - K8sSignedImageAnnotation → 3 annotations?   │     │
│  └─────────────────┬──────────────────────────────┘     │
│         pass=admit │ fail=audit (dryrun) / deny         │
└────────────────────▼──────────────────────────────────────┘
                     │
┌────────────────────▼──────────────────────────────────────┐
│  Future: sigstore/policy-controller (PR #19+)             │
│  - Pull cosign public key from ConfigMap                  │
│  - Verify image.zta/signature against canonical bytes     │
│  - Reject if signature invalid OR key-id mismatch         │
└───────────────────────────────────────────────────────────┘
```

## 4. ConstraintTemplates (Rego)

| Template | Đích | Logic chính |
|---|---|---|
| `K8sImageDigestRequired` | Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob | Mọi `image` field phải chứa `@sha256:`. Có exemption list cho image bên thứ ba quản lý qua helm (vault, kong, keycloak, cilium, elasticsearch). |
| `K8sBlockLatestTag` | Như trên | Block `:latest` rõ ràng + implicit no-tag. Áp lên cả image exempt — không có ngoại lệ cho `:latest`. |
| `K8sSignedImageAnnotation` | Deployment, StatefulSet, DaemonSet (job7189-apps) | `.spec.template.metadata.annotations` phải có `image.zta/signed-by`, `image.zta/signature-algo`, `image.zta/signature`. |

`enforcementAction: dryrun` ban đầu — chỉ audit, không reject. Khi label
coverage 100% → switch sang `deny`.

## 5. Cách triển khai

### Lần đầu (one-time)

```bash
# 1. Cài cosign (nếu chưa)
go install github.com/sigstore/cosign/v2/cmd/cosign@latest
# hoặc tham khảo https://docs.sigstore.dev/cosign/installation/

# 2. Sinh keypair
bash scripts/zta-cosign-keygen.sh
#   → infras/cosign-keys/zta.key  (gitignored)
#   → infras/cosign-keys/zta.pub  (committed)
#   → ConfigMap security/zta-cosign-public-key

# 3. Áp dụng Gatekeeper templates + constraints
bash scripts/zta-deploy-gatekeeper.sh --constraints-only
```

### Mỗi lần deploy workload

```bash
# Sign deployment manifest (mutates in-place by default)
bash scripts/zta-cosign-sign-deployment.sh \
  infras/k8s-yaml/job7189-apps/identity-service-deploy.yaml

# Apply (now passes K8sSignedImageAnnotation)
kubectl apply -f infras/k8s-yaml/job7189-apps/identity-service-deploy.yaml

# Verify annotation present
kubectl -n job7189-apps get deploy identity-service \
  -o jsonpath='{.spec.template.metadata.annotations.image\.zta/signed-by}'
```

### Rotate key (compromised hoặc periodic)

```bash
bash scripts/zta-cosign-keygen.sh --rotate
# Old private key backed up at infras/cosign-keys/zta.key.old.<ts>
# Re-sign tất cả Deployment YAML và apply lại.
```

## 6. Verify (Test 4h)

```bash
bash 09-verify-zta.sh | grep "Test 4h" -A 20
```

Mong đợi (sau khi sign hết workloads):
```
   ✅ PASS: Image-trust ConstraintTemplates registered (3/3)
   ✅ PASS: image-digest-required: 0 violations
   ✅ PASS: block-latest-tag: 0 violations
   ✅ PASS: Cosign public key published (1234 bytes)
   ✅ PASS: Sample workload identity-service signed by 'zta-platform-team'
```

## 7. CISA ZTMM mapping

| Pillar | Function | Trước PR #16 | Sau PR #16 |
|---|---|---|---|
| Applications | **Continuous deployment** | Initial — không enforce image hygiene | **Advanced** — enforce digest + signed annotation tại admission |
| Networks | Microsegmentation | Advanced+ (Cilium) | unchanged |
| Identity | Continuous evaluation | Optimal (PDP PR #15) | unchanged |

## 8. Limitations & roadmap

- **Stub verification**: Constraint chỉ kiểm annotation _có_, không cryptographically verify signature. Để verify thực:
  - PR #19+: deploy `sigstore/policy-controller` (~150Mi RAM)
  - Hoặc: Validating Admission Policy (CEL) đọc public key từ ConfigMap, dùng OpenSSL để verify
- **No SBOM signing yet**: Cosign hỗ trợ `cosign attest` cho SPDX/CycloneDX SBOM. Future PR sẽ thêm:
  - `syft <image> -o spdx-json` → SBOM artifact
  - `cosign attest --predicate sbom.spdx.json --type spdx <image>`
  - Gatekeeper constraint kiểm tra attestation tồn tại
- **Helm-managed images**: vault, kong, keycloak, cilium đều ở exemption list. Khi nào upgrade chart, cần update digest reference theo (chart-level signing là Sigstore Project work-in-progress).

## 9. Tham chiếu

- NIST SP 800-204D — Software Supply Chain Security in DevOps
- CISA ZTMM 2.0 — Applications pillar, Continuous Deployment function
- Sigstore Cosign: https://docs.sigstore.dev/cosign/overview
- OPA Gatekeeper Cosign verification (sigstore policy-controller): https://docs.sigstore.dev/policy-controller/overview
