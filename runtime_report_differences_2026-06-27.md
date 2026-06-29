# Chênh lệch giữa báo cáo và hệ thống đang chạy

Ngày rà soát: 2026-06-27  
Phạm vi: chỉ đọc trạng thái cụm Kubernetes và đối chiếu nhanh với nội dung báo cáo hiện tại.  
Lưu ý: đây là ghi nhận để xem xét, không khẳng định tất cả đều là lỗi báo cáo.

## 1. Hạ tầng cụm

- Báo cáo mô tả cụm Kubernetes nhiều nút kết nối qua Tailscale. Cụm hiện có 4 node Ready: `7189srv01`, `7189srv02`, `7189srv03`, `7189srv05`.
- Ba node đầu đang chạy Kubernetes `v1.30.0`, riêng `7189srv05` là `v1.30.14`. Nếu báo cáo viết như một cụm đồng nhất về phiên bản Kubernetes thì nên cân nhắc ghi mềm hơn.
- `7189srv05` hiện có `INTERNAL-IP` là `172.16.82.128`, trong khi các node còn lại dùng dải `100.x` của Tailscale. Nếu báo cáo nói toàn bộ node dùng địa chỉ Tailscale làm địa chỉ nội bộ Kubernetes thì chưa khớp hoàn toàn.

## 2. Namespace và tài nguyên ngoài mạch chính

- Cụm có namespace `zta-demo` mới hơn, hiện không có workload ứng dụng nhưng có các `ClusterImagePolicy` hiển thị khi truy vấn trong namespace này. Namespace này chưa thấy được nhắc trong báo cáo.
- Namespace `security` có thêm `oauth2-proxy` và CronJob `impossible-travel-shadow`. Báo cáo có nói Kong/OPA/Keycloak, nhưng nếu chưa nói rõ lớp OAuth2 proxy bảo vệ các giao diện quản trị thì có thể thiếu so với hệ thống thật.

## 3. Workload Job7189

- Bảy backend chính đang chạy đúng mạch báo cáo: `identity-service`, `workspace-service`, `job-service`, `hiring-service`, `candidate-service`, `communication-service`, `storage-service`.
- Mỗi backend Laravel hiện chạy kèm nhiều thành phần phụ: `spiffe-helper`, `vault-agent-init`, `env-loader`, `env-watcher`, `app`, `vault-agent`. Vì vậy nếu báo cáo chỉ nói "một container ứng dụng" thì chưa phản ánh đúng trạng thái hiện tại.
- Tất cả pod nghiệp vụ và Redis trong `job7189-apps` đang có `trust-score=100` và `score-bucket=high`. Điều này khớp với nhận định chưa kiểm chứng được cô lập tự động do chưa có workload rủi ro thấp trong các dịch vụ chính.
- Có tài nguyên cũ/khả nghi trong `job7189-apps`: `service/identity`, `service/identity-redis` và `ingress/identity` cùng tồn tại với `identity-service`. Hai service cũ hiện không có endpoint, nhưng vẫn cùng host `identity.job7189.local`. Báo cáo hiện chỉ mô tả một `identity-service`, nên phần này cần xem lại nếu muốn phản ánh đúng cụm đang chạy.

## 4. Gateway, Ingress và giao diện quản trị

- `kong-proxy` vẫn là `NodePort` cổng `30000`.
- `phpmyadmin` vẫn là `NodePort` cổng `30080`, `kibana` vẫn có `NodePort` cổng `30601`.
- Đồng thời cụm có các Ingress OAuth2 mới hơn như `ingress-oauth2-db`, `ingress-oauth2-grafana`, `ingress-oauth2-kibana`, `ingress-oauth2-prometheus`, `ingress-oauth2-hubble`.
- Vì vậy báo cáo nên phân biệt rõ: một số NodePort vẫn tồn tại, nhưng một số đường truy cập qua Ingress đã được bọc thêm OAuth2 proxy. Nếu chỉ nói "mở NodePort để tiện thử nghiệm" thì hơi thiếu so với trạng thái hiện tại.

## 5. Admission, chữ ký image và Gatekeeper

- `policy-controller-webhook` đang chạy trong `cosign-system`.
- Gatekeeper hiện có các constraint:
  - `block-latest-tag`: `dryrun`, 4 vi phạm.
  - `image-digest-required`: `dryrun`, 122 vi phạm.
  - `signed-image-annotation-required`: `dryrun`, 0 vi phạm.
  - `zta-labels-required`: `dryrun`, 6 vi phạm.
  - `zta-block-host-mounts`: `deny`, 0 vi phạm.
  - `zta-restrict-privileged`: `deny`, 0 vi phạm.
- Điều này khớp với cách viết "một phần ở chế độ ghi nhận/cảnh báo". Tuy nhiên nếu ở đâu trong báo cáo nói Gatekeeper đang chặn digest/tag chưa ghim thì cần chỉnh lại: các chính sách này đang ở `dryrun`.
- Các vi phạm digest/tag hiện chủ yếu nằm ở workload hạ tầng như OPA, OAuth2 proxy, Prometheus, node-exporter, Grafana, Filebeat, Kong, MySQL, Kafka, phpMyAdmin.

## 6. Trivy và dữ liệu lỗ hổng

- `trivy-operator` đang chạy trong `security-cdm`.
- Hiện `VulnerabilityReport` chỉ thấy cho một số image hạ tầng hoặc tác vụ bảo mật như `cilium-envoy`, `etcd`, `filebeat`, `threat-intel-refresh`; chưa thấy báo cáo lỗ hổng cho các backend Job7189 chính.
- Có job `scan-vulnerabilityreport` đang chạy tại thời điểm kiểm tra.
- Nếu báo cáo viết rằng Trivy đang cung cấp trạng thái CVE đầy đủ cho từng workload nghiệp vụ thì chưa khớp với trạng thái hiện tại. Nên viết thận trọng hơn: Trivy đã triển khai và có báo cáo cho một phần workload; độ phủ thực tế cần kiểm tra theo từng thời điểm.

## 7. Threat intelligence và CronJob

- `threat-intel-refresh` hiện `SUSPEND=False`, lịch `0 * * * *`, lần chạy gần nhất khoảng 13 phút trước khi kiểm tra.
- Có cả job hoàn thành và job thất bại trong lịch sử gần đây.
- Báo cáo nói đồng bộ theo giờ là đúng ở trạng thái hiện tại, nhưng nên giữ ghi chú rằng hiệu quả phụ thuộc vào lần chạy thành công gần nhất.

## 8. PDP và vòng phản hồi

- `zta-pdp` đang chạy và log có các dòng `reconcile-complete`.
- Log cũng ghi một lỗi tạm thời khi xử lý pod `scan-vulnerabilityreport` đang bị xóa: không thêm được finalizer vào pod đang terminating. Đây không nhất thiết ảnh hưởng các workload chính, nhưng là dấu hiệu vận hành nên ghi nhận nếu báo cáo nói PDP chạy ổn định tuyệt đối.
- Các chính sách `ccnp-low-trust-isolate-ew`, `ccnp-medium-trust-restrict-ew` và `cnp-block-low-trust-to-vault` đang tồn tại, nhưng chưa có workload Job7189 chính nào ở bucket `low` hoặc `medium`.

## 9. Cilium, Hubble và mã hóa

- Cilium đang bật Hubble, L7 proxy và kube-proxy replacement.
- `mesh-auth-enabled=true`.
- `enable-wireguard=false`.
- `routing-mode=tunnel`, `tunnel-protocol=vxlan`.
- Như vậy báo cáo hiện viết Cilium WireGuard chưa bật là đúng. Nếu nói Tailscale thay thế mã hóa pod-to-pod thì không đúng; nếu nói Tailscale là lớp bảo vệ hạ tầng phòng thí nghiệm thì hợp lý hơn.

## 10. Tetragon và giám sát thời gian chạy

- Tetragon DaemonSet hiện `DESIRED=3`, không chạy trên đủ 4 node. Điều này có thể do node selector/toleration, nhưng nếu báo cáo ngầm hiểu Tetragon phủ toàn bộ cụm 4 node thì cần kiểm tra lại.
- Các `TracingPolicyNamespaced` hiện có ở `data`, `job7189-apps`, `security`, `vault`; ngoài ra có `TracingPolicy` toàn cụm `monitor-kernel-module-load`.
- Điều này khớp với báo cáo nếu báo cáo chỉ nói chính sách áp dụng ở một số namespace trọng yếu, không phải mọi namespace.

## 11. Observability

- `node-exporter` chạy trên 4 node.
- `hubble-flow-shipper` chạy trên 4 node.
- `filebeat` chỉ `DESIRED=3`, không phủ 4 node.
- Nếu báo cáo nói Filebeat thu log container trên toàn bộ node thì chưa khớp hoàn toàn với trạng thái hiện tại.

## 12. Vault

- `vault-0` đang unsealed, version `1.17.6`, storage type là `file`, `HA Enabled=false`.
- Ngoài `vault-0` còn có `vault-dev` đang chạy.
- Báo cáo nên tránh khiến người đọc hiểu đây là Vault HA/production. Cách viết hiện tại nếu đã nhấn mạnh môi trường mô phỏng thì ổn.

## 13. Gợi ý ưu tiên xem lại trong báo cáo

1. Làm rõ trạng thái thực thi thật của Gatekeeper: nhiều chính sách đang `dryrun`, chỉ một số chính sách ở `deny`.
2. Làm rõ độ phủ Trivy hiện tại: chưa thấy VulnerabilityReport cho các backend Job7189 chính tại thời điểm kiểm tra.
3. Bổ sung hoặc giải thích các lớp mới đang chạy: OAuth2 proxy, impossible-travel-shadow, namespace `zta-demo`.
4. Rà phần quan sát: Filebeat không chạy trên đủ 4 node, trong khi Hubble shipper và node-exporter có chạy đủ.
5. Rà phần runtime: Tetragon hiện chỉ có 3 pod agent, không phủ toàn bộ 4 node nếu nhìn theo DaemonSet hiện tại.
6. Rà tài nguyên cũ `identity`/`identity-redis` không có endpoint nhưng vẫn còn Ingress cùng host với `identity-service`.

## Lệnh đọc-only đã dùng

- `kubectl get nodes -o wide`
- `kubectl get ns`
- `kubectl get pods -A -o wide`
- `kubectl get deploy,sts,ds,svc,ingress -A -o wide`
- `kubectl get cnp,ccnp -A`
- `kubectl get constraints --all-namespaces`
- `kubectl get constrainttemplates`
- `kubectl get cronjob -A -o wide`
- `kubectl get jobs -A`
- `kubectl get tracingpolicies,tracingpoliciesnamespaced -A`
- `kubectl get vulnerabilityreports -A`
- `kubectl -n kube-system get cm cilium-config -o yaml`
- `kubectl -n vault exec vault-0 -- vault status`
- `kubectl -n security logs deploy/zta-pdp --tail=80`
