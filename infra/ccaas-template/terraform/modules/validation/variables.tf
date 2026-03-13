# Validation Module - Variables
#
# WHAT: Input variables for the Government CCaaS validation module.
#
# WHY: Configurable testing parameters allow different test intensities
#      for different environments (dev vs. production).

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# CONNECT CONFIGURATION
# ============================================================================

variable "connect_instance_id" {
  description = "Amazon Connect instance ID to test"
  type        = string
}

variable "connect_instance_arn" {
  description = "Amazon Connect instance ARN"
  type        = string
}

variable "contact_flow_ids" {
  description = "Map of contact flow names to IDs for testing"
  type        = map(string)
  default     = {}
}

variable "queue_ids" {
  description = "Map of queue names to IDs for validation"
  type        = map(string)
  default     = {}
}

variable "phone_numbers" {
  description = "Phone numbers associated with the Connect instance"
  type        = list(string)
  default     = []
}

# ============================================================================
# LEX CONFIGURATION
# ============================================================================

variable "lex_bot_id" {
  description = "Lex V2 Bot ID"
  type        = string
}

variable "lex_bot_alias_id" {
  description = "Lex V2 Bot Alias ID"
  type        = string
}

variable "lex_bot_locale" {
  description = "Lex bot locale"
  type        = string
  default     = "en_US"
}

# ============================================================================
# BEDROCK CONFIGURATION
# ============================================================================

variable "bedrock_agent_id" {
  description = "Bedrock Agent ID (optional)"
  type        = string
  default     = ""
}

variable "bedrock_agent_alias_id" {
  description = "Bedrock Agent Alias ID (optional)"
  type        = string
  default     = ""
}

variable "bedrock_guardrail_id" {
  description = "Bedrock Guardrail ID for testing"
  type        = string
  default     = ""
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for direct testing"
  type        = string
  default     = "anthropic.claude-sonnet-4-5-20250929-v1:0"
}

# ============================================================================
# LAMBDA CONFIGURATION
# ============================================================================

variable "lambda_function_arns" {
  description = "Map of Lambda function names to ARNs for mocking/testing"
  type        = map(string)
  default     = {}
}

# ============================================================================
# DYNAMODB CONFIGURATION
# ============================================================================

variable "dynamodb_table_names" {
  description = "DynamoDB table names to validate"
  type        = list(string)
  default     = []
}

# ============================================================================
# TEST SCHEDULE CONFIGURATION
# ============================================================================

variable "enable_scheduled_tests" {
  description = "Enable scheduled automated testing"
  type        = bool
  default     = true
}

variable "functional_test_schedule" {
  description = "Cron expression for functional tests (default: daily at 6 AM UTC)"
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "load_test_schedule" {
  description = "Cron expression for load tests (default: weekly Sunday 2 AM UTC)"
  type        = string
  default     = "cron(0 2 ? * SUN *)"
}

variable "security_scan_schedule" {
  description = "Cron expression for security scans (default: daily at 3 AM UTC)"
  type        = string
  default     = "cron(0 3 * * ? *)"
}

# ============================================================================
# LOAD TESTING CONFIGURATION
# ============================================================================

variable "load_test_vpc_id" {
  description = "VPC ID for load testing containers (optional)"
  type        = string
  default     = ""
}

variable "load_test_subnet_ids" {
  description = "Subnet IDs for load testing containers (optional)"
  type        = list(string)
  default     = []
}

variable "baseline_concurrent_users" {
  description = "Number of concurrent users for baseline load test"
  type        = number
  default     = 10
}

variable "peak_concurrent_users" {
  description = "Number of concurrent users for peak load test"
  type        = number
  default     = 100
}

variable "stress_concurrent_users" {
  description = "Number of concurrent users for stress test"
  type        = number
  default     = 500
}

variable "load_test_duration_seconds" {
  description = "Duration of each load test in seconds"
  type        = number
  default     = 300
}

# ============================================================================
# NOTIFICATION CONFIGURATION
# ============================================================================

variable "alert_sns_topic_arn" {
  description = "SNS topic ARN for test failure alerts"
  type        = string
  default     = ""
}

variable "alert_email_addresses" {
  description = "Email addresses for test failure notifications"
  type        = list(string)
  default     = []
}

# ============================================================================
# REPORT CONFIGURATION
# ============================================================================

variable "report_bucket_name" {
  description = "S3 bucket name for storing validation reports (created if not provided)"
  type        = string
  default     = ""
}

variable "report_retention_days" {
  description = "Number of days to retain validation reports"
  type        = number
  default     = 90
}

# ============================================================================
# FEDRAMP COMPLIANCE
# ============================================================================

variable "enable_fedramp_validation" {
  description = "Enable FedRAMP-specific compliance validation"
  type        = bool
  default     = true
}

variable "fedramp_level" {
  description = "FedRAMP authorization level (low, moderate, high)"
  type        = string
  default     = "moderate"
  validation {
    condition     = contains(["low", "moderate", "high"], var.fedramp_level)
    error_message = "FedRAMP level must be: low, moderate, or high."
  }
}

# ============================================================================
# AI VALIDATION CONFIGURATION
# ============================================================================

variable "ai_accuracy_threshold" {
  description = "Minimum acceptable AI intent recognition accuracy (0.0-1.0)"
  type        = number
  default     = 0.85
}

variable "ai_latency_threshold_ms" {
  description = "Maximum acceptable AI response latency in milliseconds"
  type        = number
  default     = 3000
}

variable "enable_pii_guardrail_tests" {
  description = "Enable PII blocking guardrail tests"
  type        = bool
  default     = true
}
