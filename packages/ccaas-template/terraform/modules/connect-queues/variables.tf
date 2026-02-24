# =============================================================================
# Amazon Connect Queues Module - Variables
# =============================================================================

variable "instance_id" {
  description = "Amazon Connect instance ID"
  type        = string
}

variable "census_hours_id" {
  description = "Hours of operation ID for census survey hours"
  type        = string
}

variable "always_open_hours_id" {
  description = "Hours of operation ID for 24/7 availability"
  type        = string
}

variable "outbound_caller_id" {
  description = "Phone number ID for outbound caller ID (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
