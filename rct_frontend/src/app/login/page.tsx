"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useMockAuth } from "@/lib/auth/mock";
import { passwordGrant } from "@/lib/auth/keycloak";

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="text-sm text-slate-500">Loading…</div>}>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const { role } = useMockAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const callbackUrl = params.get("callbackUrl");

  useEffect(() => {
    if (role) {
      router.replace(callbackUrl ?? (role === "admin" ? "/admin" : "/recruiter"));
    }
  }, [role, router, callbackUrl]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await passwordGrant(username.trim(), password);
      router.replace(
        callbackUrl ?? (res.role === "admin" ? "/admin" : "/recruiter"),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Đăng nhập thất bại");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-md rounded-xl border bg-white p-8 shadow">
      <h1 className="text-xl font-semibold">Đăng nhập</h1>
      <p className="mt-1 text-sm text-slate-500">
        Đăng nhập bằng tài khoản Keycloak realm <code>job7189</code>. Vai trò
        (nhà tuyển dụng / quản trị) được xác định theo quyền trong token.
      </p>

      <form onSubmit={submit} className="mt-6 space-y-4">
        <label className="block text-sm">
          <span className="font-medium text-slate-700">Tên đăng nhập</span>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            className="mt-1 w-full rounded border px-3 py-2"
            required
          />
        </label>

        <label className="block text-sm">
          <span className="font-medium text-slate-700">Mật khẩu</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            className="mt-1 w-full rounded border px-3 py-2"
            required
          />
        </label>

        {error && (
          <p className="rounded bg-red-50 px-3 py-2 text-sm text-red-600">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded bg-brand px-4 py-2 text-white hover:bg-brand-dark disabled:opacity-60"
        >
          {loading ? "Đang đăng nhập…" : "Vào hệ thống"}
        </button>
      </form>

      <div className="mt-6 text-center text-sm">
        <p className="text-slate-600">
          Chưa có tài khoản?{" "}
          <Link
            href="/signup"
            className="font-medium text-brand hover:underline"
          >
            Đăng ký ngay
          </Link>
        </p>
      </div>
    </div>
  );
}
