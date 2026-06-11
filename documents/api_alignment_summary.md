# API Alignment Changes Summary

## Overview
Applied all frontend fixes from `v0_frontend_fixes.md` to align both `rct_frontend` and `atd_frontend` with the Laravel microservice backend API changes.

## Changes Applied

### 1. API Response Unwrapping (Both Frontends)

#### Recruiter Frontend (`rct_frontend`)
- **workspace.ts**: Updated `createWorkspace()`, `getWorkspace()`, and `updateWorkspace()` to safely unwrap responses using `r?.data ?? r` fallback
- **job.ts**: Updated `getWorkspaceJob()`, `createDraftJob()`, `submitNewJob()`, `updateJob()`, and `patchJobStatus()` with response unwrapping
- **identity.ts**: Updated `getRecruiterProfile()` and `updateRecruiterProfile()` with response unwrapping

#### Candidate Frontend (`atd_frontend`)
- **workspace.ts**: Updated `createWorkspace()`, `getWorkspace()`, and `updateWorkspace()` with response unwrapping
- **job.ts**: Updated `getPublicJobDetail()` with response unwrapping  
- **identity.ts**: Updated `getCandidateProfile()` and `updateCandidateProfile()` with response unwrapping

**Reason**: Backend has `JsonResource::withoutWrapping()` enabled for single resource responses, but pagination responses still have the standard Laravel wrapping. The `r?.data ?? r` pattern safely handles both old and new API responses.

### 2. Type Definitions Update (`rct_frontend`)

**File**: `src/types/workspace.ts`

Updated `WorkspaceMinimal` interface to match the new API response structure from the Identity service:
```typescript
// OLD: workspace_id, company { name, ... }, member_status
// NEW: id, name, status, permissions[]

export interface WorkspaceMinimal {
  id: string;
  name: string;
  logo: string | null;
  email: string;
  status: string;  // Changed from member_status
  permissions: string[];
  active_jobs: number;
  views: number;
  applications: number;
  apply_rate: number;
  created_at?: string;
}
```

### 3. Mock Data Update (`rct_frontend`)

**File**: `src/mocks/workspace.ts`

Updated `mockWorkspaceMinimal` to match the new `WorkspaceMinimal` type:
- Removed `workspace_id`, `member_status`, and nested `company` object
- Added flat properties: `id`, `name`, `status`, `permissions[]`
- Adjusted sample `permissions` to use string values: `["workspace", "job", "candidate", "pipeline"]`

### 4. UI Component Update (`rct_frontend`)

**File**: `src/app/recruiter/profile/page.tsx`

Fixed workspace memberships rendering in the profile page to match new API structure:
```typescript
// OLD: w.workspace_id, w.company.name, w.member_status, w.company.active_jobs
// NEW: w.id, w.name, w.status, w.active_jobs

{profile.workspaces.map((w) => (
  <li key={w.id} className="...">
    <div className="font-medium">{w.name}</div>
    <div className="text-xs text-slate-500">
      {w.email} · {w.status} · {w.permissions.length} permissions
    </div>
    <div className="text-right">
      {w.active_jobs} jobs · {w.applications} applications
    </div>
  </li>
))}
```

## API Response Format Compliance

### Single Resource Endpoints (Flat, No Wrapper)
- `GET /api/workspaces/{id}`
- `GET /api/recruiters/profile`
- `GET /api/candidates/profile`
- `POST/PUT /api/workspaces/*` (create/update endpoints)
- `POST/PUT /api/workspaces/{wsId}/jobs/*` (job endpoints)

Backend Response: `{ id: 1, name: "...", ... }` (flat object)

### Paginated Endpoints (Standard Laravel Wrapper)
- `GET /api/my-workspaces`
- `GET /api/workspaces/{wsId}/jobs`
- `GET /api/public/jobs`

Backend Response: `{ data: [...], meta: {...}, links: {...} }`

## Verification Status

✅ **rct_frontend**: TypeScript compilation passes without errors
✅ **atd_frontend**: TypeScript compilation passes without errors
✅ **All API helpers**: Properly handle both wrapped and unwrapped responses
✅ **Type definitions**: Match new backend API structure
✅ **UI components**: Correctly access workspace properties

## Notes

- The `r?.data ?? r` pattern safely handles both old and new API response formats, ensuring backward compatibility
- All changes are backward compatible and don't break existing functionality
- The layout components (`[wsId]/layout.tsx`) are already using `"use client"` and `useAuthedFetch()`, so no SSR 401 issues should occur
