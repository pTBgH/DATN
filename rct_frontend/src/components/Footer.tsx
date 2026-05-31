import Link from "next/link";
import { ExternalLink } from "lucide-react";

export function Footer() {
  return (
    <footer className="border-t border-slate-100 bg-white py-8 px-4">
      <div className="mx-auto max-w-7xl flex items-center justify-between gap-6 text-xs text-slate-600">
        <div className="flex items-center gap-2.5">
          <div className="w-6 h-6 bg-brand rounded-[8px] flex items-center justify-center text-white text-xs font-bold">
            J
          </div>
          <span className="font-medium text-slate-900">Job7189</span>
        </div>
        
        <div className="flex items-center gap-6">
          <Link href="/recruiter" className="hover:text-brand transition-colors duration-300">
            Recruiter
          </Link>
          <a 
            href="http://localhost:3002" 
            target="_blank" 
            rel="noopener noreferrer"
            className="hover:text-brand transition-colors duration-300 inline-flex items-center gap-1"
          >
            Candidates
            <ExternalLink className="w-3 h-3" />
          </a>
          <a href="#" className="hover:text-brand transition-colors duration-300">
            About
          </a>
          <a href="#" className="hover:text-brand transition-colors duration-300">
            Terms
          </a>
        </div>

        <p className="text-slate-400">&copy; 2026 Job7189</p>
      </div>
    </footer>
  );
}
