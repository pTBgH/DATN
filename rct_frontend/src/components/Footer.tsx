import Link from "next/link";
import { ExternalLink } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t border-slate-200 bg-slate-50 py-3 px-4">
      <div className="mx-auto max-w-7xl flex items-center justify-between gap-4 text-xs text-slate-600">
        <div className="flex items-center gap-2">
          <div className="w-5 h-5 bg-brand rounded flex items-center justify-center text-white text-xs font-bold">
            J
          </div>
          <span className="font-medium text-slate-900">Job7189</span>
        </div>
        
        <div className="flex items-center gap-4">
          <Link href="/recruiter" className="hover:text-brand transition">
            Recruiter
          </Link>
          <a 
            href="http://localhost:3002" 
            target="_blank" 
            rel="noopener noreferrer"
            className="hover:text-brand transition flex items-center gap-1"
          >
            Candidates
            <ExternalLink className="w-3 h-3" />
          </a>
          <a href="#" className="hover:text-brand transition">
            About
          </a>
          <a href="#" className="hover:text-brand transition">
            Terms
          </a>
        </div>

        <p className="text-slate-500">&copy; 2026 Job7189</p>
      </div>
    </footer>
  );
}
