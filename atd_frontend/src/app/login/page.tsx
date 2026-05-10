"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useMockAuth } from "@/lib/auth/mock";

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
  const { email: stored, signIn } = useMockAuth();
  const [email, setEmail] = useState("minh.tran@example.com");
  const [name, setName] = useState("Minh Tran");

  const callbackUrl = params.get("callbackUrl") ?? "/applications";

  useEffect(() => {
    if (stored) router.replace(callbackUrl);
  }, [stored, router, callbackUrl]);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    signIn(email, name);
    router.replace(callbackUrl);
  };

  return (
    <div className="mx-auto max-w-md rounded-xl border bg-white p-8 shadow">
      <h1 className="text-xl font-semibold">Đăng nhập ứng viên</h1>
      <p className="mt-1 text-sm text-slate-500">
        Mock mode — nhập email + tên để vào trang ứng viên. Khi nối backend thật,
        form này sẽ được thay bằng OIDC redirect tới Keycloak realm{" "}
        <code>job7189</code>.
      </p>

      <form onSubmit={submit} className="mt-6 space-y-4">
        <Field label="Họ tên">
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full rounded border px-3 py-2"
            required
          />
        </Field>
        <Field label="Email">
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded border px-3 py-2"
            required
          />
        </Field>
        <button
          type="submit"
          className="w-full rounded bg-brand px-4 py-2 text-white hover:bg-brand-dark"
        >
          Đăng nhập (mock)
        </button>
      </form>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block text-sm">
      <span className="font-medium text-slate-700">{label}</span>
      <div className="mt-1">{children}</div>
    </label>
  );
}
