# =============================================================================
# CloudTrail Audit Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for CloudTrail log encryption"
  type        = string
}

variable "logs_kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days (FedRAMP: min 90 days)"
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "FedRAMP requires minimum 90 days log retention."
  }
}

variable "access_log_bucket_id" {
  description = "S3 bucket ID for access logging (optional)"
  type        = string
  default     = ""
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs for security alarms"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
