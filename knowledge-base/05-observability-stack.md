# Observability Stack — EFK + Prometheus + Grafana + Hubble

## Tong quan

| Component | Namespace | File YAML | Trang thai Deploy Chain |
|-----------|-----------|-----------|------------------------|
| Elasticsearch 7.17.18 | monitoring | `05-elasticsearch.yaml` | ✅ Trong script 02 |
| Filebeat (DaemonSet) | monitoring | `06-filebeat.yaml` | ✅ Trong script 02 |
| Kibana | monitoring | (trong `05-elasticsearch.yaml`) | ✅ Trong script 02 |
| Prometheus 2.51 | monitoring | `08-prometheus.yaml` | ❌ CHUA trong script 02 |
| Grafana 10.4 | monitoring | `09-grafana.yaml` | ❌ CHUA trong script 02 |
| Hubble UI/CLI | kube-system | Cilium Helm values | ✅ Bat trong Cilium install |

---

## EFK Stack

### Elasticsearch
- Version: 7.17.18 (single-node) — image `docker.elastic.co/elasticsearch/elasticsearch:7.17.18` (xac nhan tren cluster 2026-06-03, snapshot 40)
- Resource: request 512Mi / limit 1Gi
- JVM: `-Xms512m -Xmx512m`
- Storage: emptyDir (mat data khi restart)
- Note: ngu RAM lon nhat

### Filebeat
- Type: DaemonSet (1 pod moi worker node = 3 pods)
- Resource: request 100Mi / limit 200Mi
- Filter: CHI thu thap tu 4 namespace:
  - `job7189-apps`, `gateway`, `security`, `data`
- Output: `elasticsearch:9200`

### Kibana
- Deploy cung `05-elasticsearch.yaml`
- Port: 5601
- Dung de query security events

### Log sources
| Nguon | Noi dung |
|-------|----------|
| Kong Gateway | API request, 401/403 bi tu choi JWT |
| Keycloak | Dang nhap thanh cong/that bai, tao/thu hoi token |
| Microservices | Loi ung dung, truy cap DB, exception |
| MySQL/Kafka | Ket noi moi, loi xac thuc, query bat thuong |

---

## Prometheus + Grafana

### Prometheus
- Version: 2.51.0
- Resource: request 512Mi / limit 1Gi
- Scrape configs (5 nguon):

| Job | Target | Trang thai |
|-----|--------|------------|
| prometheus | Self-scrape | ✅ |
| node-exporter | Node CPU/RAM/Disk | ❌ Thieu deployment |
| kubernetes-pods | Pod co annotation `prometheus.io/scrape` | ✅ |
| kube-state-metrics | K8s object state | ❌ Thieu deployment |
| kafka | Kafka JMX metrics | ❌ Thieu deployment |

### GAP: 3 scrape targets khong co provider
- `node-exporter`: can deploy DaemonSet
- `kube-state-metrics`: can deploy Deployment
- `kafka-jmx-exporter`: can deploy sidecar/standalone

### Grafana
- Version: 10.4.0
- Resource: request 256Mi / limit 512Mi
- Datasource: auto-provisioned Prometheus
- Dashboard: chua co pre-built dashboards

### Security Metrics quan trong
- `hubble_flows_processed_total` — Dropped vs Forwarded packets
- TCP Retransmission rate — network policy conflict hoac MitM
- Pod CPU/Memory anomaly — crypto-mining hoac DoS
- Kafka consumer lag — potential DoS
- Vault lease count — credential abuse

---

## Hubble

- Component cua Cilium
- Hubble Relay + Hubble UI bat trong Cilium Helm values
- CLI: `hubble observe -n job7189-apps --verdict DROPPED`
- UI: truc quan hoa network flow

### Gap
- Khong co post-check cho Hubble relay/ui sau khi cai Cilium
- Neu Hubble khong len → minh chung observability trong chapter3 yeu

---

## Action Items

1. **P0**: Them deploy `08-prometheus.yaml` + `09-grafana.yaml` vao script 02
2. **P1**: Deploy node-exporter, kube-state-metrics (hoac cat scrape jobs)
3. **P1**: Tao Grafana dashboards cho Cilium drops + Vault leases
4. **P2**: Deploy Alertmanager + alerting rules
