/**
 * Thin fetch wrapper used by every service-specific module.
 *
 * Behaviour (skeleton / mock-first):
 *   - Reads bearer token from localStorage("job7189.token") — replace with the
 *     real auth provider (NextAuth Keycloak, BFF cookie, …) when wiring backend.
 *   - Adds optional `Host` override (Kong matches some routes by Host header).
 *   - Throws ApiError on non-2xx with parsed body.
 *
 * In mock mode (NEXT_PUBLIC_USE_MOCK=true) every service module short-circuits
 * to fixtures in `src/mocks` and never calls this wrapper.
 */

import { config } from "@/lib/config";
import type { ApiError } from "@/types";

interface RequestOptions extends Omit<RequestInit, "body"> {
  /** Object body, will be JSON-stringified. Pass FormData via `rawBody`. */
  body?: unknown;
  /** Pre-serialised body for FormData / file uploads. */
  rawBody?: BodyInit;
  /** Query string params. */
  query?: Record<string, string | number | boolean | undefined | null>;
  /** Override bearer token (used in server components / route handlers). */
  token?: string | null;
}

export class ApiClientError extends Error {
  status: number;
  errors?: Record<string, string[]>;

  constructor(error: ApiError) {
    super(error.message);
    this.status = error.status ?? 0;
    this.errors = error.errors;
  }
}

function buildUrl(path: string, query?: RequestOptions["query"]) {
  const base = config.apiBaseUrl.replace(/\/$/, "");
  const url = new URL(path.startsWith("/") ? `${base}${path}` : `${base}/${path}`);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v === undefined || v === null) continue;
      url.searchParams.append(k, String(v));
    }
  }
  return url.toString();
}

async function getBrowserToken(): Promise<string | null> {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage.getItem("job7189.token");
  } catch {
    return null;
  }
}

export async function apiFetch<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const headers = new Headers(opts.headers);
  headers.set("Accept", "application/json");
  if (config.apiHostOverride) headers.set("Host", config.apiHostOverride);

  const token = opts.token === null ? null : opts.token ?? (await getBrowserToken());
  if (token) headers.set("Authorization", `Bearer ${token}`);

  let body: BodyInit | undefined = opts.rawBody;
  if (body === undefined && opts.body !== undefined) {
    headers.set("Content-Type", "application/json");
    body = JSON.stringify(opts.body);
  }

  try {
    const res = await fetch(buildUrl(path, opts.query), {
      ...opts,
      headers,
      body,
    });

    if (res.status === 204) {
      return undefined as T;
    }

    const text = await res.text();
    const parsed = text ? safeJson(text) : null;

    if (!res.ok) {
      const err: ApiError =
        typeof parsed === "object" && parsed !== null
          ? (parsed as ApiError)
          : { message: `HTTP ${res.status}` };
      err.status = res.status;
      throw new ApiClientError(err);
    }

    return parsed as T;
  } catch (error) {
    if (error instanceof ApiClientError) {
      throw error;
    }
    throw new ApiClientError({
      message: error instanceof Error ? error.message : "Lỗi kết nối API",
      status: 0,
    });
  }
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}
