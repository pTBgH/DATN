/**
 * Candidate Service — DTOs
 * Sources:
 *   - src/candidate_service/laravel_back/app/Http/Resources/CvResource.php
 *   - src/candidate_service/laravel_back/app/Http/Controllers/JobApplicationController.php
 */

export interface CvResource {
  cv_id: string;
  user_id: string;
  title: string;
  cv_path: string;
  is_default: boolean;
  view_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface ApplicationHistoryItem {
  application_id: string;
  applied_at: string;
  status: number;
  stage: {
    id: string | null;
    name: string;
    color: string;
  };
  job: {
    id: string;
    title: string;
    company_name: string;
    logo: string | null;
    status: string | number;
    slug: string | null;
  };
}

export interface ApplicationHistoryResponse {
  data: ApplicationHistoryItem[];
}

export interface ApplyJobInput {
  cv_id: string;
}

export interface CreateCvInput {
  title: string;
  cv_path: string;
}

export interface SaveJobInput {
  job_id: string;
  is_saved: boolean;
}

export interface HideJobInput {
  job_id: string;
  is_hidden: boolean;
}
