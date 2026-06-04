"use client";

import { useState, useEffect } from "react";
import { workspaceApi } from "@/lib/api";
import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import type { CreateWorkspaceInput, WorkspaceResource, CompanyOptionsResponse } from "@/types/workspace";

interface CreateWorkspaceModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (workspace: WorkspaceResource) => void;
}

export function CreateWorkspaceModal({
  isOpen,
  onClose,
  onSuccess,
}: CreateWorkspaceModalProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [options, setOptions] = useState<CompanyOptionsResponse | null>(null);
  const [formData, setFormData] = useState<CreateWorkspaceInput>({
    name: "",
    email: "",
    location: "",
    size: undefined,
    industry: undefined,
  });

  useEffect(() => {
    if (isOpen) {
      workspaceApi.getCompanyOptions()
        .then(setOptions)
        .catch(err => console.error("Failed to load options:", err));
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (!formData.name.trim()) {
        throw new Error("Vui lòng nhập tên công ty");
      }
      if (!formData.email.trim()) {
        throw new Error("Vui lòng nhập email");
      }

      const result = await workspaceApi.createWorkspace(formData);
      onSuccess(result);
      setFormData({ name: "", email: "", location: "", size: undefined, industry: undefined });
      onClose();
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : "Lỗi tạo workspace. Vui lòng thử lại.";
      console.error("[v0] Error creating workspace:", err);
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <Card className="w-full max-w-md bg-white">
        <div className="border-b border-gray-200 px-6 py-4">
          <h2 className="text-lg font-semibold text-slate-900">Tạo Workspace Mới</h2>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 px-6 py-4">
          {error && (
            <div className="rounded-lg bg-red-50 p-4 border border-red-200">
              <div className="flex gap-2">
                <div className="text-red-600 text-lg leading-none mt-0.5">⚠</div>
                <div>
                  <p className="text-sm font-medium text-red-900">{error}</p>
                  <p className="text-xs text-red-700 mt-1">
                    Vui lòng kiểm tra lại thông tin. Nếu lỗi vẫn tiếp tục, hãy liên hệ với bộ phận hỗ trợ.
                  </p>
                </div>
              </div>
            </div>
          )}

          <div>
            <label htmlFor="name" className="block text-sm font-medium text-slate-700">
              Tên Công Ty / Workspace
            </label>
            <input
              type="text"
              id="name"
              name="name"
              value={formData.name}
              onChange={handleChange}
              placeholder="VD: Acme Corporation"
              className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-slate-900 placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-medium text-slate-700">
              Email Workspace
            </label>
            <input
              type="email"
              id="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              placeholder="hr@company.com"
              className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-slate-900 placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              disabled={loading}
            />
          </div>

          <div>
            <label htmlFor="location" className="block text-sm font-medium text-slate-700">
              Địa Điểm
            </label>
            <input
              type="text"
              id="location"
              name="location"
              value={formData.location}
              onChange={handleChange}
              placeholder="VD: Hà Nội, VN"
              className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-slate-900 placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              disabled={loading}
            />
          </div>

          {options && (
            <>
              <div>
                <label htmlFor="size" className="block text-sm font-medium text-slate-700">
                  Quy Mô Công Ty
                </label>
                <select
                  id="size"
                  name="size"
                  value={formData.size || ""}
                  onChange={(e) =>
                    setFormData((prev) => ({
                      ...prev,
                      size: e.target.value ? parseInt(e.target.value) : undefined,
                    }))
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-slate-900 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  disabled={loading}
                >
                  <option value="">-- Chọn quy mô --</option>
                  {options.sizes.map((size) => (
                    <option key={size.id} value={size.id}>
                      {size.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label htmlFor="industry" className="block text-sm font-medium text-slate-700">
                  Ngành Nghề
                </label>
                <select
                  id="industry"
                  name="industry"
                  value={formData.industry || ""}
                  onChange={(e) =>
                    setFormData((prev) => ({
                      ...prev,
                      industry: e.target.value ? parseInt(e.target.value) : undefined,
                    }))
                  }
                  className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 text-slate-900 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  disabled={loading}
                >
                  <option value="">-- Chọn ngành --</option>
                  {options.industries.map((industry) => (
                    <option key={industry.id} value={industry.id}>
                      {industry.name}
                    </option>
                  ))}
                </select>
              </div>
            </>
          )}

          <div className="flex gap-2 pt-4">
            <Button
              variant="outline"
              className="flex-1"
              onClick={onClose}
              disabled={loading}
            >
              Hủy
            </Button>
            <Button
              variant="primary"
              className="flex-1"
              type="submit"
              disabled={loading}
            >
              {loading ? "Đang tạo..." : "Tạo Workspace"}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
