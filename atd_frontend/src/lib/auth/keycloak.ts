/**
 * Real Keycloak login for the applicant frontend (atd).
 *
 * Uses the OAuth2 Resource Owner Password Credentials grant against the
 * realm token endpoint (proxied through Kong). The client must be a PUBLIC
 * client with "Direct Access Grants" enabled (candidate-app-dev).
 *
 * On success the access token is stored in localStorage under the same keys
 * the rest of the app already reads (TOKEN_KEY for api/client.ts, STORAGE_KEY
 * for useMockAuth / TopNav), so no other component needs to change.
 *
 * Env (NEXT_PUBLIC_*, baked at build time):
 *   NEXT_PUBLIC_USE_MOCK=false
 *   NEXT_PUBLIC_API_BASE_URL=<kong-url>
 *   NEXT_PUBLIC_KEYCLOAK_URL=<kong-url>
 *   NEXT_PUBLIC_KEYCLOAK_REALM=job7189
 *   NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=candidate-app-dev
 */

"use client";

import { config } from "@/lib/config";
import { STORAGE_KEY, TOKEN_KEY } from "@/lib/auth/mock";

const REFRESH_KEY = "job7189.refresh";

export interface LoginResult {
  email: string;
  name: string;
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
  const name =
    (claims.name as string) || (claims.preferred_username as string) || email;
  const roles =
    ((claims.realm_access as { roles?: string[] } | undefined)?.roles) ?? [];

  window.localStorage.setItem(TOKEN_KEY, tok.access_token);
  if (tok.refresh_token) {
    window.localStorage.setItem(REFRESH_KEY, tok.refresh_token);
  }
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ email, name }));

  return { email, name, roles };
}

export function logout() {
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(REFRESH_KEY);
  window.localStorage.removeItem(STORAGE_KEY);
}

export async function registerUser(
  email: string,
  password: string,
): Promise<LoginResult> {
  const base = config.keycloak.baseUrl.replace(/\/$/, "");
  const url = `${base}/realms/${config.keycloak.realm}/protocol/openid-connect/registrations`;

  const registerRes = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      password,
      firstName: "",
      lastName: "",
    }),
  });

  if (!registerRes.ok) {
    let message = `Đăng ký thất bại (HTTP ${registerRes.status})`;
    try {
      const err = (await registerRes.json()) as {
        errorMessage?: string;
        error?: string;
      };
      message = err.errorMessage || err.error || message;
    } catch {
      /* keep default message */
    }
    throw new Error(message);
  }

  // After successful registration, log in
  return passwordGrant(email, password);
}
