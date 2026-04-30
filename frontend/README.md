# Job7189 — Frontend

Next.js 14 + TypeScript + Tailwind, deploy trên **Cloudflare Pages**.
Kết nối tới 7 microservice Laravel qua **Kong gateway** và xác thực bằng **Keycloak realm `job7189`**.

> Folder này tách hoàn toàn khỏi `src/` (Laravel back-end) để có thể CI/CD độc lập trên Cloudflare.

## 1. Cấu trúc

```
frontend/
├── docs/
│   └── API_INVENTORY.md            # Danh mục API đã được khảo sát từ src/
├── src/
│   ├── app/                        # App Router pages
│   │   ├── (public)                # /, /jobs, /jobs/[id]
│   │   ├── login/
│   │   ├── candidate/              # Ứng viên
│   │   ├── recruiter/[wsId]/...    # Nhà tuyển dụng + workspace + board
│   │   └── api/auth/[...nextauth]  # NextAuth Keycloak
│   ├── lib/
│   │   ├── api/                    # Client mỗi service (toggle mock ↔ real)
│   │   ├── auth/options.ts         # NextAuthOptions cho Keycloak
│   │   └── config.ts               # Đọc env vars
│   ├── mocks/                      # Mock fixtures khớp Laravel Resources
│   └── types/                      # Typescript DTOs (mirror Resource classes)
├── next.config.mjs
├── wrangler.toml                   # Cloudflare Pages
├── tsconfig.json
└── tailwind.config.ts
```

## 2. Yêu cầu

- Node.js >= 20
- npm hoặc pnpm
- (deploy) wrangler CLI hoặc Cloudflare Pages dashboard

## 3. Chạy local

```bash
cd frontend
cp .env.example .env.local
# default: NEXT_PUBLIC_USE_MOCK=true → không cần Kong/Keycloak vẫn chạy được
npm install
npm run dev
# http://localhost:3000
```

### Switch sang real API

Sửa `.env.local`:

```env
NEXT_PUBLIC_USE_MOCK=false
NEXT_PUBLIC_API_BASE_URL=https://api.job7189.com
NEXT_PUBLIC_KEYCLOAK_URL=https://auth.job7189.com
NEXT_PUBLIC_KEYCLOAK_REALM=job7189
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=web-frontend

KEYCLOAK_ISSUER=https://auth.job7189.com/realms/job7189
KEYCLOAK_CLIENT_ID=web-frontend
KEYCLOAK_CLIENT_SECRET=<set if confidential client>
NEXTAUTH_SECRET=<openssl rand -base64 32>
NEXTAUTH_URL=http://localhost:3000
```

> Cần khai báo client `web-frontend` (public, redirect `http://localhost:3000/api/auth/callback/keycloak`) trong realm `job7189`. Nếu chưa có client, có thể dùng `candidate-app-dev` (confidential) — sửa `KEYCLOAK_CLIENT_ID` và set `KEYCLOAK_CLIENT_SECRET`.

## 4. Deploy lên Cloudflare Pages

```bash
# 1. Build adapter từ Next.js → Cloudflare Worker bundle
npm run pages:build

# 2. Push lên Cloudflare
wrangler pages deploy .vercel/output/static --project-name=job7189-frontend

# Đặt secrets (chỉ cần làm 1 lần)
wrangler pages secret put NEXTAUTH_SECRET --project-name job7189-frontend
wrangler pages secret put KEYCLOAK_CLIENT_SECRET --project-name job7189-frontend
```

Hoặc kết nối repo GitHub trực tiếp với Pages dashboard, dùng:
- Build command: `npm run pages:build`
- Build output: `.vercel/output/static`
- Compatibility flags: `nodejs_compat`

## 5. Mock data

Mọi function trong `src/lib/api/*.ts` đều check `config.useMock`:

```ts
export async function getRecruiterProfile(): Promise<RecruiterFullProfile> {
  if (config.useMock) return Promise.resolve(mockRecruiterProfile);
  return apiFetch<RecruiterFullProfile>("/api/recruiters/profile");
}
```

Dữ liệu mock nằm ở `src/mocks/*.ts` và **đúng schema** với Laravel Resource (xem cột "Output schema" trong [`docs/API_INVENTORY.md`](./docs/API_INVENTORY.md)).

## 6. Mapping API ↔ pages

| Page | Endpoints |
|---|---|
| `/` | `GET /api/public/jobs` |
| `/jobs` | `GET /api/public/jobs?q=...` |
| `/jobs/[id]` | `GET /api/public/jobs/{id}` |
| `/login` | `POST {keycloak}/realms/job7189/protocol/openid-connect/token` |
| `/candidate` | `GET /api/candidates/profile` + `GET /api/resumes` + `GET /api/my-applications` |
| `/recruiter` | `GET /api/my-workspaces` |
| `/recruiter/[wsId]` | `GET /api/workspaces/{wsId}` + `GET /api/workspaces/{wsId}/jobs` |
| `/recruiter/[wsId]/jobs/[jobId]` | `GET /api/workspaces/{wsId}/jobs/{jobId}` + `GET /api/board/{jobId}` |

## 7. Scripts

| Lệnh | Mục đích |
|---|---|
| `npm run dev` | Dev server |
| `npm run build` | Build production (Node target) |
| `npm run start` | Chạy production build (Node) |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run lint` | ESLint |
| `npm run pages:build` | Build adapter Cloudflare Pages |
| `npm run pages:deploy` | Upload bundle lên Cloudflare |
| `npm run preview` | Preview adapter bằng wrangler |

## 8. Kế hoạch tiếp theo (chưa làm)

- Trang upload CV (`POST /api/presigned-url` → `PUT MinIO` → `POST /api/resumes`).
- Form đăng job (`POST /api/workspaces/{wsId}/jobs/draft`).
- Drag-and-drop di chuyển ứng viên giữa stage (`POST /api/applications/{id}/move`).
- Trang phỏng vấn (`POST /api/applications/{id}/interviews`).
- Chat realtime (cần WebSocket/SSE — backend chưa expose, hiện chỉ poll qua REST).
- E2E test với Playwright (`tests/`).
