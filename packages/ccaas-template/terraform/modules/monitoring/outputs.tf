# Monitoring Module - Outputs

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.census_agent.dashboard_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.census_agent.dashboard_name}"
}

output "alarm_arns" {
  description = "List of CloudWatch alarm ARNs"
  value = concat(
    [for alarm in aws_cloudwatch_metric_alarm.lambda_errors : alarm.arn],
    [for alarm in aws_cloudwatch_metric_alarm.lambda_duration : alarm.arn],
    [for alarm in aws_cloudwatch_metric_alarm.dynamodb_throttles : alarm.arn],
    [aws_cloudwatch_metric_alarm.lex_missed_utterances.arn]
  )
}
