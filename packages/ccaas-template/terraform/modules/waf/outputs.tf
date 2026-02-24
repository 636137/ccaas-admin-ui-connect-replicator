# =============================================================================
# WAF Module - Outputs
# =============================================================================

output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "WAF Web ACL name"
  value       = aws_wafv2_web_acl.main.name
}

output "blocked_ip_set_arn" {
  description = "Blocked IP set ARN"
  value       = aws_wafv2_ip_set.blocked_ips.arn
}

output "allowed_ip_set_arn" {
  description = "Allowed IP set ARN"
  value       = aws_wafv2_ip_set.allowed_ips.arn
}

output "log_group_name" {
  description = "WAF CloudWatch log group name"
  value       = aws_cloudwatch_log_group.waf.name
}

output "log_group_arn" {
  description = "WAF CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.waf.arn
}
