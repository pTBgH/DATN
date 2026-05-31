/**
 * Resolve environment configuration.
 *
 * `NEXT_PUBLIC_USE_MOCK=true` means every API call short-circuits to the
 * in-memory mock fixtures (./mocks/*). Useful for local development before
 * Kong + Keycloak are reachable.
 */

export const config = {
  useMock:
    (process.env.NEXT_PUBLIC_USE_MOCK ?? "true").toLowerCase() === "true",
  apiBaseUrl:
    process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://api.job7189.com",
  apiHostOverride: process.env.NEXT_PUBLIC_API_HOST_OVERRIDE ?? "",
  keycloak: {
    baseUrl:
      process.env.NEXT_PUBLIC_KEYCLOAK_URL ?? "https://auth.job7189.com",
    realm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM ?? "job7189",
    clientId:
      process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID ?? "recruiter-app-dev",
  },
} as const;

export const keycloakIssuer = `${config.keycloak.baseUrl}/realms/${config.keycloak.realm}`;
