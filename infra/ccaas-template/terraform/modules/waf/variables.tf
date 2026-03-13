# =============================================================================
# WAF Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "scope" {
  description = "WAF scope: REGIONAL or CLOUDFRONT"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

variable "enable_geo_restriction" {
  description = "Enable geographic restriction (US-only)"
  type        = bool
  default     = true
}

variable "allowed_countries" {
  description = "List of allowed country codes when geo restriction is enabled"
  type        = list(string)
  default     = ["US"]
}

variable "expected_host_header" {
  description = "Expected host header value for request validation"
  type        = string
  default     = ".amazonaws.com"
}

variable "blocked_ip_addresses" {
  description = "List of IP addresses to block (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "allowed_ip_addresses" {
  description = "List of trusted IP addresses (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "WAF log retention period in days"
  type        = number
  default     = 365
}

variable "logs_kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
  default     = ""
}

variable "block_alarm_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 1000
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs for alarms"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
