# Bedrock Module - Outputs

output "guardrail_id" {
  description = "Bedrock guardrail ID"
  value       = aws_bedrock_guardrail.census_guardrail.guardrail_id
}

output "guardrail_arn" {
  description = "Bedrock guardrail ARN"
  value       = aws_bedrock_guardrail.census_guardrail.guardrail_arn
}

output "guardrail_version" {
  description = "Bedrock guardrail version"
  value       = aws_bedrock_guardrail_version.v1.version
}
