# Bedrock Module - Main

resource "aws_bedrock_guardrail" "census_guardrail" {
  name        = "${var.name_prefix}-guardrail"
  description = "Guardrail for Census Enumerator AI Agent"

  blocked_input_messaging  = "I apologize, but I'm not able to process that request. Let me continue with the census survey questions."
  blocked_outputs_messaging = "I apologize, but I cannot provide that information. Let me help you complete your census response."

  # Content Policy - Block harmful content
  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  # Sensitive Information Policy - Block PII
  sensitive_information_policy_config {
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_BANK_ACCOUNT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "PIN"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "PASSWORD"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_CVV"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_EXPIRY"
      action = "BLOCK"
    }
  }

  # Topic Policy - Deny certain topics
  topic_policy_config {
    topics_config {
      name       = "ImmigrationStatus"
      definition = "Questions or discussions about immigration status, citizenship status, visa status, or legal residency"
      type       = "DENY"
      examples   = [
        "Are you a citizen?",
        "What is your immigration status?",
        "Are you here legally?",
        "Do you have a green card?"
      ]
    }
    topics_config {
      name       = "FinancialInformation"
      definition = "Requests for financial information like income, bank accounts, credit scores, or salary"
      type       = "DENY"
      examples   = [
        "What is your income?",
        "What is your bank account number?",
        "How much money do you make?",
        "What is your salary?"
      ]
    }
    topics_config {
      name       = "PoliticalOpinions"
      definition = "Questions or statements about political views, voting preferences, or political parties"
      type       = "DENY"
      examples   = [
        "Who did you vote for?",
        "What political party do you support?",
        "What do you think about the president?",
        "Are you a Democrat or Republican?"
      ]
    }
    topics_config {
      name       = "LawEnforcementRelated"
      definition = "Questions about criminal history, arrests, or law enforcement interactions"
      type       = "DENY"
      examples   = [
        "Have you ever been arrested?",
        "Do you have a criminal record?",
        "Have you had any trouble with the law?"
      ]
    }
  }

  # Word Policy - Block specific words/phrases
  word_policy_config {
    words_config {
      text = "social security number"
    }
    words_config {
      text = "SSN"
    }
    words_config {
      text = "bank account"
    }
    words_config {
      text = "credit card"
    }
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }

  tags = var.tags
}

# Create a version of the guardrail
resource "aws_bedrock_guardrail_version" "v1" {
  guardrail_arn = aws_bedrock_guardrail.census_guardrail.guardrail_arn
  description   = "Version 1 - Initial release"
}
