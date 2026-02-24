# Lambda Module - Outputs

output "fulfillment_lambda_arn" {
  description = "ARN of the fulfillment Lambda function"
  value       = aws_lambda_function.fulfillment.arn
}

output "fulfillment_lambda_name" {
  description = "Name of the fulfillment Lambda function"
  value       = aws_lambda_function.fulfillment.function_name
}

output "backend_lambda_arn" {
  description = "ARN of the backend Lambda function"
  value       = aws_lambda_function.backend.arn
}

output "backend_lambda_name" {
  description = "Name of the backend Lambda function"
  value       = aws_lambda_function.backend.function_name
}

output "function_names" {
  description = "List of all Lambda function names"
  value = [
    aws_lambda_function.fulfillment.function_name,
    aws_lambda_function.backend.function_name
  ]
}
