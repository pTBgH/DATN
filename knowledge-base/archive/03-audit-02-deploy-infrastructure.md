# Audit Script 02 - deploy infrastructure

File: `02-deploy-infrastructure.sh`

## Scope script
- Tao credentials bootstrap.
- Deploy cert-manager issuer, Vault, MySQL, Keycloak, Kafka, Kong, oauth2-proxy, ingress, ELK.

## Diem manh
- Co timeout wrappers (`run_with_timeout`) va strict mode (`WAIT_STRICT`).
- Thu tu deploy hop ly cho Vault/MySQL/Keycloak theo phu thuoc.
- Co health checks cho MySQL, Keycloak, oauth2-proxy.
- Co logic build/push image Keycloak va local registry bootstrap.

## Gap quan trong so voi chapter3

1) Observability chua day du theo claim
- Script 02 hien apply:
  - `infras/k8s-yaml/05-elasticsearch.yaml`
  - `infras/k8s-yaml/06-filebeat.yaml`
- Chua thay apply:
  - `infras/k8s-yaml/08-prometheus.yaml`
  - `infras/k8s-yaml/09-grafana.yaml`
- Anh huong: chapter3 mo ta stack EFK + Prometheus + Grafana + Hubble, nhung pipeline tu dong hien chua dap ung.

2) Cilium microseg policy chua duoc apply
- Co policy files trong repo, nhung 02 script khong goi apply policy.
- Anh huong: bao cao de cao deny-all/allow-explicit, nhung deploy chain chua bien no thanh behavior mac dinh.

3) Prometheus scrape targets co nguy co "dang cau hinh nhung khong co resource"
- Trong `08-prometheus.yaml` co scrape `node-exporter`, `kube-state-metrics`, `kafka-jmx-exporter`.
- Repo chua co manifest deploy cac thanh phan nay.
- Neu bo sung 08/09 ma khong bo sung target providers, dashboard se thieu du lieu/false alarm.

## Risks
- Validation cuoi script check toan cluster pod Running/Ready co the fail boi workload co trang thai khac (vd Completed job) du he thong van dung duoc.
- Secret bootstrap van dua vao K8s secret (`app-secrets`) cho mysql root va keycloak admin (du hop ly cho bootstrap, nhung can note ro trong doc de tranh overclaim "zero static secret").

## Ke hoach bo sung uu tien

P0:
- Them deploy monitoring con thieu vao script 02:
  - apply 08-prometheus
  - apply 09-grafana
- Them wait/check cho prometheus va grafana pod.

P0:
- Hook apply Cilium policy o phase phu hop (sau khi core services len, truoc hoac sau microservices theo chien luoc).
- It nhat apply policy cho namespace app + data voi rollback path.

P1:
- Bo sung hoac loai bo scrape targets khong ton tai:
  - Neu dung: tao manifests cho node-exporter, kube-state-metrics, kafka-jmx-exporter.
  - Neu khong dung: bo cac job scrape de giam noise.

P1:
- Chinh validation cuoi script theo service critical set thay vi tat ca pod cluster-wide.

P2:
- Tach profile deploy:
  - infra-minimal
  - infra-full-observability
  de chu dong theo tai nguyen may.

## Acceptance criteria
- Chay script 02 xong co:
  - Vault, MySQL, Keycloak, Kong, oauth2-proxy healthy.
  - EFK + Prometheus + Grafana healthy.
  - In ra report pass/fail tung nhom (Identity, Data, Gateway, Observability).
