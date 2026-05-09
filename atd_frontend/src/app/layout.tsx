import type { Metadata } from "next";
import "./globals.css";
import { config } from "@/lib/config";
import { TopNav } from "@/components/TopNav";

// Required by Cloudflare Pages (@cloudflare/next-on-pages): every dynamic
// segment must run on the edge runtime. Setting it on the root layout makes
// every child route inherit it automatically.
export const runtime = "edge";

export const metadata: Metadata = {
  title: "Job7189 — Apply",
  description: "Tìm việc và ứng tuyển trên Job7189 (zero-trust hiring)",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="min-h-screen font-sans antialiased">
        <TopNav />
        <main className="mx-auto max-w-6xl px-4 py-8">{children}</main>
        <footer className="border-t bg-white py-6 text-center text-xs text-slate-500">
          Job7189 ATD · Realm Keycloak <code>{config.keycloak.realm}</code> · Gateway{" "}
          <code>{config.apiBaseUrl}</code>
        </footer>
      </body>
    </html>
  );
}
