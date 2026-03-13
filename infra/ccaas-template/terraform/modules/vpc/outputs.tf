# =============================================================================
# VPC Module - Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (if NAT enabled)"
  value       = aws_subnet.public[*].id
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "dynamodb_endpoint_id" {
  description = "DynamoDB VPC endpoint ID"
  value       = aws_vpc_endpoint.dynamodb.id
}

output "s3_endpoint_id" {
  description = "S3 VPC endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "flow_log_group_name" {
  description = "VPC Flow Logs CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "flow_log_group_arn" {
  description = "VPC Flow Logs CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.flow_logs.arn
}

output "nat_gateway_ips" {
  description = "Elastic IP addresses of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "interface_endpoints" {
  description = "Map of interface endpoint IDs"
  value = {
    lambda         = var.enable_interface_endpoints ? aws_vpc_endpoint.lambda[0].id : null
    secretsmanager = var.enable_interface_endpoints ? aws_vpc_endpoint.secretsmanager[0].id : null
    kms            = var.enable_interface_endpoints ? aws_vpc_endpoint.kms[0].id : null
    logs           = var.enable_interface_endpoints ? aws_vpc_endpoint.logs[0].id : null
    bedrock        = var.enable_interface_endpoints ? aws_vpc_endpoint.bedrock_runtime[0].id : null
    sns            = var.enable_interface_endpoints ? aws_vpc_endpoint.sns[0].id : null
    sts            = var.enable_interface_endpoints ? aws_vpc_endpoint.sts[0].id : null
  }
}
