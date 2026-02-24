# =============================================================================
# Amazon Connect Users Module - Variables
# =============================================================================

variable "instance_id" {
  description = "Amazon Connect instance ID"
  type        = string
}

variable "agent_routing_profile_id" {
  description = "Routing profile ID for agents"
  type        = string
}

variable "supervisor_routing_profile_id" {
  description = "Routing profile ID for supervisors"
  type        = string
}

variable "agent_emails" {
  description = "List of email addresses for test agents (5 required)"
  type        = list(string)
  default = [
    "census.agent1@example.com",
    "census.agent2@example.com",
    "census.agent3@example.com",
    "census.agent4@example.com",
    "census.agent5@example.com"
  ]

  validation {
    condition     = length(var.agent_emails) >= 5
    error_message = "At least 5 agent email addresses are required."
  }
}

variable "supervisor_email" {
  description = "Email address for test supervisor"
  type        = string
  default     = "census.supervisor@example.com"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
