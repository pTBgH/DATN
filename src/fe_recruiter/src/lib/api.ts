import axios, { AxiosInstance, AxiosError } from 'axios';
import Cookie from 'js-cookie';

// Read base URL from environment variables
const baseURL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000';

console.log('[API Client] Initializing with baseURL:', baseURL);
console.log('[API Client] Environment:', process.env.NODE_ENV);
console.log('[API Client] Keycloak URL:', process.env.NEXT_PUBLIC_KEYCLOAK_URL);

const api: AxiosInstance = axios.create({
    baseURL,
    timeout: 30000,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Request interceptor - Log all requests
api.interceptors.request.use(
    (config) => {
        const token = Cookie.get('access_token');
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }
        
        console.log(
            `[API] Request: ${config.method?.toUpperCase()} ${config.url}`,
            { hasToken: !!token }
        );
        
        return config;
    },
    (error) => {
        console.error('[API] Request error:', error);
        return Promise.reject(error);
    }
);

// Response interceptor - Log responses and handle errors
api.interceptors.response.use(
    (response) => {
        console.log(
            `[API] Response: ${response.status} ${response.config.url}`,
            { dataSize: JSON.stringify(response.data || {}).length }
        );
        return response.data;
    },
    (error: AxiosError) => {
        const status = error.response?.status;
        const url = error.config?.url;

        if (status === 401) {
            console.error('[API] 401 Unauthorized - Clearing tokens and redirecting to login');
            Cookie.remove('access_token');
            Cookie.remove('refresh_token');
            if (typeof window !== 'undefined') {
                window.location.href = '/login';
            }
        } else if (status === 404) {
            console.error(`[API] 404 Not Found - ${url}`);
        } else if (status === 500) {
            console.error('[API] 500 Server Error from backend');
        } else if (!status) {
            console.error(
                `[API] Network Error - Backend at ${baseURL} may be unreachable.`,
                'Error:', error.message
            );
        } else {
            console.error(`[API] HTTP ${status} - ${url}`);
        }

        const errorData = error.response?.data || {};
        console.error('[API] Error response:', errorData);

        return Promise.reject(error.response?.data || error);
    }
);

/**
 * Test backend connectivity for debugging
 */
export const testConnectivity = async () => {
    try {
        console.log('[API] Testing connectivity with backend...');
        const response = await api.get('/health');
        console.log('[API] ✅ Backend is healthy:', response);
        return { status: 'healthy', data: response };
    } catch (error) {
        console.error('[API] ❌ Backend connectivity test failed:', error);
        return { status: 'unhealthy', error };
    }
};

export default api;
