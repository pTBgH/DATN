import { useCallback } from 'react';
import api from '@/lib/api';

export const useJobAPI = () => {
    const getJobs = useCallback(async (workspaceId: string, page = 1) => {
        return api.get(`/api/workspaces/${workspaceId}/jobs`, {
            params: { page },
        });
    }, []);

    const createJob = useCallback(async (workspaceId: string, data: any) => {
        return api.post(`/api/workspaces/${workspaceId}/jobs`, data);
    }, []);

    const updateJob = useCallback(async (jobId: string, data: any) => {
        return api.put(`/api/jobs/${jobId}`, data);
    }, []);

    return { getJobs, createJob, updateJob };
};

export const useHiringAPI = () => {
    const getHiringBoard = useCallback(async (workspaceId: string) => {
        return api.get(`/api/workspaces/${workspaceId}/hiring-board`);
    }, []);

    const moveApplication = useCallback(async (appId: string, stage: string) => {
        return api.put(`/api/applications/${appId}`, { status: stage });
    }, []);

    const getApplications = useCallback(async (workspaceId: string) => {
        return api.get(`/api/workspaces/${workspaceId}/applications`);
    }, []);

    return { getHiringBoard, moveApplication, getApplications };
};

export const useWorkspaceAPI = () => {
    const getWorkspaces = useCallback(async () => {
        return api.get('/api/workspaces');
    }, []);

    const getWorkspaceById = useCallback(async (id: string) => {
        return api.get(`/api/workspaces/${id}`);
    }, []);

    const createWorkspace = useCallback(async (data: any) => {
        return api.post('/api/workspaces', data);
    }, []);

    return { getWorkspaces, getWorkspaceById, createWorkspace };
};
