# IAM Module - Outputs

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "lex_service_role_arn" {
  description = "ARN of the Lex service role"
  value       = aws_iam_role.lex_service.arn
}

output "lex_service_role_name" {
  description = "Name of the Lex service role"
  value       = aws_iam_role.lex_service.name
}

output "connect_service_role_arn" {
  description = "ARN of the Connect service role"
  value       = aws_iam_role.connect_service.arn
}
