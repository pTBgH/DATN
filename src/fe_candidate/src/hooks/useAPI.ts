import { useCallback } from 'react';
import api from '@/lib/api';
import { Job, Application, CV, ApiResponse } from '@/lib/types';

export const useJobAPI = () => {
    const getJobs = useCallback(async (page = 1, limit = 10) => {
        return api.get<any, ApiResponse<Job[]>>('/api/jobs', {
            params: { page, limit },
        });
    }, []);

    const getJobById = useCallback(async (id: string) => {
        return api.get<any, ApiResponse<Job>>(`/api/jobs/${id}`);
    }, []);

    const searchJobs = useCallback(async (keyword: string, page = 1) => {
        return api.get<any, ApiResponse<Job[]>>('/api/jobs/search', {
            params: { keyword, page },
        });
    }, []);

    return { getJobs, getJobById, searchJobs };
};

export const useApplicationAPI = () => {
    const createApplication = useCallback(async (jobId: string, cvId: string) => {
        return api.post<any, ApiResponse<Application>>('/api/applications', {
            job_id: jobId,
            cv_id: cvId,
        });
    }, []);

    const getApplications = useCallback(async () => {
        return api.get<any, ApiResponse<Application[]>>('/api/applications');
    }, []);

    const getApplicationById = useCallback(async (id: string) => {
        return api.get<any, ApiResponse<Application>>(`/api/applications/${id}`);
    }, []);

    return { createApplication, getApplications, getApplicationById };
};

export const useCVAPI = () => {
    const uploadCV = useCallback(async (file: File) => {
        const formData = new FormData();
        formData.append('file', file);
        return api.post<any, ApiResponse<CV>>('/api/cvs/upload', formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
    }, []);

    const getCVs = useCallback(async () => {
        return api.get<any, ApiResponse<CV[]>>('/api/cvs');
    }, []);

    const setPrimaryCV = useCallback(async (cvId: string) => {
        return api.put<any, ApiResponse<CV>>(`/api/cvs/${cvId}/primary`, {});
    }, []);

    const deleteCV = useCallback(async (cvId: string) => {
        return api.delete<any, ApiResponse<void>>(`/api/cvs/${cvId}`);
    }, []);

    return { uploadCV, getCVs, setPrimaryCV, deleteCV };
};
