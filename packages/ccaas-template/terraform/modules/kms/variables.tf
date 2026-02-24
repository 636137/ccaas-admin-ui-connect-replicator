# =============================================================================
# KMS Encryption Module - Variables
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

variable "key_administrators" {
  description = "List of IAM ARNs allowed to administer KMS keys"
  type        = list(string)
  default     = []
}

variable "key_deletion_window" {
  description = "Waiting period before key deletion (7-30 days). FedRAMP recommends 30 days."
  type        = number
  default     = 30

  validation {
    condition     = var.key_deletion_window >= 7 && var.key_deletion_window <= 30
    error_message = "Key deletion window must be between 7 and 30 days."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
