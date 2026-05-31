import Link from "next/link";
import { ExternalLink } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t border-slate-100 bg-white py-16">
      <div className="mx-auto max-w-6xl px-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-12 mb-12">
          {/* Brand */}
          <div>
            <div className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 bg-brand rounded-[10px] flex items-center justify-center text-white text-sm font-bold">
                J
              </div>
              <span className="font-semibold text-slate-900">Job7189</span>
            </div>
            <p className="text-xs text-slate-500 leading-relaxed">
              Nền tảng tuyển dụng không kỳ thị, minh bạch và hiệu quả
            </p>
          </div>

          {/* For Candidates */}
          <div>
            <h3 className="text-sm font-semibold text-slate-900 mb-4">Cho Ứng Viên</h3>
            <ul className="space-y-3">
              <li>
                <Link href="/jobs" className="text-xs text-slate-600 hover:text-brand transition-colors duration-300">
                  Tìm việc làm
                </Link>
              </li>
              <li>
                <Link href="/applications" className="text-xs text-slate-600 hover:text-brand transition-colors duration-300">
                  Đơn ứng tuyển
                </Link>
              </li>
              <li>
                <Link href="/profile" className="text-xs text-slate-600 hover:text-brand transition-colors duration-300">
                  Hồ sơ
                </Link>
              </li>
            </ul>
          </div>

          {/* For Recruiters */}
          <div>
            <h3 className="text-sm font-semibold text-slate-900 mb-4">Cho Nhà Tuyển Dụng</h3>
            <ul className="space-y-3">
              <li>
                <a 
                  href="http://localhost:3001" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-xs text-slate-600 hover:text-brand transition-colors duration-300 inline-flex items-center gap-1"
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
                  className="text-xs text-slate-600 hover:text-brand transition-colors duration-300 inline-flex items-center gap-1"
                >
                  Workspace
                  <ExternalLink className="w-3 h-3" />
                </a>
              </li>
            </ul>
          </div>

          {/* About */}
          <div>
            <h3 className="text-sm font-semibold text-slate-900 mb-4">Thông Tin</h3>
            <ul className="space-y-3">
              <li>
                <a href="#" className="text-xs text-slate-600 hover:text-brand transition-colors duration-300">
                  Về chúng tôi
                </a>
              </li>
              <li>
                <a href="#" className="text-xs text-slate-600 hover:text-brand transition-colors duration-300">
                  Điều khoản
                </a>
              </li>
              <li>
                <a href="#" className="text-xs text-slate-600 hover:text-brand transition-colors duration-300">
                  Liên hệ
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="border-t border-slate-100 pt-8 text-center text-xs text-slate-400">
          <p>&copy; 2026 Job7189. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
