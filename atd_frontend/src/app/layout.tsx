import type { Metadata } from "next";
import { Merriweather, Inter } from "next/font/google";
import "./globals.css";
import { config } from "@/lib/config";
import { TopNav } from "@/components/TopNav";
import { Footer } from "@/components/Footer";

const merriweather = Merriweather({
  subsets: ["latin"],
  weight: ["400", "700"],
  variable: "--font-serif",
});

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
});

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
    <html lang="vi" className="bg-background">
      <body className={`${inter.variable} ${merriweather.variable} min-h-screen font-sans antialiased flex flex-col`}>
        <TopNav />
        <main className="mx-auto max-w-6xl px-4 py-12 flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
