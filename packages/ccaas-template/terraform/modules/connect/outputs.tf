# =============================================================================
# Amazon Connect Instance Module - Outputs
# =============================================================================

output "instance_id" {
  description = "Connect instance ID"
  value       = aws_connect_instance.main.id
}

output "instance_arn" {
  description = "Connect instance ARN"
  value       = aws_connect_instance.main.arn
}

output "instance_alias" {
  description = "Connect instance alias"
  value       = aws_connect_instance.main.instance_alias
}

output "service_role" {
  description = "Connect service role ARN"
  value       = aws_connect_instance.main.service_role
}

output "storage_bucket_name" {
  description = "S3 bucket for Connect storage"
  value       = aws_s3_bucket.connect_storage.id
}

output "storage_bucket_arn" {
  description = "ARN of S3 bucket for Connect storage"
  value       = aws_s3_bucket.connect_storage.arn
}

output "census_hours_of_operation_id" {
  description = "ID of Census survey hours of operation"
  value       = aws_connect_hours_of_operation.census_hours.hours_of_operation_id
}

output "always_open_hours_of_operation_id" {
  description = "ID of 24/7 hours of operation"
  value       = aws_connect_hours_of_operation.always_open.hours_of_operation_id
}

output "supervisor_quick_connect_id" {
  description = "ID of supervisor quick connect"
  value       = aws_connect_quick_connect.supervisor_quick_connect.quick_connect_id
}

output "supervisor_quick_connect_arn" {
  description = "ARN of supervisor quick connect"
  value       = aws_connect_quick_connect.supervisor_quick_connect.arn
}
output "access_url" {
  description = "URL to access the Amazon Connect CCP"
  value       = "https://${aws_connect_instance.main.instance_alias}.my.connect.aws"
}