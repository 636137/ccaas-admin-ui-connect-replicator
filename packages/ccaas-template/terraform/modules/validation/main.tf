# Validation Module - Main Orchestration
#
# WHAT: Deploys automated testing infrastructure for Government CCaaS deployments.
#
# WHY: Validates that each deployment works correctly before going live and
#      continuously monitors quality in production.
#
# COMPONENTS:
#   - S3 bucket for test reports
#   - Lambda functions for test orchestration
#   - Step Functions for workflow management
#   - EventBridge for scheduled testing
#   - SNS for notifications

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  common_tags = merge(var.tags, {
    Module      = "validation"
    Environment = var.environment
  })
  
  # Generate unique report bucket name if not provided
  report_bucket = var.report_bucket_name != "" ? var.report_bucket_name : "${var.name_prefix}-validation-reports-${local.account_id}"
}

# ============================================================================
# S3 BUCKET FOR VALIDATION REPORTS
# ============================================================================

resource "aws_s3_bucket" "validation_reports" {
  bucket = local.report_bucket
  
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-validation-reports"
  })
}

resource "aws_s3_bucket_versioning" "validation_reports" {
  bucket = aws_s3_bucket.validation_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "validation_reports" {
  bucket = aws_s3_bucket.validation_reports.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "validation_reports" {
  bucket = aws_s3_bucket.validation_reports.id
  
  rule {
    id     = "expire-old-reports"
    status = "Enabled"
    
    expiration {
      days = var.report_retention_days
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "validation_reports" {
  bucket = aws_s3_bucket.validation_reports.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# SNS TOPIC FOR ALERTS
# ============================================================================

resource "aws_sns_topic" "validation_alerts" {
  count = var.alert_sns_topic_arn == "" ? 1 : 0
  
  name = "${var.name_prefix}-validation-alerts"
  
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  for_each = var.alert_sns_topic_arn == "" ? toset(var.alert_email_addresses) : []
  
  topic_arn = aws_sns_topic.validation_alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}

locals {
  alert_topic_arn = var.alert_sns_topic_arn != "" ? var.alert_sns_topic_arn : (
    length(aws_sns_topic.validation_alerts) > 0 ? aws_sns_topic.validation_alerts[0].arn : ""
  )
}

# ============================================================================
# IAM ROLE FOR LAMBDA FUNCTIONS
# ============================================================================

resource "aws_iam_role" "validation_lambda" {
  name = "${var.name_prefix}-validation-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy" "validation_lambda" {
  name = "${var.name_prefix}-validation-lambda-policy"
  role = aws_iam_role.validation_lambda.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Sid    = "ConnectTesting"
        Effect = "Allow"
        Action = [
          "connect:DescribeInstance",
          "connect:ListContactFlows",
          "connect:ListQueues",
          "connect:ListPhoneNumbers",
          "connect:DescribeContactFlow",
          "connect:GetCurrentMetricData",
          "connect:GetMetricData",
          "connect:StartContactSimulation",
          "connect:CreateTestCase",
          "connect:UpdateTestCase",
          "connect:DeleteTestCase",
          "connect:ListTestCases",
          "connect:DescribeTestCase",
          "connect:StartTestExecution",
          "connect:ListTestExecutions",
          "connect:DescribeTestExecution"
        ]
        Resource = [
          var.connect_instance_arn,
          "${var.connect_instance_arn}/*"
        ]
      },
      {
        Sid    = "LexTesting"
        Effect = "Allow"
        Action = [
          "lex:RecognizeText",
          "lex:RecognizeUtterance",
          "lex:DescribeBot",
          "lex:DescribeBotAlias",
          "lex:ListIntents",
          "lex:DescribeIntent"
        ]
        Resource = [
          "arn:aws:lex:${local.region}:${local.account_id}:bot/${var.lex_bot_id}",
          "arn:aws:lex:${local.region}:${local.account_id}:bot-alias/${var.lex_bot_id}/${var.lex_bot_alias_id}"
        ]
      },
      {
        Sid    = "BedrockTesting"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ApplyGuardrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBValidation"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:GetItem"
        ]
        Resource = [
          for table in var.dynamodb_table_names :
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${table}"
        ]
      },
      {
        Sid    = "S3Reports"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.validation_reports.arn,
          "${aws_s3_bucket.validation_reports.arn}/*"
        ]
      },
      {
        Sid    = "SNSAlerts"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = local.alert_topic_arn != "" ? [local.alert_topic_arn] : ["*"]
      },
      {
        Sid    = "ConfigCompliance"
        Effect = "Allow"
        Action = [
          "config:DescribeComplianceByConfigRule",
          "config:GetComplianceDetailsByConfigRule",
          "config:DescribeConfigRules",
          "config:DescribeConformancePackCompliance"
        ]
        Resource = "*"
      },
      {
        Sid    = "StepFunctionsExecution"
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:ListExecutions"
        ]
        Resource = "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${var.name_prefix}-*"
      }
    ]
  })
}

# ============================================================================
# LAMBDA LAYER FOR SHARED CODE
# ============================================================================

data "archive_file" "validation_layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-layer"
  output_path = "${path.module}/dist/validation-layer.zip"
}

resource "aws_lambda_layer_version" "validation_utils" {
  layer_name          = "${var.name_prefix}-validation-utils"
  filename            = data.archive_file.validation_layer.output_path
  source_code_hash    = data.archive_file.validation_layer.output_base64sha256
  compatible_runtimes = ["nodejs18.x", "nodejs20.x"]
  
  description = "Shared utilities for validation Lambda functions"
}

# ============================================================================
# ORCHESTRATOR LAMBDA FUNCTION
# ============================================================================

data "archive_file" "orchestrator" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/orchestrator"
  output_path = "${path.module}/dist/orchestrator.zip"
}

resource "aws_lambda_function" "orchestrator" {
  function_name    = "${var.name_prefix}-validation-orchestrator"
  role             = aws_iam_role.validation_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 300
  memory_size      = 512
  
  filename         = data.archive_file.orchestrator.output_path
  source_code_hash = data.archive_file.orchestrator.output_base64sha256
  
  layers = [aws_lambda_layer_version.validation_utils.arn]
  
  environment {
    variables = {
      CONNECT_INSTANCE_ID    = var.connect_instance_id
      LEX_BOT_ID             = var.lex_bot_id
      LEX_BOT_ALIAS_ID       = var.lex_bot_alias_id
      BEDROCK_MODEL_ID       = var.bedrock_model_id
      BEDROCK_GUARDRAIL_ID   = var.bedrock_guardrail_id
      REPORT_BUCKET          = aws_s3_bucket.validation_reports.id
      ALERT_TOPIC_ARN        = local.alert_topic_arn
      ENVIRONMENT            = var.environment
      AI_ACCURACY_THRESHOLD  = tostring(var.ai_accuracy_threshold)
      AI_LATENCY_THRESHOLD   = tostring(var.ai_latency_threshold_ms)
    }
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/aws/lambda/${aws_lambda_function.orchestrator.function_name}"
  retention_in_days = 30
  
  tags = local.common_tags
}

# ============================================================================
# AI VALIDATOR LAMBDA FUNCTION
# ============================================================================

data "archive_file" "ai_validator" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/ai-validator"
  output_path = "${path.module}/dist/ai-validator.zip"
}

resource "aws_lambda_function" "ai_validator" {
  function_name    = "${var.name_prefix}-ai-validator"
  role             = aws_iam_role.validation_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 120
  memory_size      = 512
  
  filename         = data.archive_file.ai_validator.output_path
  source_code_hash = data.archive_file.ai_validator.output_base64sha256
  
  layers = [aws_lambda_layer_version.validation_utils.arn]
  
  environment {
    variables = {
      LEX_BOT_ID             = var.lex_bot_id
      LEX_BOT_ALIAS_ID       = var.lex_bot_alias_id
      LEX_BOT_LOCALE         = var.lex_bot_locale
      BEDROCK_MODEL_ID       = var.bedrock_model_id
      BEDROCK_GUARDRAIL_ID   = var.bedrock_guardrail_id
      ACCURACY_THRESHOLD     = tostring(var.ai_accuracy_threshold)
      LATENCY_THRESHOLD_MS   = tostring(var.ai_latency_threshold_ms)
      ENABLE_PII_TESTS       = tostring(var.enable_pii_guardrail_tests)
    }
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "ai_validator" {
  name              = "/aws/lambda/${aws_lambda_function.ai_validator.function_name}"
  retention_in_days = 30
  
  tags = local.common_tags
}

# ============================================================================
# REPORT GENERATOR LAMBDA FUNCTION
# ============================================================================

data "archive_file" "report_generator" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/report-generator"
  output_path = "${path.module}/dist/report-generator.zip"
}

resource "aws_lambda_function" "report_generator" {
  function_name    = "${var.name_prefix}-report-generator"
  role             = aws_iam_role.validation_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 120
  memory_size      = 512
  
  filename         = data.archive_file.report_generator.output_path
  source_code_hash = data.archive_file.report_generator.output_base64sha256
  
  layers = [aws_lambda_layer_version.validation_utils.arn]
  
  environment {
    variables = {
      REPORT_BUCKET   = aws_s3_bucket.validation_reports.id
      ENVIRONMENT     = var.environment
      FEDRAMP_LEVEL   = var.fedramp_level
    }
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "report_generator" {
  name              = "/aws/lambda/${aws_lambda_function.report_generator.function_name}"
  retention_in_days = 30
  
  tags = local.common_tags
}

# ============================================================================
# STEP FUNCTIONS STATE MACHINE
# ============================================================================

resource "aws_iam_role" "step_functions" {
  name = "${var.name_prefix}-validation-sfn-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy" "step_functions" {
  name = "${var.name_prefix}-validation-sfn-policy"
  role = aws_iam_role.step_functions.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.orchestrator.arn,
          aws_lambda_function.ai_validator.arn,
          aws_lambda_function.report_generator.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "validation_workflow" {
  name     = "${var.name_prefix}-validation-workflow"
  role_arn = aws_iam_role.step_functions.arn
  
  definition = jsonencode({
    Comment = "Government CCaaS Validation Workflow"
    StartAt = "InitializeValidation"
    States = {
      InitializeValidation = {
        Type     = "Task"
        Resource = aws_lambda_function.orchestrator.arn
        Parameters = {
          "action"       = "initialize"
          "testSuite.$"  = "$.testSuite"
          "environment"  = var.environment
        }
        ResultPath = "$.initialization"
        Next       = "ParallelValidation"
      }
      ParallelValidation = {
        Type = "Parallel"
        Branches = [
          {
            StartAt = "FunctionalTests"
            States = {
              FunctionalTests = {
                Type     = "Task"
                Resource = aws_lambda_function.orchestrator.arn
                Parameters = {
                  "action"      = "runFunctionalTests"
                  "config.$"    = "$.initialization.config"
                }
                ResultPath = "$.functionalResults"
                End        = true
              }
            }
          },
          {
            StartAt = "AIValidation"
            States = {
              AIValidation = {
                Type     = "Task"
                Resource = aws_lambda_function.ai_validator.arn
                Parameters = {
                  "action"   = "runAllTests"
                  "config.$" = "$.initialization.config"
                }
                ResultPath = "$.aiResults"
                End        = true
              }
            }
          },
          {
            StartAt = "SecurityValidation"
            States = {
              SecurityValidation = {
                Type     = "Task"
                Resource = aws_lambda_function.orchestrator.arn
                Parameters = {
                  "action"      = "runSecurityTests"
                  "config.$"    = "$.initialization.config"
                }
                ResultPath = "$.securityResults"
                End        = true
              }
            }
          }
        ]
        ResultPath = "$.parallelResults"
        Next       = "GenerateReport"
      }
      GenerateReport = {
        Type     = "Task"
        Resource = aws_lambda_function.report_generator.arn
        Parameters = {
          "action"       = "generateReport"
          "results.$"    = "$.parallelResults"
          "testSuite.$"  = "$.testSuite"
          "environment"  = var.environment
        }
        ResultPath = "$.report"
        Next       = "CheckResults"
      }
      CheckResults = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.report.overallStatus"
            StringEquals  = "FAILED"
            Next          = "SendFailureAlert"
          }
        ]
        Default = "ValidationComplete"
      }
      SendFailureAlert = {
        Type     = "Task"
        Resource = aws_lambda_function.orchestrator.arn
        Parameters = {
          "action"     = "sendAlert"
          "report.$"   = "$.report"
          "alertType"  = "VALIDATION_FAILED"
        }
        Next = "ValidationFailed"
      }
      ValidationFailed = {
        Type  = "Fail"
        Error = "ValidationFailed"
        Cause = "One or more validation tests failed"
      }
      ValidationComplete = {
        Type = "Succeed"
      }
    }
  })
  
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${var.name_prefix}-validation-workflow"
  retention_in_days = 30
  
  tags = local.common_tags
}

# ============================================================================
# EVENTBRIDGE SCHEDULED RULES
# ============================================================================

resource "aws_cloudwatch_event_rule" "functional_tests" {
  count = var.enable_scheduled_tests ? 1 : 0
  
  name                = "${var.name_prefix}-functional-tests-schedule"
  description         = "Trigger daily functional validation tests"
  schedule_expression = var.functional_test_schedule
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "functional_tests" {
  count = var.enable_scheduled_tests ? 1 : 0
  
  rule     = aws_cloudwatch_event_rule.functional_tests[0].name
  arn      = aws_sfn_state_machine.validation_workflow.arn
  role_arn = aws_iam_role.eventbridge.arn
  
  input = jsonencode({
    testSuite = "functional"
    scheduled = true
    timestamp = "$${aws:CurrentTime}"
  })
}

resource "aws_cloudwatch_event_rule" "load_tests" {
  count = var.enable_scheduled_tests ? 1 : 0
  
  name                = "${var.name_prefix}-load-tests-schedule"
  description         = "Trigger weekly load tests"
  schedule_expression = var.load_test_schedule
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "load_tests" {
  count = var.enable_scheduled_tests ? 1 : 0
  
  rule     = aws_cloudwatch_event_rule.load_tests[0].name
  arn      = aws_sfn_state_machine.validation_workflow.arn
  role_arn = aws_iam_role.eventbridge.arn
  
  input = jsonencode({
    testSuite = "load"
    scheduled = true
    timestamp = "$${aws:CurrentTime}"
  })
}

resource "aws_cloudwatch_event_rule" "security_scans" {
  count = var.enable_scheduled_tests ? 1 : 0
  
  name                = "${var.name_prefix}-security-scans-schedule"
  description         = "Trigger daily security compliance scans"
  schedule_expression = var.security_scan_schedule
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "security_scans" {
  count = var.enable_scheduled_tests ? 1 : 0
  
  rule     = aws_cloudwatch_event_rule.security_scans[0].name
  arn      = aws_sfn_state_machine.validation_workflow.arn
  role_arn = aws_iam_role.eventbridge.arn
  
  input = jsonencode({
    testSuite = "security"
    scheduled = true
    timestamp = "$${aws:CurrentTime}"
  })
}

# IAM role for EventBridge
resource "aws_iam_role" "eventbridge" {
  name = "${var.name_prefix}-validation-eventbridge-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy" "eventbridge" {
  name = "${var.name_prefix}-validation-eventbridge-policy"
  role = aws_iam_role.eventbridge.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.validation_workflow.arn
    }]
  })
}
