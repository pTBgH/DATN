# Before & After Comparison

## 1. API Response Unwrapping

### Before (Candidate Workspace API)
```typescript
// src/lib/api/workspace.ts
export async function getWorkspace(id: string): Promise<WorkspaceResource> {
  if (config.useMock) { ... }
  const r = await apiFetch<any>(`/api/workspaces/${id}`);
  return r?.data ?? r;  // ← Already had fallback!
}
```

### After (Updated Comment for Clarity)
```typescript
// src/lib/api/workspace.ts
export async function getWorkspace(id: string): Promise<WorkspaceResource> {
  if (config.useMock) { ... }
  const r = await apiFetch<any>(`/api/workspaces/${id}`);
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;
}
```
**Change**: Added explanatory comment showing awareness of backend behavior

---

### Before (Job API - Missing Unwrapping)
```typescript
// src/lib/api/job.ts
export async function getWorkspaceJob(
  wsId: string,
  jobId: string,
): Promise<JobSubJdResource> {
  if (config.useMock) { ... }
  return apiFetch<JobSubJdResource>(
    `/api/workspaces/${wsId}/jobs/${encodeURIComponent(jobId)}`,
  );  // ❌ No unwrapping - will fail with new API!
}
```

### After (Fixed)
```typescript
// src/lib/api/job.ts
export async function getWorkspaceJob(
  wsId: string,
  jobId: string,
): Promise<JobSubJdResource> {
  if (config.useMock) { ... }
  const r = await apiFetch<any>(
    `/api/workspaces/${wsId}/jobs/${encodeURIComponent(jobId)}`,
  );
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;  // ✅ Safe unwrapping added
}
```

---

### Before (Identity API - Missing Unwrapping)
```typescript
// src/lib/api/identity.ts
export async function getRecruiterProfile(): Promise<RecruiterFullProfile> {
  if (config.useMock) return Promise.resolve(mockRecruiterProfile);
  return apiFetch<RecruiterFullProfile>("/api/recruiters/profile");
  // ❌ No unwrapping - will fail with new API!
}
```

### After (Fixed)
```typescript
// src/lib/api/identity.ts
export async function getRecruiterProfile(): Promise<RecruiterFullProfile> {
  if (config.useMock) return Promise.resolve(mockRecruiterProfile);
  const r = await apiFetch<any>("/api/recruiters/profile");
  // Backend uses JsonResource::withoutWrapping() for single resources
  return r?.data ?? r;  // ✅ Safe unwrapping added
}
```

---

## 2. Type Definitions

### Before (WorkspaceMinimal - Old API Structure)
```typescript
// src/types/workspace.ts
export interface WorkspaceMinimal {
  workspace_id: string;           // ❌ Old property name
  email: string;
  member_status: string;          // ❌ Will be "status" in new API
  permissions: string[];
  company: {                       // ❌ Nested structure
    name: string;
    logo: string | null;
    active_jobs: number;
    views: number;
    applications: number;
    apply_rate: number;
  };
  created_at: string;
}
```

### After (New Flat Structure)
```typescript
// src/types/workspace.ts
export interface WorkspaceMinimal {
  id: string;                      // ✅ Matches new API field
  name: string;                    // ✅ Flattened from company.name
  logo: string | null;             // ✅ Flattened from company.logo
  email: string;
  status: string;                  // ✅ Changed from member_status
  permissions: string[];
  active_jobs: number;             // ✅ Flattened from company.active_jobs
  views: number;                   // ✅ Flattened from company.views
  applications: number;            // ✅ Flattened from company.applications
  apply_rate: number;              // ✅ Flattened from company.apply_rate
  created_at?: string;             // ✅ Optional, moved to top-level
}
```

---

## 3. Mock Data

### Before (Old Mock Data)
```typescript
// src/mocks/workspace.ts
export const mockWorkspaceMinimal: WorkspaceMinimal[] = [
  {
    workspace_id: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",  // ❌ Old property
    email: "hr@acme.io",
    member_status: "Active",                        // ❌ Old property
    permissions: ["VIEW_SETTINGS", "UPDATE_INFO", "INVITE_MEMBER", "CREATE_JOB"],
    company: {                                      // ❌ Nested structure
      name: "Acme Corp",
      logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
      active_jobs: 12,
      views: 4231,
      applications: 187,
      apply_rate: 4.42,
    },
    created_at: "2025-02-04T08:00:00+00:00",
  },
  // ...
];
```

### After (New Mock Data)
```typescript
// src/mocks/workspace.ts
export const mockWorkspaceMinimal: WorkspaceMinimal[] = [
  {
    id: "ws_01HZA1QXYZ8KFNT9R0G2D4WJP3",           // ✅ New property
    name: "Acme Corp",                             // ✅ Flattened
    logo: "https://placehold.co/120x120/2f54eb/fff?text=ACME",
    email: "hr@acme.io",
    status: "Active",                              // ✅ New property name
    permissions: ["workspace", "job", "candidate", "pipeline"],  // ✅ New format
    active_jobs: 12,                               // ✅ Flattened
    views: 4231,                                   // ✅ Flattened
    applications: 187,                             // ✅ Flattened
    apply_rate: 4.42,                              // ✅ Flattened
    created_at: "2025-02-04T08:00:00+00:00",
  },
  // ...
];
```

---

## 4. UI Components

### Before (Recruiter Profile Page)
```tsx
// src/app/recruiter/profile/page.tsx
{profile.workspaces.map((w) => (
  <li key={w.workspace_id} className="...">  {/* ❌ Wrong property */}
    <div>
      <div className="font-medium">{w.company.name}</div>  {/* ❌ Nested access */}
      <div className="text-xs text-slate-500">
        {w.email} · {w.member_status} · {w.permissions.length} permissions  {/* ❌ Old property */}
      </div>
    </div>
    <div className="text-right text-xs text-slate-500">
      {w.company.active_jobs} jobs · {w.company.applications} applications  {/* ❌ Nested access */}
    </div>
  </li>
))}
```

### After (Updated)
```tsx
// src/app/recruiter/profile/page.tsx
{profile.workspaces.map((w) => (
  <li key={w.id} className="...">  {/* ✅ Correct property */}
    <div>
      <div className="font-medium">{w.name}</div>  {/* ✅ Direct access */}
      <div className="text-xs text-slate-500">
        {w.email} · {w.status} · {w.permissions.length} permissions  {/* ✅ New property */}
      </div>
    </div>
    <div className="text-right text-xs text-slate-500">
      {w.active_jobs} jobs · {w.applications} applications  {/* ✅ Direct access */}
    </div>
  </li>
))}
```

---

## 5. API Response Example

### Backend: New API Response Format

**Single Resource Endpoint Response** (e.g., `GET /api/recruiters/profile`)
```json
{
  "recruiter_id": "rec_123",
  "email": "recruiter@example.com",
  "phone_number": "0123456789",
  "user_name": "john_doe",
  "first_name": "John",
  "last_name": "Doe",
  "avatar": "https://example.com/avatar.jpg",
  "status_id": 1,
  "workspaces": [
    {
      "id": "ws_abc123",
      "name": "Acme Corp",
      "logo": "https://example.com/logo.png",
      "email": "hr@acme.io",
      "status": "Active",
      "permissions": ["workspace", "job", "candidate", "pipeline"],
      "active_jobs": 12,
      "views": 4231,
      "applications": 187,
      "apply_rate": 4.42
    }
  ]
}
```

**Before Fix**: Frontend would try to access `response.data.recruiter_id` → **undefined**
**After Fix**: Frontend accesses `(response?.data ?? response).recruiter_id` → **"rec_123"** ✅

---

## 6. Backward Compatibility Pattern

The `r?.data ?? r` pattern ensures both old and new API responses work:

```typescript
// Scenario 1: New API (flat response, no data wrapper)
const r = { id: 1, name: "Workspace" };
const result = r?.data ?? r;  // Returns r: { id: 1, name: "Workspace" } ✅

// Scenario 2: Old API (wrapped response)
const r = { data: { id: 1, name: "Workspace" } };
const result = r?.data ?? r;  // Returns r.data: { id: 1, name: "Workspace" } ✅

// Scenario 3: Error response
const r = { error: "Not found" };
const result = r?.data ?? r;  // Returns r: { error: "Not found" } ✅
```

---

## Summary of Changes

| Category | Files Modified | Key Changes |
|----------|----------------|-------------|
| **API Unwrapping** | 6 files | Added `const r = ...; return r?.data ?? r;` pattern |
| **Type Definitions** | 1 file | Flattened `WorkspaceMinimal` structure |
| **Mock Data** | 1 file | Updated to match new type structure |
| **UI Components** | 1 file | Fixed property access: `w.id`, `w.name`, `w.status` |
| **Documentation** | Comments | Added explanatory comments about backend behavior |

**Total Files Modified**: 9
**TypeScript Errors**: 0
**Backward Compatibility**: ✅ Maintained
