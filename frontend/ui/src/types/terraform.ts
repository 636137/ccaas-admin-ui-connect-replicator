/**
 * Terraform variable types matching terraform/variables.tf
 */

export interface TerraformVariables {
  // Basic Configuration
  project_name: string;
  environment: string;
  owner: string;
  aws_region: string;

  // Bedrock Configuration
  bedrock_model_id: string;

  // Connect Configuration
  create_connect_instance: boolean;
  connect_instance_alias: string;

  // Lex Configuration
  lex_voice_id: string;
  lex_locale: string;
  lex_nlu_confidence_threshold: number;

  // Lambda Configuration
  lambda_runtime: string;
  lambda_timeout: number;
  lambda_memory_size: number;

  // DynamoDB Configuration
  dynamodb_billing_mode: string;
  dynamodb_enable_encryption: boolean;
  dynamodb_enable_point_in_time_recovery: boolean;

  // Connect Users
  agent_emails: string[];
  supervisor_email: string;

  // Monitoring Configuration
  alarm_sns_topic_arn?: string;
  enable_detailed_monitoring: boolean;
  log_retention_days: number;

  // Security/KMS Configuration
  enable_kms_encryption: boolean;
  kms_key_arn?: string;

  // VPC Configuration
  deploy_in_vpc: boolean;
  vpc_id?: string;
  vpc_subnet_ids?: string[];
  vpc_security_group_ids?: string[];
  vpc_cidr?: string;
  availability_zones?: string[];
  enable_nat_gateway?: boolean;
  single_nat_gateway?: boolean;
  enable_vpc_endpoints?: boolean;

  // FedRAMP Compliance
  enable_fedramp_compliance: boolean;
  kms_key_administrators?: string[];
  audit_log_retention_days?: number;
  security_notification_arns?: string[];
  security_contact_email?: string;

  // WAF Configuration
  enable_waf: boolean;
  waf_rate_limit?: number;
  waf_geo_restriction?: boolean;
  waf_allowed_countries?: string[];

  // Backup Configuration
  enable_backup: boolean;
  enable_cross_region_backup: boolean;
  dr_vault_arn?: string;
  backup_admin_role_arns?: string[];

  // Validation Module
  enable_validation_module: boolean;
  validation_notification_email?: string;
  ai_accuracy_threshold?: number;
  ai_latency_threshold?: number;
}

export interface TerraformOutputs {
  connect_instance_id?: string;
  connect_instance_arn?: string;
  lambda_function_arn?: string;
  lex_bot_id?: string;
  lex_bot_alias_id?: string;
  dynamodb_table_name?: string;
  kms_key_id?: string;
  vpc_id?: string;
}

export interface GeneratedFiles {
  'terraform.tfvars': string;
  'agent-configuration-bedrock.json': string;
  'agent-configuration-connect.json': string;
  'lex-bot-definition.json': string;
  'README.md': string;
}
