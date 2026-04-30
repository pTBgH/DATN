import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";
import { Providers } from "./providers";
import { config } from "@/lib/config";

export const metadata: Metadata = {
  title: "Job7189",
  description: "Zero-trust hiring platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="min-h-screen font-sans">
        <Providers>
          <header className="border-b bg-white">
            <div className="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3">
              <Link href="/" className="text-lg font-semibold text-brand">
                Job7189
              </Link>
              <nav className="flex items-center gap-4 text-sm text-slate-600">
                <Link href="/jobs">Việc làm</Link>
                <Link href="/candidate">Ứng viên</Link>
                <Link href="/recruiter">Nhà tuyển dụng</Link>
              </nav>
              <div className="ml-auto flex items-center gap-3 text-sm">
                {config.useMock ? (
                  <span className="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
                    MOCK MODE
                  </span>
                ) : null}
                <Link
                  href="/login"
                  className="rounded bg-brand px-3 py-1.5 text-white hover:bg-brand-dark"
                >
                  Đăng nhập
                </Link>
              </div>
            </div>
          </header>
          <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
          <footer className="border-t bg-white py-6 text-center text-xs text-slate-500">
            Job7189 · Realm Keycloak: <code>{config.keycloak.realm}</code> · Gateway:{" "}
            <code>{config.apiBaseUrl}</code>
          </footer>
        </Providers>
      </body>
    </html>
  );
}
