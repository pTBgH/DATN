// Enhanced API Client with Vault Support & Debugging
import axios, { AxiosInstance, AxiosError, AxiosResponse } from 'axios';
import Cookie from 'js-cookie';
import { envService } from './env-service';

/**
 * API Client Factory with features:
 * - Vault-based configuration
 * - Request/Response logging
 * - Token management
 * - Keycloak integration
 * - Backend connectivity tracking
 */
class APIClientFactory {
    private instance: AxiosInstance | null = null;
    private config = {
        baseURL: 'http://localhost:8000',
    };
    private isInitialized: boolean = false;

    /**
     * Initialize API client with configuration
     */
    async initialize(): Promise<AxiosInstance> {
        if (this.isInitialized && this.instance) {
            return this.instance;
        }

        try {
            // Get configuration from Vault or environment
            const envConfig = await envService.getConfig();
            this.config = { baseURL: envConfig.apiBaseUrl };

            console.log('[API] Using backend URL:', this.config.baseURL);
            console.log('[API] Keycloak URL:', envConfig.keycloakUrl);
            console.log('[API] Keycloak Realm:', envConfig.keycloakRealm);
        } catch (error) {
            console.warn('[API] Failed to load config from Vault, using defaults');
        }

        this.instance = axios.create({
            ...this.config,
            timeout: 30000,
            headers: {
                'Content-Type': 'application/json',
            },
        });

        this.setupInterceptors(this.instance);
        this.isInitialized = true;

        return this.instance;
    }

    /**
     * Setup request and response interceptors
     */
    private setupInterceptors(instance: AxiosInstance): void {
        // Request Interceptor - Add token & logging
        instance.interceptors.request.use(
            (config) => {
                const token = Cookie.get('access_token');

                if (token) {
                    config.headers.Authorization = `Bearer ${token}`;
                }

                // Log request for debugging
                console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`, {
                    hasToken: !!token,
                    timestamp: new Date().toISOString(),
                });

                return config;
            },
            (error) => {
                console.error('[API Request Error]', error);
                return Promise.reject(error);
            }
        );

        // Response Interceptor - Handle responses & errors
        instance.interceptors.response.use(
            (response: AxiosResponse) => {
                console.log(`[API Response] ${response.status} ${response.config.url}`, {
                    dataLength: JSON.stringify(response.data).length,
                    timestamp: new Date().toISOString(),
                });

                return response.data;
            },
            (error: AxiosError) => {
                const status = error.response?.status;
                const url = error.config?.url;

                if (status === 401) {
                    console.error('[API] 401 Unauthorized - Token invalid or expired');
                    Cookie.remove('access_token');
                    Cookie.remove('refresh_token');

                    if (typeof window !== 'undefined') {
                        // Check if we're already on login page
                        if (!window.location.pathname.includes('/login')) {
                            window.location.href = '/login';
                        }
                    }
                } else if (status === 403) {
                    console.error('[API] 403 Forbidden - No permission to access resource');
                } else if (status === 404) {
                    console.error('[API] 404 Not Found -', url);
                } else if (status === 500) {
                    console.error('[API] 500 Server Error');
                } else if (!status) {
                    // Network error
                    console.error('[API] Network Error - Backend may be unreachable at', this.config.baseURL, error.message);
                }

                const errorResponse = error.response?.data || {
                    message: error.message,
                    status: status || 'NETWORK_ERROR',
                };

                console.error('[API Error Response]', errorResponse);

                return Promise.reject(errorResponse);
            }
        );
    }

    /**
     * Test backend connectivity
     */
    async testConnectivity(): Promise<boolean> {
        if (!this.instance) {
            await this.initialize();
        }

        try {
            const response = await this.instance!.get('/health');
            console.log('[API Health Check] Backend is accessible:', response);
            return true;
        } catch (error) {
            console.error('[API Health Check] Backend is NOT accessible:', error);
            return false;
        }
    }

    /**
     * Get instance
     */
    async getInstance(): Promise<AxiosInstance> {
        if (!this.instance) {
            await this.initialize();
        }
        return this.instance!;
    }
}

// Singleton instance
const clientFactory = new APIClientFactory();

// Export initialized instance
export default (async () => {
    return await clientFactory.getInstance();
})();

export { clientFactory };
