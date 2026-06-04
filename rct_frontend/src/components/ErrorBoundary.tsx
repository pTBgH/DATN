"use client";

import React from "react";
import { Button } from "@/components/Button";

interface ErrorBoundaryProps {
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends React.Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    console.error("[v0] ErrorBoundary caught error:", error);
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error("[v0] Error details:", {
      message: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack,
    });
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4">
          <div className="flex gap-3">
            <div className="text-red-600 text-xl leading-none mt-0.5">⚠</div>
            <div className="flex-1">
              <h3 className="font-semibold text-red-900">Có lỗi xảy ra</h3>
              <p className="text-sm text-red-700 mt-1">
                {this.state.error?.message || "Một lỗi không xác định đã xảy ra"}
              </p>
              <details className="mt-2 text-xs text-red-600 cursor-pointer">
                <summary className="font-medium">Chi tiết lỗi (dành cho nhà phát triển)</summary>
                <pre className="mt-1 overflow-auto max-h-48 bg-red-100 p-2 rounded text-xs whitespace-pre-wrap break-words">
                  {this.state.error?.stack}
                </pre>
              </details>
              <Button
                variant="outline"
                size="sm"
                onClick={this.handleReset}
                className="mt-3"
              >
                Thử lại
              </Button>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
