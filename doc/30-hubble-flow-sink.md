# 30. Hubble flow → Elasticsearch sink (audit trail persist)

PR #21 — Step 2.3.11. Persist Cilium Hubble L3-L7 flow logs vào Elasticsearch để Chapter 4 thesis có audit trail evidence dài hạn.

## 1. Bối cảnh

PR #7 (Observability baseline) đã enable Hubble — Cilium-native flow visibility tool. Hubble agent trên mỗi node thu thập eBPF flow events (drops, allows, L7 HTTP, DNS, kafka, etc.) và expose qua Hubble Relay gRPC.

Vấn đề: **flows tồn tại in-memory ngắn hạn** (default ring buffer 4096 events / agent). Khi cluster có traffic spike, evidence cũ bị overwrite. Audit retroactive (sau 1 tuần) không khả thi.

PR #21 ship flows ra disk + Elasticsearch để:
- Persist 30-90 ngày (tuỳ ES retention policy)
- Query qua Kibana cho thesis Chapter 4 evidence
- Correlate với Falco alerts (PR #22) bằng timestamp + pod name

## 2. Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ Each node                                                           │
│                                                                     │
│  ┌─────────────────────┐            ┌──────────────────────────┐   │
│  │ cilium-agent        │  hostPath  │ filebeat                 │   │
│  │ (DaemonSet)         │            │ (DaemonSet, this PR)     │   │
│  │                     │            │                           │   │
│  │ hubble-export-file  ├────────────► /hostlogs/cilium/hubble/  │   │
│  │ /var/run/cilium/    │  RO mount  │   events.log              │   │
│  │   hubble/events.log │            │                           │   │
│  │ - JSON-pb per line  │            │ filestream input parses   │   │
│  │ - 10MB rotation     │            │ as ndjson                 │   │
│  │ - 5 backup files    │            │ kubernetes metadata       │   │
│  └─────────────────────┘            │ enrichment                │   │
│                                     └──────────┬────────────────┘   │
└──────────────────────────────────────────────┬─┘                    │
                                               │ HTTP POST /index     │
                                               ▼                      │
                              ┌────────────────────────────┐          │
                              │ Elasticsearch (ns: data)   │          │
                              │ index: hubble-flows-       │          │
                              │   YYYY.MM.DD               │          │
                              │ template: 1 shard, 0       │          │
                              │   replicas (Kind 1-master) │          │
                              └────────────────────────────┘          │
```

## 3. Hubble export configuration

PR #21 patches `kube-system/cilium-config` ConfigMap:
```
data:
  hubble-export-file-path: /var/run/cilium/hubble/events.log
  hubble-export-file-max-size-mb: "10"
  hubble-export-file-max-backups: "5"
```

Cilium agent reads cilium-config on restart and starts streaming flows to that file. Each line là một protobuf-JSON document:

```json
{
  "time": "2026-04-26T14:00:00.123Z",
  "verdict": "DROPPED",
  "drop_reason_desc": "POLICY_DENIED",
  "ethernet": {...},
  "IP": {"source": "10.244.1.5", "destination": "10.96.0.10"},
  "l4": {"TCP": {...}},
  "source": {"identity": 1234, "namespace": "data", "pod_name": "kafka-0"},
  "destination": {"identity": 5678, "namespace": "vault", "pod_name": "vault-0"},
  "Type": "L3_L4",
  "node_name": "kind-job7189-worker"
}
```

Cilium tự động rotate khi vượt 10MB; giữ tối đa 50MB historical per node trên disk.

## 4. Filebeat shipper

DaemonSet `hubble-flow-shipper` (ns: monitoring), 1 pod/node:
- Image: `docker.elastic.co/beats/filebeat:8.10.4` (~96Mi RAM)
- Mount: hostPath `/var/run/cilium/hubble` RO → container `/hostlogs/cilium/hubble`
- Input: `filestream` với `ndjson` parser
- Output: HTTP POST tới `elasticsearch.data.svc.cluster.local:9200`
- Index pattern: `hubble-flows-%{+yyyy.MM.dd}`

Filebeat watches both `events.log` (current) và `events.log.*` (rotated) để không miss flow nào during rotation.

### Index template

```yaml
setup.template.enabled: true
setup.template.name: "hubble-flows"
setup.template.pattern: "hubble-flows-*"
setup.template.settings:
  index.number_of_shards: 1
  index.number_of_replicas: 0    # Kind has 1 ES master, no replicas
```

## 5. Triển khai

```bash
# Prerequisite: PR #7 (Hubble enabled), Elasticsearch trong ns 'data' (PR #5)
bash scripts/zta-deploy-hubble-export.sh

# Verify
kubectl -n kube-system exec ds/cilium -c cilium-agent -- ls -la /var/run/cilium/hubble/
kubectl -n monitoring logs ds/hubble-flow-shipper --tail=20
kubectl -n data exec deploy/elasticsearch -- \
  curl -s http://localhost:9200/_cat/indices/hubble-flows-*

# Test 4l
bash 09-verify-zta.sh | grep "Test 4l" -A 12
```

## 6. Kibana dashboard (manual setup, 5 phút)

1. Browse Kibana (http://localhost:5601 hoặc port-forward)
2. Stack Management → Index Patterns → Create: `hubble-flows-*`, time field `time`
3. Discover → Filter `verdict: DROPPED` → top sources/destinations
4. Visualize → Pie chart by `source.namespace` cho dropped flows
5. Create thesis dashboard:
   - "L3 dropped flows per ns (last 24h)"
   - "L7 HTTP 4xx/5xx per workload"
   - "DNS queries per service"

## 7. Resource budget

| Component | RAM req/limit | CPU | Replicas |
|---|---|---|---|
| filebeat (DS) | 96/192 Mi | 30m/200m | 4 (per node) |
| cilium hubble buffer | +10Mi | negligible | 4 |
| ES storage | ~50MB/day cluster traffic | — | — |
| **Total RAM** |  |  | **~400-800Mi** |

ES storage rough estimate (Kind cluster traffic): 30-50MB/day raw, 200-400MB/day indexed. 30-day retention ~12GB.

## 8. CISA ZTMM mapping

| Pillar | Trước | Sau (PR #21) |
|---|---|---|
| **Visibility & Analytics** | partial (Hubble in-memory only) | **persistent audit trail** |
| **Networks** | Advanced+ (Cilium microseg) | Advanced+ (no change) |

PR #21 không lift CISA tier nào nhưng provide critical evidence cho audit/compliance. Đặc biệt phù hợp cho thesis Chapter 4 (verification & evidence).

## 9. Limitations

- **No mTLS to ES**: filebeat output dùng HTTP. Cluster-internal traffic OK; production cần TLS + auth.
- **No deduplication**: nếu cilium agent restart, có thể re-ship vài flow trùng lặp (filebeat checkpoints offsets in `/usr/share/filebeat/data/registry/`).
- **No alerting**: index ES chỉ để query/visualize. Realtime alert là PR #22 Falco's job.
- **Retention**: tự manage qua ILM (chưa setup) hoặc external job (curator). 30-day default rough estimate.

## 10. Roadmap mở rộng

- **PR #21a**: ILM policy auto-deletes hubble-flows index >30 days.
- **PR #21b**: Hubble flow → Loki (alternative ES, lighter weight).
- **PR #21c**: Hubble metrics (Prometheus) → Grafana dashboard cho real-time view.
- **PR #21d**: Sigma rules trên hubble-flows index để correlate với MITRE ATT&CK.
