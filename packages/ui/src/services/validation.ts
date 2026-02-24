/**
 * Validation schemas and functions using Zod
 */

import { z } from 'zod';
import type { WizardConfig } from '../types';

/**
 * Basic Info validation schema
 */
export const basicInfoSchema = z.object({
  projectName: z
    .string()
    .min(3, 'Project name must be at least 3 characters')
    .max(64, 'Project name must be at most 64 characters')
    .regex(
      /^[a-z0-9][a-z0-9-]*[a-z0-9]$/,
      'Project name must be lowercase alphanumeric with hyphens, cannot start or end with hyphen'
    ),
  environment: z.enum(['dev', 'staging', 'prod'], {
    errorMap: () => ({ message: 'Environment must be dev, staging, or prod' }),
  }),
  owner: z.string().email('Owner must be a valid email address'),
  awsRegion: z.string().min(1, 'AWS region is required'),
});

/**
 * AI Model validation schema
 */
export const aiModelSchema = z.object({
  bedrockModelId: z.string().min(1, 'Bedrock model ID is required'),
});

/**
 * Connect validation schema
 */
export const connectSchema = z.object({
  createConnectInstance: z.boolean(),
  connectInstanceAlias: z
    .string()
    .min(1, 'Connect instance alias is required')
    .max(64, 'Instance alias must be at most 64 characters')
    .regex(
      /^[a-z0-9][a-z0-9-]*[a-z0-9]$/,
      'Instance alias must be lowercase alphanumeric with hyphens'
    ),
});

/**
 * Users validation schema
 */
export const usersSchema = z.object({
  agentEmails: z
    .array(z.string().email('Each agent email must be valid'))
    .min(1, 'At least one agent email is required')
    .max(10, 'Maximum 10 agent emails allowed'),
  supervisorEmail: z.string().email('Supervisor email must be valid'),
});

/**
 * Lex validation schema
 */
export const lexSchema = z.object({
  voiceId: z.string().min(1, 'Voice ID is required'),
  locale: z.string().min(1, 'Locale is required'),
  nluConfidenceThreshold: z
    .number()
    .min(0, 'NLU threshold must be at least 0')
    .max(1, 'NLU threshold must be at most 1'),
});

/**
 * Lambda validation schema
 */
export const lambdaSchema = z.object({
  runtime: z.enum(['nodejs18.x', 'nodejs20.x']),
  timeout: z
    .number()
    .int('Timeout must be an integer')
    .min(1, 'Timeout must be at least 1 second')
    .max(900, 'Timeout must be at most 900 seconds'),
  memorySize: z
    .number()
    .int('Memory size must be an integer')
    .min(128, 'Memory size must be at least 128 MB')
    .max(10240, 'Memory size must be at most 10240 MB')
    .refine((val) => val % 64 === 0, 'Memory size must be a multiple of 64'),
});

/**
 * DynamoDB validation schema
 */
export const dynamodbSchema = z.object({
  billingMode: z.enum(['PAY_PER_REQUEST', 'PROVISIONED']),
  enableEncryption: z.boolean(),
  enablePointInTimeRecovery: z.boolean(),
});

/**
 * VPC validation schema
 */
export const vpcSchema = z.object({
  useExistingVpc: z.boolean(),
  vpcCidr: z
    .string()
    .regex(
      /^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$/,
      'VPC CIDR must be valid (e.g., 10.0.0.0/16)'
    )
    .optional(),
  availabilityZones: z.array(z.string()).min(2, 'At least 2 AZs required').optional(),
  enableNatGateway: z.boolean().optional(),
  singleNatGateway: z.boolean().optional(),
  vpcId: z.string().optional(),
  subnetIds: z.array(z.string()).optional(),
  securityGroupIds: z.array(z.string()).optional(),
  enableVpcEndpoints: z.boolean(),
});

/**
 * Security validation schema with FedRAMP conditional requirements
 */
export const securitySchema = z
  .object({
    enableFedRampCompliance: z.boolean(),
    enableWaf: z.boolean(),
    enableKmsEncryption: z.boolean(),
    kmsKeyArn: z.string().optional(),
    securityContactEmail: z.string().email().optional(),
    auditLogRetentionDays: z.number().int().min(1, 'Log retention must be at least 1 day'),
    deployInVpc: z.boolean(),
    kmsKeyAdministrators: z.array(z.string()).optional(),
    securityNotificationArns: z.array(z.string()).optional(),
  })
  .refine(
    (data) => {
      // If FedRAMP is enabled, security contact email is required
      if (data.enableFedRampCompliance && !data.securityContactEmail) {
        return false;
      }
      return true;
    },
    {
      message: 'Security contact email is required when FedRAMP compliance is enabled',
      path: ['securityContactEmail'],
    }
  )
  .refine(
    (data) => {
      // If FedRAMP is enabled, audit log retention must be at least 90 days
      if (data.enableFedRampCompliance && data.auditLogRetentionDays < 90) {
        return false;
      }
      return true;
    },
    {
      message: 'Audit log retention must be at least 90 days for FedRAMP compliance',
      path: ['auditLogRetentionDays'],
    }
  );

/**
 * WAF validation schema
 */
export const wafSchema = z.object({
  rateLimit: z.number().int().min(100, 'Rate limit must be at least 100'),
  enableGeoRestriction: z.boolean(),
  allowedCountries: z.array(z.string()).min(1, 'At least one country must be allowed'),
  ipWhitelist: z.array(z.string()).optional(),
});

/**
 * Monitoring validation schema
 */
export const monitoringSchema = z.object({
  alarmSnsTopicArn: z.string().optional(),
  enableDetailedMonitoring: z.boolean(),
  logRetentionDays: z.number().int().min(1, 'Log retention must be at least 1 day'),
});

/**
 * Backup validation schema
 */
export const backupSchema = z.object({
  enableBackup: z.boolean(),
  enableCrossRegionBackup: z.boolean(),
  drVaultArn: z.string().optional(),
  backupAdminRoleArns: z.array(z.string()).optional(),
});

/**
 * Validation module schema
 */
export const validationSchema = z.object({
  enableValidationModule: z.boolean(),
  validationNotificationEmail: z.string().email().optional(),
  aiAccuracyThreshold: z
    .number()
    .min(0, 'Accuracy threshold must be at least 0')
    .max(1, 'Accuracy threshold must be at most 1'),
  aiLatencyThreshold: z.number().int().min(0, 'Latency threshold must be at least 0'),
});

/**
 * Complete wizard configuration schema
 */
export const wizardConfigSchema = z.object({
  mode: z.enum(['mvp', 'comprehensive']),
  basic: basicInfoSchema,
  aiModel: aiModelSchema,
  connect: connectSchema,
  users: usersSchema,
  lex: lexSchema,
  lambda: lambdaSchema,
  dynamodb: dynamodbSchema,
  vpc: vpcSchema,
  security: securitySchema,
  waf: wafSchema,
  monitoring: monitoringSchema,
  backup: backupSchema,
  validation: validationSchema,
});

/**
 * Validate wizard configuration
 */
export function validateWizardConfig(config: WizardConfig) {
  const result = wizardConfigSchema.safeParse(config);
  
  if (!result.success) {
    const errors = result.error.issues.map((issue) => ({
      field: issue.path.join('.'),
      message: issue.message,
    }));
    return { valid: false, errors };
  }
  
  return { valid: true, errors: [] };
}

/**
 * Validate individual wizard section
 */
export function validateSection(
  section: keyof Omit<WizardConfig, 'mode'>,
  data: unknown
) {
  const schemas = {
    basic: basicInfoSchema,
    aiModel: aiModelSchema,
    connect: connectSchema,
    users: usersSchema,
    lex: lexSchema,
    lambda: lambdaSchema,
    dynamodb: dynamodbSchema,
    vpc: vpcSchema,
    security: securitySchema,
    waf: wafSchema,
    monitoring: monitoringSchema,
    backup: backupSchema,
    validation: validationSchema,
  };
  
  const schema = schemas[section];
  if (!schema) {
    return { valid: false, errors: [{ field: section, message: 'Invalid section' }] };
  }
  
  const result = schema.safeParse(data);
  
  if (!result.success) {
    const errors = result.error.issues.map((issue) => ({
      field: `${section}.${issue.path.join('.')}`,
      message: issue.message,
    }));
    return { valid: false, errors };
  }
  
  return { valid: true, errors: [] };
}

/**
 * Get default wizard configuration
 */
export function getDefaultWizardConfig(): WizardConfig {
  return {
    mode: 'mvp',
    basic: {
      projectName: '',
      environment: 'dev',
      owner: '',
      awsRegion: 'us-east-1',
    },
    aiModel: {
      bedrockModelId: '',
    },
    connect: {
      createConnectInstance: true,
      connectInstanceAlias: '',
    },
    users: {
      agentEmails: [''],
      supervisorEmail: '',
    },
    lex: {
      voiceId: 'Ruth',
      locale: 'en_US',
      nluConfidenceThreshold: 0.4,
    },
    lambda: {
      runtime: 'nodejs18.x',
      timeout: 30,
      memorySize: 256,
    },
    dynamodb: {
      billingMode: 'PAY_PER_REQUEST',
      enableEncryption: true,
      enablePointInTimeRecovery: true,
    },
    vpc: {
      useExistingVpc: false,
      vpcCidr: '10.0.0.0/16',
      availabilityZones: [],
      enableNatGateway: true,
      singleNatGateway: false,
      enableVpcEndpoints: true,
    },
    security: {
      enableFedRampCompliance: false,
      enableWaf: true,
      enableKmsEncryption: true,
      auditLogRetentionDays: 90,
      deployInVpc: true,
    },
    waf: {
      rateLimit: 2000,
      enableGeoRestriction: true,
      allowedCountries: ['US'],
    },
    monitoring: {
      enableDetailedMonitoring: false,
      logRetentionDays: 90,
    },
    backup: {
      enableBackup: true,
      enableCrossRegionBackup: false,
    },
    validation: {
      enableValidationModule: false,
      aiAccuracyThreshold: 0.85,
      aiLatencyThreshold: 3000,
    },
  };
}
