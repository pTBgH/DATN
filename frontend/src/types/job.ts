/**
 * Job Service — DTOs
 * Sources:
 *   - src/job_service/laravel_back/app/Http/Resources/JobSubJdResource.php
 *   - src/job_service/laravel_back/app/Http/Resources/JobJdResource.php
 *   - src/job_service/laravel_back/app/Http/Controllers/Job/Traits/JobValidationRules.php
 *   - src/job_service/laravel_back/app/Http/Controllers/OptionController.php
 *   - src/job_service/laravel_back/app/Http/Controllers/Public/MetadataController.php
 */

export type JobStatus =
  | "Draft"
  | "Pending"
  | "Published"
  | "Rejected"
  | "Closed"
  | "Archived";

export interface JobSubJdResource {
  job_id: string;
  title: string;
  slug: string;
  company_id: string;
  company_name: string | null;
  company_logo?: string | null;
  status: JobStatus | string;
  description: string | null;
  requirements: string | null;
  benefits: string | null;
  salary_min: number | null;
  salary_max: number | null;
  deadline: string;
  view_count: number;
  apply_count: number;
}

export type JobJdResource = JobSubJdResource;

export interface JobInput {
  company_id?: string;
  pipeline_id?: string;
  title: string;
  description?: string;
  requirements?: string;
  benefits?: string;
  keywords?: string;
  deadline?: string;
  up_date?: string;
  salary_min?: number;
  salary_max?: number;
  currency?: number;
  min_age?: number;
  max_age?: number;
  job_link?: string;
  exp_years?: number;
  job_type?: number;
  job_sector?: number;
  working_type?: number;
  contract_type?: number;
  degree_level?: number;
  sex?: number;
  location_id?: number;
  detail_address?: string;
}

export interface JobListFilters {
  q?: string;
  status?: number;
  exp_years?: number;
  location_id?: number;
  job_types?: number[];
  sectors?: number[];
  sort_by?:
    | "highest_view"
    | "lowest_view"
    | "highest_application"
    | "lowest_application"
    | "newest"
    | "oldest"
    | "updated_time"
    | "name_az"
    | "name_za"
    | "deadline_earliest"
    | "deadline_latest";
  page?: number;
}

export interface NamedOption {
  id: number;
  name: string;
}

export interface GeneralOptionsResponse {
  job_types: NamedOption[];
  job_sectors: NamedOption[];
  working_types: NamedOption[];
  contract_types: NamedOption[];
  degree_levels: NamedOption[];
  currencies: NamedOption[];
  sexes: NamedOption[];
}

export interface CommonMetadataResponse {
  sizes: NamedOption[];
  industries: NamedOption[];
  cities: NamedOption[];
}

/** Generic Laravel paginator */
export interface Paginated<T> {
  data: T[];
  links?: {
    first: string | null;
    last: string | null;
    prev: string | null;
    next: string | null;
  };
  meta?: {
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
}
