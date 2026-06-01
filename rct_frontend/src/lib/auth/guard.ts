"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiClientError } from "@/lib/api/client";
import { TOKEN_KEY } from "@/lib/auth/mock";

export interface FetchState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

/**
 * useAuthedFetch — gọi 1 async API có yêu cầu Bearer token. Tự xử lý:
 *   - token chưa có (chưa login)         → redirect /login?callbackUrl=...
 *   - response 401 (token hết hạn, sai)   → redirect /login?callbackUrl=...
 *   - lỗi khác                            → set error
 */
export function useAuthedFetch<T>(
  fetcher: () => Promise<T>,
  deps: React.DependencyList,
): FetchState<T> {
  const router = useRouter();
  const [state, setState] = useState<FetchState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  useEffect(() => {
    let cancelled = false;

    const token =
      typeof window !== "undefined"
        ? window.localStorage.getItem(TOKEN_KEY)
        : null;

    if (!token) {
      const cb = typeof window !== "undefined" ? window.location.pathname : "/";
      router.replace(`/login?callbackUrl=${encodeURIComponent(cb)}`);
      return;
    }

    setState((s) => ({ ...s, loading: true, error: null }));

    fetcher()
      .then((data) => {
        if (!cancelled) setState({ data, loading: false, error: null });
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        if (e instanceof ApiClientError && e.status === 401) {
          const cb =
            typeof window !== "undefined" ? window.location.pathname : "/";
          router.replace(`/login?callbackUrl=${encodeURIComponent(cb)}`);
          return;
        }
        setState({
          data: null,
          loading: false,
          error: e instanceof Error ? e.message : "Có lỗi xảy ra",
        });
      });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
