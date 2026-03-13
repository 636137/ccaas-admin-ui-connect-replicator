# =============================================================================
# Amazon Connect Instance Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "name_suffix" {
  description = "Suffix for unique resource names"
  type        = string
}

variable "instance_alias" {
  description = "Alias for the Connect instance (must be unique across AWS)"
  type        = string
}

variable "identity_management_type" {
  description = "Identity management type: SAML, CONNECT_MANAGED, or EXISTING_DIRECTORY"
  type        = string
  default     = "CONNECT_MANAGED"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (leave empty to use AWS managed key)"
  type        = string
  default     = ""
}

variable "supervisor_phone_number" {
  description = "Phone number for supervisor quick connect (E.164 format)"
  type        = string
  default     = "+18005551234"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
