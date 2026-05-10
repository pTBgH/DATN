# Job7189 — Recruiter & Admin Frontend (`rct_frontend`)

Console cho **nhà tuyển dụng** và **quản trị hệ thống**, deploy trên
**Cloudflare Pages**. Stack giống `frontend/`: Next.js 14 + TypeScript + Tailwind
+ `@cloudflare/next-on-pages`.

> Đây là **skeleton mock-first**: mọi API call đều short-circuit về
> `src/mocks/*.ts`. Khi nối backend thật, đổi `NEXT_PUBLIC_USE_MOCK=false` và
> wire NextAuth Keycloak (xem `frontend/`).

## Cấu trúc

```
rct_frontend/
├── src/
│   ├── app/
│   │   ├── page.tsx                # Landing — chọn role
│   │   ├── login/                  # Mock login (chọn recruiter | admin)
│   │   ├── recruiter/              # Recruiter console
│   │   │   ├── page.tsx            # List workspace
│   │   │   ├── profile/            # Hồ sơ
│   │   │   ├── messages/           # Hộp thư
│   │   │   └── [wsId]/             # Mỗi workspace
│   │   │       ├── page.tsx        # Tổng quan
│   │   │       ├── jobs/           # CRUD job + chi tiết + board
│   │   │       ├── pipelines/      # Pipeline tuyển dụng
│   │   │       ├── members/        # Mời / quản lý thành viên
│   │   │       ├── settings/       # Workspace settings
│   │   │       └── applications/   # Chi tiết đơn ứng tuyển
│   │   └── admin/                  # System admin console
│   │       ├── page.tsx
│   │       ├── jobs/               # Duyệt tin
│   │       ├── sectors/            # CRUD ngành nghề
│   │       ├── users/              # Quản lý user
│   │       └── companies/          # Quản lý công ty
│   ├── components/                 # TopNav, Stat, …
│   ├── lib/
│   │   ├── api/                    # 1 module / service Laravel + admin
│   │   ├── auth/mock.ts            # Mock auth helper (localStorage)
│   │   └── config.ts
│   ├── mocks/                      # Fixtures khớp Laravel Resource
│   └── types/                      # DTOs mirror Resource classes
├── next.config.mjs
├── wrangler.toml                   # Cloudflare project: job7189-rct
├── tailwind.config.ts
└── tsconfig.json
```

## Chạy local

```bash
cd rct_frontend
cp .env.example .env.local
npm install
npm run dev      # http://localhost:3001
```

## Build & deploy lên Cloudflare Pages

```bash
npm run pages:build       # @cloudflare/next-on-pages → .vercel/output/static
npm run pages:deploy      # wrangler pages deploy --project-name=job7189-rct
```

Yêu cầu env trong CI / Pages dashboard:

| Biến | Loại | Ghi chú |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | secret | quyền `Pages:Edit` |
| `CLOUDFLARE_ACCOUNT_ID` | secret | account id của bạn |
| `NEXT_PUBLIC_USE_MOCK` | public | `true` ở skeleton |
| `NEXT_PUBLIC_API_BASE_URL` | public | dùng khi `USE_MOCK=false` |

## Chuyển sang real API

1. `NEXT_PUBLIC_USE_MOCK=false`
2. Wire NextAuth Keycloak (`frontend/src/lib/auth/options.ts` là tham chiếu).
3. Kong gateway phải có route cho cả 7 service Laravel + admin endpoints.

## Mapping API ↔ pages

Xem `../frontend/docs/API_INVENTORY.md` (cùng inventory dùng cho cả 3 FE).
