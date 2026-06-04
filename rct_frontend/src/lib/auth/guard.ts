"use client";

import { useEffect, useState, useRef } from "react";
import { useRouter } from "next/navigation";
import { ApiClientError } from "@/lib/api/client";
import { TOKEN_KEY } from "@/lib/auth/mock";

export interface FetchState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  refetch?: () => Promise<void>;
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
): FetchState<T> & { refetch: () => Promise<void> } {
  const router = useRouter();
  const cancelledRef = useRef(false);
  const [state, setState] = useState<FetchState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  const performFetch = async (): Promise<void> => {
    // Reset cancelled flag when starting a new fetch
    cancelledRef.current = false;

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

    try {
      const data = await fetcher();
      if (!cancelledRef.current) setState({ data, loading: false, error: null });
    } catch (e: unknown) {
      if (cancelledRef.current) return;
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
    }
  };

  useEffect(() => {
    cancelledRef.current = false;
    performFetch();
    return () => {
      cancelledRef.current = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return {
    ...state,
    refetch: performFetch,
  };
}
