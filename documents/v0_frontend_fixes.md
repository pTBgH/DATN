# Hướng Dẫn Chi Tiết Fix Lỗi Frontend (Dành Cho v0 / Developer)

Tài liệu này hệ thống lại toàn bộ các thay đổi của backend API và hướng dẫn chi tiết cách viết prompt/code để `v0` hoặc developer sửa các lỗi hiện tại ở frontend (`rct_frontend` và `atd_frontend`).

---

## 1. Các Thay Đổi Quan Trọng Của Backend API

Hiện tại, backend đã được thống nhất cấu hình và sửa đổi các điểm sau:
1. **Không sử dụng Data Wrapping cho Single Resource**: Backend sử dụng `JsonResource::withoutWrapping()`. Điều này có nghĩa là các API trả về **1 đối tượng duy nhất** (ví dụ: `GET /api/workspaces/{id}`, `GET /api/recruiters/profile`) sẽ trả về đối tượng phẳng trực tiếp (Flat Object), **không** nằm trong wrapper `{ "data": {...} }`.
2. **Laravel Pagination vẫn giữ Data Wrapping**: Các API phân trang (ví dụ: `GET /api/workspaces/{wsId}/jobs`) vẫn giữ cấu trúc mặc định của Laravel: `{ "data": [...], "meta": {...}, "links": {...} }`.
3. **API Options (`/api/options/company-types`)**: Đã chuyển từ `workspace-service` sang `job-service`. API trả về 200 OK với cấu trúc:
   ```json
   {
     "sizes": [{"id": 1, "name": "1-10"}, ...],
     "industries": [{"id": 1, "name": "Technology"}, ...]
   }
   ```
4. **Admin Sectors API**: Đầy đủ các phương thức `GET`, `POST`, `PUT`, `DELETE` trên `/api/admin/categories/sectors`.
5. **Recruiter Profile API (`GET /api/recruiters/profile`)**: Trả về flat object:
   ```json
   {
     "recruiter_id": 1,
     "email": "recruiter1@job7189.local",
     "phone_number": "...",
     "user_name": "...",
     "first_name": "...",
     "last_name": "...",
     "avatar": "...",
     "status_id": 1,
     "workspaces": [
       {
         "id": "workspace-uuid",
         "name": "Tên Workspace",
         "logo": "...",
         "active_jobs": 0,
         "views": 0,
         "applications": 0,
         "apply_rate": 0,
         "status": "Active",
         "permissions": ["workspace", "job", "candidate", "pipeline"]
       }
     ]
   }
   ```

---

## 2. Hướng Dẫn Sửa Lỗi Trên Frontend

### Vấn đề 1: Next.js Layout Component Lỗi SSR (Token 401)
* **Nguyên nhân**: File `layout.tsx` (nhất là trong `[wsId]/layout.tsx`) chạy ở phía Server (Server Component) nơi không truy cập được `localStorage` của trình duyệt để đọc JWT Token, dẫn đến việc gửi request không có header `Authorization` -> Backend trả về `401 Unauthorized` và gây crash trang.
* **Cách sửa**: Chuyển các Layout/Component cần gọi API có Auth thành Client Component (`"use client"`) và sử dụng hook `useAuthedFetch` để gọi API ở phía Client an toàn.
* **Mẫu Code đúng cho `[wsId]/layout.tsx`**:
  ```tsx
  "use client";

  import { useParams } from "next/navigation";
  import { workspaceApi } from "@/lib/api";
  import { useAuthedFetch } from "@/lib/auth/guard";
  import { PageLoading, PageError } from "@/components/PageState";

  export default function WorkspaceLayout({ children }: { children: React.ReactNode }) {
    const params = useParams<{ wsId: string }>();
    const { wsId } = params ?? {};

    const { data: ws, loading, error } = useAuthedFetch(
      () => workspaceApi.getWorkspace(wsId!),
      [wsId]
    );

    if (loading) return <PageLoading label="Đang tải thông tin workspace..." />;
    if (error) return <PageError message={error} />;
    if (!ws) return null;

    return (
      <div>
        {/* Render thanh navigation với thông tin ws.name */}
        <header className="border-b px-6 py-4">
          <h1 className="text-xl font-bold">{ws.name}</h1>
        </header>
        <main className="p-6">{children}</main>
      </div>
    );
  }
  ```

### Vấn đề 2: Unwrapping Response ở API Client Helpers
* **Nguyên nhân**: Mặc dù backend đã bật `withoutWrapping()`, để code an toàn khi tương thích với cả 2 dạng (cũ và mới), API Client Helpers nên dùng cú pháp `r?.data ?? r` để unwrap dữ liệu an toàn.
* **Cách sửa**: Cập nhật các hàm lấy Single Resource trong `src/lib/api/*.ts` (ví dụ: `workspace.ts`, `job.ts`, `identity.ts`) để bóc tách data an toàn.
* **Ví dụ trong `src/lib/api/workspace.ts`**:
  ```typescript
  export async function getWorkspace(wsId: string): Promise<WorkspaceResource> {
    if (config.useMock) return Promise.resolve(mockWorkspaces[0]);
    const r = await apiFetch<any>(`/api/workspaces/${wsId}`);
    return r?.data ?? r; // Trả về phẳng đối tượng workspace
  }
  ```
* **Ví dụ trong `src/lib/api/job.ts`**:
  ```typescript
  export async function getWorkspaceJob(wsId: string, jobId: string): Promise<JobSubJdResource> {
    if (config.useMock) return Promise.resolve(mockRecruiterJobs[0]);
    const r = await apiFetch<any>(`/api/workspaces/${wsId}/jobs/${encodeURIComponent(jobId)}`);
    return r?.data ?? r;
  }
  ```

### Vấn đề 3: Sai Lệch Tên Thuộc Tính Trong Form Cài Đặt Quy Mô/Ngành Nghề
* **Nguyên nhân**: Khi load trang `settings/page.tsx` của workspace, API `/api/options/company-types` trả về dữ liệu chuẩn hóa dạng `sizes` và `industries`. Cần binding chính xác `s.id`/`s.name` và `i.id`/`i.name`.
* **Mẫu code đúng cho `settings/page.tsx`**:
  ```tsx
  {/* Quy mô dropdown */}
  <select className="w-full rounded border px-3 py-2">
    {opts.sizes.map((s) => (
      <option key={s.id} value={s.id}>
        {s.name}
      </option>
    ))}
  </select>

  {/* Ngành nghề dropdown */}
  <select className="w-full rounded border px-3 py-2">
    {opts.industries.map((i) => (
      <option key={i.id} value={i.id}>
        {i.name}
      </option>
    ))}
  </select>
  ```

### Vấn đề 4: Xử Lý Quyền Lợi và Trạng Thái Ở Trang Profile của Nhà Tuyển Dụng
* **Nguyên nhân**: Trang profile tuyển dụng (`/recruiter/profile`) cần đọc chính xác danh sách các workspace của user kèm quyền hạn dạng mảng chuỗi (`permissions: string[]`).
* **Cách sửa**: Sử dụng cấu trúc profile mới và render danh sách membership an toàn (thêm check `w.company?.name` hoặc fallback `w.name` nếu không có company).
* **Mẫu code đúng trong `src/app/recruiter/profile/page.tsx`**:
  ```tsx
  {profile.workspaces.map((w) => (
    <div key={w.id} className="border p-4 rounded mb-2">
      <h3 className="font-bold">{w.name}</h3>
      <p className="text-sm text-slate-500">Trạng thái: {w.status}</p>
      <div className="flex gap-1 mt-2">
        {w.permissions.map((p) => (
          <span key={p} className="text-xs bg-slate-100 px-2 py-0.5 rounded">
            {p}
          </span>
        ))}
      </div>
    </div>
  ))}
  ```

---

## 3. Bản Prompt Mẫu Để Copy/Paste Vào `v0`

Hãy copy đoạn text dưới đây vào `v0` để nó tự động sửa code Next.js frontend:

```text
Please help me fix the following frontend bugs in my Next.js (App Router) project to align it with the Laravel microservice backend API:

Context of backend API:
1. Laravel resources have `JsonResource::withoutWrapping()` enabled, meaning single resource responses (like `getWorkspace`, `getWorkspaceJob`, `getRecruiterProfile`) return a flat JSON object directly, NOT wrapped inside a "data" key.
2. Pagination responses (like `listWorkspaceJobs`) still keep the Laravel default wrapping: `{ "data": [...], "meta": ..., "links": ... }`.
3. The options endpoint `GET /api/options/company-types` returns `{ "sizes": [{"id": 1, "name": "1-10"}], "industries": [{"id": 1, "name": "Tech"}] }`.

Please implement the following fixes:

1. Update the API Fetch helpers in `src/lib/api/workspace.ts`, `src/lib/api/job.ts`, and `src/lib/api/identity.ts` so that all single resource getters safely unwrap the envelope using `r?.data ?? r` fallback. For example:
   ```typescript
   export async function getWorkspace(wsId: string) {
     const r = await apiFetch<any>(`/api/workspaces/${wsId}`);
     return r?.data ?? r;
   }
   ```
   Apply this pattern to `getWorkspace`, `createWorkspace`, `updateWorkspace`, `getWorkspaceJob`, `createDraftJob`, `submitNewJob`, `updateJob`, and `getRecruiterProfile`.

2. Fix Layout Rendering crash in `src/app/recruiter/[wsId]/layout.tsx` (and other layouts that request authenticated data). Make sure they are client-side components using `"use client"` and execute data fetching with the `useAuthedFetch` hook to avoid calling APIs during server-side pre-rendering where the browser localStorage JWT token is unavailable.

3. Fix properties binding in workspace settings dropdowns `src/app/recruiter/[wsId]/settings/page.tsx` for quy mô (sizes) and ngành (industries). Populate options correctly using:
   - Quy mô: `opts.sizes.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)`
   - Ngành: `opts.industries.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)`

4. Fix workspace memberships rendering in the profile page `src/app/recruiter/profile/page.tsx`. Map memberships using `w.name` or `w.company?.name` safely, check `w.status`, and map the string permission tags in `w.permissions` correctly.
```
