interface ConfigInput {
  // Basic
  projectName: string
  environment: string
  owner: string
  awsRegion: string
  // AI Model
  bedrockModelId: string
  // Connect
  createConnectInstance: boolean
  connectInstanceAlias: string
  // Users
  agentEmails: string[]
  supervisorEmail: string
  // Lex
  lexVoiceId: string
  lexLocale: string
  lexNluConfidenceThreshold: number
  // Lambda
  lambdaRuntime: string
  lambdaTimeout: number
  lambdaMemorySize: number
  // DynamoDB
  dynamodbBillingMode: string
  dynamodbEnableEncryption: boolean
  dynamodbEnablePointInTimeRecovery: boolean
  // VPC
  vpcUseExisting: boolean
  vpcCidr?: string
  vpcId?: string
  vpcSubnetIds?: string[]
  vpcSecurityGroupIds?: string[]
  vpcAvailabilityZones?: string[]
  vpcEnableNatGateway?: boolean
  vpcSingleNatGateway?: boolean
  vpcEnableVpcEndpoints: boolean
  // Security
  enableFedrampCompliance: boolean
  enableWaf: boolean
  enableKmsEncryption: boolean
  kmsKeyArn?: string
  securityContactEmail?: string
  auditLogRetentionDays: number
  deployInVpc: boolean
  kmsKeyAdministrators?: string[]
  securityNotificationArns?: string[]
  // WAF
  wafRateLimit: number
  wafEnableGeoRestriction: boolean
  wafAllowedCountries: string[]
  wafIpWhitelist?: string[]
  // Monitoring
  alarmSnsTopicArn?: string
  enableDetailedMonitoring: boolean
  logRetentionDays: number
  // Backup
  enableBackup: boolean
  enableCrossRegionBackup: boolean
  drVaultArn?: string
  backupAdminRoleArns?: string[]
  // Validation
  enableValidationModule: boolean
  validationNotificationEmail?: string
  aiAccuracyThreshold: number
  aiLatencyThreshold: number
  // Mode
  mode: string
}

export function generateTerraformConfig(input: ConfigInput): string {
  const timestamp = new Date().toISOString()
  
  return `# ============================================
# Government CCaaS in a Box - Terraform Configuration  
# Generated: ${timestamp}
# Mode: ${input.mode.toUpperCase()}
# ============================================

# ============================================
# Basic Configuration
# ============================================
project_name = "${input.projectName}"
environment  = "${input.environment}"
owner        = "${input.owner}"
aws_region   = "${input.awsRegion}"

# ============================================
# Amazon Bedrock (AI Model)
# ============================================
bedrock_model_id = "${input.bedrockModelId}"

# ============================================
# Amazon Connect
# ============================================
create_connect_instance = ${input.createConnectInstance}
connect_instance_alias  = "${input.connectInstanceAlias}"

# ============================================
# Connect Users
# ============================================
agent_emails     = ${JSON.stringify(input.agentEmails, null, 2)}
supervisor_email = "${input.supervisorEmail}"

# ============================================
# Amazon Lex Configuration
# ============================================
lex_voice_id                  = "${input.lexVoiceId}"
lex_locale                    = "${input.lexLocale}"
lex_nlu_confidence_threshold  = ${input.lexNluConfidenceThreshold}

# ============================================
# AWS Lambda Configuration
# ============================================
lambda_runtime     = "${input.lambdaRuntime}"
lambda_timeout     = ${input.lambdaTimeout}
lambda_memory_size = ${input.lambdaMemorySize}

# ============================================
# DynamoDB Configuration
# ============================================
dynamodb_billing_mode                 = "${input.dynamodbBillingMode}"
dynamodb_enable_encryption            = ${input.dynamodbEnableEncryption}
dynamodb_enable_point_in_time_recovery = ${input.dynamodbEnablePointInTimeRecovery}

# ============================================
# VPC Configuration
# ============================================
deploy_in_vpc        = ${input.deployInVpc}
${input.vpcUseExisting ? `# Using existing VPC
vpc_id                = "${input.vpcId || 'REPLACE_WITH_VPC_ID'}"
# vpc_subnet_ids        = ${JSON.stringify(input.vpcSubnetIds || ['subnet-xxx', 'subnet-yyy'])}
# vpc_security_group_ids = ${JSON.stringify(input.vpcSecurityGroupIds || ['sg-xxx'])}
` : `# Creating new VPC
vpc_cidr             = "${input.vpcCidr || '10.0.0.0/16'}"
availability_zones   = ${JSON.stringify(input.vpcAvailabilityZones || ['us-east-1a', 'us-east-1b', 'us-east-1c'])}
enable_nat_gateway   = ${input.vpcEnableNatGateway ?? true}
single_nat_gateway   = ${input.vpcSingleNatGateway ?? false}
`}enable_vpc_endpoints = ${input.vpcEnableVpcEndpoints}

# ============================================
# Security & Encryption
# ============================================
enable_kms_encryption = ${input.enableKmsEncryption}
${input.kmsKeyArn ? `kms_key_arn           = "${input.kmsKeyArn}"` : '# kms_key_arn           = "arn:aws:kms:region:account-id:key/key-id"'}

# ============================================
# FedRAMP Compliance
# ============================================
enable_fedramp_compliance = ${input.enableFedrampCompliance}
${input.enableFedrampCompliance ? `audit_log_retention_days  = ${input.auditLogRetentionDays}
${input.securityContactEmail ? `security_contact_email    = "${input.securityContactEmail}"` : '# security_contact_email    = "security@example.gov"  # REQUIRED: Set your security contact email'}
${input.kmsKeyAdministrators && input.kmsKeyAdministrators.length > 0 ? `kms_key_administrators    = ${JSON.stringify(input.kmsKeyAdministrators, null, 2)}` : '# kms_key_administrators    = ["arn:aws:iam::account-id:role/admin"]'}
${input.securityNotificationArns && input.securityNotificationArns.length > 0 ? `security_notification_arns = ${JSON.stringify(input.securityNotificationArns, null, 2)}` : '# security_notification_arns = ["arn:aws:sns:region:account-id:security-alerts"]'}
` : `# audit_log_retention_days  = ${input.auditLogRetentionDays}
# security_contact_email    = "security@example.gov"
`}
# ============================================
# AWS WAF Configuration
# ============================================
enable_waf = ${input.enableWaf}
${input.enableWaf ? `waf_rate_limit         = ${input.wafRateLimit}
waf_geo_restriction    = ${input.wafEnableGeoRestriction}
waf_allowed_countries  = ${JSON.stringify(input.wafAllowedCountries, null, 2)}
${input.wafIpWhitelist && input.wafIpWhitelist.length > 0 ? `# waf_ip_whitelist       = ${JSON.stringify(input.wafIpWhitelist, null, 2)}` : '# waf_ip_whitelist       = ["1.2.3.4/32"]'}
` : ''}
# ============================================
# Monitoring & Logging
# ============================================
enable_detailed_monitoring = ${input.enableDetailedMonitoring}
log_retention_days         = ${input.logRetentionDays}
${input.alarmSnsTopicArn ? `alarm_sns_topic_arn        = "${input.alarmSnsTopicArn}"` : '# alarm_sns_topic_arn        = "arn:aws:sns:region:account-id:alarms"'}

# ============================================
# Backup & Disaster Recovery
# ============================================
enable_backup               = ${input.enableBackup}
enable_cross_region_backup  = ${input.enableCrossRegionBackup}
${input.enableCrossRegionBackup && input.drVaultArn ? `dr_vault_arn                = "${input.drVaultArn}"` : '# dr_vault_arn                = "arn:aws:backup:dr-region:account-id:backup-vault:vault-name"'}
${input.backupAdminRoleArns && input.backupAdminRoleArns.length > 0 ? `backup_admin_role_arns      = ${JSON.stringify(input.backupAdminRoleArns, null, 2)}` : '# backup_admin_role_arns      = ["arn:aws:iam::account-id:role/backup-admin"]'}

# ============================================
# AI Validation Module
# ============================================
enable_validation_module       = ${input.enableValidationModule}
${input.enableValidationModule 
  ? `validation_notification_email = "${input.validationNotificationEmail}"
ai_accuracy_threshold         = ${input.aiAccuracyThreshold}
ai_latency_threshold          = ${input.aiLatencyThreshold}`
  : `# validation_notification_email = "validation@example.gov"
# ai_accuracy_threshold         = 0.85
# ai_latency_threshold          = 3000`
}

# ============================================
# End of Configuration
# ============================================
`
}

export function generateAgentConfig(input: ConfigInput): object {
  return {
    agentName: `${input.projectName}-census-agent`,
    foundationModel: input.bedrockModelId,
    idleSessionTTLInSeconds: 600,
    description: 'AI Census Agent for Government CCaaS',
  }
}
