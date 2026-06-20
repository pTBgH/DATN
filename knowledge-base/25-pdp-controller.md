# Step 2.3.6 — PDP Controller (Adaptive Loop Closure)

## Mục đích

Đóng vòng adaptive trong kiến trúc Zero Trust: từ **enforcement-only** (PEP1-4 chỉ chặn theo CNP/Constraint/TracingPolicy đã viết sẵn) lên **continuous evaluation** (CISA ZTMM Identity Optimal — "Continuously evaluate trust").

Câu hỏi PDP trả lời:
- Pod nào đang **thiếu** label ZTA (drift sau khi rolling-update)?
- Trust score (0-100) hiện tại của mỗi pod là bao nhiêu?
- Khi nào label thay đổi → emit audit event để Filebeat → Elasticsearch lưu vĩnh viễn?

## Vị trí trong NIST 800-207 PDP/PEP architecture

```
                ┌─────────────────────────────────────────────┐
                │   PDP (Policy Decision Point) — PR #15      │
                │   • watch Pod label changes                 │
                │   • compute trust-score                     │
                │   • emit drift event                        │
                │   • annotate zta.job7189/trust-score        │
                └────────────────┬────────────────────────────┘
                                 │
       ┌─────────────────────────┼─────────────────────────────┐
       ▼                         ▼                             ▼
   PEP1 (CNP)              PEP3 (Gatekeeper)              PEP4 (Tetragon)
   Cilium L3-L7            OPA admission                  kprobe runtime
                                                          (TracingPolicy)
```

PDP **không** trực tiếp tạo CNP (giảm rủi ro auto-policy gen) — thay vào đó:
1. **Audit drift** qua structured stdout log (Filebeat ship → ES → Kibana dashboard).
2. **Annotate trust-score** trên từng pod → Prometheus có thể scrape qua `kube-state-metrics` nếu cần.
3. **Expose metrics** `pdp_label_compliance{ns,pod}`, `pdp_label_drift_total{ns}`, `pdp_trust_score{ns,pod}` qua endpoint `:9100/metrics`.

## 6 ZTA labels được verify

(Định nghĩa chi tiết ở `knowledge-base/19-label-schema.md`. Schema theo Phase 4 hardening — prefix `zta.job7189/*`, **KHÔNG** dùng prefix `cilium.zta/*` cũ.)

| Label | Giá trị mẫu | Mục đích |
|-------|-------------|----------|
| `zta.job7189/tier` | `T0` / `T1` / `T2` / `T3` | Phân tier theo độ nhạy data (T0 = public/edge, T3 = restricted) |
| `zta.job7189/role` | `api` / `db` / `gateway` / `sso` / `proxy` / `pdp` / ... | Vai trò workload trong kiến trúc (Why trong 5W1H) |
| `zta.job7189/team` | `security` / `data` / `platform` / `backend` | Team/SA chịu trách nhiệm (Who trong 5W1H) |
| `zta.job7189/data-classification` | `public` / `internal` / `confidential` / `none` | Phân loại data nhạy cảm (What trong 5W1H) |
| `zta.job7189/env` | `prod` / `staging` / `dev` | Môi trường runtime (lifecycle) |
| `zta.job7189/exposure` | `cluster-only` / `internal` / `external` | Mức exposure ra ngoài cluster (Where) |

> **Lưu ý lịch sử:** Schema ban đầu (PR #15 ZTA gap-fix) dùng prefix `cilium.zta/*`
> với 6 labels `{tier,source,destination,role,owner,sensitivity}`. Phase 4 ZTA
> hardening (B14 series) chuẩn hoá toàn cluster về `zta.job7189/*` để đồng bộ
> với CNP selectors và Trivy Operator scan-policy. PDP Controller đã được
> migrate sang schema mới (commit branch `devin/*-pdp-zta-label-schema`).

## Cấu trúc

```
infras/
├── pdp/                          # Source code (Python)
│   ├── pdp_controller.py        # kopf operator
│   └── requirements.txt
└── k8s-yaml/pdp/                 # Manifests
    ├── 10-rbac.yaml             # SA + ClusterRole + Binding
    ├── 20-configmap.yaml         # python script + reqs (no image build)
    └── 30-deployment.yaml        # python:3.11-slim + Service

scripts/zta-deploy-pdp.sh         # one-shot deploy + CNP egress allow
```

## Cài đặt

Pre-req: cluster up, namespace `security` exists.

```bash
bash scripts/zta-deploy-pdp.sh
```

Script sẽ:
1. Regenerate `20-configmap.yaml` từ `infras/pdp/pdp_controller.py` (đảm bảo CM in sync với source).
2. Apply RBAC + ConfigMap + Deployment + Service.
3. Tạo CNP `allow-pdp-controller-egress` (apiserver + DNS + PyPI cho pip).
4. Wait `kubectl rollout status` 180s.

> ✅ **Trạng thái vòng adaptive (xác nhận cluster 2026-06-20):**
> - `PDP_CVE_INPUT` **vẫn không set tường minh** trên Deployment `zta-pdp` → code mặc định
>   `os.environ.get("PDP_CVE_INPUT","true")` = **`true`** ⇒ **CVE-gating đang BẬT**.
> - CNP **`cnp-block-low-trust-to-vault` ĐÃ được apply và đang enforcing** trong namespace
>   `vault` (xác nhận `kubectl get cnp -A | grep block-low-trust-to-vault`).
> ⇒ Các mảnh để **đóng vòng adaptive đã đủ** (PDP chấm điểm → gán `score-bucket` →
> CNP chặn pod `low/medium` truy cập Vault). Hiện tại tất cả pod nghiệp vụ đang `high`
> nên chưa có pod nào bị chặn thực tế — muốn minh chứng end-to-end cần tạo lại một pod
> điểm thấp (vd image có CVE Critical) rồi quan sát bị CNP chặn egress tới Vault.
>
> _(Lịch sử: snapshot 2026-06-03 từng ghi `PDP_CVE_INPUT=false` + CNP "chưa apply".
> Cả hai đã thay đổi từ sau đó.)_

## Verify

```bash
# Pod ready?
kubectl -n security get pod -l app=zta-pdp

# Logs (structured JSON)
kubectl -n security logs -l app=zta-pdp --tail=30

# Trust-score annotation đã được PDP ghi?
kubectl -n job7189-apps get pod -o json \
  | jq '.items[] | {pod: .metadata.name, score: .metadata.annotations["zta.job7189/trust-score"], bucket: .metadata.labels["zta.job7189/score-bucket"]}'

# Prometheus metrics
kubectl -n security port-forward svc/zta-pdp-metrics 9100:9100 &
curl -s localhost:9100/metrics | grep ^pdp_
# Mong đợi:
#   pdp_label_compliance{namespace="job7189-apps",pod="..."} 1.0
#   pdp_trust_score{namespace="job7189-apps",pod="..."} 100.0
#   pdp_reconcile_total 5.0

# Test 4g trong 09-verify-zta.sh
bash 09-verify-zta.sh | grep "Test 4g" -A 6
```

## Demo drift detection

```bash
# 1. Xóa 1 label trên 1 pod → PDP phải log drift trong < 60s
POD=$(kubectl -n job7189-apps get pod -l app=identity-service -o jsonpath='{.items[0].metadata.name}')
kubectl -n job7189-apps label pod $POD zta.job7189/data-classification- --overwrite

# 2. Xem PDP log
sleep 65
kubectl -n security logs -l app=zta-pdp --tail=10 | grep label-drift
# Mong đợi: {"event":"label-drift","ns":"job7189-apps","pod":"...","missing":"zta.job7189/data-classification","score":"95","bucket":"high"}

# 3. Trust score giảm
kubectl -n job7189-apps get pod $POD -o jsonpath='{.metadata.annotations.zta\.job7189/trust-score}'
# Mong đợi: "95" (5/6 labels, missing_ratio = 1/6, score = 100 - round(30 * 1/6) = 95)

# 4. Score-bucket label đã update?
kubectl -n job7189-apps get pod $POD -o jsonpath='{.metadata.labels.zta\.job7189/score-bucket}'
# Mong đợi: "high" (95 >= 80)
```

## Bằng chứng triển khai (Phase 5.B.1, 2026-05)

Sau khi merge `fix(pdp): migrate ... zta.job7189/* label schema` và
`bash scripts/zta-deploy-pdp.sh`, PDP đã reconcile và gán trust-score
cho **35 / 35** pod trong 7 ZTA namespaces.

```
NAME                       READY   STATUS    RESTARTS   AGE
zta-pdp-5bc48b78bd-t49fl   1/1     Running   0          ~3m
```

### Bản đồ trust-score thực tế (`namespace: job7189-apps`)

| Nhóm pod | Số pod | Score | Bucket | Lý do |
|---|---|---|---|---|
| 8 microservice chính (candidate, communication, hiring, identity, job, storage, workspace, +backend) | 8 | **100** | **high** | Đủ 6 label, image Trivy không có CVE Critical/High |
| 5 Redis sidecar (`*-service-redis`) | 5 | **30** | **low** | Đủ 6 label, **image `library/redis` có Critical + High CVE** |
| Redis của storage/workspace | 2 | **30** | **low** | Cùng nhóm Redis ở trên |

### Score formula áp dụng cho Redis (ví dụ minh hoạ)

```
score = max(0, 100 - WEIGHT_LABEL × missing_ratio − WEIGHT_CRITICAL × has_crit
                       − WEIGHT_HIGH × has_high)
      = max(0, 100 − 30 × (0/6) − 50 × 1 − 20 × 1)
      = 30
bucket = "low"   (< BUCKET_MEDIUM_THRESHOLD = 50)
```

→ Đây **không phải bug** mà chính là đầu ra mong muốn của vòng adaptive:
PDP đã đọc `VulnerabilityReport` của Trivy Operator, phát hiện image
Redis có CVE nặng, và hạ trust-score cho mọi pod dùng image đó. CNP/Gatekeeper
phía sau có thể bắt vào nhãn `zta.job7189/score-bucket=low` để hạn chế
egress hoặc reject re-schedule.

> **Cập nhật 2026-06-20:** trên cluster hiện tại **tất cả** pod `job7189-apps`
> (kể cả Redis) đang ở `score-bucket=high`, và chỉ còn **5 `VulnerabilityReport`**
> (trước đây ~45). Tức input Trivy đã thay đổi (image Redis có thể đã được vá hoặc
> số VR thu hẹp). Bảng "Redis = low" ở trên là minh chứng lịch sử của Phase 5.B.1;
> để tái hiện kịch bản "low-trust bị CNP chặn Vault" cần chủ động đưa vào một image
> có CVE Critical/High.

### Caveat — Cosign webhook chặn PATCH

Trong lần deploy đầu, 4 pod (`storage-service`, `workspace-service` và 2
Redis tương ứng) **không nhận được trust-score** vì Vault Agent Injector
chèn sidecar `hashicorp/vault:1.21.2` (tag-based, không phải digest) vào
spec pod, và `ValidatingWebhookConfiguration policy.sigstore.dev` re-validate
toàn pod spec mỗi khi PDP gọi `kubectl patch`. Webhook trả về:

```
admission webhook "policy.sigstore.dev" denied the request:
validation failed: invalid value: hashicorp/vault:1.21.2 must be an image digest:
spec.containers[3].image, spec.initContainers[0].image
```

Giải pháp: thu hẹp scope webhook về **chỉ CREATE** (không re-validate UPDATE),
xem chi tiết ở `knowledge-base/28-sigstore-policy-controller.md` §7a. Sau khi patch
webhook và restart PDP pod, cả 4 pod đều nhận trust-score đúng quy luật trên.

## CISA ZTMM tác động

| Trục | Trước PDP | Sau PDP |
|------|-----------|---------|
| **Identity** | Advanced (Keycloak + Vault SA mapping) | **Optimal** (continuous evaluation + structured drift audit) |
| **Visibility & Analytics** | Advanced (Hubble + Prometheus + ELK) | **Advanced+** (PDP metrics + drift events ship to ES) |
| **Automation & Orchestration** | Initial | **Advanced** (continuous reconcile loop) |

## Resource budget

- 1 replica (singleton operator)
- requests: 50m CPU / 128Mi RAM
- limits: 200m CPU / 256Mi RAM
- Image: `python:3.11-slim` (~150MB pulled once)
- pip install ~30s mỗi pod restart (cache trong /tmp emptyDir)

## Hardening notes

- ServiceAccount-based identity (chứ không hardcode token).
- ClusterRole **chỉ** cho phép `get/list/watch/patch` trên `pods` + leases — không tạo CNP/CR khác.
- `runAsNonRoot=true`, `readOnlyRootFilesystem=false` (cần ghi pip cache; nếu muốn fully read-only, đổi sang pre-built image).
- `seccompProfile: RuntimeDefault` + `drop ALL capabilities`.
- CNP egress restrict: chỉ apiserver + DNS + PyPI (pip cần khi container start).

## Roadmap

- **PR #16**: SBOM signing — Cosign verify + Gatekeeper `ImageSignatureRequired` constraint.
- **PR #17**: SPIRE workload attestation thay SA token (CISA Devices Initial → Advanced).
- **PR #18**: Falco + Falcosidekick — detection-only layer (alert qua ES + Slack).
