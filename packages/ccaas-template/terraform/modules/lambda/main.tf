# Lambda Module - Main

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "fulfillment" {
  name              = "/aws/lambda/${var.name_prefix}-fulfillment"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/aws/lambda/${var.name_prefix}-backend"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Archive Lambda code
data "archive_file" "fulfillment_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lex-bot/lambda"
  output_path = "${path.module}/files/fulfillment.zip"
}

data "archive_file" "backend_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda"
  output_path = "${path.module}/files/backend.zip"
}

# Lex Fulfillment Lambda
resource "aws_lambda_function" "fulfillment" {
  function_name = "${var.name_prefix}-fulfillment"
  description   = "Lex fulfillment handler for Census Enumerator bot"
  
  filename         = data.archive_file.fulfillment_lambda.output_path
  source_code_hash = data.archive_file.fulfillment_lambda.output_base64sha256
  
  handler = "fulfillment.handler"
  runtime = var.runtime
  timeout = var.timeout
  memory_size = var.memory_size
  
  role = var.lambda_execution_role_arn

  environment {
    variables = {
      CENSUS_TABLE_NAME  = var.census_table_name
      ADDRESS_TABLE_NAME = var.address_table_name
      AWS_REGION_NAME    = var.aws_region
      ENVIRONMENT        = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.fulfillment]

  tags = var.tags
}

# Backend Lambda (for Connect integration)
resource "aws_lambda_function" "backend" {
  function_name = "${var.name_prefix}-backend"
  description   = "Backend handler for Census Enumerator agent"
  
  filename         = data.archive_file.backend_lambda.output_path
  source_code_hash = data.archive_file.backend_lambda.output_base64sha256
  
  handler = "index.handler"
  runtime = var.runtime
  timeout = var.timeout
  memory_size = var.memory_size
  
  role = var.lambda_execution_role_arn

  environment {
    variables = {
      CENSUS_TABLE_NAME  = var.census_table_name
      ADDRESS_TABLE_NAME = var.address_table_name
      BEDROCK_MODEL_ID   = var.bedrock_model_id
      AWS_REGION_NAME    = var.aws_region
      ENVIRONMENT        = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.backend]

  tags = var.tags
}

# Lambda permission for Connect
resource "aws_lambda_permission" "connect_invoke_backend" {
  statement_id  = "AllowConnectInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "connect.amazonaws.com"
}
