// Service Layer - Job Management (OOP Style)
import api from './api';

export interface Job {
    id: string;
    title: string;
    company: string;
    location: string;
    salary_min?: number;
    salary_max?: number;
    job_type: string;
    description: string;
    created_at: string;
    updated_at?: string;
}

export interface JobFilter {
    keyword?: string;
    location?: string;
    jobType?: string;
    page?: number;
    limit?: number;
}

export interface JobListResponse {
    data: Job[];
    total: number;
    page: number;
    limit: number;
}

/**
 * JobService - Handles all job-related API calls
 * OOP Pattern with caching and error handling
 */
class JobService {
    private cache: Map<string, { data: any; timestamp: number }> = new Map();
    private cacheExpiry: number = 5 * 60 * 1000; // 5 minutes TTL

    /**
     * Get cache key based on parameters
     */
    private getCacheKey(filter: JobFilter): string {
        return `jobs_${JSON.stringify(filter || {})}`;
    }

    /**
     * Check if cache is still valid
     */
    private isCacheValid(timestamp: number): boolean {
        return Date.now() - timestamp < this.cacheExpiry;
    }

    /**
     * Get all jobs with optional filtering
     * @param filter - Filter parameters
     * @returns Promise with job list
     */
    async getJobs(filter?: JobFilter): Promise<JobListResponse> {
        try {
            const cacheKey = this.getCacheKey(filter || {});
            const cached = this.cache.get(cacheKey);

            if (cached && this.isCacheValid(cached.timestamp)) {
                console.log('Using cached jobs data');
                return cached.data;
            }

            const response = await api.get<JobListResponse>('/jobs', {
                params: {
                    page: filter?.page || 1,
                    limit: filter?.limit || 20,
                    keyword: filter?.keyword,
                    location: filter?.location,
                    job_type: filter?.jobType,
                },
            });

            // Cache the response
            this.cache.set(cacheKey, {
                data: response,
                timestamp: Date.now(),
            });

            return response as unknown as JobListResponse;
        } catch (error) {
            console.error('Error fetching jobs:', error);
            throw new Error('Failed to fetch jobs. Please try again later.');
        }
    }

    /**
     * Search jobs by keyword
     * @param keyword - Search keyword
     * @param limit - Results limit
     * @returns Promise with filtered jobs
     */
    async searchJobs(keyword: string, limit: number = 20): Promise<JobListResponse> {
        return this.getJobs({ keyword, limit });
    }

    /**
     * Get job by ID
     * @param jobId - Job ID
     * @returns Promise with job detail
     */
    async getJobById(jobId: string): Promise<Job> {
        try {
            const res = await api.get<Job>(`/jobs/${jobId}`);
            return res as unknown as Job;
        } catch (error) {
            console.error(`Error fetching job ${jobId}:`, error);
            throw new Error('Failed to fetch job details.');
        }
    }

    /**
     * Clear cache when needed
     */
    clearCache(): void {
        this.cache.clear();
    }

    /**
     * Clear specific cache entry
     */
    clearCacheEntry(filter?: JobFilter): void {
        const cacheKey = this.getCacheKey(filter || {});
        this.cache.delete(cacheKey);
    }
}

export const jobService = new JobService();
