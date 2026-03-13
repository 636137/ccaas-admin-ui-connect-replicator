# =============================================================================
# Census Enumerator AI Agent - Terraform Main Configuration
# =============================================================================
#
# WHAT THIS DOES:
# Deploys all AWS infrastructure needed for the Census Enumerator AI Agent:
# - DynamoDB tables for storing survey responses and addresses
# - Lambda functions for backend processing
# - IAM roles and policies for service permissions
# - Amazon Lex bot for natural language understanding
# - Bedrock guardrails for content filtering
# - CloudWatch dashboards for monitoring
#
# HOW TO USE:
# 1. cp terraform.tfvars.example terraform.tfvars
# 2. Edit terraform.tfvars with your values (Connect instance ID, etc.)
# 3. terraform init
# 4. terraform plan
# 5. terraform apply
#
# PREREQUISITES:
# - AWS CLI configured with appropriate permissions
# - Amazon Connect instance already created
# - Amazon Bedrock model access enabled
# - Terraform >= 1.5.0
#
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # REMOTE STATE: Uncomment for production deployments to enable team collaboration
  # and state locking. Requires an S3 bucket and DynamoDB table for locking.
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "census-enumerator/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  # DEFAULT TAGS: Applied to all resources for cost tracking and organization
  default_tags {
    tags = {
      Project     = "CensusEnumerator"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Random suffix ensures unique resource names across deployments
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  name_suffix = random_id.suffix.hex
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# =============================================================================
# MODULE: DynamoDB Tables
# Stores survey responses and address lookup data
# =============================================================================
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix = local.name_prefix
  environment = var.environment
  
  tags = local.common_tags
}

# =============================================================================
# MODULE: IAM Roles and Policies
# Creates service roles for Lambda, Lex, and cross-service permissions
# =============================================================================
module "iam" {
  source = "./modules/iam"

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  account_id             = data.aws_caller_identity.current.account_id
  dynamodb_table_arns    = module.dynamodb.table_arns
  lex_bot_arn            = module.lex.bot_arn
  
  tags = local.common_tags
}

# =============================================================================
# MODULE: Lambda Functions
# Backend business logic for address lookup, data saving, etc.
# =============================================================================
module "lambda" {
  source = "./modules/lambda"

  name_prefix               = local.name_prefix
  environment               = var.environment
  aws_region                = var.aws_region
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  census_table_name         = module.dynamodb.census_responses_table_name
  address_table_name        = module.dynamodb.census_addresses_table_name
  bedrock_model_id          = var.bedrock_model_id
  
  tags = local.common_tags
}

# =============================================================================
# MODULE: Amazon Lex Bot
# Natural language understanding for voice and chat interactions
# =============================================================================
module "lex" {
  source = "./modules/lex"

  name_prefix                = local.name_prefix
  environment                = var.environment
  lex_service_role_arn       = module.iam.lex_service_role_arn
  fulfillment_lambda_arn     = module.lambda.fulfillment_lambda_arn
  bedrock_model_arn          = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  voice_id                   = var.lex_voice_id
  
  tags = local.common_tags

  depends_on = [module.lambda]
}

# Lambda Permission for Lex
resource "aws_lambda_permission" "lex_invoke_fulfillment" {
  statement_id  = "AllowLexInvocation"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.fulfillment_lambda_name
  principal     = "lexv2.amazonaws.com"
  source_arn    = "${module.lex.bot_arn}/*"
}

# =============================================================================
# MODULE: Amazon Connect Instance
# Creates the Connect instance with all required features enabled
# =============================================================================
module "connect" {
  source = "./modules/connect"
  count  = var.create_connect_instance ? 1 : 0

  name_prefix    = local.name_prefix
  name_suffix    = local.name_suffix
  instance_alias = var.connect_instance_alias
  account_id     = data.aws_caller_identity.current.account_id
  
  tags = local.common_tags
}

# =============================================================================
# MODULE: Connect Queues and Routing Profiles
# Creates realistic queues for Census survey operations
# =============================================================================
module "connect_queues" {
  source = "./modules/connect-queues"
  count  = var.create_connect_instance ? 1 : 0

  instance_id          = module.connect[0].instance_id
  census_hours_id      = module.connect[0].census_hours_of_operation_id
  always_open_hours_id = module.connect[0].always_open_hours_of_operation_id
  
  tags = local.common_tags

  depends_on = [module.connect]
}

# =============================================================================
# MODULE: Connect Users
# Creates test agents, supervisors, and security profiles
# =============================================================================
module "connect_users" {
  source = "./modules/connect-users"
  count  = var.create_connect_instance ? 1 : 0

  instance_id                  = module.connect[0].instance_id
  agent_routing_profile_id     = module.connect_queues[0].routing_profile_ids["Census-General-Agent"]
  supervisor_routing_profile_id = module.connect_queues[0].routing_profile_ids["Census-Supervisor"]
  agent_emails                 = var.agent_emails
  supervisor_email             = var.supervisor_email
  
  tags = local.common_tags

  depends_on = [module.connect_queues]
}

# =============================================================================
# MODULE: Contact Lens Rules
# Real-time and post-contact analytics rules for quality management
# =============================================================================
module "contact_lens" {
  source = "./modules/contact-lens"
  count  = var.create_connect_instance ? 1 : 0

  instance_id           = module.connect[0].instance_id
  supervisor_user_ids   = [module.connect_users[0].supervisor_user_id]
  notification_email    = var.supervisor_email
  
  tags = local.common_tags

  depends_on = [module.connect_users]
}

# Bedrock Guardrail
module "bedrock" {
  source = "./modules/bedrock"

  name_prefix = local.name_prefix
  environment = var.environment
  
  tags = local.common_tags
}

# CloudWatch Alarms and Dashboard
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix              = local.name_prefix
  environment              = var.environment
  aws_region               = var.aws_region
  lambda_function_names    = module.lambda.function_names
  dynamodb_table_names     = module.dynamodb.table_names
  lex_bot_id               = module.lex.bot_id
  alarm_sns_topic_arn      = var.alarm_sns_topic_arn
  
  tags = local.common_tags
}

# =============================================================================
# MODULE: Validation and Testing
# Automated validation suite for deployment verification and AI quality
# =============================================================================
module "validation" {
  source = "./modules/validation"
  count  = var.enable_validation_module ? 1 : 0

  project_name = var.project_name
  environment  = var.environment

  # Connect configuration
  connect_instance_id  = var.create_connect_instance ? module.connect[0].instance_id : var.connect_instance_id
  connect_instance_arn = var.create_connect_instance ? module.connect[0].instance_arn : "arn:aws:connect:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${var.connect_instance_id}"

  # Lex configuration
  lex_bot_id       = module.lex.bot_id
  lex_bot_alias_id = module.lex.bot_alias_id
  lex_locale_id    = "en_US"

  # Bedrock configuration
  bedrock_agent_id       = try(module.bedrock.agent_id, "")
  bedrock_agent_alias_id = try(module.bedrock.agent_alias_id, "")
  bedrock_guardrail_id   = try(module.bedrock.guardrail_id, "")
  bedrock_model_id       = var.bedrock_model_id

  # Lambda functions to validate
  lambda_arns = module.lambda.function_arns

  # DynamoDB tables to validate
  dynamodb_table_names = module.dynamodb.table_names

  # Notification settings
  notification_email = var.validation_notification_email

  # AI validation thresholds
  ai_accuracy_threshold = var.ai_accuracy_threshold
  ai_latency_threshold  = var.ai_latency_threshold

  tags = local.common_tags

  depends_on = [module.lex, module.lambda, module.dynamodb]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
