/**
 * Mock-only auth helper for the recruiter + admin frontend.
 *
 * Stores the picked role in localStorage so the layout can render the right
 * navigation. Replace with NextAuth Keycloak provider (or a BFF cookie) when
 * wiring the real backend; the rest of the app only depends on the public
 * `useMockAuth` hook below.
 */

"use client";

import { useCallback, useEffect, useState } from "react";

export type MockRole = "recruiter" | "admin";

export const STORAGE_KEY = "job7189.rct.role";
export const TOKEN_KEY = "job7189.token";

export interface MockAuthState {
  role: MockRole | null;
  email: string | null;
}

function read(): MockAuthState {
  if (typeof window === "undefined") return { role: null, email: null };
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return { role: null, email: null };
    const parsed = JSON.parse(raw) as MockAuthState;
    return parsed.role ? parsed : { role: null, email: null };
  } catch {
    return { role: null, email: null };
  }
}

export function useMockAuth() {
  const [state, setState] = useState<MockAuthState>({ role: null, email: null });

  useEffect(() => {
    setState(read());
  }, []);

  const signIn = useCallback((role: MockRole, email: string) => {
    const next: MockAuthState = { role, email };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    window.localStorage.setItem(TOKEN_KEY, `mock-${role}-${Date.now()}`);
    setState(next);
  }, []);

  const signOut = useCallback(() => {
    window.localStorage.removeItem(STORAGE_KEY);
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem("job7189.refresh");
    setState({ role: null, email: null });
  }, []);

  return { ...state, signIn, signOut };
}
