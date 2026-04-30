# API Inventory — Job7189 Microservices

> Tài liệu này được sinh ra bằng cách đọc trực tiếp `routes/api.php` + `Http/Controllers/**/*.php` + `Http/Resources/**/*.php` của 7 service Laravel trong `src/`, và `infras/kong/kong.yml`.
> Đây là **contract** giữa frontend Next.js và backend; cấu trúc mock data trong `frontend/src/mocks` phải khớp **chính xác** với cột “Output schema” ở dưới.

## 0. Conventions

### 0.1 Gateway

- Tất cả request từ frontend đi qua **Kong Gateway** (DB-less mode), không gọi trực tiếp service.
- URL cluster nội bộ:`http://172.22.0.4:30003` (NodePort).
- DNS public (qua ingress/Cloudflare): `https://api.job7189.com` — dùng cái này từ frontend khi triển khai.
- Header bắt buộc cho route nội bộ Kong:
  - `Host: api.job7189.com`
  - `Authorization: Bearer <jwt>` (cho route có plugin `jwt`)
  - `Content-Type: application/json` (cho POST/PUT/PATCH có body)
  - `Accept-Language: vi|en` (tuỳ chọn, dùng cho `/api/options/company-types`)

### 0.2 Authentication — Keycloak realm `job7189`

| Field | Value |
|---|---|
| Issuer | `http://auth.job7189.local/realms/job7189` (cluster) hoặc `https://auth.job7189.com/realms/job7189` (public) |
| Token endpoint | `{ENDPOINT}/realms/job7189/protocol/openid-connect/token` |
| Algorithm | RS256 |
| Default flow (server-to-server) | `grant_type=client_credentials` với `client_id=candidate-app-dev`, `client_secret=KXrY9JiKFTbsWUdmMSKXWiw0uP21qw7x` |
| Recommended flow (browser) | OIDC Authorization Code + PKCE với client public `web-frontend` (cần tạo trong Keycloak) |
| Token TTL | 300s (`expires_in`) |
| JWT validated by | Kong plugin `jwt` (Consumer `keycloak-user`, key trùng với `iss` claim) |

> Internal realm (chỉ cho service-to-service qua mTLS) **không dùng** ở frontend. Frontend chỉ thấy realm `job7189`.

### 0.3 Response shape

Laravel API Resource trả về một trong hai dạng:

- Single resource → `{ ...fields }` (không bọc).
- Collection / pagination → `{ "data": [...], "links": {...}, "meta": {...} }`.
- Lỗi validate → `422 { "message": "...", "errors": { "field": [...] } }`.
- Không có quyền → `403 { "message": "Forbidden" }`.
- Không tìm thấy → `404 { "message": "..." }`.

### 0.4 Naming

- Mọi field response **đã được map sang `snake_case`** ở Resource layer (ví dụ `WorkspaceID` → `workspace_id`).
- Frontend không bao giờ thấy PascalCase từ DB.

### 0.5 Bảng tóm tắt service & namespace cluster

| Service | DNS in-cluster | Mục đích | Source folder |
|---|---|---|---|
| identity-service | `identity-service.job7189-apps.svc.cluster.local` | Hồ sơ recruiter / candidate, user lookup | `src/identity_service` |
| workspace-service | `workspace-service.job7189-apps.svc.cluster.local` | Workspace + thành viên + invitation + permission | `src/workspace_service` |
| job-service | `job-service.job7189-apps.svc.cluster.local` | Job CRUD, công ty (JobCompany), metadata | `src/job_service` |
| candidate-service | `candidate-service.job7189-apps.svc.cluster.local` | CV, ứng tuyển, tương tác (saved/hidden) | `src/candidate_service` |
| hiring-service | `hiring-service.job7189-apps.svc.cluster.local` | Pipeline, board kanban, interview, scorecard | `src/hiring_service` |
| communication-service | `communication-service.job7189-apps.svc.cluster.local` | Conversation + message + email nội bộ | `src/communication_service` |
| storage-service | `storage-service.job7189-apps.svc.cluster.local` | Presigned URL S3/MinIO | `src/storage_service` |

---

## 1. Identity Service

`src/identity_service/laravel_back/routes/api.php` · Kong route prefix: `identity-*`.

### 1.1 Public

| Method | Path (qua Kong) | Auth | Mô tả | Controller | Output |
|---|---|---|---|---|---|
| `GET` | `/api/health` | — | Health check | inline | `{"status":"ok","service":"Identity Service"}` |
| `GET` | `/api/companies/search?query=...` | — | Tìm công ty (autocomplete) | `Company\CompanyController@search` | `[{ "CompanyID": "...", "CompanyName": "...", ...}]` (không qua Resource) |
| `GET` | `/api/options/general` | — | Danh mục JobType, JobSector, WorkingType, ContractType, DegreeLevel, Currency, Sex | `OptionController@getGeneralOptions` | `{ "job_types":[{"id":1,"name":"..."}], "job_sectors":[...], "working_types":[...], ... }` |

### 1.2 Recruiter — `role:recruiter`

Yêu cầu: `Authorization: Bearer <jwt với realm role recruiter>`.

| Method | Path | Mô tả | Controller | Input | Output (Resource) |
|---|---|---|---|---|---|
| `GET` | `/api/recruiters/profile` | Lấy hồ sơ recruiter hiện tại + danh sách workspace | `Recruiter\RecruiterController@getMyProfile` | — | `RecruiterFullProfile` (xem §1.5) |
| `PUT` | `/api/recruiters/profile` | Cập nhật hồ sơ | `Recruiter\RecruiterController@update` | `{ user_name?, phone_number?, first_name?, last_name? }` | `RecruiterResource` |
| `POST` | `/api/recruiters/profile` | Khởi tạo profile (gắn `company_id`) | `Recruiter\RecruiterController@store` | `{ company_id?, job_title? }` | `RecruiterResource` |

### 1.3 Candidate — `role:candidate`

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/candidates/profile` | Hồ sơ candidate | `Candidate\CandidateProfileController@show` | — | `CandidateProfileResource` |
| `PUT` | `/api/candidates/profile` | Cập nhật hồ sơ candidate | `Candidate\CandidateProfileController@update` | `{ user_name?, first_name?, last_name?, phone_number?, sex_id?, birth?, avatar?, experience_years? }` | `CandidateProfileResource` |

### 1.4 Internal (service-to-service, **không expose ra frontend**)

| Method | Path | Mô tả |
|---|---|---|
| `POST` | `/api/internal/auth/sync-user` | Webhook từ Keycloak khi tạo user mới |
| `GET` | `/api/internal/users/{id}` | Lookup user nội bộ |

### 1.5 Schema chính

#### `RecruiterResource`
```ts
type RecruiterResource = {
  recruiter_id: string;
  email: string;
  phone_number: string | null;
  user_name: string;
  first_name: string;
  last_name: string;
  avatar?: string | null;
  status_id: number;
  workspaces?: WorkspaceMinimal[];
};

type WorkspaceMinimal = {
  workspace_id: string;
  email: string;
  member_status: string;
  permissions: string[];
  company: {
    name: string;
    logo: string | null;
    active_jobs: number;
    views: number;
    applications: number;
    apply_rate: number;
  };
  created_at: string; // ISO 8601
};
```

#### `RecruiterFullProfile` (response của `GET /api/recruiters/profile`)
```ts
type RecruiterFullProfile = {
  recruiter_id: string;
  email: string;
  phone_number: string | null;
  user_name: string;
  first_name: string;
  last_name: string;
  avatar: string | null;
  status_id: number;
  workspaces: WorkspaceMinimal[]; // được fetch từ workspace-service qua API internal
};
```

---

## 2. Workspace Service

`src/workspace_service/laravel_back/routes/api.php` · Kong route prefix: `workspace-*`.

### 2.1 Public

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/options/company-types` | Sizes + Industries cho form tạo công ty | `OptionController@getCompanyOptions` | header `Accept-Language: vi\|en` | `{ "sizes": [{"id":1,"name":"1-10"}], "industries":[{"id":1,"name":"...","code":"IT"}] }` |

### 2.2 Internal (S2S)

| Method | Path | Mô tả |
|---|---|---|
| `GET` | `/api/internal/workspaces/by-user/{userId}` | Trả về tất cả workspace của user (gọi từ identity-service) |
| `GET` | `/api/internal/permissions/{wsId}/{userId}` | Permission của user trong workspace |

### 2.3 Authenticated — `IdentifyUserContext`

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/my-workspaces` | List workspace của recruiter hiện tại | `Workspace\WorkspaceController@index` | — | `WorkspaceResource[]` (collection) |
| `POST` | `/api/workspaces` | Tạo workspace mới | `Workspace\WorkspaceController@store` | `{ name*, email*, location?, size?, industry?, city?, district?, logo?, website? }` | `WorkspaceResource` |
| `GET` | `/api/workspaces/{workspace}` | Chi tiết workspace | `Workspace\WorkspaceController@show` (cần `VIEW_SETTINGS`) | — | `WorkspaceResource` |
| `PUT` | `/api/workspaces/{workspace}` | Cập nhật | `Workspace\WorkspaceController@update` (cần `UPDATE_INFO`) | `{ name?, logo?, location?, size?, city?, district?, industry?, website? }` | `WorkspaceResource` |
| `DELETE` | `/api/workspaces/{workspace}` | Xóa | `Workspace\WorkspaceController@destroy` (cần `DELETE_WORKSPACE`) | — | `{ "message": "..." }` |
| `GET` | `/api/workspaces/{workspace}/members` | List thành viên | `Workspace\WorkspaceMemberController@index` | — | `RecruiterResource[]` |
| `GET` | `/api/workspaces/{workspace}/members/pending` | Thành viên chờ duyệt | `Workspace\WorkspaceMemberController@indexPending` | — | `RecruiterResource[]` |
| `POST` | `/api/workspaces/{workspace}/invite-code` | Tạo mã mời | `Workspace\WorkspaceMemberController@createInviteCode` | `{ expires_in_hours?: number }` | `{ ivitetation_id, code, expires_at }` (lưu ý typo trong code: `ivitetation_id`) |
| `POST` | `/api/workspaces/{workspace}/invite-mail` | Mời qua mail | `Workspace\WorkspaceMemberController@inviteViaMail` | `[{ email*, ...permissions }]` | `{ "message": "Invitations sent." }` |
| `PUT` | `/api/workspaces/{workspace}/members/{recruiterId}` | Sửa quyền 1 thành viên | `Workspace\WorkspaceMemberController@updateMember` | permission keys | `{ "message": "..." }` |
| `DELETE` | `/api/workspaces/{workspace}/members/{recruiter}` | Xoá thành viên | `Workspace\WorkspaceMemberController@removeMember` | — | `204` |
| `POST` | `/api/invitations/accept` | Chấp nhận mời (token) | `Workspace\WorkspaceMemberController@accept` | `{ token: string(40) }` | `{ success, message, workspace: WorkspaceResource }` |
| `POST` | `/api/invitations/join-by-code` | Tham gia bằng mã | `Workspace\WorkspaceMemberController@joinByCode` | `{ code: string(6) }` | `{ success, message, workspace? }` |

### 2.4 Recruiter convenience (vẫn trong workspace-service)

| Method | Path | Mô tả | Input |
|---|---|---|---|
| `PUT` | `/api/recruiters/sectors` | Cập nhật ngành quan tâm | `{ sectors: number[] }` |
| `POST` | `/api/recruiters/interactions/saved-jobs` | Toggle saved | `{ job_id*, is_saved* }` |
| `POST` | `/api/recruiters/interactions/hidden-jobs` | Toggle hidden | `{ job_id*, is_hidden* }` |

### 2.5 Schema

#### `WorkspaceResource`
```ts
type WorkspaceResource = {
  // CompanyMinimalState
  id: string;          // = WorkspaceID
  name: string;
  logo: string | null;
  permissions: number; // bitmask permissions
  // CompanyState
  location: string | null;
  active_jobs: number;
  views: number;
  applications: number;
  apply_rate: number;     // %
  email: string;
  plan: string | null;
  usage: number | null;
};
```

> Lưu ý: `WorkspaceResource` ở **identity-service** trả về cấu trúc khác (xem §1.5) — cùng tên class nhưng schema khác.

---

## 3. Job Service

`src/job_service/laravel_back/routes/api.php` · Kong route prefix: `job-*`.

### 3.1 Public

| Method | Path | Mô tả | Controller | Output |
|---|---|---|---|---|
| `GET` | `/api/public/jobs` | List job (homepage) | `Job\JobController@publicSearch` | Pagination of `JobJdResource` |
| `GET` | `/api/public/jobs/{idOrSlug}` | Chi tiết job public | `Job\JobController@publicDetail` | `JobJdResource` |
| `GET` | `/api/options/general` | Như Identity (route trùng) | `OptionController@getGeneralOptions` | giống §1.1 |
| `GET` | `/api/metadata/common` | Sizes + Industries + Cities | `Public\MetadataController@getCommon` | `{ sizes:[{id,name}], industries:[{id,name}], cities:[{id,name}] }` |
| `GET` | `/api/metadata/districts/{cityId}` | Quận theo city | `Public\MetadataController@getDistricts` | `[{id,name}]` |
| `GET` | `/api/public/metadata/common` | Variant public | giống trên | giống trên |
| `GET` | `/api/public/metadata/districts/{cityId}` | Variant public | giống trên | giống trên |
| `GET` | `/api/companies/{id}` | Chi tiết công ty | `Job\JobCompanyController@show` | JobCompany model serialized |

Query params cho `publicSearch`: `q?`, `location_id?`, `limit?` (default 20, paginated).

### 3.2 Recruiter — `role:recruiter`

Yêu cầu: middleware `IdentifyUserContext` + `role:recruiter`.

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/workspaces/{wsId}/jobs` | List jobs trong workspace với filter | `Job\JobController@index` | query: `q?, status?, exp_years?, location_id?, job_types[]?, sectors[]?, sort_by?` | Pagination of `JobSubJdResource` |
| `GET` | `/api/workspaces/{wsId}/jobs/{jobId}` | Chi tiết | `Job\JobController@show` | — | `JobSubJdResource` |
| `POST` | `/api/workspaces/{wsId}/jobs/manual` | Tạo manual | `Job\JobMakingController@createManualJob` | `JobInput` (xem §3.6) | `JobSubJdResource` |
| `POST` | `/api/workspaces/{wsId}/jobs/draft` | Lưu nháp | `Job\JobMakingController@saveDraft` | `JobInput` | `JobSubJdResource` |
| `POST` | `/api/workspaces/{wsId}/jobs/submit` | Gửi duyệt | `Job\JobMakingController@submitNewJob` | `JobInput` | `JobSubJdResource` |
| `PUT` | `/api/workspaces/{wsId}/jobs/{jobId}` | Sửa | `Job\JobController@update` (trait `HandlesJobUpdate`) | `JobInput` | `JobSubJdResource` |
| `PATCH` | `/api/workspaces/{wsId}/jobs/{jobId}/submit` | Submit nháp đã có | `Job\JobStatusController@submit` | — | `JobSubJdResource` |
| `POST` | `/api/workspaces/{wsId}/jobs/{jobId}/rollback` | Quay lại version | `Job\JobHistoryController@rollback` | `{ version: number }` | `JobSubJdResource` |

### 3.3 Admin — `super.admin`

| Method | Path | Mô tả |
|---|---|---|
| `GET` | `/api/admin/jobs` | List job đang chờ duyệt |
| `PATCH` | `/api/admin/jobs/{jobId}/approve` | Duyệt |
| `GET`/`POST`/`PUT`/`DELETE` | `/api/admin/categories/sectors` | CRUD ngành nghề (`Admin\CategoryController`) |

### 3.4 Internal (S2S)

| Method | Path | Mô tả |
|---|---|---|
| `POST` | `/api/internal/jobs/batch-info` | Lấy nhanh thông tin nhiều job (`{ ids: string[] }`) |

### 3.5 Schema

#### `JobSubJdResource` (Recruiter view)
```ts
type JobSubJdResource = {
  job_id: string;
  title: string;
  slug: string;
  company_id: string;
  company_name: string | null; // được enrich bởi CompanyDataEnricher
  company_logo?: string | null;
  status: string;              // enum label, ví dụ "Draft" | "Pending" | "Published" | "Closed"
  description: string | null;
  requirements: string | null;
  benefits: string | null;
  salary_min: number | null;
  salary_max: number | null;
  deadline: string;            // YYYY-MM-DD
  view_count: number;
  apply_count: number;
};
```

#### `JobJdResource` (Public view) — schema tương tự nhưng nguồn dữ liệu là bảng `job_jds` (read-optimized).

#### `JobInput` (POST/PUT body)
```ts
type JobInput = {
  company_id?: string;
  pipeline_id?: string;          // <=36 chars
  title: string;                 // <=1000
  description?: string;
  requirements?: string;
  benefits?: string;
  keywords?: string;
  deadline?: string;             // ISO date, after_or_equal:today
  up_date?: string;              // ISO date, after_or_equal:today
  salary_min?: number;
  salary_max?: number;
  currency?: number;             // CurrencyID
  min_age?: number;
  max_age?: number;
  job_link?: string;             // URL
  exp_years?: number;            // 0..50
  job_type?: number;
  job_sector?: number;
  working_type?: number;
  contract_type?: number;
  degree_level?: number;
  sex?: number;
  location_id?: number;
  detail_address?: string;
};
```

---

## 4. Candidate Service

`src/candidate_service/laravel_back/routes/api.php` · Kong route prefix: `candidate-*`.

### 4.1 Authenticated — `role:candidate`

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/resumes` | List CV của candidate | `ResumeController@index` | — | `CvResource[]` |
| `POST` | `/api/resumes` | Đăng ký CV mới (sau khi đã upload qua presigned-url) | `ResumeController@store` | `{ title*, cv_path* }` | `CvResource` |
| `GET` | `/api/resumes/{id}` | Chi tiết | `ResumeController@show` | — | `CvResource` |
| `PUT` | `/api/resumes/{id}` | Sửa | `ResumeController@update` | partial `CvResource` | `CvResource` |
| `DELETE` | `/api/resumes/{id}` | Xoá | `ResumeController@destroy` | — | `204` |
| `POST` | `/api/resumes/{id}/default` | Đặt làm CV mặc định | `ResumeController@setDefault` | — | `{ message, data: CvResource }` |
| `POST` | `/api/jobs/{jobId}/apply` | Ứng tuyển | `JobApplicationController@apply` | `{ cv_id* }` | `{ message, application_id }` |
| `GET` | `/api/my-applications` | Lịch sử ứng tuyển | `JobApplicationController@myHistory` | — | `{ data: ApplicationHistory[] }` |
| `POST` | `/api/interactions/saved-jobs` | Toggle save | `InteractionController@toggleSavedJob` (a.k.a. `setSaved`) | `{ job_id*, is_saved* }` | `{ message, data }` |
| `GET` | `/api/interactions/saved-jobs` | List saved | `InteractionController@getSavedJobs` | — | `JobSubJdResource[]` |
| `POST` | `/api/interactions/hidden-jobs` | Toggle hide | `InteractionController@setHidden` | `{ job_id*, is_hidden* }` | `{ message, data }` |

### 4.2 Schema

#### `CvResource` (candidate-service)
```ts
type CvResource = {
  cv_id: string;
  user_id: string;
  title: string;
  cv_path: string;       // S3 path (chưa phải URL public)
  is_default: boolean;
  view_url: string | null; // signed URL fetched on the fly từ storage-service
  created_at: string;
  updated_at: string;
};
```

#### `ApplicationHistory` (response của `myHistory`)
```ts
type ApplicationHistory = {
  application_id: string;
  applied_at: string;     // ISO
  status: number;         // StatusID
  stage: { id: string|null, name: string, color: string };
  job: {
    id: string;           // JobID
    title: string;
    company_name: string;
    logo: string | null;
    status: string | number;
    slug: string | null;
  };
};
```

---

## 5. Hiring Service

`src/hiring_service/laravel_back/routes/api.php` · Kong route prefix: `hiring-*`.

### 5.1 Authenticated — `IdentifyUserContext`

#### Pipeline

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/workspaces/{workspaceId}/pipelines` | List pipeline + stages | `Hiring\HiringPipelineController@index` | — | `HiringPipelineResource[]` |
| `POST` | `/api/workspaces/{workspaceId}/pipelines` | Tạo (auto thêm stage `Hired`/`Rejected`) | `@store` | `{ name*, stages*: [{ name*, color? }] }` | `HiringPipelineResource` |
| `GET` | `/api/workspaces/{workspaceId}/pipelines/{pipelineId}` | Chi tiết | `@show` | — | `HiringPipelineResource` |
| `PUT` | `/api/workspaces/{workspaceId}/pipelines/{pipelineId}` | Sửa | `@update` | `{ name*, stages*: [{ name*, color? }] }` | `HiringPipelineResource` |
| `DELETE` | `/api/workspaces/{workspaceId}/pipelines/{pipelineId}` | Xoá | `@destroy` | — | `204` |
| `PUT` | `/api/workspaces/{workspaceId}/pipelines/{pipelineId}/workflow` | Lưu workflow JSON | `Hiring\WorkflowController@updateConfig` | `{ nodes*: [], connections*: [], settings? }` | `200` |

#### Board (Kanban)

| Method | Path | Mô tả | Controller | Output |
|---|---|---|---|---|
| `GET` | `/api/board/{jobId}` | Board ứng viên cho 1 job | `Hiring\HiringBoardController@getBoard` | `BoardData` (xem §5.3) |
| `GET` | `/api/applications/{applicationId}` | Chi tiết application | `@showApplication` | `ApplicationDetailResource` |
| `POST` | `/api/applications/{applicationId}/move` | Đổi stage | `@moveApplication` | input `{ new_stage_id* }`, output `200` |
| `POST` | `/api/applications/{applicationId}/scorecards` | Chấm scorecard | `Hiring\ScorecardController@store` | `{ score_data* (object), comment? }` → `ScorecardResource` |

#### Interview

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/applications/{applicationId}/interviews` | List | `Hiring\InterviewController@index` | — | `InterviewResource[]` |
| `POST` | `/api/applications/{applicationId}/interviews` | Tạo lịch | `@store` | `{ start_time*, end_time*, location?, note? }` | `InterviewResource` |
| `GET` | `/api/interviews/{interviewId}` | Chi tiết | `@show` | — | `InterviewResource` |
| `PUT` | `/api/interviews/{interviewId}` | Sửa | `@update` | `{ start_time?, end_time?, status?, location? }` | `InterviewResource` |
| `DELETE` | `/api/interviews/{interviewId}` | Hủy | `@destroy` | — | `200` |
| `POST` | `/api/interviews/{interviewId}/feedback` | Nộp feedback | `@submitFeedback` | `{ feedback* }` | `200` |

### 5.2 Internal (S2S)

| Method | Path | Mô tả |
|---|---|---|
| `POST` | `/api/internal/applications` | Tạo application từ candidate-service |
| `GET` | `/api/internal/applications/candidate/{userId}` | Tất cả app của 1 candidate |

### 5.3 Schema

#### `HiringPipelineResource`
```ts
type HiringPipelineResource = {
  pipeline_id: string;
  workspace_id: string;
  name: string;
  is_default: boolean;
  stages?: PipelineStageResource[]; // chỉ có khi `whenLoaded('stages')`
  created_at: string;
  updated_at: string;
};

type PipelineStageResource = {
  stage_id: string;
  name: string;
  order: number;
  color: string | null;
  is_system: boolean;
  created_at: string;
};
```

#### `BoardData` (response `getBoard`)
```ts
type BoardData = {
  job_id: string;
  pipeline_id: string;
  stages: Array<{
    stage_id: string;
    name: string;
    order: number;
    color: string | null;
    is_system_stage: boolean;
    candidates: CandidateCardResource[];
  }>;
};

type CandidateCardResource = {
  application_id: string;
  cv_id: string;
  candidate_name: string;
  candidate_email: string;
  cv_url: string;
  score: number;       // hiện hard-code 70 (demo)
  applied_at: string;
};
```

#### `ApplicationDetailResource`
```ts
type ApplicationDetailResource = {
  id: string;          // ApplicationID
  stage: { id: string, name: string, color: string };
  candidate: {
    id: string;
    cv_id: string;
    name: string;       // snapshot
    email: string;      // snapshot
    phone: string | null;
    cv_url: string;
  };
  applied_at: string;
};
```

#### `InterviewResource`
```ts
type InterviewResource = {
  interview_id: string;
  application_id: string;
  start_time: string;  // ISO
  end_time: string;    // ISO
  status: 'Scheduled' | 'Completed' | 'Cancelled';
  location: string | null;  // Link Meet hoặc địa chỉ
  note: string | null;
  created_at: string;
  feedback: string | null;
};
```

#### `ScorecardResource`
```ts
type ScorecardResource = {
  scorecard_id: string;
  application_id: string;
  interviewer: { id: string, name: string };
  score_data: Record<string, number>;
  comment: string | null;
  created_at: string;
};
```

---

## 6. Communication Service

`src/communication_service/laravel_back/routes/api.php` · Kong route prefix: `comm-*`.

### 6.1 Authenticated — `IdentifyUserContext`

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/conversations` | List hội thoại | `ChatController@index` | — | `Conversation[]` |
| `POST` | `/api/conversations` | Tạo/lấy hội thoại 1-1 trong workspace | `ChatController@store` | `{ target_user_id*, workspace_id* }` | `Conversation` |
| `GET` | `/api/conversations/{id}/messages` | Tin nhắn (paginate 50) | `ChatController@messages` | — | Paginator của `Message` |
| `POST` | `/api/messages` | Gửi tin | `ChatController@sendMessage` | `{ conversation_id*, content* }` | `Message` |

### 6.2 Internal (S2S)

| Method | Path | Mô tả | Input |
|---|---|---|---|
| `POST` | `/api/internal/email/send` | Gửi email từ service khác | `{ to* (email), subject*, body*, source? }` |

### 6.3 Schema (mock theo model)

```ts
type Conversation = {
  ConversationID: string;
  WorkspaceID: string;
  Type: string;                // 'direct' | ...
  participants: Array<{ UserID: string, role?: string }>;
  last_message?: Message;
  CreatedAt: string;
  UpdatedAt: string;
};

type Message = {
  MessageID: string;
  ConversationID: string;
  SenderID: string;
  Content: string;
  CreatedAt: string;
};
```

> Lưu ý: ChatController **không bọc qua Resource**, trả về model raw (PascalCase). Frontend cần map lại nếu muốn snake_case.

---

## 7. Storage Service

`src/storage_service/laravel_back/routes/api.php` · Kong route prefix: `storage-*`.

### 7.1 Public (qua Kong, **không có** plugin jwt — vẫn cần token nếu app yêu cầu)

| Method | Path | Mô tả | Controller | Input | Output |
|---|---|---|---|---|---|
| `GET` | `/api/presigned-url?filename=...&type=cv\|avatar\|logo` | Lấy URL upload tới MinIO/S3 | `StorageController@getPresignedUrl` | query | `{ url, path, expires_in }` |
| `POST` | `/api/presigned-url` | Tạo URL upload (PUT) — variant với body | `PresignedUrlController@getUploadUrl` | `{ filename*, type*: 'cv'\|'avatar'\|'logo' }` | `{ url, path, expires_in }` |

### 7.2 Internal (S2S)

| Method | Path | Mô tả | Input |
|---|---|---|---|
| `POST` | `/api/internal/files/view-url` | Tạo URL xem file | `{ path* }` → `{ url }` |

### 7.3 Frontend upload flow

```
1. POST /api/presigned-url    body: { filename, type } → { url, path }
2. PUT  <url>                 body: <file binary>      → 200 OK (vào MinIO)
3. POST /api/resumes          body: { title, cv_path: path } → CvResource
```

---

## 8. Frontend → Service mapping (cheatsheet)

| Tính năng UI | Endpoints |
|---|---|
| Login (web) | `POST /realms/job7189/protocol/openid-connect/token` (Auth code + PKCE) |
| Header / Profile dropdown | `GET /api/recruiters/profile` hoặc `GET /api/candidates/profile` |
| Public homepage — list job | `GET /api/public/jobs`, `GET /api/options/general` |
| Public homepage — chi tiết | `GET /api/public/jobs/{id}` |
| Apply (candidate) | `POST /api/jobs/{jobId}/apply` |
| Resume manager | `GET/POST/DELETE /api/resumes`, `POST /api/presigned-url` |
| Recruiter dashboard | `GET /api/my-workspaces` |
| Workspace settings | `GET/PUT /api/workspaces/{ws}` + `/members*` |
| Job manager (recruiter) | `GET/POST/PUT /api/workspaces/{ws}/jobs/...` |
| Hiring board kanban | `GET /api/board/{jobId}`, `POST /api/applications/{id}/move` |
| Interview scheduling | `GET/POST /api/applications/{id}/interviews`, `POST /api/interviews/{id}/feedback` |
| Chat | `GET /api/conversations`, `GET /api/conversations/{id}/messages`, `POST /api/messages` |

---

## 9. Mock data cho frontend

Mock data đặt ở `frontend/src/mocks/*.ts`, mỗi file 1 service, export object `mock<ResourceName>` đúng kiểu TypeScript đã liệt kê ở §1.5–§7.3. Khi switch sang real API:

```ts
// frontend/.env.local
NEXT_PUBLIC_USE_MOCK=true   // dùng mock; false → gọi Kong
NEXT_PUBLIC_API_BASE_URL=https://api.job7189.com
NEXT_PUBLIC_KEYCLOAK_URL=https://auth.job7189.com
NEXT_PUBLIC_KEYCLOAK_REALM=job7189
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=web-frontend
```

Khi `NEXT_PUBLIC_USE_MOCK=false`, lớp `apiClient` sẽ:
1. Lấy access token từ NextAuth session (Keycloak provider, realm `job7189`).
2. Gắn `Authorization: Bearer <token>` + `Host: api.job7189.com`.
3. Gọi tới `${NEXT_PUBLIC_API_BASE_URL}/<endpoint>`.
4. Nếu nhận 401, thử refresh token; thất bại → redirect login.
