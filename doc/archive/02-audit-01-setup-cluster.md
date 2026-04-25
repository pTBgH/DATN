# Audit Script 01 - setup cluster

File: `01-setup-cluster.sh`

## Scope script
- Tao lai Kind cluster.
- Cai Cilium, cert-manager, ingress-nginx.
- Tao namespace co ban.

## Diem manh
- Co pre-check va wait API server truoc khi apply Gateway API.
- Cai Cilium bang helm upgrade/install + wait timeout ro rang.
- Co quick-check cho cert-manager va ingress-nginx sau khi deploy.
- Co patch baseline cilium-config theo huong on dinh:
  - `enable-wireguard=false`
  - `enable-l7-proxy=true`
  - `mesh-auth-enabled=false`

## Do lech voi bao cao
- Bao cao chapter3 co mo ta microsegmentation la tru cot quan trong, nhung script 01 chua hook apply cac Cilium policy.
- Dieu nay khong sai ve vai tro (01 la cluster bootstrap), nhung can ghi ro trong doc la policy se duoc apply o phase sau de tranh hieu la da bat full policy tu phase 1.

## Risks
- Khong thay hook kiem tra trang thai Hubble relay/ui sau khi cai Cilium (chi bat trong values).
- Neu Hubble khong len, phan minh chung observability trong chapter3 se yeu.

## Ke hoach bo sung de xong phase 1 sach

P0:
- Them post-check nho cho Hubble components:
  - `kubectl -n kube-system get pods -l k8s-app=hubble-relay`
  - `kubectl -n kube-system get svc hubble-ui`
- In ra ket qua pass/fail ro rang.

P1:
- Them bien mode cho script 01:
  - `ZTA_BASELINE_ONLY=1` (mac dinh) thi chi bootstrap cluster.
  - `ZTA_ENABLE_POLICIES=1` thi goi policy apply script sau khi cluster healthy.

P2:
- Tich hop test nho e2e cho Cilium:
  - deploy 1 pod test,
  - check DNS resolution,
  - check pod-to-pod in namespace default.

## Acceptance criteria
- Script 01 ket thuc voi output check-list co cac muc:
  - Cilium DS rollout = OK
  - Cilium operator rollout = OK
  - Hubble relay/ui = OK (hoac warning co chu thich)
  - cert-manager = OK
  - ingress-nginx = OK
