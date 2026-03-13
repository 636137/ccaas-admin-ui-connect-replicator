# =============================================================================
# AWS Config Rules Module - Outputs
# =============================================================================

output "config_recorder_id" {
  description = "AWS Config recorder ID"
  value       = aws_config_configuration_recorder.main.id
}

output "config_bucket_name" {
  description = "S3 bucket for Config history"
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "S3 bucket ARN for Config history"
  value       = aws_s3_bucket.config.arn
}

output "config_role_arn" {
  description = "IAM role ARN for Config"
  value       = aws_iam_role.config.arn
}

output "notification_topic_arn" {
  description = "SNS topic ARN for Config notifications"
  value       = aws_sns_topic.config_notifications.arn
}

output "config_rules" {
  description = "Map of Config rule names"
  value = {
    s3_encryption           = aws_config_config_rule.s3_bucket_server_side_encryption_enabled.name
    dynamodb_encryption     = aws_config_config_rule.dynamodb_table_encrypted_kms.name
    ebs_encryption          = aws_config_config_rule.ec2_ebs_encryption_by_default.name
    rds_encryption          = aws_config_config_rule.rds_storage_encrypted.name
    cloudwatch_encryption   = aws_config_config_rule.cloudwatch_log_group_encrypted.name
    root_mfa                = aws_config_config_rule.root_account_mfa_enabled.name
    iam_user_mfa            = aws_config_config_rule.iam_user_mfa_enabled.name
    no_root_access_key      = aws_config_config_rule.iam_root_access_key_check.name
    password_policy         = aws_config_config_rule.iam_password_policy.name
    cloudtrail_enabled      = aws_config_config_rule.cloudtrail_enabled.name
    cloudtrail_validation   = aws_config_config_rule.cloudtrail_log_file_validation.name
    s3_logging              = aws_config_config_rule.s3_bucket_logging_enabled.name
    vpc_flow_logs           = aws_config_config_rule.vpc_flow_logs_enabled.name
    restricted_ssh          = aws_config_config_rule.restricted_ssh.name
    restricted_rdp          = aws_config_config_rule.restricted_rdp.name
    s3_no_public_read       = aws_config_config_rule.s3_bucket_public_read_prohibited.name
    s3_no_public_write      = aws_config_config_rule.s3_bucket_public_write_prohibited.name
    lambda_in_vpc           = aws_config_config_rule.lambda_inside_vpc.name
  }
}
