/**
 * Wizard configuration types for the CCaaS deployment wizard
 */

export type Environment = 'dev' | 'staging' | 'prod';
export type WizardMode = 'mvp' | 'comprehensive';
export type BillingMode = 'PAY_PER_REQUEST' | 'PROVISIONED';
export type LambdaRuntime = 'nodejs18.x' | 'nodejs20.x';

export interface BasicConfig {
  projectName: string;
  environment: Environment;
  owner: string;
  awsRegion: string;
}

export interface AIModelConfig {
  bedrockModelId: string;
}

export interface ConnectConfig {
  createConnectInstance: boolean;
  connectInstanceAlias: string;
}

export interface UsersConfig {
  agentEmails: string[];
  supervisorEmail: string;
}

export interface LexConfig {
  voiceId: string;
  locale: string;
  nluConfidenceThreshold: number;
}

export interface LambdaConfig {
  runtime: LambdaRuntime;
  timeout: number;
  memorySize: number;
}

export interface DynamoDBConfig {
  billingMode: BillingMode;
  enableEncryption: boolean;
  enablePointInTimeRecovery: boolean;
}

export interface VPCConfig {
  useExistingVpc: boolean;
  // For new VPC
  vpcCidr?: string;
  availabilityZones?: string[];
  enableNatGateway?: boolean;
  singleNatGateway?: boolean;
  // For existing VPC
  vpcId?: string;
  subnetIds?: string[];
  securityGroupIds?: string[];
  // VPC endpoints
  enableVpcEndpoints: boolean;
}

export interface SecurityConfig {
  enableFedRampCompliance: boolean;
  enableWaf: boolean;
  enableKmsEncryption: boolean;
  kmsKeyArn?: string;
  securityContactEmail?: string;
  auditLogRetentionDays: number;
  deployInVpc: boolean;
  kmsKeyAdministrators?: string[];
  securityNotificationArns?: string[];
}

export interface WafConfig {
  rateLimit: number;
  enableGeoRestriction: boolean;
  allowedCountries: string[];
  ipWhitelist?: string[];
}

export interface MonitoringConfig {
  alarmSnsTopicArn?: string;
  enableDetailedMonitoring: boolean;
  logRetentionDays: number;
}

export interface BackupConfig {
  enableBackup: boolean;
  enableCrossRegionBackup: boolean;
  drVaultArn?: string;
  backupAdminRoleArns?: string[];
}

export interface ValidationConfig {
  enableValidationModule: boolean;
  validationNotificationEmail?: string;
  aiAccuracyThreshold: number;
  aiLatencyThreshold: number;
}

/**
 * Complete wizard configuration
 */
export interface WizardConfig {
  mode: WizardMode;
  basic: BasicConfig;
  aiModel: AIModelConfig;
  connect: ConnectConfig;
  users: UsersConfig;
  lex: LexConfig;
  lambda: LambdaConfig;
  dynamodb: DynamoDBConfig;
  vpc: VPCConfig;
  security: SecurityConfig;
  waf: WafConfig;
  monitoring: MonitoringConfig;
  backup: BackupConfig;
  validation: ValidationConfig;
}

/**
 * Wizard step metadata
 */
export interface WizardStep {
  id: string;
  title: string;
  description: string;
  showInMvp: boolean;
  component: React.ComponentType<WizardStepProps>;
}

export interface WizardStepProps {
  config: WizardConfig;
  onChange: (updates: Partial<WizardConfig>) => void;
  onNext: () => void;
  onPrevious: () => void;
  mode: WizardMode;
}
