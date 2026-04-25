# Audit Script 03 - deploy microservices

File: `03-deploy-microservices.sh`

## Scope script
- Setup local registry flow + build/push image.
- Validate Vault dynamic DB readiness.
- Helmfile apply 7 Laravel services.
- Readiness gate cho deployments.

## Diem manh
- Co nhieu gate truoc deploy:
  - MySQL ready
  - Vault unsealed
  - Vault DB roles + k8s auth roles + KV paths
- Co diagnostics kha day du khi pod fail init.
- Co co che cau hinh kind node pull image tu local registry.

## Gap/Risk quan trong

1) Push success false-positive
- Tai line 638 co pattern:
  - `if docker push ... | grep ... || true; then`
- Do co `|| true`, dieu kien if co xu huong thanh cong ke ca khi push fail.
- He qua: script thong bao push ok nhung thuc te registry co the chua co image.

2) Microsegmentation khong duoc kich hoat trong chain 03
- Script 03 khong goi `infras/k8s-yaml/cilium-policies/apply-zta-microsegmentation.sh`.
- 20-security-policies cung khong duoc apply tu dong.
- He qua: cluster co the chay duoc app nhung chua enforce dung security posture nhu bao cao.

3) Registry verify strategy can siet
- Co verify tag tren local registry host, nhung can dam bao verify cung endpoint ma chart se pull.
- Nen co check truc tiep image pull tu 1 worker node sau push batch.

## Ke hoach bo sung uu tien

P0:
- Sua logic push thanh fail dung khi push that bai:
  - tach command push va grep parse log,
  - khong dung `|| true` trong dieu kien quyet dinh success.

P0:
- Sau helmfile deploy (hoac truoc, theo strategy), them gate policy:
  - apply microseg policies,
  - chay 2 test pod (attacker/allowed) de xac nhan DENY/ALLOW.

P1:
- Them mode cho script 03:
  - `SECURITY_ENFORCE=1` (bat policy + verification)
  - `SECURITY_ENFORCE=0` (chi deploy app de debug nhanh)

P1:
- Them summary "security gate" vao cuoi script:
  - Vault readiness = pass/fail
  - Registry pull probe = pass/fail
  - Microseg test = pass/fail

P2:
- Them artifact log gon vao `k8s-management/operational/` de chapter3 co the trich ngay.

## Acceptance criteria
- Neu push that bai, script fail dung va thong bao ro image nao fail.
- Sau deploy xong, test attacker pod bi chan va allowed pod truy cap duoc endpoint cho phep.
- Helm deployments van Ready trong timeout mac dinh.
