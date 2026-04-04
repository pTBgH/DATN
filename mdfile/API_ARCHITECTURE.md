# Microservices API Architecture Diagram

## Service Interactions & Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FRONTEND APPLICATION                               │
│  (Next.js Candidate/Recruiter Portal)                                        │
└──────────┬──────────────────────┬──────────────────────────┬──────────────────┘
           │                      │                          │
    ┌──────▼──────┐       ┌──────▼──────┐         ┌────────▼────────┐
    │  Keycloak   │       │   Storage   │         │   Kong Gateway   │
    │  (Auth)     │       │  (MinIO)    │         │  (API Gateway)   │
    └──────┬──────┘       └──────┬──────┘         └────────┬─────────┘
           │                     │                        │
           │    ┌────────────────┼────────────────┐       │
           │    │                │                │       │
     ┌─────▼────▼────┐   ┌──────▼──────┐  ┌──────▼────────▼─────────────────┐
     │  IDENTITY     │   │  CANDIDATE  │  │  JOB SERVICE                    │
     │  SERVICE      │   │  SERVICE    │  │  ├─ Public: Search & Browse     │
     │               │   │             │  │  ├─ Recruiter: CRUD & Publish  │
     │ /health       │   │ /resumes    │  │  ├─ Admin: Approve/Reject      │
     │ /profile      │   │ /apply      │  │  └─ Internal: Batch info       │
     │ /internal/*   │   │ /saved-jobs │  │                                 │
     └────┬──────────┘   └──────┬──────┘  └────┬─────────────────┬──────────┘
          │                     │              │                 │
          │                     │         ┌────▼────────────┐   │
          │                     │         │  WORKSPACE      │   │
          │                     │         │  SERVICE        │   │
          │                     │         │                 │   │
          │                     │         │ /workspaces     │   │
          │                     │         │ /members        │   │
          │                     │         │ /invitations    │   │
          │                     │         │ /permissions    │   │
          │                     │         └────┬────────────┘   │
          │                     │              │                │
          │     ┌───────────────┼──────────────┼────────────┐   │
          │     │               │              │            │   │
     ┌────▼─────▼───┐   ┌──────▼──────────────▼──┐   ┌─────▼───────────────┐
     │ HIRING        │   │ COMMUNICATION          │   │ (OTHER SERVICES)    │
     │ SERVICE       │   │ SERVICE                │   │                     │
     │               │   │                        │   │ - Analytics         │
     │ /board/*      │   │ /conversations         │   │ - Notifications     │
     │ /applications │   │ /messages              │   │ - Reporting         │
     │ /pipelines    │   │ /internal/email/send   │   │                     │
     │ /interviews   │   │                        │   │                     │
     │ /scorecards   │   │ (Event Listener for    │   │                     │
     │               │   │  Kafka messages)       │   │                     │
     └──────────────┘   └────────────────────────┘   └─────────────────────┘
           │
      ┌────▼────────────────────────────────────┐
```

## Database Schema Relationships

```
┌──────────────────────────────────────────────────────────────────────────┐
│ IDENTITY DB (job7189_identity_db)                                        │
├──────────────────────────────────────────────────────────────────────────┤
│ user_profiles (Keycloak + Local)                                         │
│   id (UUID) → represents actual user from Keycloak                       │
│   keycloak_id                                                             │
│   email, name, type (recruiter|candidate)                               │
└──────┬───────────────────────────────────────────────┬────────────────────┘
       │                                               │
       │                                               │
  ┌────▼──────────────────────┐              ┌────────▼──────────────────┐
  │ CANDIDATE DB              │              │ WORKSPACE DB             │
  │ (job7189_candidate_db)     │              │ (job7189_workspace_db)   │
  ├───────────────────────────┤              ├──────────────────────────┤
  │ service_users             │              │ service_users            │
  │ usr_cvs                   │              │   internal_id (UUID)     │
  │   - CVID (UUID)           │              │   keycloak_id            │
  │   - UserID → Identity     │              │ workspaces               │
  │   - CVPath → Storage      │              │   - WorkspaceID (UUID)   │
  │   - IsDefault (bool)      │              │   - Name, Logo, Email    │
  │   - Education (JSON)      │              │ workspace_members        │
  │   - Experience (JSON)     │              │   - RecruiterID → Ident. │
  │   - Skills (JSON)         │              │   - WorkspaceID          │
  │ usr_job_interacts         │              │   - permissions (mask)   │
  │   - UserID, JobID         │              │ workspace_invitations    │
  │   - IsSaved (bool)        │              │   - email, token, code   │
  └───────────────────────────┘              └──────────────────────────┘
           │                                            │
           │                                    ┌───────▼──────┐
           │                                    │ WORKSPACE ID │
           │                                    │ = Company ID │
           │                                    └───────┬──────┘
           │                                            │
  ┌────────▼──────────────────────────┐      ┌────────▼──────────┐
  │ JOB DB (job7189_job_db)            │      │ HIRING DB         │
  ├────────────────────────────────────┤      │ (job7189_hiring   │
  │ job_companies                      │      │  _db)             │
  │   - CompanyID = WorkspaceID        │      ├───────────────────┤
  │   - CompanyName, Industry, Size    │      │ rct_hiring_       │
  │ job_jds (optimized read table)     │      │ pipelines         │
  │   - JobID (UUID)                   │      │   - Pipeline ID   │
  │   - CompanyID → WorkspaceID        │      │   - WorkspaceID   │
  │   - Title, Description             │      │   - WorkflowCfg   │
  │   - Requirements (JSON)            │      │ hiring_stages     │
  │   - Location, Salary               │      │   - StageName     │
  │   - DegreeLevel, ContractType      │      │ job_applications  │
  │ job_contractors, job_degreelevels  │      │   - AppID (UUID)  │
  │ job_company_sizes, job_industries  │      │   - JobID         │
  │   (metadata tables)                │      │   - CVID → Cand.  │
  │                                    │      │   - WorkspaceID   │
  │                                    │      │   - StageID       │
  │                                    │      │   - ApplicantID   │
  │                                    │      │ interviews        │
  │                                    │      │   - StartTime     │
  │                                    │      │   - Location      │
  │                                    │      │ hiring_scorecards │
  │                                    │      │   - ScoreJson     │
  │                                    │      │ hiring_executions │
  │                                    │      │   (workflow runs) │
  └────────────────────────────────────┘      └───────────────────┘
```

## API Endpoint Grouping by Use Case

### 1. Candidate Experience
```
┌─ Candidate Journey ──────────────────────────────────────────┐
│                                                              │
│ 1. PROFILE (Identity Service)                               │
│    GET  /api/candidates/profile                             │
│    PUT  /api/candidates/profile                             │
│                                                              │
│ 2. RESUME MANAGEMENT (Candidate Service)                    │
│    GET    /api/resumes               → List my CVs          │
│    POST   /api/resumes               → Upload new CV        │
│    GET    /api/resumes/{id}          → View CV details      │
│    PUT    /api/resumes/{id}          → Update CV metadata  │
│    PATCH  /api/resumes/{id}/default  → Set as default      │
│    DELETE /api/resumes/{id}          → Delete CV           │
│                                                              │
│ 3. FILE UPLOAD (Storage Service)                            │
│    GET  /presigned-url  → Get MinIO upload URL             │
│    (Then PUT file directly to MinIO)                        │
│                                                              │
│ 4. JOB SEARCH (Job Service)                                 │
│    GET /public/jobs                  → Search jobs          │
│    GET /public/jobs/{id}             → View job details     │
│    GET /public/metadata/*            → Get filters          │
│                                                              │
│ 5. JOB APPLICATION (Candidate Service)                      │
│    POST /jobs/{jobId}/apply          → Submit application   │
│    GET  /my-applications             → View my applications │
│                                                              │
│ 6. SAVED JOBS (Candidate Service)                           │
│    POST /interactions/saved-jobs     → Save/unsave job      │
│    GET  /interactions/saved-jobs     → View saved jobs      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 2. Recruiter Experience
```
┌─ Recruiter Journey ──────────────────────────────────────────┐
│                                                              │
│ 1. WORKSPACE SETUP (Workspace Service)                      │
│    POST /workspaces                  → Create workspace      │
│    GET  /my-workspaces               → List my workspaces    │
│    PUT  /workspaces/{ws}             → Update workspace      │
│                                                              │
│ 2. MEMBER MANAGEMENT (Workspace Service)                    │
│    POST /workspaces/{ws}/members/    → Invite members       │
│      invitations/invite-by-email                            │
│    GET  /workspaces/{ws}/members     → List members         │
│    PUT  /workspaces/{ws}/members     → Update permissions   │
│    DELETE /workspaces/{ws}/members/{id} → Remove member    │
│                                                              │
│ 3. COMPANY SETUP (Job Service)                              │
│    GET  /companies/{id}              → Get company info     │
│    PUT  /companies/{id}              → Update company       │
│                                                              │
│ 4. JOB MANAGEMENT (Job Service)                             │
│    GET  /workspaces/{ws}/jobs        → List jobs            │
│    POST /workspaces/{ws}/jobs/draft  → Save draft           │
│    POST /workspaces/{ws}/jobs/submit → Submit for approval  │
│    PUT  /workspaces/{ws}/jobs/{id}   → Update job           │
│    PATCH /workspaces/{ws}/jobs/      → Submit for publish   │
│      {id}/submit                                            │
│    PATCH /workspaces/{ws}/jobs/      → Publish/Unpublish   │
│      {id}/unpublish                                         │
│                                                              │
│ 5. HIRING SETUP (Hiring Service)                            │
│    GET  /workspaces/{ws}/pipelines   → List pipelines       │
│    POST /workspaces/{ws}/pipelines   → Create pipeline      │
│    GET  /workspaces/{ws}/pipelines/  → Get workflow def.    │
│      {id}/workflow                                          │
│    POST /workspaces/{ws}/pipelines/  → Configure workflow   │
│      {id}/workflow                                          │
│                                                              │
│ 6. HIRING BOARD (Hiring Service)                            │
│    GET  /board/{jobId}               → View kanban board    │
│    POST /applications/{id}/move      → Move application     │
│    GET  /applications/{id}           → View app details     │
│                                                              │
│ 7. INTERVIEWS (Hiring Service)                              │
│    POST /applications/{id}/          → Schedule interview   │
│      interviews                                             │
│    PUT  /interviews/{id}             → Reschedule           │
│    DELETE /interviews/{id}           → Cancel               │
│    POST /interviews/{id}/feedback    → Submit feedback      │
│                                                              │
│ 8. EVALUATION (Hiring Service)                              │
│    POST /applications/{id}/          → Submit scorecard     │
│      scorecards                                             │
│    GET  /applications/{id}/          → View evaluations     │
│      scorecards                                             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 3. Admin Experience
```
┌─ Admin Functions ────────────────────────────────────────────┐
│                                                              │
│ 1. JOB APPROVAL (Job Service)                               │
│    GET  /admin/jobs                  → List pending jobs    │
│    PATCH /admin/jobs/{id}/approve    → Approve job         │
│    PATCH /admin/jobs/{id}/reject     → Reject job          │
│                                                              │
│ 2. CATEGORY MANAGEMENT (Job Service)                        │
│    POST /admin/categories/sectors    → Add job sector      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Event-Driven Workflow

```
          Candidate Service                 Kafka                 Hiring Service
          ────────────────                  ─────                 ──────────────

        POST /jobs/{id}/apply
                  │
                  │ (Valid CV, Job exists)
                  │
                  ├─→ Publish Event:
                  │   "candidate.applied"
                  │
                  │   {
                  │    application_id: uuid,
                  │    job_id: uuid,
                  │    cv_id: uuid,
                  │    applicant_id: uuid,
                  │    workspace_id: uuid,
                  │    applied_at: timestamp
                  │   }
                  │
                  └──────────────────────────→ job7189.applications
                                                    │
                                                    ├─→ Subscribe
                                                    │
                                                    ├─→ POST /internal/applications
                                                    │
                                                    └─→ Create JobApplication record
                                                        in hiring_db


          Hiring Service                    Kafka              Communication Service
          ──────────────                    ─────              ─────────────────────

        POST /applications/{id}/move
                  │
                  │ (Validate, Update Stage)
                  │
                  ├─→ Trigger Workflow Pipeline
                  │   (If configured)
                  │
                  ├─→ Publish Event:
                  │   "application.moved"
                  │
                  │   {
                  │    application_id: uuid,
                  │    new_stage_id: uuid,
                  │    stage_name: string,
                  │    candidate_name: string,
                  │    candidate_email: string,
                  │    job_title: string
                  │   }
                  │
                  └──────────────────────────→ job7189.communication
                                                    │
                                                    ├─→ Subscribe
                                                    │
                                                    ├─→ Prepare Email
                                                    │   (Template: stage_moved)
                                                    │
                                                    └─→ POST /internal/email/send
                                                        └─→ Send Email to Candidate
```

## Request/Response Flow Example

```
SCENARIO: Candidate uploads resume and applies to job

1. Frontend: Get Upload URL
   GET /storage/presigned-url?filename=resume.pdf&type=cv
   ↓
   Response:
   {
     "upload_url": "https://minio/upload?signed=...",
     "file_path": "cvs/uuid-1234.pdf",
     "file_url": "https://minio-public/cvs/uuid-1234.pdf"
   }

2. Frontend: Upload file directly to MinIO
   PUT https://minio/upload?signed=...
   (Binary file data)
   ↓
   File stored in MinIO

3. Frontend: Save CV metadata
   POST /candidate/resumes
   {
     "title": "My Resume 2026",
     "cv_path": "cvs/uuid-1234.pdf"
   }
   ↓
   Response:
   {
     "data": {
       "id": "uuid",
       "title": "My Resume 2026",
       "cv_path": "cvs/uuid-1234.pdf",
       "is_default": true,
       "created_at": "2026-01-21T14:44:44Z"
     }
   }

4. Frontend: Search jobs
   GET /job/public/jobs?q=developer
   ↓
   Response:
   {
     "data": [
       {
         "id": "job-uuid",
         "title": "Senior Developer",
         "company_name": "Tech Corp",
         "location": "Ho Chi Minh City",
         ...
       }
     ]
   }

5. Frontend: Apply to job
   POST /candidate/jobs/{job-uuid}/apply
   {
     "cv_id": "cv-uuid"
   }
   ↓
   Candidate Service:
   - Validates CV ownership
   - Fetches Job details
   - Publishes Kafka event
   
   Response:
   {
     "application_id": "app-uuid",
     "message": "Application submitted successfully"
   }

6. Hiring Service receives Kafka event
   - Creates JobApplication record
   - Application appears on Hiring Board
   
   → Recruiter sees new application on kanban board

7. Recruiter moves application to Interview stage
   POST /hiring/applications/{app-uuid}/move
   {
     "new_stage_id": "interview-stage-uuid"
   }
   ↓
   Hiring Service:
   - Updates application stage
   - Triggers workflow
   - Publishes Kafka event
   - Workflow engine sends email via Communication Service
   
   Communication Service sends email to candidate

8. Email received:
   Subject: "You've been moved to Interview stage"
   Body: "Congratulations! You've been moved to the Interview stage..."
```

## Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYERS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ FRONTEND                                                        │
│  ├─ Next.js (React)                                           │
│  ├─ Candidate Portal                                          │
│  └─ Recruiter Dashboard                                       │
│                                                                 │
│ API GATEWAY                                                    │
│  └─ Kong API Gateway (DBless mode)                            │
│                                                                 │
│ MICROSERVICES (Kubernetes)                                    │
│  ├─ Identity Service (Laravel 11 + Keycloak)                 │
│  ├─ Candidate Service (Laravel 11)                           │
│  ├─ Job Service (Laravel 11)                                 │
│  ├─ Hiring Service (Laravel 11)                              │
│  ├─ Workspace Service (Laravel 11)                           │
│  ├─ Communication Service (Laravel 11)                       │
│  └─ Storage Service (Laravel 11 + MinIO)                     │
│                                                                 │
│ MESSAGE QUEUE                                                  │
│  └─ Kafka (Event streaming)                                   │
│                                                                 │
│ DATABASES                                                      │
│  ├─ MySQL 8.0 (One DB per service)                           │
│  │  ├─ job7189_identity_db                                   │
│  │  ├─ job7189_candidate_db                                  │
│  │  ├─ job7189_job_db                                        │
│  │  ├─ job7189_hiring_db                                     │
│  │  ├─ job7189_workspace_db                                  │
│  │  ├─ job7189_communication_db                              │
│  │  └─ job7189_storage_db                                    │
│  ├─ phpMyAdmin (for dev/admin)                               │
│  └─ Elasticsearch (Logging)                                   │
│                                                                 │
│ STORAGE                                                        │
│  └─ MinIO (S3-compatible object storage)                      │
│                                                                 │
│ AUTHENTICATION                                                 │
│  └─ Keycloak (OpenID Connect provider)                        │
│                                                                 │
│ MONITORING                                                     │
│  ├─ Prometheus (Metrics)                                      │
│  ├─ Grafana (Dashboards)                                      │
│  ├─ Filebeat (Log shipping)                                   │
│  └─ Elasticsearch (Log aggregation)                           │
│                                                                 │
│ ORCHESTRATION                                                  │
│  └─ Kubernetes (Kind Cluster)                                 │
│     ├─ Cilium (Network policies)                              │
│     ├─ Cert Manager (SSL/TLS)                                │
│     └─ Docker Registry (Private image storage)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```
