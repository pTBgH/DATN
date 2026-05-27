import type { Metadata } from "next";
import "./globals.css";
import { config } from "@/lib/config";
import { TopNav } from "@/components/TopNav";

// Required by Cloudflare Pages (@cloudflare/next-on-pages): every dynamic
// segment must run on the edge runtime. Setting it on the root layout makes
// every child route inherit it automatically.
export const runtime = "edge";

export const metadata: Metadata = {
  title: "Job7189 — Recruiter & Admin",
  description: "Zero-trust hiring platform — recruiter and admin console",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="h-screen font-sans antialiased flex flex-col">
        <TopNav />
        <main className="mx-auto max-w-7xl px-4 py-8 flex-1 overflow-auto w-full">{children}</main>
      </body>
    </html>
  );
}
