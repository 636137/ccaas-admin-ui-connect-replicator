# =============================================================================
# AWS Backup Module - Variables
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
  description = "KMS key ARN for backup encryption"
  type        = string
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup copy for disaster recovery"
  type        = bool
  default     = false
}

variable "dr_vault_arn" {
  description = "ARN of backup vault in DR region (create separately in DR region)"
  type        = string
  default     = ""
}

variable "backup_admin_role_arns" {
  description = "IAM role ARNs allowed to manage backup vault"
  type        = list(string)
  default     = []
}

variable "backup_resource_arns" {
  description = "List of resource ARNs to backup"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs to backup"
  type        = list(string)
  default     = []
}

variable "report_bucket_name" {
  description = "S3 bucket name for backup reports"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
