/**
 * Real Keycloak login for the recruiter + admin frontend (rct).
 *
 * OAuth2 Resource Owner Password Credentials grant against the realm token
 * endpoint (proxied through Kong). The client must be a PUBLIC client with
 * "Direct Access Grants" enabled (recruiter-app).
 *
 * The recruiter/admin role is derived from the token's realm roles so the
 * existing layout/nav (which gates on `role`) keeps working. Tokens are
 * stored under the same localStorage keys the rest of the app already reads.
 *
 * Env (NEXT_PUBLIC_*, baked at build time):
 *   NEXT_PUBLIC_USE_MOCK=false
 *   NEXT_PUBLIC_API_BASE_URL=<kong-url>
 *   NEXT_PUBLIC_KEYCLOAK_URL=<kong-url>
 *   NEXT_PUBLIC_KEYCLOAK_REALM=job7189
 *   NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=recruiter-app
 */

"use client";

import { config } from "@/lib/config";
import { STORAGE_KEY, TOKEN_KEY, type MockRole } from "@/lib/auth/mock";

const REFRESH_KEY = "job7189.refresh";

export interface LoginResult {
  role: MockRole;
  email: string;
  roles: string[];
}

interface TokenResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
}

function decodeJwt(token: string): Record<string, unknown> {
  try {
    const payload = token.split(".")[1];
    const json = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(decodeURIComponent(escape(json))) as Record<string, unknown>;
  } catch {
    return {};
  }
}

export async function passwordGrant(
  username: string,
  password: string,
): Promise<LoginResult> {
  // Mock mode: bypass Keycloak and use localStorage
  if (config.useMock) {
    // Mock user roles: admin for "admin", recruiter for anything else
    const roles = username === "admin" ? ["admin"] : ["recruiter"];
    const role: MockRole = roles.includes("admin") ? "admin" : "recruiter";
    const email = `${username}@job7189.local`;

    // Store token and auth state
    window.localStorage.setItem(TOKEN_KEY, `mock-${role}-${Date.now()}`);
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ role, email }));

    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 300));

    return { role, email, roles };
  }

  const base = config.keycloak.baseUrl.replace(/\/$/, "");
  const url = `${base}/realms/${config.keycloak.realm}/protocol/openid-connect/token`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "password",
      client_id: config.keycloak.clientId,
      username,
      password,
      scope: "openid",
    }),
  });

  if (!res.ok) {
    let message = `Đăng nhập thất bại (HTTP ${res.status})`;
    try {
      const err = (await res.json()) as { error_description?: string; error?: string };
      message = err.error_description || err.error || message;
    } catch {
      /* keep default message */
    }
    throw new Error(message);
  }

  const tok = (await res.json()) as TokenResponse;
  const claims = decodeJwt(tok.access_token);

  const email =
    (claims.email as string) ||
    (claims.preferred_username as string) ||
    username;
  const roles =
    ((claims.realm_access as { roles?: string[] } | undefined)?.roles) ?? [];
  const role: MockRole = roles.includes("admin") ? "admin" : "recruiter";

  window.localStorage.setItem(TOKEN_KEY, tok.access_token);
  if (tok.refresh_token) {
    window.localStorage.setItem(REFRESH_KEY, tok.refresh_token);
  }
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ role, email }));

  return { role, email, roles };
}

export function logout() {
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(REFRESH_KEY);
  window.localStorage.removeItem(STORAGE_KEY);
}
