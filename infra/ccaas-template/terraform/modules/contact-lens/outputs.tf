# =============================================================================
# Contact Lens Rules Module - Outputs
# =============================================================================

output "real_time_rule_ids" {
  description = "IDs of created real-time Contact Lens rules"
  value = {
    frustration_detection = aws_connect_rule.realtime_frustration_detected.id
    agent_request         = aws_connect_rule.realtime_agent_request.id
    privacy_concern       = aws_connect_rule.realtime_privacy_concern.id
    negative_sentiment    = aws_connect_rule.realtime_negative_sentiment.id
    survey_completing     = aws_connect_rule.realtime_survey_completing.id
  }
}

output "post_call_rule_ids" {
  description = "IDs of created post-call Contact Lens rules"
  value = {
    survey_completed    = aws_connect_rule.post_survey_completed.id
    survey_refused      = aws_connect_rule.post_survey_refused.id
    callback_scheduled  = aws_connect_rule.post_callback_scheduled.id
    escalation_required = aws_connect_rule.post_escalation.id
    language_barrier    = aws_connect_rule.post_language_barrier.id
    complex_case        = aws_connect_rule.post_complex_case.id
    positive_experience = aws_connect_rule.post_positive_experience.id
    ai_success_metrics  = aws_connect_rule.post_ai_success.id
  }
}

output "post_chat_rule_ids" {
  description = "IDs of created post-chat Contact Lens rules"
  value = {
    chat_completed = aws_connect_rule.post_chat_completed.id
    chat_abandoned = aws_connect_rule.post_chat_abandoned.id
    chat_escalated = aws_connect_rule.post_chat_escalated.id
  }
}

output "category_ids" {
  description = "IDs of created Contact Lens categories"
  value = { for k, v in aws_connect_contact_category.categories : k => v.id }
}

output "vocabulary_id" {
  description = "ID of the Census custom vocabulary"
  value       = aws_connect_vocabulary.census_terms.id
}

output "vocabulary_arn" {
  description = "ARN of the Census custom vocabulary"
  value       = aws_connect_vocabulary.census_terms.arn
}
