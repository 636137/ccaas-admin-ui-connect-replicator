# Lex Module - Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "lex_service_role_arn" {
  description = "ARN of the Lex service role"
  type        = string
}

variable "fulfillment_lambda_arn" {
  description = "ARN of the fulfillment Lambda function"
  type        = string
}

variable "bedrock_model_arn" {
  description = "ARN of the Bedrock model for generative AI"
  type        = string
}

variable "voice_id" {
  description = "Amazon Polly voice ID"
  type        = string
  default     = "Ruth"
}

variable "nlu_confidence_threshold" {
  description = "NLU confidence threshold"
  type        = number
  default     = 0.40
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
