// Service Layer - Environment Management with Vault Support
import axios from 'axios';

interface VaultConfig {
    vaultUrl: string;
    vaultToken?: string;
    secretPath: string;
    cacheTTL: number; // TTL in seconds
}

interface EnvConfig {
    apiBaseUrl: string;
    keycloakUrl: string;
    keycloakRealm: string;
    keycloakClientId: string;
    environment: string;
    nodeEnv: string;
}

class EnvironmentService {
    private config: EnvConfig | null = null;
    private lastFetch: number = 0;
    private vaultConfig: VaultConfig;

    constructor() {
        this.vaultConfig = {
            vaultUrl: process.env.NEXT_PUBLIC_VAULT_URI || 'http://localhost:8200',
            vaultToken: process.env.VAULT_TOKEN,
            secretPath: process.env.NEXT_PUBLIC_VAULT_SECRET_PATH || 'secret/data/job7189/frontend',
            cacheTTL: 3600, // 1 hour cache
        };
    }

    /**
     * Get config from Vault or environment variables
     */
    async getConfig(): Promise<EnvConfig> {
        // Return cached config if still valid
        if (this.config && (Date.now() - this.lastFetch) < (this.vaultConfig.cacheTTL * 1000)) {
            return this.config;
        }

        try {
            // Try to fetch from Vault first (if available)
            if (this.vaultConfig.vaultToken && typeof window === 'undefined') {
                this.config = await this.fetchFromVault();
                this.lastFetch = Date.now();
                return this.config;
            }
        } catch (error) {
            console.warn('Vault access failed, falling back to environment variables:', error);
        }

        // Fallback to environment variables
        this.config = this.getFromEnv();
        this.lastFetch = Date.now();
        return this.config;
    }

    /**
     * Fetch configuration from HashiCorp Vault
     */
    private async fetchFromVault(): Promise<EnvConfig> {
        const vaultClient = axios.create({
            baseURL: this.vaultConfig.vaultUrl,
            headers: {
                'X-Vault-Token': this.vaultConfig.vaultToken,
            },
        });

        try {
            const response = await vaultClient.get(`/v1/${this.vaultConfig.secretPath}`);
            const secrets = response.data.data.data;

            return {
                apiBaseUrl: secrets.API_BASE_URL || 'http://localhost:8000',
                keycloakUrl: secrets.KEYCLOAK_URL || 'http://localhost:8080',
                keycloakRealm: secrets.KEYCLOAK_REALM || 'job7189',
                keycloakClientId: secrets.KEYCLOAK_CLIENT_ID || 'fe-candidate',
                environment: secrets.ENVIRONMENT || 'development',
                nodeEnv: secrets.NODE_ENV || 'development',
            };
        } catch (error) {
            console.error('Failed to fetch from Vault:', error);
            throw error;
        }
    }

    /**
     * Get configuration from environment variables
     */
    private getFromEnv(): EnvConfig {
        return {
            apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000',
            keycloakUrl: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8080',
            keycloakRealm: process.env.NEXT_PUBLIC_KEYCLOAK_REALM || 'job7189',
            keycloakClientId: process.env.NEXT_PUBLIC_KEYCLOAK_CLIENT_ID || 'fe-candidate',
            environment: process.env.NEXT_PUBLIC_ENV || 'development',
            nodeEnv: process.env.NODE_ENV || 'development',
        };
    }

    /**
     * Validate that all required configs are present
     */
    isConfigValid(config: EnvConfig): boolean {
        return !!(
            config.apiBaseUrl &&
            config.keycloakUrl &&
            config.keycloakRealm &&
            config.keycloakClientId
        );
    }
}

export const envService = new EnvironmentService();
export type { EnvConfig };
