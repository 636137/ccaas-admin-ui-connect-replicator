# =============================================================================
# VPC Module - Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

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
  description = "Use a single NAT Gateway (cost savings) vs one per AZ (high availability)"
  type        = bool
  default     = false  # FedRAMP recommends HA setup
}

variable "enable_interface_endpoints" {
  description = "Enable VPC interface endpoints (PrivateLink) for AWS services"
  type        = bool
  default     = true
}

variable "logs_kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption"
  type        = string
  default     = ""
}

variable "flow_log_retention_days" {
  description = "VPC Flow Log retention period in days"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
