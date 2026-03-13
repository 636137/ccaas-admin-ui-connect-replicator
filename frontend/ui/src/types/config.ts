/**
 * Configuration and API response types
 */

export interface ApiError {
  message: string;
  code?: string;
  details?: Record<string, string[]>;
}

export interface ValidationError {
  field: string;
  message: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
}

export interface PrerequisiteCheck {
  terraform: {
    installed: boolean;
    version?: string;
  };
  awsCli: {
    installed: boolean;
    version?: string;
  };
  bedrockAccess?: {
    enabled: boolean;
    models?: string[];
  };
}

export interface GeneratePackageRequest {
  config: Record<string, unknown>;
}

export interface GeneratePackageResponse {
  success: boolean;
  message?: string;
  downloadUrl?: string;
}

export interface DeploymentStatus {
  id: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  message?: string;
  progress?: number;
  createdAt: string;
  completedAt?: string;
}

export interface BedrockModel {
  id: string;
  name: string;
  tier: 'economy' | 'standard' | 'premium' | 'flagship';
  regions: string[];
  govCloudSupport: boolean;
  inputModalities: string[];
}

/**
 * AWS Region metadata
 */
export interface AwsRegion {
  code: string;
  name: string;
  govCloud: boolean;
}

export const AWS_REGIONS: AwsRegion[] = [
  { code: 'us-east-1', name: 'US East (N. Virginia)', govCloud: false },
  { code: 'us-east-2', name: 'US East (Ohio)', govCloud: false },
  { code: 'us-west-1', name: 'US West (N. California)', govCloud: false },
  { code: 'us-west-2', name: 'US West (Oregon)', govCloud: false },
  { code: 'us-gov-west-1', name: 'AWS GovCloud (US-West)', govCloud: true },
  { code: 'us-gov-east-1', name: 'AWS GovCloud (US-East)', govCloud: true },
  { code: 'ca-central-1', name: 'Canada (Central)', govCloud: false },
  { code: 'eu-west-1', name: 'Europe (Ireland)', govCloud: false },
  { code: 'eu-west-2', name: 'Europe (London)', govCloud: false },
  { code: 'eu-central-1', name: 'Europe (Frankfurt)', govCloud: false },
  { code: 'ap-southeast-1', name: 'Asia Pacific (Singapore)', govCloud: false },
  { code: 'ap-southeast-2', name: 'Asia Pacific (Sydney)', govCloud: false },
];

/**
 * Country codes for WAF geo-restriction
 */
export const COUNTRY_CODES = [
  { code: 'US', name: 'United States' },
  { code: 'CA', name: 'Canada' },
  { code: 'GB', name: 'United Kingdom' },
  { code: 'AU', name: 'Australia' },
  { code: 'DE', name: 'Germany' },
  { code: 'FR', name: 'France' },
  { code: 'JP', name: 'Japan' },
  { code: 'SG', name: 'Singapore' },
];
