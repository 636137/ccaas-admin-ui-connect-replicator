# IAM Module - Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs"
  type        = list(string)
}

variable "lex_bot_arn" {
  description = "Lex bot ARN"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
