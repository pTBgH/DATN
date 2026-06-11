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
  const [mounted, setMounted] = useState(false);
  const [state, setState] = useState<FetchState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  const performFetch = async (): Promise<void> => {
    // Reset cancelled flag when starting a new fetch
    cancelledRef.current = false;

    const token = window.localStorage.getItem(TOKEN_KEY);

    if (!token) {
      // Show error message instead of redirecting immediately
      setState({
        data: null,
        loading: false,
        error: "Bạn cần đăng nhập để xem nội dung này",
      });
      return;
    }

    setState((s) => ({ ...s, loading: true, error: null }));

    try {
      const data = await fetcher();
      if (!cancelledRef.current) setState({ data, loading: false, error: null });
    } catch (e: unknown) {
      if (cancelledRef.current) return;
      if (e instanceof ApiClientError && e.status === 401) {
        // 401 after silent refresh failed - show error instead of immediate redirect
        setState({
          data: null,
          loading: false,
          error: "Phiên đăng nhập của bạn đã hết hạn. Vui lòng đăng nhập lại.",
        });
        return;
      }
      setState({
        data: null,
        loading: false,
        error: e instanceof Error ? e.message : "Có lỗi xảy ra",
      });
    }
  };

  // Only run on client after mount
  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;
    cancelledRef.current = false;
    performFetch();
    return () => {
      cancelledRef.current = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mounted, ...deps]);

  // Return loading state on server to prevent hydration mismatch
  if (!mounted) {
    return {
      data: null,
      loading: true,
      error: null,
      refetch: performFetch,
    };
  }

  return {
    ...state,
    refetch: performFetch,
  };
}
