# API Documentation - Microservices Architecture

## Overview
This job recruitment platform uses 7 microservices with Laravel backends. All services follow a consistent RESTful API structure with authentication via Keycloak tokens and an internal user context middleware.

---

## 1. IDENTITY SERVICE
**Base URL**: `http://identity-service/api`
**Purpose**: User profile management and sync with Keycloak

### Authentication
- Uses `VerifyKeycloakToken` middleware
- Keycloak token validation on protected endpoints
- Supports role-based access (recruiter, candidate)

### Endpoints

#### Public/Health
- `GET /health` - Health check

#### Recruiter Profile (Authenticated)
- `GET /recruiters/profile` - Get my profile
- `PUT /recruiters/profile` - Update my profile
  - **Request**: `{ name, email, ... }` (updatable profil fields)
  - **Response**: Updated recruiter object

#### Candidate Profile (Authenticated)
- `GET /candidates/profile` - Get my profile
- `PUT /candidates/profile` - Update my profile

#### Internal APIs (for other services)
- `POST /internal/auth/sync-user` - Sync user from Keycloak
  - **Request**: `{ keycloak_id, email, name, type }`
  - **Response**: Synced user data
  
- `GET /internal/users/{id}` - Get user details
  - **Response**: `{ internal_id, keycloak_id, email, name, type, ... }`

### Data Models
```
ServiceUser:
- internal_id (UUID)
- keycloak_id (string)
- email (string)
- name (string)
- type (enum: recruiter|candidate)
- created_at, updated_at
```

---

## 2. CANDIDATE SERVICE
**Base URL**: `http://candidate-service/api`
**Purpose**: Resume/CV management and job applications

### Authentication
- Uses `IdentifyUserContext` middleware
- Role guard: `role:candidate`
- Requires Keycloak token

### Endpoints

#### Health
- `GET /health` - Service health check

#### CV/Resume Management
- `GET /resumes` - List my CVs
  - **Response**: `[{ id, title, cv_path, is_default, view_url, ... }]`
  
- `POST /resumes` - Create new CV
  - **Request**: `{ title (required), cv_path (required string from Storage Service) }`
  - **Response**: `{ id, title, cv_path, is_default, ... }`
  
- `GET /resumes/{id}` - Get CV details
  
- `PUT /resumes/{id}` - Update CV metadata
  - **Request**: `{ title }`
  
- `PATCH /resumes/{id}/default` - Set as default CV
  
- `DELETE /resumes/{id}` - Delete CV (soft delete)

#### Job Applications
- `POST /jobs/{jobId}/apply` - Apply to a job
  - **Request**: `{ cv_id (required, must be owned by user) }`
  - **Response**: `{ application_id (UUID), message }`
  - **Side Effects**: Produces Kafka event `job7189.applications`
  
- `GET /my-applications` - Get application history
  - **Response**: `[{ application_id, job_id, status, applied_at, ... }]`

#### Interactions/Saved Jobs
- `POST /interactions/saved-jobs` - Save or unsave a job
  - **Request**: `{ job_id, is_saved (boolean) }`
  
- `GET /interactions/saved-jobs` - Get saved jobs list
  - **Response**: `[{ job_id, saved_at, ... }]`

### Data Models
```
CV:
- CVID (UUID) [PK]
- UserID (UUID) [FK to Identity Service]
- Title (string)
- CVPath (string) - MinIO path "cvs/uuid.pdf"
- IsDefault (boolean)
- IsPublic (boolean)
- Education (JSON array)
- Experience (JSON array)
- TechnicalSkills (JSON array)
- SoftSkills (JSON array)
- Template (JSON)
- CreatedAt, UpdatedAt, DeletedAt

JobInteraction:
- UserID (UUID)
- JobID (UUID)
- IsSaved (boolean)
- CreatedAt, UpdatedAt
```

---

## 3. JOB SERVICE
**Base URL**: `http://job-service/api`
**Purpose**: Job posting management and search

### Authentication
- Uses `IdentifyUserContext` middleware
- Role guard for recruiters: `role:recruiter`
- Public endpoints for job search (no auth required)

### Endpoints

#### Public Endpoints (No Auth)
- `GET /options/general` - Get general metadata options
  
- `GET /public/jobs` - Search jobs (paginated)
  - **Query Params**: `q, location_id, limit, sort_by`
  - **Response**: Paginated job list
  
- `GET /public/jobs/{id}` - Get job details
  - **Response**: `{ id, title, description, company_id, company_name, location, salary, ... }`
  
- `GET /public/metadata/common` - Common metadata (job types, contract types, etc.)
  
- `GET /public/metadata/districts/{city_id}` - Get districts for a city

#### Admin Routes (Super Admin Only)
- `GET /admin/jobs` - List pending jobs for approval
- `PATCH /admin/jobs/{jobId}/approve` - Approve job posting
- `PATCH /admin/jobs/{jobId}/reject` - Reject job posting
- `POST /admin/categories/sectors` - Create job sector

#### Recruiter Routes (Authenticated)
- `GET /workspaces/{wsId}/jobs` - List jobs in workspace
  - **Query Params**: `q, status, exp_years, location_id, sectors, sort_by`
  
- `GET /workspaces/{wsId}/jobs/{jobId}` - Get job details
  
- `PUT /workspaces/{wsId}/jobs/{jobId}` - Update job
  - **Request**: `{ title, description, location, salary_min, salary_max, ... }`
  
- `POST /workspaces/{wsId}/jobs/manual` - Create manual job
  - **Request**: `{ title, description, location, job_type, ... }`
  
- `POST /workspaces/{wsId}/jobs/draft` - Save job as draft
  - **Request**: Same as create
  
- `POST /workspaces/{wsId}/jobs/submit` - Submit job for review
  
- `POST /workspaces/{wsId}/jobs/from-file` - Extract job from file (AI)
  - **Request**: `{ file }`
  
- `PATCH /workspaces/{wsId}/jobs/{jobId}/submit` - Submit for publishing
  
- `PATCH /workspaces/{wsId}/jobs/{jobId}/unpublish` - Unpublish job
  
- `PATCH /workspaces/{wsId}/jobs/{jobId}/close` - Close job
  
- `POST /workspaces/{wsId}/jobs/{jobId}/rollback` - Rollback to previous version

#### Company Management
- `GET /companies/{id}` - Get company details
- `PUT /companies/{id}` - Update company info

#### Internal APIs
- `POST /internal/jobs/batch-info` - Get batch of jobs info (for other services)
  - **Request**: `{ job_ids: [...] }`
  - **Response**: `{ job_id: { title, company_name, ... }, ... }`

### Data Models
```
Job:
- JobID (UUID) [PK]
- CompanyID (UUID) [workspace reference]
- Title (string)
- Description (text)
- Requirements (JSON array)
- LocationID (UUID)
- SalaryMin, SalaryMax (decimal)
- ContractTypeID (FK)
- DegreeLevelID (FK)
- JobTypeID (FK)
- SectorID (FK)
- Status (enum: draft, pending, published, closed)
- IsActive (boolean)
- CreatedAt, UpdatedAt

Company:
- CompanyID (UUID)
- CompanyName (string)
- LocationID (UUID)
- SizeID (FK)
- IndustryID (FK)
- Website (string)
- Description (text)

Reference Tables:
- job_contracttypes (ID, Name) - Full-time, Part-time, Freelance, etc.
- job_degreelevels (ID, Name) - Intern, Junior, Senior, etc.
- job_company_sizes (ID, SizeName) - Company size ranges
- job_industries (ID, IndustryName) - Industry categories
```

---

## 4. HIRING SERVICE
**Base URL**: `http://hiring-service/api`
**Purpose**: Recruitment pipeline, hiring board, interviews, and scorecards

### Authentication
- Uses `IdentifyUserContext` middleware
- Workspace-based permission checking via `CheckHiringPerm` middleware

### Endpoints

#### Internal APIs (for other services)
- `POST /internal/applications` - Create application record
  - **Request**: `{ job_id, cv_id, applicant_id, workspace_id, ... }`
  - **Response**: Created application
  
- `GET /internal/applications/candidate/{id}` - Get applications by candidate

#### Hiring Pipelines (Workflow Definition)
- `GET /workspaces/{workspaceId}/pipelines/workflow-definitions` - Get available workflow templates
  
- `GET /workspaces/{workspaceId}/pipelines` - List all pipelines
  - **Response**: `[{ id, name, is_default, stages: [...], ... }]`
  
- `POST /workspaces/{workspaceId}/pipelines` - Create new pipeline
  - **Request**: `{ name, stages: [{ name, color }, ...] }`
  - **Response**: Created pipeline with auto-added "Hired" and "Rejected" stages
  - **Side Effects**: Produces Kafka event
  
- `GET /workspaces/{workspaceId}/pipelines/{pipelineId}` - Get pipeline details
  
- `PUT /workspaces/{workspaceId}/pipelines/{pipelineId}` - Update pipeline
  
- `DELETE /workspaces/{workspaceId}/pipelines/{pipelineId}` - Delete pipeline

#### Pipeline Workflow Configuration
- `GET /workspaces/{workspaceId}/pipelines/{pipelineId}/workflow` - Get workflow config (graph structure)
  - **Response**: `{ nodes: [...], connections: [...] }`
  
- `POST /workspaces/{workspaceId}/pipelines/{pipelineId}/workflow` - Update workflow config
  - **Request**: `{ nodes: [...], connections: [...] }`

#### Hiring Board (Kanban View)
- `GET /board/{jobId}` - Get hiring board for a job
  - **Response**: 
    ```json
    {
      "job_id": "...",
      "job_title": "...",
      "stages": [
        {
          "stage_id": "...",
          "stage_name": "...",
          "applications": [
            {
              "application_id": "...",
              "candidate_name": "...",
              "cv_path": "...",
              "status": "..."
            }
          ]
        }
      ]
    }
    ```

#### Applications Management
- `GET /applications/{applicationId}` - Get application details
  - **Response**: `{ id, job_id, candidate_id, status, cv_path, email, applied_at, ... }`
  
- `POST /applications/{applicationId}/move` - Move application to different stage
  - **Request**: `{ new_stage_id }`
  - **Side Effects**: Triggers workflow pipeline, sends emails via Kafka
  - **Response**: `{ success, message, data: {...} }`

#### Scorecards (Interview Evaluations)
- `POST /applications/{applicationId}/scorecards` - Create scorecard
  - **Request**: `{ score_data (object), comment }`
  - **Response**: Created scorecard
  
- `GET /applications/{applicationId}/scorecards` - Get all scorecards for application
  - **Response**: `[{ id, interviewer_id, interviewer_name, score_json, comment, created_at, ... }]`

#### Interviews
- `GET /applications/{applicationId}/interviews` - Get interviews for application
  - **Response**: `[{ id, start_time, end_time, status, location, ... }]`
  
- `POST /applications/{applicationId}/interviews` - Schedule new interview
  - **Request**: `{ start_time (datetime, required), end_time (datetime, required), location (nullable, URL for video call), note }`
  - **Response**: Created interview
  - **Side Effects**: Produces Kafka event for Communication Service to send email
  
- `GET /interviews/{interviewId}` - Get interview details
  
- `PUT /interviews/{interviewId}` - Update/reschedule interview
  - **Request**: `{ start_time, end_time, status, location }`
  
- `DELETE /interviews/{interviewId}` - Cancel interview
  
- `POST /interviews/{interviewId}/feedback` - Submit interview feedback
  - **Request**: `{ feedback (string) }`

### Data Models
```
HiringPipeline:
- PipelineID (UUID)
- WorkspaceID (UUID)
- Name (string)
- IsDefault (boolean)
- WorkflowConfig (JSON) - Graph: nodes & connections
- Settings (JSON)

HiringStage:
- StageID (UUID)
- PipelineID (UUID)
- Name (string)
- StageOrder (integer)
- Color (string, hex)
- IsSystemStage (boolean) - "Hired" and "Rejected" are system stages

JobApplication:
- ApplicationID (UUID)
- JobID (UUID) - from Job Service
- CVID (UUID) - from Candidate Service
- WorkspaceID (UUID) - from Workspace Service
- ApplicantID (UUID) - from Identity Service
- StageID (UUID) - current stage in pipeline
- StatusID (foreign key) - application status
- Name, Email, Phone (snapshots from application time)
- CvUrl (cached path to CV file)
- AppliedAt, UpdatedAt

Scorecard:
- ScorecardID (UUID)
- ApplicationID (UUID)
- InterviewerID (UUID)
- InterviewerName (string) - snapshot
- ScoreJson (JSON) - { culture_fit: 5, communication: 4.5, problem_solving: 3, technical_skills: 4 }
- Comment (text)
- CreatedAt, UpdatedAt

Interview:
- InterviewID (UUID)
- ApplicationID (UUID)
- StartTime (datetime)
- EndTime (datetime)
- Status (enum: Scheduled, Completed, Cancelled)
- Location (string) - Meet URL
- Note (text)
- Feedback (text)
- CreatedAt

HiringExecution (Workflow Execution):
- ExecutionID (UUID)
- PipelineID (UUID)
- ApplicationID (UUID)
- Status (enum: running, completed, failed, waiting)
- CurrentNode (string)
- ExecutionData (JSON)
- Logs (JSON array of execution steps)
- StartedAt, FinishedAt
```

---

## 5. WORKSPACE SERVICE
**Base URL**: `http://workspace-service/api`
**Purpose**: Company/workspace management and member permissions

### Authentication
- Uses `IdentifyUserContext` middleware
- Permission-based access control

### Endpoints

#### Public Endpoints
- `GET /options/company-types` - Get company type options
  - **Response**: `[{ id, name }, ...]`

#### Workspace CRUD (Authenticated)
- `POST /workspaces` - Create new workspace
  - **Request**: `{ name, email, location, size, industry, city, district, logo, website }`
  - **Response**: Created workspace
  
- `GET /my-workspaces` - List my workspaces
  - **Response**: `[{ id, name, logo, email, created_at, ... }]`
  
- `GET /workspaces/{workspace}` - Get workspace details
  - **Testing**: Permission check required
  
- `PUT /workspaces/{workspace}` - Update workspace
  - **Request**: `{ name, logo, location, size, city, district, industry, website }`
  
- `DELETE /workspaces/{workspace}` - Delete workspace
  - **Testing**: Permission check required

#### Members Management
- `GET /workspaces/{workspace}/members` - List workspace members
  - **Response**: `[{ recruiter_id, name, email, permissions, status, ... }]`
  
- `PUT /workspaces/{workspace}/members` - Update member permissions
  - **Request**: `{ permissions: { workspace_perm, job_perm, candidate_perm, pipeline_perm } }`
  
- `DELETE /workspaces/{workspace}/members/{recruiter}` - Remove member

#### Invitations
- `POST /invitations/accept` - Accept workspace invitation
  - **Request**: `{ token or code }`
  
- `POST /invitations/join-by-code` - Join using code
  - **Request**: `{ code }`
  
- `POST /workspaces/{workspace}/members/invitations/invite-by-email` - Invite by email
  - **Request**: `{ email, permissions: { ... } }`
  - **Response**: Invitation created
  
- `POST /workspaces/{workspace}/members/invitations/create-code` - Create invite code
  - **Response**: `{ code, expires_at }`

#### Internal APIs
- `GET /internal/workspaces/by-user/{userId}` - Get workspaces for user (for Identity Service)
  
- `GET /internal/permissions/{wsId}/{userId}` - Get user permissions in workspace
  - **Response**: `{ workspace_perm, job_perm, candidate_perm, pipeline_perm }`
  
- `POST /internal/companies/batch-info` - Get batch company info (for Job Service)
  - **Request**: `{ company_ids: [...] }`

### Data Models
```
Workspace:
- WorkspaceID (UUID)
- Name (string)
- Logo (string URL)
- Email (string)
- CreatedAt, UpdatedAt

WorkspaceInvitation:
- InvitationID (UUID)
- WorkspaceID (UUID)
- InvitedBy (UUID) - who sent the invite
- email (string)
- permissions (JSON)
- token (string) - 64-char unique token
- code (string) - 10-char human-readable code
- expires_at (datetime)
- created_at, updated_at

WorkspaceMember:
- RecruiterID (UUID) [FK to Identity Service]
- WorkspaceID (UUID)
- workspace_permissions (bigint bitmask)
- job_permissions (bigint bitmask)
- candidate_permissions (bigint bitmask)
- pipeline_permissions (bigint bitmask)
- status_id (enum: 1=Active, 2=Pending)
- created_at, updated_at

Permission Bitmasks:
- workspace_permissions: VIEW_SETTINGS, UPDATE_INFO, DELETE_WORKSPACE, etc.
- job_permissions: READ_JOB, CREATE_JOB, UPDATE_JOB, DELETE_JOB, PUBLISH_JOB, etc.
- candidate_permissions: READ_CANDIDATE, EXPORT_CANDIDATE, etc.
- pipeline_permissions: READ_PIPELINE, CREATE_PIPELINE, UPDATE_PIPELINE, DELETE_PIPELINE, etc.
```

---

## 6. COMMUNICATION SERVICE
**Base URL**: `http://communication-service/api`
**Purpose**: Email communications and messaging

### Authentication
- Uses `IdentifyUserContext` middleware for protected routes

### Endpoints

#### Health
- `GET /health` - Service health check

#### Chat (Authenticated)
- `GET /conversations` - List my conversations
  
- `POST /conversations` - Start new chat
  - **Request**: `{ participant_id }`
  
- `GET /conversations/{id}/messages` - Get messages in conversation
  
- `POST /messages` - Send message
  - **Request**: `{ conversation_id, message }`

#### Internal APIs
- `POST /internal/email/send` - Send email (called by other services)
  - **Request**: `{ to, subject, template, variables }`
  - **Response**: `{ status }`

### Data Models
```
Email:
- Sent via internal API
- Templates available: emails.stage_moved, emails.interview_scheduled, etc.
- Variables injected into templates for personalization
```

---

## 7. STORAGE SERVICE
**Base URL**: `http://storage-service/api`
**Purpose**: File upload/download management with MinIO

### Authentication
- Public upload URL generation (no auth)
- Internal APIs for file access

### Endpoints

#### Upload Management
- `GET /presigned-url` - Get upload URL (public)
  - **Query Params**: `filename, type (cv|avatar|logo)`
  - **Response**: 
    ```json
    {
      "success": true,
      "upload_url": "minio-presigned-url-for-PUT",
      "file_path": "cvs/uuid.pdf",
      "file_url": "public-access-url"
    }
    ```
  - **How it works**:
    1. Frontend calls this endpoint with filename and type
    2. Gets back a presigned URL valid for 20 minutes
    3. Frontend directly PUTs file to that URL using the `upload_url`
    4. Frontend stores the returned `file_path` and sends it to appropriate service

#### Internal APIs
- `POST /internal/files/view-url` - Get view/download URL
  - **Request**: `{ path: "cvs/uuid.pdf" }`
  - **Response**: `{ url: "presigned-download-url" }`
  - Called by Candidate Service to prepare view links for CVs

### Data Models
```
MinIO Bucket Structure:
- cvs/ - CV files (uploaded by candidates)
- avatars/ - Profile images
- logos/ - Company logos

File Naming: {type}s/{uuid}.{extension}
Example: cvs/019be103-99bb-70d8-80b4-36175c4ea020.pdf
```

---

## Request/Response Patterns

### Standard Response Format
All API responses follow Laravel Resource pattern (snake_case transformation):

```json
{
  "data": {
    "id": "uuid",
    "name": "string",
    "created_at": "2026-01-21T14:44:44.000000Z",
    "updated_at": "2026-01-21T14:44:44.000000Z"
  }
}
```

For collections:
```json
{
  "data": [
    { "id": "uuid", "name": "..." },
    { "id": "uuid", "name": "..." }
  ],
  "links": {
    "first": "url?page=1",
    "last": "url?page=n",
    "next": "url?page=2"
  },
  "meta": {
    "current_page": 1,
    "from": 1,
    "last_page": 10,
    "per_page": 15,
    "to": 15,
    "total": 150
  }
}
```

### Error Responses
```json
{
  "message": "Error description",
  "errors": {
    "field_name": ["validation message"]
  }
}
```

HTTP Status Codes:
- `200` - Success
- `201` - Created
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden (no permission)
- `404` - Not found
- `422` - Unprocessable entity
- `500` - Server error

---

## Authentication Mechanisms

### 1. Keycloak Integration (Identity Service)
- Uses `VerifyKeycloakToken` middleware
- Validates JWT tokens from Keycloak
- Extracts user info: `keycloak_id`, `email`, `name`, `type` (recruiter/candidate)

### 2. Internal User Context (Other Services)
- Uses `IdentifyUserContext` middleware
- Middleware extracts user info from token headers
- Sets authenticated user in Auth facade
- Available as `Auth::user()` in controllers

### 3. Role-Based Guards
- `role:recruiter` - Only recruiters can access
- `role:candidate` - Only candidates can access
- `super.admin` - Only super admins can access

### 4. Permission-Based Checks
- Workspace: Bitmask-based permissions
- Services use `CheckHiringPerm`, `CheckJobPerm` middleware
- Permissions stored as bigint bitmasks in database

### 5. Service-to-Service Communication
- Internal APIs use logical foreign keys (no token validation)
- Rely on network isolation in Kubernetes
- Future: Can add internal API keys/secrets

---

## Event-Driven Communication (Kafka)

### Published Events
1. **job7189.applications** - When candidate applies
   ```json
   {
     "event_type": "candidate.applied",
     "data": {
       "application_id": "uuid",
       "job_id": "uuid",
       "cv_id": "uuid",
       "applicant_id": "uuid",
       "applicant_email": "email@",
       "workspace_id": "uuid",
       "applied_at": "iso8601"
     }
   }
   ```

2. **job7189.pipeline** - When pipeline is created
   ```json
   {
     "event_type": "pipeline.created",
     "data": {
       "pipeline_id": "uuid",
       "workspace_id": "uuid",
       "name": "string",
       "is_default": boolean
     }
   }
   ```

3. **job7189.communication** - When email/message needs sending
   - Triggered by stage movements, interview scheduling
   - Consumed by Communication Service

### Event Flow Examples
1. **Application Applied**:
   - Candidate Service publishes → Hiring Service consumes → Creates JobApplication record

2. **Application Moved to Stage**:
   - Hiring Service triggers workflow → Produces email event → Communication Service sends email

---

## Data Flow Examples

### Complete Application Flow
```
1. Frontend: Call Storage Service → GET /presigned-url
   → Get upload URL
   
2. Frontend: PUT file to MinIO via presigned URL
   → File uploaded
   
3. Frontend: Call Candidate Service → POST /resumes
   → Sends cv_path from Storage Service
   → CV record created in candidate_db
   
4. Frontend: Call Job Service → GET /public/jobs/{jobId}
   → Gets job details (enriched with company info)
   
5. Frontend: Call Candidate Service → POST /jobs/{jobId}/apply
   → Sends cv_id
   → Publishes Kafka event
   
6. Hiring Service: Consumes Kafka event → POST /internal/applications
   → Creates JobApplication record
   → Application appears on Hiring Board
```

### Hiring Board Workflow
```
1. Recruiter: Call Hiring Service → GET /board/{jobId}
   → Returns kanban board with stages and applications
   
2. Recruiter: Call Hiring Service → POST /applications/{id}/move
   → Moves application to new stage
   → Triggers workflow pipeline
   → Publishes Kafka event
   
3. Communication Service: Consumes event
   → Sends email to candidate about stage change
   
4. Recruiter: Call Hiring Service → POST /applications/{id}/interviews
   → Schedules interview
   → Creates Interview record
   
5. Recruiter: Call Hiring Service → POST /applications/{id}/scorecards
   → Submits evaluation scores
   → Creates Scorecard record
```

---

## File Storage Structure

### MinIO Bucket Layout
```
job7189-bucket/
├── cvs/
│   ├── 019be103-99bb-70d8-80b4-36175c4ea020.pdf
│   ├── 019bcb34-47bc-708b-b23f-8c9e3b8db0d6.pdf
│   └── ...
├── avatars/
│   ├── user-avatar-uuid.png
│   └── ...
└── logos/
    ├── company-logo-uuid.png
    └── ...
```

Presigned URLs generated by Storage Service are valid for:
- Upload: 20 minutes
- Download/View: As per configuration (typically longer)

---

## Database Structure Summary

### Databases
- `job7189_candidate_db` - CVs, user interactions
- `job7189_job_db` - Jobs, companies, metadata
- `job7189_hiring_db` - Applications, pipelines, stages, interviews, scorecards
- `job7189_workspace_db` - Workspaces, members, invitations, permissions
- `job7189_communication_db` - Messages, conversations, email logs
- `job7189_storage_db` - File metadata (optional)
- `job7189_identity_db` - User profiles (Keycloak managed)

### Key Relationships
```
User (Keycloak) 
  ↓
ServiceUser (in each service)
  ↓
├── Recruiter → Workspace → WorkspaceMember → Permissions
│                   ↓
│              Job → Company
│                   ↓
│              JobApplication ← Application
│
└── Candidate → CV (Collection)
                   ↓
              CVPath (MinIO)
```

---

## Important Notes for Frontend Development

1. **CV Upload Flow**:
   - Don't upload files directly to services
   - Always use Storage Service `/presigned-url` endpoint
   - Store returned `file_path` when saving CV

2. **Resource Transformation**:
   - All APIs return snake_case in responses
   - Send requests in snake_case (Laravel auto-transforms to PascalCase in DB)

3. **Workspace-First Architecture**:
   - Most operations are scoped to workspace
   - Routes pattern: `/workspaces/{wsId}/resource`

4. **Permission System**:
   - Use returned permission bitmasks
   - Check before showing UI elements
   - Server validates all operations

5. **Async Operations**:
   - Application workflows run asynchronously via Kafka
   - Emails sent via Communication Service
   - Use polling or WebSocket for real-time updates

6. **Soft Deletes**:
   - CVs use soft deletes (DeletedAt column)
   - Filter out deleted records in requests

7. **Pagination**:
   - Most list endpoints support: `page`, `per_page` query parameters
   - Default limit: 15-20 items per page

---

## Frontend Integration Checklist

- [ ] Implement file upload via Storage Service presigned URLs
- [ ] Handle Keycloak token storage and refresh
- [ ] Implement user context middleware simulation on frontend
- [ ] Build Job search interface with filters
- [ ] Build CV management interface
- [ ] Implement application submission flow
- [ ] Build Hiring Board (Kanban view)
- [ ] Implement Workspace management
- [ ] Handle real-time notifications for stage changes
- [ ] Display interview scheduling UI
- [ ] Implement scorecard submission form
- [ ] Build workspace member invitation system
- [ ] Handle permission-based UI visibility
- [ ] Implement error handling and user feedback
