/**
 * Mock-only auth helper for the applicant frontend.
 *
 * Replace with NextAuth Keycloak provider (or a BFF cookie) when wiring the
 * real backend; the rest of the app only depends on the public `useMockAuth`
 * hook below.
 */

"use client";

import { useCallback, useEffect, useState } from "react";

export const STORAGE_KEY = "job7189.atd.session";
export const TOKEN_KEY = "job7189.token";

export interface MockAuthState {
  email: string | null;
  name: string | null;
}

function read(): MockAuthState {
  if (typeof window === "undefined") return { email: null, name: null };
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return { email: null, name: null };
    return JSON.parse(raw) as MockAuthState;
  } catch {
    return { email: null, name: null };
  }
}

export function useMockAuth() {
  const [state, setState] = useState<MockAuthState>({ email: null, name: null });

  useEffect(() => {
    setState(read());
  }, []);

  const signIn = useCallback((email: string, name: string) => {
    const next: MockAuthState = { email, name };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
    window.localStorage.setItem(TOKEN_KEY, `mock-candidate-${Date.now()}`);
    setState(next);
  }, []);

  const signOut = useCallback(() => {
    window.localStorage.removeItem(STORAGE_KEY);
    window.localStorage.removeItem(TOKEN_KEY);
    setState({ email: null, name: null });
  }, []);

  return { ...state, signIn, signOut };
}
