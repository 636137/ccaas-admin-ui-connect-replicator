# Census Enumerator AI Agent - Variables

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "census-enumerator"
}

variable "owner" {
  description = "Owner tag for resources"
  type        = string
  default     = "census-bureau"
}

# Bedrock Configuration
variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID for AI agent"
  type        = string
  default     = "anthropic.claude-sonnet-4-5-20250929-v1:0"

  validation {
    condition = contains([
      "anthropic.claude-3-haiku-20240307-v1:0",
      "anthropic.claude-3-5-haiku-20241022-v1:0",
      "anthropic.claude-haiku-4-5-20251001-v1:0",
      "anthropic.claude-sonnet-4-20250514-v1:0",
      "anthropic.claude-sonnet-4-5-20250929-v1:0",
      "anthropic.claude-sonnet-4-6",
      "anthropic.claude-opus-4-1-20250805-v1:0",
      "anthropic.claude-opus-4-5-20251101-v1:0",
      "anthropic.claude-opus-4-6-v1"
    ], var.bedrock_model_id)
    error_message = "Invalid Bedrock model ID. Must be a supported Claude model."
  }
}

# Lex Configuration
variable "lex_voice_id" {
  description = "Amazon Polly voice ID for Lex bot"
  type        = string
  default     = "Ruth"
}

variable "lex_locale" {
  description = "Locale for Lex bot"
  type        = string
  default     = "en_US"
}

variable "lex_nlu_confidence_threshold" {
  description = "NLU confidence threshold for intent matching"
  type        = number
  default     = 0.40
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_enable_encryption" {
  description = "Enable server-side encryption for DynamoDB tables"
  type        = bool
  default     = true
}

variable "dynamodb_enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

# Amazon Connect Configuration
variable "create_connect_instance" {
  description = "Whether to create a new Amazon Connect instance (set to false to use existing)"
  type        = bool
  default     = true
}

variable "connect_instance_id" {
  description = "Existing Amazon Connect instance ID (required if create_connect_instance is false)"
  type        = string
  default     = ""
}

variable "connect_instance_alias" {
  description = "Unique alias for the Amazon Connect instance (lowercase, alphanumeric, hyphens only)"
  type        = string
  default     = "census-enumerator"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.connect_instance_alias))
    error_message = "Instance alias must be lowercase alphanumeric with hyphens, cannot start/end with hyphen."
  }
}

variable "connect_contact_flow_name" {
  description = "Name for the Census Enumerator contact flow"
  type        = string
  default     = "CensusEnumeratorFlow"
}

# Connect Users Configuration
variable "agent_emails" {
  description = "List of email addresses for test agent users"
  type        = list(string)
  default     = [
    "census.agent1@example.com",
    "census.agent2@example.com",
    "census.agent3@example.com",
    "census.agent4@example.com",
    "census.agent5@example.com"
  ]
}

variable "supervisor_email" {
  description = "Email address for the supervisor user"
  type        = string
  default     = "census.supervisor@example.com"
}

# Monitoring Configuration
variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

# Security Configuration
variable "enable_kms_encryption" {
  description = "Enable KMS encryption for sensitive data"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN (leave empty to create new key)"
  type        = string
  default     = ""
}

# VPC Configuration (optional)
variable "vpc_id" {
  description = "VPC ID for Lambda deployment (optional)"
  type        = string
  default     = ""
}

variable "vpc_subnet_ids" {
  description = "Subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}
# =============================================================================
# FedRAMP Compliance Configuration
# =============================================================================

variable "enable_fedramp_compliance" {
  description = "Enable FedRAMP compliance modules (KMS, CloudTrail, VPC, WAF, Config, Backup)"
  type        = bool
  default     = true
}

variable "deploy_in_vpc" {
  description = "Deploy Lambda functions and resources in VPC for network isolation"
  type        = bool
  default     = true
}

variable "kms_key_administrators" {
  description = "List of IAM ARNs allowed to administer KMS keys"
  type        = list(string)
  default     = []
}

variable "audit_log_retention_days" {
  description = "Retention period for audit logs in days (FedRAMP minimum: 90)"
  type        = number
  default     = 365

  validation {
    condition     = var.audit_log_retention_days >= 90
    error_message = "FedRAMP requires minimum 90 days audit log retention."
  }
}

variable "security_notification_arns" {
  description = "List of SNS topic ARNs for security notifications"
  type        = list(string)
  default     = []
}

variable "security_contact_email" {
  description = "Email address for security alerts (FedRAMP IR-4)"
  type        = string
  default     = ""
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for outbound internet access from private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost savings) vs one per AZ (high availability)"
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC interface endpoints (PrivateLink) for AWS services"
  type        = bool
  default     = true
}

# WAF Configuration
variable "enable_waf" {
  description = "Enable WAF web application firewall"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit threshold (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

variable "waf_geo_restriction" {
  description = "Enable geographic restriction (US-only)"
  type        = bool
  default     = true
}

variable "waf_allowed_countries" {
  description = "List of allowed country codes when geo restriction is enabled"
  type        = list(string)
  default     = ["US"]
}

# Backup/DR Configuration
variable "enable_backup" {
  description = "Enable AWS Backup for disaster recovery"
  type        = bool
  default     = true
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup copy for disaster recovery"
  type        = bool
  default     = false
}

variable "dr_vault_arn" {
  description = "ARN of backup vault in DR region (create separately if needed)"
  type        = string
  default     = ""
}

variable "backup_admin_role_arns" {
  description = "IAM role ARNs allowed to manage backup vault"
  type        = list(string)
  default     = []
}

# =============================================================================
# VALIDATION MODULE CONFIGURATION
# =============================================================================

variable "enable_validation_module" {
  description = "Enable the validation module for automated testing"
  type        = bool
  default     = false
}

variable "validation_notification_email" {
  description = "Email address for validation failure notifications"
  type        = string
  default     = ""
}

variable "ai_accuracy_threshold" {
  description = "Minimum AI intent recognition accuracy (0-1)"
  type        = number
  default     = 0.85
}

variable "ai_latency_threshold" {
  description = "Maximum AI response latency in milliseconds"
  type        = number
  default     = 3000
}