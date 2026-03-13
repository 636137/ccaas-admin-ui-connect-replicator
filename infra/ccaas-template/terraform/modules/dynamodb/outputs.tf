# DynamoDB Module - Outputs

output "census_responses_table_name" {
  description = "Name of the Census Responses table"
  value       = aws_dynamodb_table.census_responses.name
}

output "census_responses_table_arn" {
  description = "ARN of the Census Responses table"
  value       = aws_dynamodb_table.census_responses.arn
}

output "census_addresses_table_name" {
  description = "Name of the Census Addresses table"
  value       = aws_dynamodb_table.census_addresses.name
}

output "census_addresses_table_arn" {
  description = "ARN of the Census Addresses table"
  value       = aws_dynamodb_table.census_addresses.arn
}

output "census_callbacks_table_name" {
  description = "Name of the Census Callbacks table"
  value       = aws_dynamodb_table.census_callbacks.name
}

output "census_callbacks_table_arn" {
  description = "ARN of the Census Callbacks table"
  value       = aws_dynamodb_table.census_callbacks.arn
}

output "table_arns" {
  description = "List of all table ARNs"
  value = [
    aws_dynamodb_table.census_responses.arn,
    aws_dynamodb_table.census_addresses.arn,
    aws_dynamodb_table.census_callbacks.arn
  ]
}

output "table_names" {
  description = "List of all table names"
  value = [
    aws_dynamodb_table.census_responses.name,
    aws_dynamodb_table.census_addresses.name,
    aws_dynamodb_table.census_callbacks.name
  ]
}
