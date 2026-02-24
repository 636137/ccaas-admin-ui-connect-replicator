# =============================================================================
# Contact Lens Rules Module - Variables
# =============================================================================

variable "instance_id" {
  description = "Amazon Connect instance ID"
  type        = string
}

variable "alert_contact_flow_id" {
  description = "Contact flow ID for supervisor alert tasks"
  type        = string
  default     = null
}

variable "supervisor_user_ids" {
  description = "List of supervisor user IDs for notifications"
  type        = list(string)
  default     = []
}

variable "notification_email" {
  description = "Email address for rule notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
