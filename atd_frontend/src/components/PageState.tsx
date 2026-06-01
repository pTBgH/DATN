"use client";

import { Card } from "@/components/Card";

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
  return (
    <Card className="py-12 text-center border border-red-200 bg-red-50">
      <div className="space-y-2">
        <div className="text-2xl text-red-500">[ ! ]</div>
        <p className="font-semibold text-red-700">Không tải được dữ liệu</p>
        <p className="text-sm text-red-600">{message}</p>
      </div>
    </Card>
  );
}
