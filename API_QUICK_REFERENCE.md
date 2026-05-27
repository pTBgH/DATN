# API Quick Reference

## Import

```typescript
import { jobApi, candidateApi, hiringApi, commApi, storageApi, identityApi, workspaceApi } from '@/lib/api';
import { ApiClientError } from '@/lib/api';
```

---

## Jobs (jobApi)

### Public Jobs
```typescript
// List
jobApi.listPublicJobs({ q: 'developer', page: 1, limit: 20 })

// Get Detail
jobApi.getPublicJobDetail(jobId)

// Metadata
jobApi.getGeneralOptions()
jobApi.getMetadataCommon()
```

### Recruiter Jobs
```typescript
// List workspace jobs
jobApi.listWorkspaceJobs(workspaceId, { q: 'search' })

// Get job
jobApi.getWorkspaceJob(workspaceId, jobId)

// Create draft
jobApi.createDraftJob(workspaceId, { title: '...', ... })

// Submit job
jobApi.submitNewJob(workspaceId, { title: '...', ... })

// Update job
jobApi.updateJob(workspaceId, jobId, { title: '...', ... })
```

---

## Candidates (candidateApi)

### Resumes
```typescript
// List resumes
candidateApi.listResumes()

// Create resume
candidateApi.createResume({ title: 'CV', cv_path: 'path/to/cv.pdf' })

// Set default
candidateApi.setDefaultResume(resumeId)

// Delete
candidateApi.deleteResume(resumeId)
```

### Applications
```typescript
// Apply to job
candidateApi.applyToJob(jobId, { cv_id: 'cv_123', ... })

// Get my applications
candidateApi.getMyApplications()
```

### Interactions
```typescript
// Save/unsave job
candidateApi.toggleSavedJob({ job_id: jobId, is_saved: true })

// Hide/show job
candidateApi.toggleHiddenJob({ job_id: jobId, is_hidden: true })
```

---

## Hiring (hiringApi)

### Pipelines
```typescript
// List
hiringApi.listPipelines(workspaceId)

// Create
hiringApi.createPipeline(workspaceId, { name: '...', ... })
```

### Board & Applications
```typescript
// Get board
hiringApi.getBoard(jobId)

// Get application detail
hiringApi.getApplicationDetail(applicationId)

// Move application between stages
hiringApi.moveApplication(applicationId, { stage_id: 'stage_123' })
```

### Interviews
```typescript
// List interviews
hiringApi.listInterviews(applicationId)

// Create interview
hiringApi.createInterview(applicationId, { 
  type: 'phone',
  scheduled_at: '2024-06-01T10:00:00Z'
})

// Update interview
hiringApi.updateInterview(interviewId, { 
  feedback: 'Good candidate',
  rating: 8
})

// Submit feedback
hiringApi.submitInterviewFeedback(interviewId, 'Feedback text')
```

### Scorecards
```typescript
// Create scorecard
hiringApi.createScorecard(applicationId, {
  score_data: { technical: 8, culture_fit: 7 },
  comment: 'Notes...'
})
```

---

## Identity (identityApi)

### Recruiter Profile
```typescript
// Get
identityApi.getRecruiterProfile()

// Update
identityApi.updateRecruiterProfile({
  company_name: '...',
  email: '...'
})
```

### Candidate Profile
```typescript
// Get
identityApi.getCandidateProfile()

// Update
identityApi.updateCandidateProfile({
  first_name: 'John',
  last_name: 'Doe',
  bio: '...'
})
```

---

## Workspace (workspaceApi)

```typescript
// List my workspaces
workspaceApi.getMyWorkspaces()

// Get workspace
workspaceApi.getWorkspace(workspaceId)

// Create workspace
workspaceApi.createWorkspace({
  name: 'My Company',
  email: 'company@example.com'
})

// Update workspace
workspaceApi.updateWorkspace(workspaceId, {
  name: 'New Name'
})

// Get company type options
workspaceApi.getCompanyOptions()

// Create invite code
workspaceApi.createInviteCode(workspaceId, 48) // 48 hours
```

---

## Communication (commApi)

### Conversations
```typescript
// List
commApi.listConversations()

// Create
commApi.createConversation({
  participant_ids: ['user1', 'user2']
})
```

### Messages
```typescript
// Get messages
commApi.getMessages(conversationId)

// Send message
commApi.sendMessage({
  conversation_id: 'conv_123',
  content: 'Hello!'
})
```

---

## Storage (storageApi)

### File Upload
```typescript
// Get presigned URL
const presigned = await storageApi.getPresignedUrl({
  filename: 'resume.pdf',
  content_type: 'application/pdf'
})

// Upload file
await storageApi.uploadFile(presigned.url, file, file.type)

// Use presigned.public_url to save in DB
```

---

## Admin (adminApi) - RCT Only

### Job Approval
```typescript
// List pending jobs
adminApi.listPendingJobs()

// Approve job
adminApi.approveJob(jobId)

// Reject job
adminApi.rejectJob(jobId, 'Reason...')
```

### Sectors
```typescript
// List sectors
adminApi.listSectors()

// Create sector
adminApi.createSector({
  name: 'Technology',
  code: 'TECH'
})
```

### Admin Lists
```typescript
// List users
adminApi.listAdminUsers()

// List companies
adminApi.listAdminCompanies()
```

---

## Error Handling

```typescript
import { ApiClientError } from '@/lib/api';

try {
  const job = await jobApi.getPublicJobDetail(id);
} catch (error) {
  if (error instanceof ApiClientError) {
    // HTTP Status
    if (error.status === 404) console.log('Not found');
    if (error.status === 401) console.log('Unauthorized');
    if (error.status === 403) console.log('Forbidden');
    
    // Validation Errors
    if (error.errors) {
      console.log(error.errors);
      // { email: ['Email is required', 'Email is invalid'] }
    }
    
    // Error Message
    console.log(error.message);
  }
}
```

---

## Common Patterns

### List with Search & Pagination
```typescript
const result = await jobApi.listPublicJobs({
  q: 'developer',
  page: 2,
  limit: 20
});

console.log(result.data);        // JobJdResource[]
console.log(result.meta.total);  // total count
console.log(result.meta.current_page);
console.log(result.meta.last_page);
```

### Workspace-Scoped Operations
```typescript
const workspaces = await workspaceApi.getMyWorkspaces();
const wsId = workspaces[0].id;

// All operations scoped to workspace
const jobs = await jobApi.listWorkspaceJobs(wsId);
const pipelines = await hiringApi.listPipelines(wsId);
```

### Nested Operations
```typescript
// Get application detail
const app = await hiringApi.getApplicationDetail(applicationId);

// Then get interviews for that application
const interviews = await hiringApi.listInterviews(applicationId);

// Create new interview for application
const interview = await hiringApi.createInterview(applicationId, {
  type: 'phone',
  scheduled_at: '2024-06-01T10:00:00Z'
});
```

### File Upload Flow
```typescript
// 1. Get presigned URL
const presigned = await storageApi.getPresignedUrl({
  filename: 'my-resume.pdf'
});

// 2. Upload file to presigned URL
await storageApi.uploadFile(presigned.url, file);

// 3. Save metadata with public URL
const cv = await candidateApi.createResume({
  title: 'My Resume',
  cv_path: presigned.public_url
});
```

### Batch Operations
```typescript
// Process multiple items in parallel
const approvals = await Promise.all([
  adminApi.approveJob(job1Id),
  adminApi.approveJob(job2Id),
  adminApi.approveJob(job3Id)
]);
```

---

## Testing with Mocks

### Enable Mock Mode
```bash
NEXT_PUBLIC_USE_MOCK=true npm run dev
```

### Or in Code
```typescript
// lib/config.ts
export const config = {
  useMock: true,  // toggle to test with mocks
};
```

### Mock Data Locations
```
/mocks/
├── identity.ts      # mockCandidateProfile, mockRecruiterProfile
├── job.ts           # mockPublicJobs, mockRecruiterJobs
├── candidate.ts     # mockCvs, mockApplicationHistory
├── workspace.ts     # mockMyWorkspaces, mockCompanyOptions
├── hiring.ts        # mockBoardData, mockApplicationDetail, mockInterviews
├── communication.ts # mockConversations, mockMessages
├── storage.ts       # mockPresignedUrl()
└── admin.ts         # mockPendingJobs, mockSectors, mockAdminUsers
```

---

## Configuration

### Environment Variables
```bash
# .env.local
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_API_HOST_OVERRIDE=api.internal
NEXT_PUBLIC_USE_MOCK=false
```

### Change Token Source
```typescript
// lib/api/client.ts - getBrowserToken()
// Current: localStorage('job7189.token')
// Change to your auth provider:
const session = await getSession(); // NextAuth
return session?.accessToken;
```

---

## Best Practices

1. **Always use TypeScript** - Full type coverage
2. **Always handle errors** - Use try-catch with ApiClientError
3. **Use mock mode for development** - Faster, no backend dependency
4. **Test with real API before deploying** - Catch integration issues
5. **Check pagination** - Don't assume page 1 only
6. **Use encodeURIComponent()** - Safe URL encoding (already done)
7. **Batch related calls** - Use Promise.all() when possible
8. **Check errors object** - Validation errors in error.errors
9. **Use config for API URL** - Don't hardcode endpoints
10. **Document new APIs** - Follow existing patterns

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **404 Not Found** | Check ID/slug is correct, endpoint path |
| **401 Unauthorized** | Check token in localStorage, update token refresh |
| **Validation Error** | Check error.errors for field-specific messages |
| **CORS Error** | Backend needs CORS headers, use proxy in dev |
| **Mock data not working** | Ensure NEXT_PUBLIC_USE_MOCK=true |
| **Type errors** | Ensure types match API response structure |
| **Timeout** | Increase fetch timeout or check backend |

---

## Resources

- **Complete Reference:** API_COMPLETE_REFERENCE.md
- **Development Guide:** API_DEVELOPMENT_GUIDE.md
- **Implementation Status:** API_IMPLEMENTATION_STATUS.md
- **Types:** /types/*.ts
- **Mock Data:** /mocks/*.ts
- **API Modules:** /lib/api/*.ts

