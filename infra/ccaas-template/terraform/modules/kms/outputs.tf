# =============================================================================
# KMS Encryption Module - Outputs
# =============================================================================

output "primary_key_id" {
  description = "Primary KMS key ID"
  value       = aws_kms_key.primary.key_id
}

output "primary_key_arn" {
  description = "Primary KMS key ARN"
  value       = aws_kms_key.primary.arn
}

output "connect_key_id" {
  description = "Connect recordings KMS key ID"
  value       = aws_kms_key.connect.key_id
}

output "connect_key_arn" {
  description = "Connect recordings KMS key ARN"
  value       = aws_kms_key.connect.arn
}

output "logs_key_id" {
  description = "CloudWatch Logs KMS key ID"
  value       = aws_kms_key.logs.key_id
}

output "logs_key_arn" {
  description = "CloudWatch Logs KMS key ARN"
  value       = aws_kms_key.logs.arn
}

output "secrets_key_id" {
  description = "Secrets Manager KMS key ID"
  value       = aws_kms_key.secrets.key_id
}

output "secrets_key_arn" {
  description = "Secrets Manager KMS key ARN"
  value       = aws_kms_key.secrets.arn
}

output "all_key_arns" {
  description = "Map of all KMS key ARNs"
  value = {
    primary = aws_kms_key.primary.arn
    connect = aws_kms_key.connect.arn
    logs    = aws_kms_key.logs.arn
    secrets = aws_kms_key.secrets.arn
  }
}
