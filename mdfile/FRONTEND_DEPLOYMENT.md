# Frontend Deployment Guide

This guide walks through deploying both frontend applications to Kubernetes using Helmfile.

## 📋 Prerequisites

- Docker installed and running
- Kubernetes cluster (KinD, minikube, or production)
- Helm 3.x installed
- Helmfile installed
- kubectl configured to access your cluster
- Local Docker registry or Docker Hub account

## 🚀 Deployment Steps

### Step 1: Build Docker Images

Build the frontend images locally or in your CI/CD pipeline.

```bash
cd /home/ptb/project/DOAN2

# Option 1: Using the provided script
./06-build-frontends.sh

# Option 2: Manual build
docker build -t localhost:5000/fe-candidate:latest ./src/fe_candidate/
docker build -t localhost:5000/fe-recruiter:latest ./src/fe_recruiter/
```

### Step 2: Push Images to Registry

If using a local registry:

```bash
# Start local registry (if not running)
docker run -d -p 5000:5000 --name registry registry:2

# Push images
docker push localhost:5000/fe-candidate:latest
docker push localhost:5000/fe-recruiter:latest
```

If using Docker Hub:

```bash
docker tag localhost:5000/fe-candidate:latest your-hub/fe-candidate:latest
docker tag localhost:5000/fe-recruiter:latest your-hub/fe-recruiter:latest

docker push your-hub/fe-candidate:latest
docker push your-hub/fe-recruiter:latest
```

### Step 3: Create Frontend Namespace

```bash
# Create namespace
kubectl create namespace frontend

# Or using yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: frontend
EOF
```

### Step 4: Update Helm Values

Edit the values files to configure your deployment:

**For Candidate Portal** (`k8s-management/values/fe-candidate-values.yaml`):

```yaml
# Update registry/image repository
image:
  repository: your-registry/fe-candidate  # Change if using different registry
  tag: latest

# Update Keycloak and API URLs
env:
  - name: NEXT_PUBLIC_API_BASE_URL
    value: http://kong.api:8000  # Adjust based on your setup
  - name: NEXT_PUBLIC_KEYCLOAK_URL
    value: http://keycloak.identity:8080
```

**For Recruiter Portal** (`k8s-management/values/fe-recruiter-values.yaml`):

```yaml
# Similar changes as above
image:
  repository: your-registry/fe-recruiter
  tag: latest
```

### Step 5: Deploy Using Helmfile

Navigate to the k8s-management directory and deploy:

```bash
cd k8s-management

# Deploy all applications (including backends + frontends)
helmfile sync

# Or deploy only frontends
helmfile -l "app in (fe-candidate,fe-recruiter)" sync

# Dry run first to preview changes
helmfile diff
```

### Step 6: Verify Deployment

```bash
# Check if pods are running
kubectl get pods -n frontend
kubectl get pods -n job7189-apps  # For backend services

# Check pod logs
kubectl logs -f -n frontend deployment/fe-candidate

# Check services
kubectl get svc -n frontend

# Check ingress
kubectl get ingress -n frontend
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
fe-candidate-66b6f7c9f7-xyz12          1/1     Running   0          2m
fe-candidate-66b6f7c9f7-abc34          1/1     Running   0          2m
fe-recruiter-5f8c9d1a2b-def56          1/1     Running   0          2m
fe-recruiter-5f8c9d1a2b-ghi78          1/1     Running   0          2m
```

### Step 7: Access Applications

#### Using Port Forward

```bash
# Candidate Portal
kubectl port-forward -n frontend svc/fe-candidate 3001:3000
# Access: http://localhost:3001

# Recruiter Portal
kubectl port-forward -n frontend svc/fe-recruiter 3002:3000
# Access: http://localhost:3002
```

#### Using Ingress

If Ingress is configured (see `k8s-management/values/`):

```bash
# Add to /etc/hosts or configure DNS
192.168.x.x candidate.app.local
192.168.x.x recruiter.app.local

# Access applications
# https://candidate.app.local
# https://recruiter.app.local
```

## 🧪 Testing After Deployment

### Test Backend Connectivity

```bash
# From cluster
kubectl exec -it -n frontend deployment/fe-candidate -- sh
curl http://kong.api:8000/health

# Or externally
./test-backend.sh http://kong-service:8000 http://keycloak-service:8080
```

### Test Application Health

```bash
# Check liveness probe
kubectl describe pod -n frontend <pod-name>

# Check readiness probe
kubectl logs -n frontend <pod-name>

# Test HTTP endpoint
kubectl exec -it -n frontend <pod-name> -- wget http://localhost:3000/
```

### Monitor Deployment

```bash
# Watch rollout status
kubectl rollout status deployment/fe-candidate -n frontend
kubectl rollout status deployment/fe-recruiter -n frontend

# Check HPA status
kubectl get hpa -n frontend

# Check events
kubectl get events -n frontend --sort-by='.lastTimestamp'
```

## 📊 Scaling & Performance

### Horizontal Pod Autoscaling

Both applications have HPA configured (2-5 replicas):

```bash
# View current HPA
kubectl get hpa -n frontend

# Monitor HPA
kubectl top pod -n frontend
kubectl top node
```

### Resource Limits

Current configuration:
- **Requests**: 250m CPU, 256Mi Memory
- **Limits**: 500m CPU, 512Mi Memory

If you need to adjust:

```bash
# Edit values
vi k8s-management/values/fe-candidate-values.yaml

# Update resources section
resources:
  limits:
    cpu: 1000m           # Increase to 1 CPU
    memory: 1Gi           # Increase to 1GB
  requests:
    cpu: 500m
    memory: 512Mi

# Redeploy
helmfile sync
```

## 🔄 Updating Deployments

### Update Image

```bash
# Rebuild image
docker build -t localhost:5000/fe-candidate:v2 ./src/fe_candidate/
docker push localhost:5000/fe-candidate:v2

# Update values
ed -i 's/tag: latest/tag: v2/' k8s-management/values/fe-candidate-values.yaml

# Redeploy
helmfile sync
```

### Rollback

```bash
# View rollout history
kubectl rollout history deployment/fe-candidate -n frontend

# Rollback to previous version
kubectl rollout undo deployment/fe-candidate -n frontend

# Rollback to specific revision
kubectl rollout undo deployment/fe-candidate -n frontend --to-revision=2
```

## 🚨 Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod -n frontend <pod-name>

# Check logs
kubectl logs -n frontend <pod-name>
kubectl logs -n frontend <pod-name> --previous

# Check image pull
kubectl get events -n frontend | grep pull
```

### Connection errors

```bash
# Test connectivity from pod
kubectl exec -it -n frontend <pod-name> -- sh
ping kong.api
curl http://kong.api:8000/health

# Check DNS
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
nslookup kong.api
```

### HPA not scaling

```bash
# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Check HPA status
kubectl describe hpa -n frontend fe-candidate

# Check pod metrics
kubectl top pod -n frontend
```

## 📋 Checklist

Before going to production:

- [ ] Backend services are running and healthy
- [ ] Docker images built and pushed to registry
- [ ] Environment variables configured correctly
- [ ] Helm values updated with production URLs
- [ ] Ingress/DNS configured
- [ ] SSL certificates installed
- [ ] Tests pass: `./test-backend.sh`
- [ ] Applications accessible from browser
- [ ] Authentication working (Keycloak integration)
- [ ] Job APIs returning data
- [ ] HPA monitoring working

## 📞 Getting Help

### Common Issues

**Issue**: "Image pull backoff"
```bash
# Solution: Check image registry and credentials
kubectl get events -n frontend | grep pull
```

**Issue**: "Connection refused" to backend
```bash
# Solution: Verify backend services are running
kubectl get pods -n job7189-apps
./test-backend.sh
```

**Issue**: "502 Bad Gateway" from Ingress
```bash
# Solution: Check service DNS resolution
kubectl exec -it -n frontend <pod-name> -- nslookup kong.api
```

## 📚 Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helmfile Documentation](https://github.com/roboll/helmfile)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Next.js Deployment](https://nextjs.org/docs/deployment)

---

**Last Updated**: 2026-03-31
