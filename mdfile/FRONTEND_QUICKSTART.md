# Frontend Quick Start

Get the Job Portal frontend running in minutes!

## 🚀 5-Minute Startup (Local Docker)

### 1. Build Images
```bash
cd /path/to/DOAN2
./06-build-frontends.sh
```

### 2. Run with Docker Compose
```bash
docker-compose -f docker-compose.frontends.yml up -d
```

### 3. Access Applications
- **Candidate Portal**: http://localhost:3001
- **Recruiter Portal**: http://localhost:3002

### 4. Test Credentials
```
Admin/Recruiter Login:
- Email: recruiter@example.com
- Password: password123

Candidate Login:
- Email: candidate@example.com
- Password: password123
```

## ☸️ Kubernetes Deployment (2 Minutes)

```bash
cd k8s-management
helmfile sync -l "app in (fe-candidate,fe-recruiter)"
```

Then access via port-forward:
```bash
kubectl port-forward -n frontend svc/fe-candidate 3001:3000
kubectl port-forward -n frontend svc/fe-recruiter 3002:3000
```

## 🧪 Test Backend Connectivity

Before running, verify backend is ready:

```bash
./test-backend.sh
```

Expected output (all ✓):
```
✓ API Gateway is running
✓ Keycloak is reachable
✓ Job Service is accessible
✓ Candidate Service is accessible
✓ Hiring Service is accessible
✓ Storage Service is accessible
```

## 📂 Project Structure

```
src/
├── fe_candidate/         # Candidate portal (port 3001)
│   ├── src/app/         # Next.js pages
│   ├── Dockerfile
│   └── package.json
├── fe_recruiter/        # Recruiter portal (port 3002)
│   ├── src/app/         # Next.js pages
│   ├── Dockerfile
│   └── package.json
```

## 🎨 What's Included

### Candidate Portal
- ✅ Login/Register
- ✅ Browse Jobs
- ✅ Search/Filter
- ✅ Job Details
- ✅ Profile & CV Management
- ✅ Apply to Jobs

### Recruiter Portal
- ✅ Login/Register
- ✅ Dashboard with Stats
- ✅ Navigation Sidebar
- ✅ Ready for: Jobs, Candidates, Hiring Board

## 🔌 Backend Integration

Both apps automatically connect to:
- **API Gateway**: Kong (Port 8000)
- **Auth**: Keycloak (Port 8080)
- **Services**: Job, Candidate, Hiring, Storage, etc.

Configure via environment variables or Helm values.

## 📝 Environment Files

Located at: `k8s-management/values/`
- `fe-candidate-values.yaml` - Candidate config
- `fe-recruiter-values.yaml` - Recruiter config

Key variables:
```yaml
env:
  - name: NEXT_PUBLIC_API_BASE_URL
    value: http://kong.api:8000
  - name: NEXT_PUBLIC_KEYCLOAK_URL
    value: http://keycloak.identity:8080
```

## 🐛 Common Issues & Solutions

### **Issue**: Docker image won't build
**Solution**: Check Docker daemon is running
```bash
docker ps  # Should work
docker build -t test . --progress=plain  # See detailed output
```

### **Issue**: Connection refused to backend
**Solution**: Verify backend is running
```bash
./test-backend.sh
curl http://localhost:8000/health
```

### **Issue**: Images won't run on Kubernetes
**Solution**: Check registry and image pull
```bash
# Check if using local registry
docker push localhost:5000/fe-candidate:latest

# Or use Docker Hub
docker tag fe-candidate:latest your-hub/fe-candidate:latest
docker push your-hub/fe-candidate:latest

# Update values with correct registry
vim k8s-management/values/fe-candidate-values.yaml
```

## 📚 Documentation

- [FRONTEND_README.md](FRONTEND_README.md) - Detailed features
- [FRONTEND_DEPLOYMENT.md](FRONTEND_DEPLOYMENT.md) - Production deployment
- [FRONTEND_FEATURES.md](FRONTEND_FEATURES.md) - Complete feature list
- [FRONTEND_API_GUIDE.md](FRONTEND_API_GUIDE.md) - API integration
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - Backend APIs

## 🛠️ Development

### Run Locally (Without Docker)

```bash
# Candidate
cd src/fe_candidate
npm install
npm run dev  # http://localhost:3000

# Recruiter
cd src/fe_recruiter
npm install
npm run dev  # http://localhost:3000
```

### Build for Production

```bash
npm run build
npm start
```

## 🚀 Next Steps

1. **Verify Setup**
   - [ ] Run `./test-backend.sh`
   - [ ] Access http://localhost:3001
   - [ ] Access http://localhost:3002

2. **Test Features**
   - [ ] Register new account
   - [ ] Login successfully
   - [ ] Browse jobs
   - [ ] Try uploading CV

3. **Deploy to K8s**
   - [ ] Update helm values with your URLs
   - [ ] Run `helmfile sync`
   - [ ] Check pod status

4. **Customize**
   - [ ] Update colors in `tailwind.config.js`
   - [ ] Add company logo in `public/`
   - [ ] Customize themes

## 📞 Getting Help

1. Check if backend is running: `./test-backend.sh`
2. View container logs: `docker logs -f <container_name>`
3. View Kubernetes logs: `kubectl logs -n frontend <pod_name>`
4. Check API connectivity: `curl -v http://localhost:8000/api/jobs`

## 🎯 Key Files to Know

| File | Purpose |
|------|---------|
| `Dockerfile` | Container image definition |
| `docker-compose.frontends.yml` | Local development setup |
| `06-build-frontends.sh` | Build script |
| `test-backend.sh` | Connectivity test |
| `k8s-management/helmfile.yaml` | K8s deployment definition |
| `k8s-management/charts/fe-*/` | Helm charts |

## ✨ Feature Highlights

- 🎨 **Beautiful UI** with Ant Design + Tailwind
- ⚡ **Fast Performance** with Next.js & React Query
- 🔐 **Secure Auth** with token-based authentication
- 📱 **Responsive Design** works on all devices
- 🚀 **Production Ready** with Docker & Kubernetes
- 🔧 **Fully Typed** with TypeScript

---

**Ready to get started? Run:**
```bash
./06-build-frontends.sh
docker-compose -f docker-compose.frontends.yml up -d
```

Then visit: http://localhost:3001 or http://localhost:3002

💡 **Tip**: Check logs if something isn't working
```bash
docker logs -f fe-candidate
docker logs -f fe-recruiter
```
