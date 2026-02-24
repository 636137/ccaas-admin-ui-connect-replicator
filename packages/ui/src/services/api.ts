/**
 * API client for communicating with the backend
 */

import type {
  WizardConfig,
  ValidationResult,
  PrerequisiteCheck,
  ApiError,
} from '../types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

/**
 * Custom error class for API errors
 */
export class ApiClientError extends Error {
  constructor(
    message: string,
    public code?: string,
    public details?: Record<string, string[]>
  ) {
    super(message);
    this.name = 'ApiClientError';
  }
}

/**
 * API client class
 */
export class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  /**
   * Make a request to the API
   */
  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      let errorData: ApiError | undefined;
      try {
        errorData = await response.json();
      } catch {
        // If response is not JSON, use status text
      }

      throw new ApiClientError(
        errorData?.message || response.statusText,
        errorData?.code,
        errorData?.details
      );
    }

    // Handle blob responses (for file downloads)
    if (response.headers.get('content-type')?.includes('application/zip')) {
      return response.blob() as T;
    }

    return response.json();
  }

  /**
   * Check API health
   */
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    return this.request('/api/health');
  }

  /**
   * Validate wizard configuration
   */
  async validateConfig(config: WizardConfig): Promise<ValidationResult> {
    return this.request('/api/config/validate', {
      method: 'POST',
      body: JSON.stringify(config),
    });
  }

  /**
   * Generate deployment package (zip file)
   */
  async generatePackage(config: WizardConfig): Promise<Blob> {
    return this.request<Blob>('/api/package/generate', {
      method: 'POST',
      body: JSON.stringify({ config }),
    });
  }

  /**
   * Download generated package
   */
  async downloadPackage(config: WizardConfig, filename: string = 'ccaas-deployment.zip'): Promise<void> {
    try {
      const blob = await this.generatePackage(config);
      
      // Create download link
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      
      // Cleanup
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      if (error instanceof ApiClientError) {
        throw error;
      }
      throw new ApiClientError('Failed to download package');
    }
  }

  /**
   * Check prerequisites (AWS CLI, Terraform)
   */
  async checkPrerequisites(): Promise<PrerequisiteCheck> {
    return this.request('/api/prerequisites/check');
  }

  /**
   * Get available Bedrock models
   */
  async getBedrockModels() {
    return this.request('/api/config/models');
  }
}

/**
 * Default API client instance
 */
export const apiClient = new ApiClient();

/**
 * React hook for API errors
 */
export function useApiError() {
  const formatError = (error: unknown): string => {
    if (error instanceof ApiClientError) {
      if (error.details) {
        const detailMessages = Object.entries(error.details)
          .map(([field, messages]) => `${field}: ${messages.join(', ')}`)
          .join('\n');
        return `${error.message}\n${detailMessages}`;
      }
      return error.message;
    }
    
    if (error instanceof Error) {
      return error.message;
    }
    
    return 'An unknown error occurred';
  };

  return { formatError };
}
