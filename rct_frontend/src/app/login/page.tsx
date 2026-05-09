"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useMockAuth, type MockRole } from "@/lib/auth/mock";

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
  const { role, signIn } = useMockAuth();
  const [pickedRole, setPickedRole] = useState<MockRole>("recruiter");
  const [email, setEmail] = useState("anna@acme.io");

  const callbackUrl = params.get("callbackUrl");

  useEffect(() => {
    if (role) {
      router.replace(callbackUrl ?? (role === "admin" ? "/admin" : "/recruiter"));
    }
  }, [role, router, callbackUrl]);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    signIn(pickedRole, email);
    router.replace(
      callbackUrl ?? (pickedRole === "admin" ? "/admin" : "/recruiter"),
    );
  };

  return (
    <div className="mx-auto max-w-md rounded-xl border bg-white p-8 shadow">
      <h1 className="text-xl font-semibold">Đăng nhập</h1>
      <p className="mt-1 text-sm text-slate-500">
        Mock mode — chọn role để vào console. Khi nối backend thật, form này sẽ
        được thay bằng OIDC redirect tới Keycloak realm <code>job7189</code>.
      </p>

      <form onSubmit={submit} className="mt-6 space-y-4">
        <label className="block text-sm">
          <span className="font-medium text-slate-700">Vai trò</span>
          <div className="mt-2 grid grid-cols-2 gap-2">
            <RolePick
              checked={pickedRole === "recruiter"}
              onPick={() => setPickedRole("recruiter")}
              label="Nhà tuyển dụng"
              hint="recruiter"
            />
            <RolePick
              checked={pickedRole === "admin"}
              onPick={() => setPickedRole("admin")}
              label="Quản trị viên"
              hint="super.admin"
            />
          </div>
        </label>

        <label className="block text-sm">
          <span className="font-medium text-slate-700">Email</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 w-full rounded border px-3 py-2"
            required
          />
        </label>

        <button
          type="submit"
          className="w-full rounded bg-brand px-4 py-2 text-white hover:bg-brand-dark"
        >
          Vào hệ thống (mock)
        </button>
      </form>
    </div>
  );
}

function RolePick({
  checked,
  onPick,
  label,
  hint,
}: {
  checked: boolean;
  onPick: () => void;
  label: string;
  hint: string;
}) {
  return (
    <button
      type="button"
      onClick={onPick}
      className={
        "rounded border px-3 py-3 text-left transition " +
        (checked ? "border-brand bg-brand-50" : "hover:bg-slate-50")
      }
    >
      <div className="font-medium text-slate-800">{label}</div>
      <div className="text-xs text-slate-500">{hint}</div>
    </button>
  );
}
