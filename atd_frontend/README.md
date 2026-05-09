# Job7189 — Applicant Frontend (`atd_frontend`)

Console dành cho **người ứng tuyển**, deploy trên **Cloudflare Pages**. Stack
giống `frontend/` và `rct_frontend/`: Next.js 14 + TypeScript + Tailwind +
`@cloudflare/next-on-pages`.

> Đây là **skeleton mock-first**: mọi API call short-circuit về
> `src/mocks/*.ts`. Khi nối backend thật, đổi `NEXT_PUBLIC_USE_MOCK=false` và
> wire NextAuth Keycloak (xem `frontend/`).

## Cấu trúc

```
atd_frontend/
├── src/
│   ├── app/
│   │   ├── page.tsx                # Trang chủ — list job nổi bật
│   │   ├── login/                  # Mock login
│   │   ├── jobs/                   # Public list + detail + apply
│   │   ├── profile/                # Hồ sơ candidate
│   │   ├── cvs/                    # Quản lý CV (presigned-url upload flow)
│   │   ├── applications/           # Đơn ứng tuyển của tôi
│   │   ├── saved/                  # Việc đã lưu
│   │   └── messages/               # Tin nhắn với nhà tuyển dụng
│   ├── components/                 # TopNav, Stat, …
│   ├── lib/                        # api/, auth/mock.ts, config.ts
│   ├── mocks/                      # Fixtures khớp Laravel Resource
│   └── types/                      # DTOs mirror Resource classes
├── next.config.mjs
├── wrangler.toml                   # Cloudflare project: job7189-atd
├── tailwind.config.ts
└── tsconfig.json
```

## Chạy local

```bash
cd atd_frontend
cp .env.example .env.local
npm install
npm run dev      # http://localhost:3002
```

## Build & deploy lên Cloudflare Pages

```bash
npm run pages:build       # @cloudflare/next-on-pages → .vercel/output/static
npm run pages:deploy      # wrangler pages deploy --project-name=job7189-atd
```

## Mapping API ↔ pages

Xem `../frontend/docs/API_INVENTORY.md` §1.3, §3.1, §4, §6, §7.
