# Census Enumerator AI Agent - Outputs

output "lex_bot_id" {
  description = "Amazon Lex bot ID"
  value       = module.lex.bot_id
}

output "lex_bot_arn" {
  description = "Amazon Lex bot ARN"
  value       = module.lex.bot_arn
}

output "lex_bot_alias_id" {
  description = "Amazon Lex bot alias ID"
  value       = module.lex.bot_alias_id
}

output "lex_bot_alias_arn" {
  description = "Amazon Lex bot alias ARN"
  value       = module.lex.bot_alias_arn
}

output "lambda_fulfillment_arn" {
  description = "Lambda fulfillment function ARN"
  value       = module.lambda.fulfillment_lambda_arn
}

output "lambda_backend_arn" {
  description = "Lambda backend function ARN"
  value       = module.lambda.backend_lambda_arn
}

output "dynamodb_census_responses_table" {
  description = "DynamoDB Census Responses table name"
  value       = module.dynamodb.census_responses_table_name
}

output "dynamodb_census_addresses_table" {
  description = "DynamoDB Census Addresses table name"
  value       = module.dynamodb.census_addresses_table_name
}

output "bedrock_guardrail_id" {
  description = "Bedrock guardrail ID"
  value       = module.bedrock.guardrail_id
}

output "bedrock_guardrail_arn" {
  description = "Bedrock guardrail ARN"
  value       = module.bedrock.guardrail_arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = module.iam.lambda_execution_role_arn
}

output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

# Amazon Connect integration outputs (when using existing instance)
output "connect_integration_instructions" {
  description = "Instructions for integrating with Amazon Connect"
  value       = <<-EOT
    To integrate with Amazon Connect:
    
    1. Associate the Lex bot with your Connect instance:
       aws connect associate-lex-bot \
         --instance-id ${var.connect_instance_id != "" ? var.connect_instance_id : "<YOUR_CONNECT_INSTANCE_ID>"} \
         --lex-bot Name=${module.lex.bot_name},LexRegion=${var.aws_region}
    
    2. Import the contact flow:
       Use the contact-flow.json file and update with:
       - Lex Bot ARN: ${module.lex.bot_alias_arn}
       - Lambda ARN: ${module.lambda.backend_lambda_arn}
    
    3. Associate a phone number with the contact flow
    
    4. Configure chat widget with your instance ID
  EOT
}
# =============================================================================
# Amazon Connect Instance Outputs (when create_connect_instance = true)
# =============================================================================

output "connect_instance_id" {
  description = "Amazon Connect instance ID"
  value       = var.create_connect_instance ? module.connect[0].instance_id : var.connect_instance_id
}

output "connect_instance_arn" {
  description = "Amazon Connect instance ARN"
  value       = var.create_connect_instance ? module.connect[0].instance_arn : null
}

output "connect_access_url" {
  description = "URL to access the Amazon Connect CCP"
  value       = var.create_connect_instance ? module.connect[0].access_url : null
}

output "connect_storage_bucket" {
  description = "S3 bucket for Connect recordings and transcripts"
  value       = var.create_connect_instance ? module.connect[0].storage_bucket_name : null
}

# =============================================================================
# Amazon Connect Queues and Routing Outputs
# =============================================================================

output "connect_queue_ids" {
  description = "Map of queue names to queue IDs"
  value       = var.create_connect_instance ? module.connect_queues[0].queue_ids : {}
}

output "connect_routing_profile_ids" {
  description = "Map of routing profile names to IDs"
  value       = var.create_connect_instance ? module.connect_queues[0].routing_profile_ids : {}
}

# =============================================================================
# Amazon Connect Users Outputs
# =============================================================================

output "connect_agent_user_ids" {
  description = "Map of agent emails to user IDs"
  value       = var.create_connect_instance ? module.connect_users[0].agent_user_ids : {}
}

output "connect_supervisor_user_id" {
  description = "Supervisor user ID"
  value       = var.create_connect_instance ? module.connect_users[0].supervisor_user_id : null
}

output "connect_security_profile_ids" {
  description = "Map of security profile names to IDs"
  value       = var.create_connect_instance ? module.connect_users[0].security_profile_ids : {}
}

# =============================================================================
# Contact Lens Outputs
# =============================================================================

output "contact_lens_real_time_rule_ids" {
  description = "IDs of real-time Contact Lens rules"
  value       = var.create_connect_instance ? module.contact_lens[0].real_time_rule_ids : {}
}

output "contact_lens_post_call_rule_ids" {
  description = "IDs of post-call Contact Lens rules"
  value       = var.create_connect_instance ? module.contact_lens[0].post_call_rule_ids : {}
}

output "contact_lens_vocabulary_id" {
  description = "Census custom vocabulary ID for speech recognition"
  value       = var.create_connect_instance ? module.contact_lens[0].vocabulary_id : null
}

# =============================================================================
# Validation Module Outputs
# =============================================================================

output "validation_state_machine_arn" {
  description = "ARN of the validation Step Functions state machine"
  value       = var.enable_validation_module ? module.validation[0].state_machine_arn : null
}

output "validation_orchestrator_function_name" {
  description = "Name of the validation orchestrator Lambda function"
  value       = var.enable_validation_module ? module.validation[0].orchestrator_function_name : null
}

output "validation_ai_validator_function_name" {
  description = "Name of the AI validator Lambda function"
  value       = var.enable_validation_module ? module.validation[0].ai_validator_function_name : null
}

output "validation_report_bucket" {
  description = "S3 bucket name for validation reports"
  value       = var.enable_validation_module ? module.validation[0].report_bucket_name : null
}

output "validation_dashboard_url" {
  description = "CloudWatch dashboard URL for validation metrics"
  value       = var.enable_validation_module ? module.validation[0].dashboard_url : null
}

output "validation_run_command" {
  description = "CLI command to run validation"
  value       = var.enable_validation_module ? module.validation[0].run_validation_command : null
}