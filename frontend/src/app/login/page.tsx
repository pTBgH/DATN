"use client";

import { signIn, useSession } from "next-auth/react";
import { Suspense, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { config, keycloakIssuer } from "@/lib/config";

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="text-sm text-slate-500">Loading…</div>}>
      <LoginContent />
    </Suspense>
  );
}

function LoginContent() {
  const { status } = useSession();
  const router = useRouter();
  const params = useSearchParams();
  const callbackUrl = params.get("callbackUrl") ?? "/";

  useEffect(() => {
    if (status === "authenticated") router.replace(callbackUrl);
  }, [status, router, callbackUrl]);

  return (
    <div className="mx-auto max-w-md rounded-xl border bg-white p-8 shadow">
      <h1 className="text-xl font-semibold">Đăng nhập</h1>
      <p className="mt-2 text-sm text-slate-600">
        Xác thực qua Keycloak — realm <code>{config.keycloak.realm}</code>.
      </p>

      <button
        type="button"
        onClick={() => signIn("keycloak", { callbackUrl })}
        className="mt-6 w-full rounded bg-brand px-4 py-2 font-medium text-white hover:bg-brand-dark"
      >
        Đăng nhập với Keycloak
      </button>

      <div className="mt-6 rounded bg-slate-50 p-3 text-xs text-slate-500">
        Issuer: <code>{keycloakIssuer}</code>
        <br />
        Client ID: <code>{config.keycloak.clientId}</code>
        <br />
        Flow: Authorization Code + PKCE.
      </div>
    </div>
  );
}
