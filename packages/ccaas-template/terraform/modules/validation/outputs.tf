# Validation Module - Outputs
#
# WHAT: Output values from the validation module.
#
# WHY: These outputs are used by other modules and CLI scripts to interact
#      with the validation infrastructure.

output "report_bucket_name" {
  description = "S3 bucket name for validation reports"
  value       = aws_s3_bucket.validation_reports.id
}

output "report_bucket_arn" {
  description = "S3 bucket ARN for validation reports"
  value       = aws_s3_bucket.validation_reports.arn
}

output "alert_topic_arn" {
  description = "SNS topic ARN for validation alerts"
  value       = local.alert_topic_arn
}

output "orchestrator_function_name" {
  description = "Name of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.function_name
}

output "orchestrator_function_arn" {
  description = "ARN of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.arn
}

output "ai_validator_function_name" {
  description = "Name of the AI validator Lambda function"
  value       = aws_lambda_function.ai_validator.function_name
}

output "ai_validator_function_arn" {
  description = "ARN of the AI validator Lambda function"
  value       = aws_lambda_function.ai_validator.arn
}

output "report_generator_function_name" {
  description = "Name of the report generator Lambda function"
  value       = aws_lambda_function.report_generator.function_name
}

output "report_generator_function_arn" {
  description = "ARN of the report generator Lambda function"
  value       = aws_lambda_function.report_generator.arn
}

output "state_machine_arn" {
  description = "ARN of the validation workflow state machine"
  value       = aws_sfn_state_machine.validation_workflow.arn
}

output "state_machine_name" {
  description = "Name of the validation workflow state machine"
  value       = aws_sfn_state_machine.validation_workflow.name
}

output "validation_lambda_role_arn" {
  description = "IAM role ARN used by validation Lambda functions"
  value       = aws_iam_role.validation_lambda.arn
}

# ============================================================================
# CONVENIENCE OUTPUTS FOR CLI USAGE
# ============================================================================

output "run_validation_command" {
  description = "AWS CLI command to trigger validation manually"
  value       = <<-EOT
    aws stepfunctions start-execution \
      --state-machine-arn ${aws_sfn_state_machine.validation_workflow.arn} \
      --input '{"testSuite": "all", "scheduled": false}'
  EOT
}

output "run_functional_tests_command" {
  description = "AWS CLI command to run functional tests"
  value       = <<-EOT
    aws stepfunctions start-execution \
      --state-machine-arn ${aws_sfn_state_machine.validation_workflow.arn} \
      --input '{"testSuite": "functional", "scheduled": false}'
  EOT
}

output "run_load_tests_command" {
  description = "AWS CLI command to run load tests"
  value       = <<-EOT
    aws stepfunctions start-execution \
      --state-machine-arn ${aws_sfn_state_machine.validation_workflow.arn} \
      --input '{"testSuite": "load", "scheduled": false}'
  EOT
}

output "run_security_tests_command" {
  description = "AWS CLI command to run security tests"
  value       = <<-EOT
    aws stepfunctions start-execution \
      --state-machine-arn ${aws_sfn_state_machine.validation_workflow.arn} \
      --input '{"testSuite": "security", "scheduled": false}'
  EOT
}

output "view_reports_command" {
  description = "AWS CLI command to list validation reports"
  value       = "aws s3 ls s3://${aws_s3_bucket.validation_reports.id}/reports/ --recursive"
}

output "download_latest_report_command" {
  description = "AWS CLI command to download the latest report"
  value       = <<-EOT
    LATEST=$(aws s3 ls s3://${aws_s3_bucket.validation_reports.id}/reports/ --recursive | sort | tail -1 | awk '{print $4}')
    aws s3 cp s3://${aws_s3_bucket.validation_reports.id}/$LATEST ./latest-validation-report.html
  EOT
}

# ============================================================================
# SCHEDULE INFORMATION
# ============================================================================

output "scheduled_tests_enabled" {
  description = "Whether scheduled tests are enabled"
  value       = var.enable_scheduled_tests
}

output "functional_test_schedule" {
  description = "Schedule for functional tests"
  value       = var.enable_scheduled_tests ? var.functional_test_schedule : "disabled"
}

output "load_test_schedule" {
  description = "Schedule for load tests"
  value       = var.enable_scheduled_tests ? var.load_test_schedule : "disabled"
}

output "security_scan_schedule" {
  description = "Schedule for security scans"
  value       = var.enable_scheduled_tests ? var.security_scan_schedule : "disabled"
}

# ============================================================================
# DASHBOARD LINK
# ============================================================================

output "dashboard_url" {
  description = "URL to the validation CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${var.name_prefix}-validation"
}

output "cloudwatch_dashboard_url" {
  description = "URL to the validation CloudWatch dashboard (alias)"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${var.name_prefix}-validation"
}

output "step_functions_console_url" {
  description = "URL to the Step Functions console for this workflow"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/states/home?region=${data.aws_region.current.name}#/statemachines/view/${aws_sfn_state_machine.validation_workflow.arn}"
}
