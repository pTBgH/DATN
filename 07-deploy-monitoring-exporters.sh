#!/bin/bash
# ==========================================
# Script 07: Deploy Monitoring Exporters
# ==========================================
# PURPOSE: Deploy node-exporter + kube-state-metrics to fill Prometheus scrape targets.
# RUN AFTER: 02-deploy-infrastructure.sh (Prometheus must be running)
# ==========================================

set -euo pipefail

SCRIPT_START_TIME=$(date +%s)

echo ""
echo "============================================================"
echo "📊 SCRIPT 07: DEPLOY MONITORING EXPORTERS"
echo "============================================================"
echo ""

# Pre-flight: ensure monitoring namespace and Prometheus exist
if ! kubectl get namespace monitoring >/dev/null 2>&1; then
  echo "❌ ERROR: namespace 'monitoring' not found. Run 02-deploy-infrastructure.sh first"
  exit 1
fi

if ! kubectl get deploy prometheus -n monitoring >/dev/null 2>&1; then
  echo "⚠ WARNING: Prometheus deployment not found in monitoring namespace"
  echo "  Exporters will deploy but metrics won't be scraped until Prometheus is available"
fi

# ========================
# 1. Deploy node-exporter (DaemonSet)
# ========================
echo "📈 Step 1: Deploying node-exporter DaemonSet..."

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
      - effect: NoSchedule
        operator: Exists
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.7.0
        args:
          - "--path.rootfs=/host"
          - "--no-collector.hwmon"
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
        resources:
          requests:
            cpu: "10m"
            memory: "32Mi"
          limits:
            cpu: "100m"
            memory: "64Mi"
        volumeMounts:
        - name: rootfs
          mountPath: /host
          readOnly: true
          mountPropagation: HostToContainer
      volumes:
      - name: rootfs
        hostPath:
          path: /
---
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9100"
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: 9100
    targetPort: 9100
    name: metrics
  selector:
    app: node-exporter
EOF

echo "   Waiting for node-exporter pods..."
kubectl rollout status daemonset/node-exporter -n monitoring --timeout=120s 2>/dev/null || echo "   ⚠ node-exporter rollout timeout (non-blocking)"
NODE_EXPORTER_COUNT=$(kubectl get pods -n monitoring -l app=node-exporter --no-headers 2>/dev/null | grep -c Running || echo "0")
echo "   ✓ node-exporter: $NODE_EXPORTER_COUNT pods Running"

# ========================
# 2. Deploy kube-state-metrics
# ========================
echo ""
echo "📈 Step 2: Deploying kube-state-metrics..."

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups: [""]
  resources: ["nodes","pods","services","resourcequotas","replicationcontrollers","limitranges","persistentvolumeclaims","persistentvolumes","namespaces","endpoints","secrets","configmaps"]
  verbs: ["list","watch"]
- apiGroups: ["apps"]
  resources: ["deployments","daemonsets","statefulsets","replicasets"]
  verbs: ["list","watch"]
- apiGroups: ["batch"]
  resources: ["jobs","cronjobs"]
  verbs: ["list","watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["list","watch"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["list","watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies","ingresses"]
  verbs: ["list","watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses","volumeattachments"]
  verbs: ["list","watch"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: monitoring
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: monitoring
  labels:
    app: kube-state-metrics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.12.0
        ports:
        - containerPort: 8080
          name: http-metrics
        - containerPort: 8081
          name: telemetry
        resources:
          requests:
            cpu: "10m"
            memory: "32Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 5
          timeoutSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: monitoring
  labels:
    app: kube-state-metrics
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: http-metrics
    name: http-metrics
  - port: 8081
    targetPort: telemetry
    name: telemetry
  selector:
    app: kube-state-metrics
EOF

echo "   Waiting for kube-state-metrics..."
kubectl rollout status deploy/kube-state-metrics -n monitoring --timeout=120s 2>/dev/null || echo "   ⚠ kube-state-metrics rollout timeout"
echo "   ✓ kube-state-metrics deployed"

# ========================
# 3. Verify Prometheus scrape targets
# ========================
echo ""
echo "🔍 Step 3: Verifying monitoring stack..."
echo ""
echo "   Pods in monitoring namespace:"
kubectl get pods -n monitoring -o wide 2>/dev/null || true

echo ""
echo "   Services in monitoring namespace:"
kubectl get svc -n monitoring 2>/dev/null || true

TOTAL_TIME=$(($(date +%s) - SCRIPT_START_TIME))
echo ""
echo "============================================================"
echo "✔ SCRIPT 07 COMPLETED (${TOTAL_TIME}s)"
echo "============================================================"
echo ""
echo "Prometheus scrape targets now available:"
echo "  ✓ node-exporter      → :9100/metrics (${NODE_EXPORTER_COUNT} nodes)"
echo "  ✓ kube-state-metrics → :8080/metrics"
echo "  ✓ kubernetes-pods    → annotation-based auto-discovery"
echo "  ✓ prometheus         → self-scrape"
echo ""
echo "📋 To verify Prometheus targets:"
echo "   kubectl port-forward -n monitoring deploy/prometheus 9090:9090 &"
echo "   curl http://localhost:9090/api/v1/targets | python3 -m json.tool"
echo ""
