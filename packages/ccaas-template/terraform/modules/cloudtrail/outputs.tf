# =============================================================================
# CloudTrail Audit Module - Outputs
# =============================================================================

output "trail_arn" {
  description = "CloudTrail trail ARN"
  value       = aws_cloudtrail.main.arn
}

output "trail_name" {
  description = "CloudTrail trail name"
  value       = aws_cloudtrail.main.name
}

output "s3_bucket_name" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}

output "security_alarms" {
  description = "Map of security alarm names"
  value = {
    unauthorized_api_calls   = aws_cloudwatch_metric_alarm.unauthorized_api_calls.alarm_name
    root_account_usage       = aws_cloudwatch_metric_alarm.root_account_usage.alarm_name
    iam_policy_changes       = aws_cloudwatch_metric_alarm.iam_policy_changes.alarm_name
    security_group_changes   = aws_cloudwatch_metric_alarm.security_group_changes.alarm_name
    console_login_without_mfa = aws_cloudwatch_metric_alarm.console_login_without_mfa.alarm_name
  }
}
