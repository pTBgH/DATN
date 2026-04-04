# Frontend API Quick Reference Guide

## Base URLs by Environment

```
Development:
  Job Service: http://localhost:3001/api
  Candidate Service: http://localhost:3002/api
  Hiring Service: http://localhost:3003/api
  Workspace Service: http://localhost:3004/api
  Identity Service: http://localhost:3005/api
  Communication Service: http://localhost:3006/api
  Storage Service: http://localhost:3007/api

Kubernetes:
  API Gateway: http://kong:8000/api
  (All services routed through Kong)
```

## Common Request Patterns

### Authentication Header
```
Authorization: Bearer {keycloak_jwt_token}
```

### Request Format
```json
{
  "field_name": "value",
  "quantity": 10,
  "active": true
}
```

### Response Format (Success)
```json
{
  "data": {
    "id": "uuid",
    "name": "value",
    "created_at": "2026-01-21T14:44:44.000000Z",
    "updated_at": "2026-01-21T14:44:44.000000Z"
  }
}
```

### Response Format (Error)
```json
{
  "message": "Validation failed",
  "errors": {
    "email": ["The email field is required"]
  }
}
```

### Pagination Query
```
GET /api/resource?page=1&per_page=20
```

---

## Candidate User Workflows

### 1. Register & Complete Profile
```
Step 1: Register via Keycloak
POST {keycloak_url}/auth/realms/job7189/protocol/openid-connect/token
Body: {
  "grant_type": "password",
  "client_id": "job7189-frontend",
  "username": "user@example.com",
  "password": "password"
}
Response: { access_token, refresh_token, ... }

Step 2: Get/Update Profile
GET /api/candidates/profile
Authorization: Bearer {access_token}

PUT /api/candidates/profile
Authorization: Bearer {access_token}
Body: {
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+84912345678",
  "avatar_url": "..."
}
```

### 2. Upload CV
```
Step 1: Get Upload URL
GET /api/storage/presigned-url?filename=john_resume.pdf&type=cv
Response: {
  "upload_url": "https://minio.example.com/upload?X-Amz-Algorithm=...",
  "file_path": "cvs/019be103-99bb-70d8-80b4-36175c4ea020.pdf"
}

Step 2: Upload File to MinIO
PUT {upload_url}
(Binary PDF file)
Response: 200 OK

Step 3: Save CV Metadata
POST /api/candidates/resumes
Authorization: Bearer {access_token}
Body: {
  "title": "My Resume 2026",
  "cv_path": "cvs/019be103-99bb-70d8-80b4-36175c4ea020.pdf"
}
Response: {
  "data": {
    "id": "resume-uuid",
    "title": "My Resume 2026",
    "cv_path": "cvs/019be103-99bb-70d8-80b4-36175c4ea020.pdf",
    "is_default": true,
    "view_url": "https://minio.example.com/cvs/019be103-99bb-70d8-80b4-36175c4ea020.pdf?X-Amz-...",
    "created_at": "2026-01-21T14:44:44Z"
  }
}
```

### 3. Search and Browse Jobs
```
Get Job Categories & Filters
GET /api/jobs/public/metadata/common
Response: {
  "data": {
    "contract_types": [
      { "id": 1, "name": "Indefinite-term" },
      { "id": 2, "name": "Fixed-term" }
    ],
    "degree_levels": [...],
    "company_sizes": [...]
  }
}

Get Districts for a City
GET /api/jobs/public/metadata/districts/{city_id}
Response: {
  "data": [
    { "id": 1, "name": "District 1" },
    { "id": 2, "name": "District 2" }
  ]
}

Search Jobs
GET /api/jobs/public/jobs?q=developer&location_id=123&limit=20&page=1
Response: {
  "data": [
    {
      "id": "job-uuid",
      "title": "Senior Developer",
      "description": "...",
      "company_id": "workspace-uuid",
      "company_name": "Tech Corp",
      "location_id": 123,
      "location_name": "Ho Chi Minh City, District 1",
      "salary_min": 20000000,
      "salary_max": 30000000,
      "contract_type_id": 1,
      "degree_level_id": 5,
      "is_active": true,
      "created_at": "2026-01-20T10:00:00Z"
    }
  ],
  "meta": { "total": 100, "per_page": 20, "current_page": 1 }
}

View Job Details
GET /api/jobs/public/jobs/{job_id}
Response: {
  "data": {
    "id": "job-uuid",
    "title": "Senior Development Engineer",
    "description": "Detailed job description...",
    "requirements_json": {
      "experience_years": 5,
      "required_skills": ["React", "Node.js", "PostgreSQL"],
      "responsibilities": [...]
    },
    "company_id": "workspace-uuid",
    "company_name": "Tech Corp",
    "location_id": 123,
    "location_details": {...},
    "salary_min": 20000000,
    "salary_max": 30000000,
    "is_active": true,
    "view_count": 512,
    "application_count": 23,
    "created_at": "2026-01-20T10:00:00Z"
  }
}
```

### 4. Apply to a Job
```
POST /api/candidates/jobs/{job_id}/apply
Authorization: Bearer {access_token}
Body: {
  "cv_id": "resume-uuid"
}
Response: {
  "application_id": "app-uuid-001",
  "message": "Application submitted successfully"
}
```

### 5. View Application History
```
GET /api/candidates/my-applications
Authorization: Bearer {access_token}
Response: {
  "data": [
    {
      "application_id": "app-uuid-001",
      "job_id": "job-uuid",
      "job_title": "Senior Developer",
      "company_name": "Tech Corp",
      "status": "Under Review",  // or "Contacted", "Rejected", etc.
      "stage": "Initial Review",
      "applied_at": "2026-01-21T14:44:44Z",
      "updated_at": "2026-01-22T09:30:00Z"
    }
  ]
}
```

### 6. Save/Unsave Jobs
```
Save a Job
POST /api/candidates/interactions/saved-jobs
Authorization: Bearer {access_token}
Body: {
  "job_id": "job-uuid",
  "is_saved": true
}
Response: { "message": "Job saved" }

View Saved Jobs
GET /api/candidates/interactions/saved-jobs
Authorization: Bearer {access_token}
Response: {
  "data": [
    {
      "job_id": "job-uuid",
      "job_title": "Senior Developer",
      "company_name": "Tech Corp",
      "saved_at": "2026-01-21T14:44:44Z"
    }
  ]
}

Unsave a Job
POST /api/candidates/interactions/saved-jobs
Authorization: Bearer {access_token}
Body: {
  "job_id": "job-uuid",
  "is_saved": false
}
Response: { "message": "Job removed from saved" }
```

---

## Recruiter User Workflows

### 1. Create Workspace
```
POST /api/workspaces
Authorization: Bearer {access_token}
Body: {
  "name": "Tech Recruitment Co.",
  "email": "contact@techrecruit.com",
  "size": 3,           // Company size category
  "industry": 4,       // Industry category
  "location": "Ho Chi Minh City",
  "city": 123,         // City ID
  "district": 456,     // District ID
  "website": "https://techrecruit.com"
}
Response: {
  "data": {
    "id": "workspace-uuid",
    "name": "Tech Recruitment Co.",
    "email": "contact@techrecruit.com",
    "created_at": "2026-01-21T14:44:44Z"
  }
}
```

### 2. Invite Team Members
```
Invite by Email
POST /api/workspaces/{workspace_id}/members/invitations/invite-by-email
Authorization: Bearer {access_token}
Body: {
  "email": "recruiter@example.com",
  "permissions": {
    "workspace_permissions": 127,    // Bitmask for workspace actions
    "job_permissions": 2047,         // Bitmask for job/posting actions
    "candidate_permissions": 255,    // Bitmask for candidate actions
    "pipeline_permissions": 127      // Bitmask for pipeline actions
  }
}
Response: { "message": "Invitation sent to recruiter@example.com" }

Create Invitation Code
POST /api/workspaces/{workspace_id}/members/invitations/create-code
Authorization: Bearer {access_token}
Response: {
  "data": {
    "code": "ABC123XYZ",
    "expires_at": "2026-02-21T14:44:44Z"
  }
}
```

### 3. Create and Manage Jobs
```
Create Draft Job
POST /api/workspaces/{ws_id}/jobs/draft
Authorization: Bearer {access_token}
Body: {
  "title": "Senior React Developer",
  "description": "We are looking for...",
  "requirements": {
    "experience_years": 5,
    "required_skills": ["React", "TypeScript", "Node.js"],
    "responsibilities": ["Lead frontend development", ...]
  },
  "location_id": 123,
  "salary_min": 20000000,
  "salary_max": 30000000,
  "contract_type_id": 1,
  "degree_level_id": 5,
  "sector_id": 4
}
Response: {
  "data": {
    "id": "job-uuid",
    "title": "Senior React Developer",
    "status": "draft",
    "created_at": "2026-01-21T14:44:44Z"
  }
}

Submit Job for Approval
POST /api/workspaces/{ws_id}/jobs/submit
Authorization: Bearer {access_token}
Body: {
  "job_id": "job-uuid"
}
Response: { "message": "Job submitted for admin approval" }

List My Jobs
GET /api/workspaces/{ws_id}/jobs?status=published&q=developer
Authorization: Bearer {access_token}
Response: {
  "data": [
    {
      "id": "job-uuid",
      "title": "Senior Developer",
      "status": "published",
      "view_count": 523,
      "application_count": 24,
      "is_active": true,
      "created_at": "2026-01-20T10:00:00Z"
    }
  ]
}

Publish Job
PATCH /api/workspaces/{ws_id}/jobs/{job_id}/submit
Authorization: Bearer {access_token}
Response: { "message": "Job published successfully" }

Close Job
PATCH /api/workspaces/{ws_id}/jobs/{job_id}/close
Authorization: Bearer {access_token}
Response: { "message": "Job closed. No more applications accepted." }
```

### 4. Set Up Hiring Pipeline
```
Get Pipeline Templates
GET /api/workspaces/{ws_id}/pipelines/workflow-definitions
Response: {
  "data": [
    {
      "name": "Standard Pipeline",
      "description": "Default hiring workflow",
      "config": { "nodes": [...], "connections": [...] }
    }
  ]
}

Create Pipeline
POST /api/workspaces/{ws_id}/pipelines
Authorization: Bearer {access_token}
Body: {
  "name": "DevOps Hiring",
  "stages": [
    { "name": "CV Review", "color": "#FF5733" },
    { "name": "Technical Test", "color": "#3366FF" },
    { "name": "Technical Interview", "color": "#33FF57" },
    { "name": "HR Interview", "color": "#FF33F1" }
  ]
}
Response: {
  "data": {
    "id": "pipeline-uuid",
    "name": "DevOps Hiring",
    "stages": [
      {
        "id": "stage-uuid-1",
        "name": "CV Review",
        "stage_order": 1,
        "color": "#FF5733"
      },
      {
        "id": "stage-uuid-2",
        "name": "Technical Test",
        "stage_order": 2,
        "color": "#3366FF"
      },
      // ... plus auto-added "Hired" and "Rejected" stages
    ]
  }
}
```

### 5. Access Hiring Board
```
Get Kanban Board
GET /api/hiring/board/{job_id}
Authorization: Bearer {access_token}
Response: {
  "data": {
    "job_id": "job-uuid",
    "job_title": "Senior Developer",
    "company_name": "Tech Corp",
    "stages": [
      {
        "stage_id": "stage-uuid-1",
        "stage_name": "CV Review",
        "stage_order": 1,
        "applications": [
          {
            "application_id": "app-uuid-001",
            "candidate_name": "John Doe",
            "candidate_email": "john@example.com",
            "applied_at": "2026-01-21T14:44:44Z",
            "cv_path": "cvs/uuid.pdf",
            "cv_url": "presigned-url-to-download-cv",
            "status": "New"
          }
        ]
      },
      {
        "stage_id": "stage-uuid-2",
        "stage_name": "Technical Interview",
        "stage_order": 3,
        "applications": []
      }
    ]
  }
}
```

### 6. Move Application & Update Status
```
Move Application to Next Stage
POST /api/hiring/applications/{app_id}/move
Authorization: Bearer {access_token}
Body: {
  "new_stage_id": "stage-uuid-2"
}
Response: {
  "success": true,
  "message": "Application moved to Technical Test",
  "data": {
    "application_id": "app-uuid-001",
    "new_stage_id": "stage-uuid-2",
    "moved_at": "2026-01-22T10:30:00Z"
  }
}
// Email sent to candidate automatically via workflow
```

### 7. Interview Management
```
Schedule Interview
POST /api/hiring/applications/{app_id}/interviews
Authorization: Bearer {access_token}
Body: {
  "start_time": "2026-02-15T14:00:00+07:00",
  "end_time": "2026-02-15T15:30:00+07:00",
  "location": "https://meet.google.com/abc-xyz-def",
  "note": "Technical interview with lead engineer"
}
Response: {
  "data": {
    "id": "interview-uuid",
    "application_id": "app-uuid",
    "start_time": "2026-02-15T14:00:00+07:00",
    "end_time": "2026-02-15T15:30:00+07:00",
    "status": "Scheduled",
    "location": "https://meet.google.com/abc-xyz-def",
    "created_at": "2026-01-22T10:30:00Z"
  }
}

Reschedule Interview
PUT /api/hiring/interviews/{interview_id}
Authorization: Bearer {access_token}
Body: {
  "start_time": "2026-02-16T14:00:00+07:00",
  "end_time": "2026-02-16T15:30:00+07:00",
  "location": "https://meet.google.com/new-link"
}
Response: { "message": "Interview rescheduled and candidate notified" }

Submit Interview Feedback
POST /api/hiring/interviews/{interview_id}/feedback
Authorization: Bearer {access_token}
Body: {
  "feedback": "Excellent communication skills, strong technical knowledge. Recommend moving to HR round."
}
Response: { "message": "Feedback recorded" }

Cancel Interview
DELETE /api/hiring/interviews/{interview_id}
Authorization: Bearer {access_token}
Response: { "message": "Interview cancelled and candidate notified" }
```

### 8. evaluation & Scoring
```
Submit Scorecard
POST /api/hiring/applications/{app_id}/scorecards
Authorization: Bearer {access_token}
Body: {
  "score_data": {
    "technical_skills": 4.5,
    "communication": 4,
    "problem_solving": 5,
    "culture_fit": 3.5
  },
  "comment": "Strong technical background but need to work on communication skills"
}
Response: {
  "data": {
    "id": "scorecard-uuid",
    "application_id": "app-uuid",
    "interviewer_id": "recruiter-uuid",
    "interviewer_name": "Alice Smith",
    "score_data": {...},
    "comment": "...",
    "created_at": "2026-01-22T10:30:00Z"
  }
}

View All Scorecards for Application
GET /api/hiring/applications/{app_id}/scorecards
Authorization: Bearer {access_token}
Response: {
  "data": [
    {
      "id": "scorecard-uuid-1",
      "interviewer_name": "Alice Smith",
      "score_data": {...},
      "comment": "...",
      "created_at": "2026-01-22T10:30:00Z"
    },
    {
      "id": "scorecard-uuid-2",
      "interviewer_name": "Bob Johnson",
      "score_data": {...},
      "comment": "...",
      "created_at": "2026-01-22T11:15:00Z"
    }
  ]
}
```

---

## Error Handling Examples

### Validation Error
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "email": ["The email must be a valid email address"],
    "password": ["The password must be at least 8 characters"]
  }
}
```

### Unauthorized
```json
{
  "message": "Unauthorized"
}
// HTTP Status: 401
```

### Forbidden (No Permission)
```json
{
  "message": "You do not have permission to perform this action"
}
// HTTP Status: 403
```

### Not Found
```json
{
  "message": "Resource not found"
}
// HTTP Status: 404
```

### Server Error
```json
{
  "message": "Internal Server Error",
  "debug": "Error details (only in development)"
}
// HTTP Status: 500
```

---

## Frontend Integration Checklist

- [ ] Setup Keycloak login/logout
- [ ] Implement token refresh mechanism
- [ ] Handle API errors globally
- [ ] Implement retry logic for failed requests
- [ ] Cache job listings for better UX
- [ ] Implement file upload with progress tracking
- [ ] Show loading states for long operations
- [ ] Implement real-time updates (WebSocket or polling)
- [ ] Handle offline scenarios gracefully
- [ ] Implement permission-based UI rendering
- [ ] Handle payment/subscription flows (if applicable)
- [ ] Implement search with debouncing
- [ ] Add API request logging in development
- [ ] Implement proper error notifications

---

## Common Gotchas & Tips

1. **CV Upload Path**: Always store the `file_path` from Storage Service, not the public `file_url`
2. **UUIDs**: Use UUID type for ID fields (not standard auto-increment integers)
3. **Response Wrapping**: Responses wrapped in `data` field, unwrap before using
4. **Pagination**: Start from page 1 (not 0)
5. **Timestamps**: Always ISO 8601 format with timezone
6. **Role Checking**: Check `type` field in user object (recruiter/candidate)
7. **Permission Bitmasks**: Don't send raw numbers, check documentation for specific bits
8. **Timeouts**: Some operations (workflow, emails) are async - don't wait for completion
9. **Concurrency**: Handle race conditions when moving applications between stages
10. **Email Notifications**: Automatic via Kafka - don't try to send manually
