"use client";

import Link from "next/link";
import { Card } from "@/components/Card";
import { Button } from "@/components/Button";

export function PageLoading({ label = "Đang tải..." }: { label?: string }) {
  return (
    <Card className="py-16 text-center bg-gray-50 border border-gray-200">
      <div className="space-y-2 text-slate-500">
        <div className="text-2xl">[ . . . ]</div>
        <p>{label}</p>
      </div>
    </Card>
  );
}

export function PageError({ message }: { message: string }) {
  const isAuthError =
    message.includes("đăng nhập") ||
    message.includes("hết hạn") ||
    message.includes("Bạn cần");

  return (
    <Card className="py-12 text-center border border-red-200 bg-red-50">
      <div className="space-y-4">
        <div className="text-2xl text-red-500">[ ! ]</div>
        <div>
          <p className="font-semibold text-red-700">
            {isAuthError ? "Phiên đăng nhập hết hạn" : "Không tải được dữ liệu"}
          </p>
          <p className="text-sm text-red-600 mt-1">{message}</p>
        </div>
        {isAuthError && (
          <Link href="/login">
            <Button variant="primary" size="sm">
              Đăng nhập lại
            </Button>
          </Link>
        )}
      </div>
    </Card>
  );
}
