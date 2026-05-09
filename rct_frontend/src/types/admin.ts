/**
 * Admin (super.admin) DTOs.
 *
 * Sources:
 *   - src/job_service/laravel_back/app/Http/Controllers/Admin/CategoryController.php
 *   - src/job_service/laravel_back routes /api/admin/jobs[/approve]
 *
 * NOTE: backend exposes plain Eloquent models for some admin endpoints, so the
 * shapes below mirror what the controllers actually return.
 */

import type { JobSubJdResource } from "./job";

export interface AdminPendingJob extends JobSubJdResource {
  submitted_at: string;
  recruiter_name: string;
  recruiter_email: string;
  workspace_name: string;
}

export interface SectorCategory {
  id: number;
  name: string;
  code: string;
  active: boolean;
  job_count: number;
  created_at: string;
}

export interface AdminUserSummary {
  user_id: string;
  email: string;
  full_name: string;
  role: "candidate" | "recruiter" | "admin";
  status: "Active" | "Suspended" | "Pending";
  created_at: string;
  last_login_at: string | null;
}

export interface AdminCompanySummary {
  company_id: string;
  name: string;
  industry: string;
  size: string;
  active_jobs: number;
  workspace_count: number;
  verified: boolean;
  created_at: string;
}
