# Lex Module - Outputs

output "bot_id" {
  description = "Lex bot ID"
  value       = aws_lexv2models_bot.census_bot.id
}

output "bot_arn" {
  description = "Lex bot ARN"
  value       = aws_lexv2models_bot.census_bot.arn
}

output "bot_name" {
  description = "Lex bot name"
  value       = aws_lexv2models_bot.census_bot.name
}

output "bot_version" {
  description = "Lex bot version"
  value       = aws_lexv2models_bot_version.v1.bot_version
}

output "bot_alias_id" {
  description = "Lex bot alias ID"
  value       = aws_lexv2models_bot_alias.prod.bot_alias_id
}

output "bot_alias_arn" {
  description = "Lex bot alias ARN"
  value       = "arn:aws:lex:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bot-alias/${aws_lexv2models_bot.census_bot.id}/${aws_lexv2models_bot_alias.prod.bot_alias_id}"
}

output "locale_id" {
  description = "Lex bot locale ID"
  value       = aws_lexv2models_bot_locale.en_us.locale_id
}

# Data sources for outputs
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
