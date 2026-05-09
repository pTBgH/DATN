import type { Metadata } from "next";
import "./globals.css";
import { config } from "@/lib/config";
import { TopNav } from "@/components/TopNav";

export const metadata: Metadata = {
  title: "Job7189 — Recruiter & Admin",
  description: "Zero-trust hiring platform — recruiter and admin console",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="min-h-screen font-sans antialiased">
        <TopNav />
        <main className="mx-auto max-w-7xl px-4 py-8">{children}</main>
        <footer className="border-t bg-white py-6 text-center text-xs text-slate-500">
          Job7189 RCT · Realm Keycloak <code>{config.keycloak.realm}</code> · Gateway{" "}
          <code>{config.apiBaseUrl}</code>
        </footer>
      </body>
    </html>
  );
}
