"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { registerUser } from "@/lib/auth/keycloak";

export default function SignupPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    // Validation
    if (!email || !password || !confirmPassword) {
      setError("Vui lòng điền tất cả các trường");
      return;
    }

    if (password !== confirmPassword) {
      setError("Mật khẩu không trùng khớp");
      return;
    }

    if (password.length < 8) {
      setError("Mật khẩu phải có ít nhất 8 ký tự");
      return;
    }

    setIsLoading(true);

    try {
      await registerUser(email, password);
      router.push("/recruiter");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Đăng ký thất bại");
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-white rounded-lg shadow-md p-8">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-slate-900 mb-2">
            Đăng Ký Nhà Tuyển Dụng
          </h1>
          <p className="text-slate-600">Tạo tài khoản để bắt đầu tuyển dụng</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
              {error}
            </div>
          )}

          <div>
            <label
              htmlFor="email"
              className="block text-sm font-medium text-slate-700 mb-1"
            >
              Email
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="your@email.com"
              className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              disabled={isLoading}
            />
          </div>

          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium text-slate-700 mb-1"
            >
              Mật khẩu
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              disabled={isLoading}
            />
            <p className="text-xs text-slate-500 mt-1">Tối thiểu 8 ký tự</p>
          </div>

          <div>
            <label
              htmlFor="confirmPassword"
              className="block text-sm font-medium text-slate-700 mb-1"
            >
              Xác Nhận Mật Khẩu
            </label>
            <input
              id="confirmPassword"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              disabled={isLoading}
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-slate-400 text-white font-semibold py-2 rounded-lg transition"
          >
            {isLoading ? "Đang đăng ký..." : "Đăng Ký"}
          </button>
        </form>

        <div className="mt-6 text-center">
          <p className="text-slate-600 text-sm">
            Đã có tài khoản?{" "}
            <Link href="/login" className="text-blue-600 hover:underline font-medium">
              Đăng nhập
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
