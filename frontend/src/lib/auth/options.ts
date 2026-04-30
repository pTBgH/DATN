/**
 * NextAuth configuration for Keycloak realm `job7189`.
 *
 * Flow: Authorization Code + PKCE.
 * On each session request, the access_token is exposed via session.accessToken
 * so the api client can attach it as `Authorization: Bearer ...` to Kong.
 *
 * Refresh: when access_token is within 30s of expiry we transparently call the
 * Keycloak token endpoint with refresh_token grant. This mirrors the flow
 * documented in API-AUTHENTICATION-GUIDE.md.
 */

import type { NextAuthOptions } from "next-auth";
import KeycloakProvider from "next-auth/providers/keycloak";

const KEYCLOAK_ISSUER =
  process.env.KEYCLOAK_ISSUER ?? "https://auth.job7189.com/realms/job7189";

interface RefreshedTokens {
  access_token: string;
  expires_in: number;
  refresh_token?: string;
  refresh_expires_in?: number;
  id_token?: string;
}

async function refreshAccessToken<
  T extends {
    refreshToken?: string;
    accessToken?: string;
    accessTokenExpires?: number;
    refreshTokenExpires?: number;
    idToken?: string;
  },
>(token: T): Promise<T> {
  if (!token.refreshToken) return token;
  try {
    const url = `${KEYCLOAK_ISSUER}/protocol/openid-connect/token`;
    const params = new URLSearchParams({
      grant_type: "refresh_token",
      client_id: process.env.KEYCLOAK_CLIENT_ID ?? "",
      client_secret: process.env.KEYCLOAK_CLIENT_SECRET ?? "",
      refresh_token: token.refreshToken,
    });

    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });
    if (!res.ok) throw new Error(`Refresh failed: HTTP ${res.status}`);
    const data = (await res.json()) as RefreshedTokens;
    return {
      ...token,
      accessToken: data.access_token,
      accessTokenExpires: Date.now() + data.expires_in * 1000,
      refreshToken: data.refresh_token ?? token.refreshToken,
      refreshTokenExpires: data.refresh_expires_in
        ? Date.now() + data.refresh_expires_in * 1000
        : token.refreshTokenExpires,
      idToken: data.id_token ?? token.idToken,
    };
  } catch {
    return { ...token, accessToken: undefined };
  }
}

export const authOptions: NextAuthOptions = {
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID ?? "",
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET ?? "",
      issuer: KEYCLOAK_ISSUER,
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, account }) {
      if (account) {
        return {
          ...token,
          accessToken: account.access_token,
          accessTokenExpires: account.expires_at
            ? account.expires_at * 1000
            : Date.now() + 300_000,
          refreshToken: account.refresh_token,
          idToken: account.id_token,
          provider: account.provider,
        };
      }
      const expires = (token as { accessTokenExpires?: number }).accessTokenExpires;
      if (expires && Date.now() < expires - 30_000) {
        return token;
      }
      return refreshAccessToken(token as Parameters<typeof refreshAccessToken>[0]);
    },
    async session({ session, token }) {
      const t = token as {
        accessToken?: string;
        idToken?: string;
        accessTokenExpires?: number;
      };
      return {
        ...session,
        accessToken: t.accessToken,
        idToken: t.idToken,
        accessTokenExpires: t.accessTokenExpires,
      };
    },
  },
  pages: {
    signIn: "/login",
  },
};
