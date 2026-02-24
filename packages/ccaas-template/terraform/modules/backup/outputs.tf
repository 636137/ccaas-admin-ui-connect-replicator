# =============================================================================
# AWS Backup Module - Outputs
# =============================================================================

output "backup_vault_name" {
  description = "Primary backup vault name"
  value       = aws_backup_vault.primary.name
}

output "backup_vault_arn" {
  description = "Primary backup vault ARN"
  value       = aws_backup_vault.primary.arn
}

output "backup_plan_id" {
  description = "Backup plan ID"
  value       = aws_backup_plan.daily.id
}

output "backup_plan_arn" {
  description = "Backup plan ARN"
  value       = aws_backup_plan.daily.arn
}

output "backup_role_arn" {
  description = "IAM role ARN for AWS Backup"
  value       = aws_iam_role.backup.arn
}

output "notification_topic_arn" {
  description = "SNS topic ARN for backup notifications"
  value       = aws_sns_topic.backup_notifications.arn
}

output "backup_selection_ids" {
  description = "Backup selection IDs"
  value = {
    all      = aws_backup_selection.all.id
    dynamodb = aws_backup_selection.dynamodb.id
  }
}
