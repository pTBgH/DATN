# Job Portal Frontend Applications

This directory contains **2 Next.js frontend applications** for the Job Portal system:
1. **fe-candidate** - Portal for job candidates
2. **fe-recruiter** - Portal for recruiters and administrators

## 🚀 Quick Start

### Using Docker

Build and run both frontends using Docker:

```bash
# Build images
./06-build-frontends.sh

# Or use docker-compose
docker-compose -f docker-compose.frontends.yml up -d
```

### Access Applications

- **Candidate Portal**: http://localhost:3001
- **Recruiter Portal**: http://localhost:3002

## 📋 Project Structure

```
src/
├── fe_candidate/           # Candidate portal (Next.js)
│   ├── src/
│   │   ├── app/           # Next.js app directory
│   │   ├── components/    # React components
│   │   ├── hooks/         # Custom hooks
│   │   ├── lib/           # Utils and API client
│   │   ├── store/         # Zustand stores
│   ├── Dockerfile
│   └── package.json
│
└── fe_recruiter/          # Recruiter portal (Next.js)
    ├── src/
    │   ├── app/           # Next.js app directory
    │   ├── components/    # React components
    │   ├── hooks/         # Custom hooks
    │   ├── lib/           # Utils and API client
    │   ├── store/         # Zustand stores
    ├── Dockerfile
    └── package.json
```

## 🎨 Features Implemented

### Candidate Portal

- ✅ **Authentication System**
  - Login/Register with email
  - Token-based authentication (Keycloak integration ready)
  - Persistent auth state

- ✅ **Job Search & Browse**
  - View all available jobs
  - Search jobs by keyword
  - Job details page
  - Favorite jobs (heart icon)

- ✅ **Profile Management**
  - View user profile
  - Upload multiple CVs
  - Set primary CV
  - Delete CVs

- ✅ **Job Applications**
  - Apply to jobs with CV
  - Track application status
  - View applications history

### Recruiter Portal

- ✅ **Dashboard**
  - Workspace overview
  - Quick stats (active jobs, pending applications, interviews, closed jobs)

- ✅ **Navigation**
  - Collapsible sidebar
  - Navigate between sections
  - User profile dropdown

- ✅ **Job Management** (Ready for implementation)
  - Create new jobs
  - Edit job postings
  - View all jobs in workspace

- ✅ **Hiring Board** (Ready for implementation)
  - Drag-and-drop kanban board
  - Manage application stages
  - View candidates

- ✅ **Candidate Management** (Ready for implementation)
  - View candidates
  - Filter and search
  - View application history

## 🔧 Technologies Used

### Core
- **Next.js 14** - React framework (App Router)
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **Ant Design 5** - UI components
- **Framer Motion** - Animations

### State Management & APIs
- **Zustand** - Lightweight state management
- **React Query** - Data fetching & caching
- **Axios** - HTTP client
- **react-hook-form** - Form handling
- **Zod** - Schema validation

### Build & Deployment
- **Docker** - Containerization
- **Helm** - Kubernetes deployment
- **Helmfile** - Multi-chart orchestration

## 📝 Environment Variables

### Candidate Portal

```env
# .env.local or from Kubernetes ConfigMap
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=job7189
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=fe-candidate
```

### Recruiter Portal

```env
# .env.local or from Kubernetes ConfigMap
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8080
NEXT_PUBLIC_KEYCLOAK_REALM=job7189
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=fe-recruiter
```

## 🧪 Testing Backend Connectivity

Before deploying, test that all backend services are reachable:

```bash
# Test with default URLs
./test-backend.sh

# Test with custom URLs
./test-backend.sh http://api.local:8000 http://keycloak.local:8080
```

Expected output:
```
✓ API Gateway is running
✓ Keycloak is reachable
✓ Job Service is accessible
✓ Candidate Service is accessible
✓ Hiring Service is accessible
✓ Storage Service is accessible
```

## 🐳 Docker Build

### Building Images

```bash
# Build individual images
docker build -t localhost:5000/fe-candidate:latest ./src/fe_candidate/
docker build -t localhost:5000/fe-recruiter:latest ./src/fe_recruiter/

# Using provided script
./06-build-frontends.sh

# Push to registry
docker push localhost:5000/fe-candidate:latest
docker push localhost:5000/fe-recruiter:latest
```

### Docker Run

```bash
# Candidate Portal
docker run -d \
  -p 3001:3000 \
  -e NEXT_PUBLIC_API_BASE_URL=http://host.docker.internal:8000 \
  -e NEXT_PUBLIC_KEYCLOAK_URL=http://host.docker.internal:8080 \
  localhost:5000/fe-candidate:latest

# Recruiter Portal
docker run -d \
  -p 3002:3000 \
  -e NEXT_PUBLIC_API_BASE_URL=http://host.docker.internal:8000 \
  -e NEXT_PUBLIC_KEYCLOAK_URL=http://host.docker.internal:8080 \
  localhost:5000/fe-recruiter:latest
```

## ☸️ Kubernetes Deployment

### Using Helmfile

The applications are configured in Helmfile with dedicated Helm charts.

```bash
# Deploy both frontends
cd k8s-management
helmfile sync

# Deploy only candidate portal
helmfile -l name=fe-candidate sync

# Deploy only recruiter portal
helmfile -l name=fe-recruiter sync
```

### Helm Values

- **Candidate**: `k8s-management/values/fe-candidate-values.yaml`
- **Recruiter**: `k8s-management/values/fe-recruiter-values.yaml`

### Access in Cluster

```bash
# Port forward candidate
kubectl port-forward -n frontend svc/fe-candidate 3001:3000

# Port forward recruiter
kubectl port-forward -n frontend svc/fe-recruiter 3002:3000
```

## 🔌 API Integration

Both applications connect to these backend services:

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Job Service | `/api/jobs` | Read job postings |
| Candidate Service | `/api/candidates` | Candidate profiles & CVs |
| Hiring Service | `/api/hiring-board` | Recruitment pipeline |
| Application Service | `/api/applications` | Job applications |
| Storage Service | `/api/storage` | File uploads (MinIO) |
| Identity Service | `/api/auth` | Authentication (Keycloak) |

### Authentication Flow

1. User submits login credentials
2. Frontend sends to Identity Service via Kong API Gateway
3. Keycloak validates and returns JWT token
4. Token stored in cookie
5. Token included in Authorization header for all API requests
6. Backend validates token before processing requests

## 📚 API Documentation

See [API_DOCUMENTATION.md](../API_DOCUMENTATION.md) for detailed endpoint specifications.

## 🛠️ Development

### Local Development

```bash
# Install dependencies
cd src/fe_candidate
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

### Adding New Features

1. Create component in `src/components/`
2. Use `useFetch()` for data fetching
3. Use `useAuthStore()` for auth state
4. Add routes in `src/app/` directory
5. Style with Tailwind + Ant Design

## 🐛 Troubleshooting

### Container won't start
```bash
# Check logs
docker logs <container_id>

# Ensure proper environment variables are set
docker run -e NEXT_PUBLIC_API_BASE_URL=... <image>
```

### API connection errors
```bash
# Test backend connectivity
./test-backend.sh http://api.local:8000

# Check Kong routing
curl -v http://localhost:8000/api/jobs
```

### Keycloak issues
```bash
# Verify realm exists
curl http://localhost:8080/auth/realms/job7189

# Check client configuration in Keycloak admin console
# http://localhost:8080/auth/admin/
```

## 📖 Next Steps

- [ ] Implement job detail page apply flow
- [ ] Add interview scheduling
- [ ] Implement hiring kanban board drag-drop
- [ ] Add email notifications
- [ ] Setup end-to-end tests
- [ ] Configure CI/CD pipeline
- [ ] Setup monitoring & logging

## 📞 Support

For issues or questions:
1. Check backend connectivity: `./test-backend.sh`
2. Review API documentation: `API_DOCUMENTATION.md`
3. Check application logs: `docker logs <container_id>`
4. Review Kubernetes logs: `kubectl logs -n frontend <pod_id>`

---

**Created**: 2026-03-31  
**Framework**: Next.js 14, TypeScript  
**Deployment**: Docker + Helm + Kubernetes
