"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useMockAuth } from "@/lib/auth/mock";
import { passwordGrant } from "@/lib/auth/keycloak";

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const { email: stored } = useMockAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const callbackUrl = params.get("callbackUrl") ?? "/browse";

  useEffect(() => {
    if (stored) router.replace(callbackUrl);
  }, [stored, router, callbackUrl]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      console.log("[v0] Login attempt with username:", username);
      await passwordGrant(username.trim(), password);
      console.log("[v0] Login successful, redirecting");
      router.replace(callbackUrl);
    } catch (err) {
      console.error("[v0] Login error:", err);
      setError(err instanceof Error ? err.message : "Đăng nhập thất bại");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = () => {
    // TODO: Implement Google OAuth login via Keycloak
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-4 py-8">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-10">
          <h1 className="text-4xl font-serif font-bold text-foreground mb-2">
            Đăng Nhập
          </h1>
          <p className="text-foreground-muted">
            Tìm công việc phù hợp với bạn
          </p>
        </div>

        {/* Form Card */}
        <div className="bg-white rounded-2xl shadow-md p-8 space-y-6">
          {/* Error Message */}
          {error && (
            <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
              {error}
            </div>
          )}

        {/* Username/Password Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-2">
                Tên đăng nhập
              </label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="your_username"
                className="w-full px-4 py-3 rounded-lg border border-muted-light bg-white text-foreground placeholder-muted focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                disabled={loading}
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground mb-2">
                Mật khẩu
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full px-4 py-3 rounded-lg border border-muted-light bg-white text-foreground placeholder-muted focus:outline-none focus:ring-2 focus:ring-brand focus:border-transparent transition"
                disabled={loading}
                required
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full mt-6 px-4 py-3 rounded-lg bg-brand text-white font-medium hover:bg-brand-dark disabled:opacity-60 disabled:cursor-not-allowed transition"
            >
              {loading ? "Đang đăng nhập…" : "Đăng Nhập"}
            </button>
        </form>

        {/* Forgot Password */}
        <div className="text-center">
          <Link
            href="/forgot-password"
            className="text-sm text-brand hover:text-brand-dark font-medium transition"
          >
            Quên mật khẩu?
          </Link>
        </div>
        </div>

        {/* Google Section - Separate */}
        <div className="mt-6 bg-white rounded-2xl shadow-md p-8">
          <p className="text-center text-sm text-foreground-muted mb-4">
            Hoặc tiếp tục bằng
          </p>
          <button
            onClick={handleGoogleLogin}
            type="button"
            disabled={loading}
            className="w-full flex items-center justify-center gap-3 px-4 py-3 rounded-lg border border-muted-light bg-white text-foreground font-medium hover:bg-surface-alt transition disabled:opacity-60"
          >
            <svg className="w-5 h-5" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
              />
            </svg>
            <span>Google</span>
          </button>
        </div>

        {/* Bottom Links */}
        <div className="mt-8 text-center space-y-4">
          <p className="text-foreground-muted text-sm">
            Chưa có tài khoản?{" "}
            <Link
              href="/signup"
              className="text-brand font-medium hover:text-brand-dark transition"
            >
              Đăng ký ngay
            </Link>
          </p>

          <p className="text-xs text-foreground-muted">
            Bằng cách đăng nhập, bạn đồng ý với{" "}
            <Link href="/terms" className="text-brand hover:text-brand-dark transition">
              Điều khoản dịch vụ
            </Link>{" "}
            &{" "}
            <Link href="/privacy" className="text-brand hover:text-brand-dark transition">
              Chính sách bảo mật
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
