"use client";

import Link from "next/link";
import { useState } from "react";

interface Props {
  wsId: string;
  location?: string | null;
  plan?: string | null;
}

export function WorkspaceMenuButton({ wsId, location, plan }: Props) {
  const [open, setOpen] = useState(false);

  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex h-8 w-8 items-center justify-center rounded-full border border-slate-300 bg-white text-sm font-medium hover:bg-slate-50 transition"
        aria-label="Menu"
      >
        ⚙
      </button>
      {open ? (
        <>
          <div
            className="fixed inset-0 z-20"
            onClick={() => setOpen(false)}
          />
          <div className="absolute right-0 mt-2 w-48 rounded-lg border bg-white shadow-lg z-30">
            <Link
              href={`/recruiter/${wsId}/members`}
              className="block px-3 py-2 text-sm text-slate-700 hover:bg-slate-50 transition"
              onClick={() => setOpen(false)}
            >
              Thành viên
            </Link>
            <Link
              href={`/recruiter/${wsId}/settings`}
              className="block px-3 py-2 text-sm text-slate-700 hover:bg-slate-50 transition"
              onClick={() => setOpen(false)}
            >
              Cài đặt
            </Link>
            <div className="border-t px-3 py-2 text-xs text-slate-500">
              {location ?? "—"} · {plan ?? "Free"}
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}
