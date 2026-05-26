import Link from "next/link";
import { ExternalLink } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t border-slate-200 bg-slate-50 py-12">
      <div className="mx-auto max-w-6xl px-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-8">
          {/* Brand */}
          <div>
            <div className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 bg-brand rounded-lg flex items-center justify-center text-white text-sm font-bold">
                J
              </div>
              <span className="font-semibold text-slate-900">Job7189</span>
            </div>
            <p className="text-xs text-slate-600">
              Nền tảng tuyển dụng không kỳ thị, minh bạch và hiệu quả
            </p>
          </div>

          {/* For Candidates */}
          <div>
            <h3 className="text-sm font-semibold text-slate-900 mb-3">Cho Ứng Viên</h3>
            <ul className="space-y-2">
              <li>
                <Link href="/jobs" className="text-xs text-slate-600 hover:text-brand transition">
                  Tìm việc làm
                </Link>
              </li>
              <li>
                <Link href="/applications" className="text-xs text-slate-600 hover:text-brand transition">
                  Đơn ứng tuyển
                </Link>
              </li>
              <li>
                <Link href="/profile" className="text-xs text-slate-600 hover:text-brand transition">
                  Hồ sơ
                </Link>
              </li>
            </ul>
          </div>

          {/* For Recruiters */}
          <div>
            <h3 className="text-sm font-semibold text-slate-900 mb-3">Cho Nhà Tuyển Dụng</h3>
            <ul className="space-y-2">
              <li>
                <a 
                  href="http://localhost:3001" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-xs text-slate-600 hover:text-brand transition flex items-center gap-1"
                >
                  Tuyển dụng ngay
                  <ExternalLink className="w-3 h-3" />
                </a>
              </li>
              <li>
                <a 
                  href="http://localhost:3001" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-xs text-slate-600 hover:text-brand transition flex items-center gap-1"
                >
                  Workspace
                  <ExternalLink className="w-3 h-3" />
                </a>
              </li>
            </ul>
          </div>

          {/* About */}
          <div>
            <h3 className="text-sm font-semibold text-slate-900 mb-3">Thông Tin</h3>
            <ul className="space-y-2">
              <li>
                <a href="#" className="text-xs text-slate-600 hover:text-brand transition">
                  Về chúng tôi
                </a>
              </li>
              <li>
                <a href="#" className="text-xs text-slate-600 hover:text-brand transition">
                  Điều khoản
                </a>
              </li>
              <li>
                <a href="#" className="text-xs text-slate-600 hover:text-brand transition">
                  Liên hệ
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="border-t border-slate-200 pt-6 text-center text-xs text-slate-500">
          <p>&copy; 2026 Job7189. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
