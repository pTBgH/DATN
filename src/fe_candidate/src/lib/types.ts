export interface ApiResponse<T> {
    data: T;
    message?: string;
    status?: number;
}

export interface PaginatedResponse<T> {
    data: T[];
    total: number;
    page: number;
    limit: number;
}

export interface Job {
    id: string;
    title: string;
    description: string;
    company: string;
    salary_min?: number;
    salary_max?: number;
    location: string;
    job_type: 'FULL_TIME' | 'PART_TIME' | 'CONTRACT' | 'TEMPORARY';
    status: 'OPEN' | 'CLOSED';
    created_at: string;
    updated_at: string;
}

export interface Application {
    id: string;
    job_id: string;
    candidate_id: string;
    cv_id: string;
    status: 'DRAFT' | 'SUBMITTED' | 'REVIEWING' | 'ACCEPTED' | 'REJECTED';
    created_at: string;
    updated_at: string;
}

export interface CV {
    id: string;
    candidate_id: string;
    file_name: string;
    file_link: string;
    is_primary: boolean;
    created_at: string;
}

export interface Candidate {
    id: string;
    email: string;
    first_name: string;
    last_name: string;
    phone?: string;
    bio?: string;
    avatar?: string;
    cvs: CV[];
    applications: Application[];
    created_at: string;
}
