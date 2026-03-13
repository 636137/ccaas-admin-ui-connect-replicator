# Lex Module - Main

# Create the Lex Bot
resource "aws_lexv2models_bot" "census_bot" {
  name        = "${var.name_prefix}-bot"
  description = "Census Enumerator survey bot for voice and chat"
  
  role_arn = var.lex_service_role_arn
  
  data_privacy {
    child_directed = false
  }

  idle_session_ttl_in_seconds = 300

  tags = var.tags
}

# Bot Locale (English US)
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = "en_US"
  
  n_lu_intent_confidence_threshold = 0.40
  
  voice_settings {
    voice_id = var.voice_id
    engine   = "generative"
  }
}

# Slot Types
resource "aws_lexv2models_slot_type" "yes_no" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "YesNoType"
  description = "Yes or No confirmation responses"

  value_selection_setting {
    resolution_strategy = "TopResolution"
  }

  slot_type_values {
    sample_value {
      value = "Yes"
    }
    synonyms {
      value = "yeah"
    }
    synonyms {
      value = "yep"
    }
    synonyms {
      value = "correct"
    }
    synonyms {
      value = "sure"
    }
  }

  slot_type_values {
    sample_value {
      value = "No"
    }
    synonyms {
      value = "nope"
    }
    synonyms {
      value = "nah"
    }
    synonyms {
      value = "incorrect"
    }
  }
}

resource "aws_lexv2models_slot_type" "relationship" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "RelationshipType"
  description = "Relationship to householder"

  value_selection_setting {
    resolution_strategy = "TopResolution"
  }

  slot_type_values {
    sample_value { value = "Self" }
    synonyms { value = "myself" }
    synonyms { value = "householder" }
  }
  slot_type_values {
    sample_value { value = "Spouse" }
    synonyms { value = "husband" }
    synonyms { value = "wife" }
    synonyms { value = "partner" }
  }
  slot_type_values {
    sample_value { value = "Child" }
    synonyms { value = "son" }
    synonyms { value = "daughter" }
  }
  slot_type_values {
    sample_value { value = "Parent" }
    synonyms { value = "mother" }
    synonyms { value = "father" }
  }
  slot_type_values {
    sample_value { value = "Sibling" }
    synonyms { value = "brother" }
    synonyms { value = "sister" }
  }
  slot_type_values {
    sample_value { value = "Grandchild" }
  }
  slot_type_values {
    sample_value { value = "Grandparent" }
  }
  slot_type_values {
    sample_value { value = "Roommate" }
    synonyms { value = "housemate" }
  }
  slot_type_values {
    sample_value { value = "Other Relative" }
  }
  slot_type_values {
    sample_value { value = "Other Non-relative" }
  }
}

resource "aws_lexv2models_slot_type" "sex" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "SexType"
  description = "Biological sex"

  value_selection_setting {
    resolution_strategy = "TopResolution"
  }

  slot_type_values {
    sample_value { value = "Male" }
    synonyms { value = "man" }
    synonyms { value = "boy" }
  }
  slot_type_values {
    sample_value { value = "Female" }
    synonyms { value = "woman" }
    synonyms { value = "girl" }
  }
}

resource "aws_lexv2models_slot_type" "race" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "RaceType"
  description = "Race categories"

  value_selection_setting {
    resolution_strategy = "TopResolution"
  }

  slot_type_values {
    sample_value { value = "White" }
    synonyms { value = "Caucasian" }
  }
  slot_type_values {
    sample_value { value = "Black or African American" }
    synonyms { value = "Black" }
    synonyms { value = "African American" }
  }
  slot_type_values {
    sample_value { value = "American Indian or Alaska Native" }
    synonyms { value = "Native American" }
  }
  slot_type_values {
    sample_value { value = "Asian" }
  }
  slot_type_values {
    sample_value { value = "Native Hawaiian or Pacific Islander" }
    synonyms { value = "Pacific Islander" }
  }
  slot_type_values {
    sample_value { value = "Some Other Race" }
    synonyms { value = "Other" }
    synonyms { value = "Mixed" }
  }
}

resource "aws_lexv2models_slot_type" "housing_tenure" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "HousingTenureType"
  description = "Housing ownership status"

  value_selection_setting {
    resolution_strategy = "TopResolution"
  }

  slot_type_values {
    sample_value { value = "Owned with mortgage" }
    synonyms { value = "own with mortgage" }
    synonyms { value = "mortgaged" }
  }
  slot_type_values {
    sample_value { value = "Owned free and clear" }
    synonyms { value = "paid off" }
    synonyms { value = "no mortgage" }
  }
  slot_type_values {
    sample_value { value = "Rented" }
    synonyms { value = "rent" }
    synonyms { value = "renting" }
  }
  slot_type_values {
    sample_value { value = "Occupied without payment" }
    synonyms { value = "no rent" }
    synonyms { value = "rent free" }
  }
}

# Welcome Intent
resource "aws_lexv2models_intent" "welcome" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "WelcomeIntent"
  description = "Initial greeting and consent"

  sample_utterance {
    utterance = "Hello"
  }
  sample_utterance {
    utterance = "Hi"
  }
  sample_utterance {
    utterance = "Start census"
  }
  sample_utterance {
    utterance = "Begin survey"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# Household Count Intent
resource "aws_lexv2models_intent" "household_count" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "HouseholdCountIntent"
  description = "Collect household count"

  sample_utterance {
    utterance = "{HouseholdCount} people"
  }
  sample_utterance {
    utterance = "There are {HouseholdCount} of us"
  }
  sample_utterance {
    utterance = "Just me"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# Collect Person Info Intent
resource "aws_lexv2models_intent" "collect_person_info" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "CollectPersonInfoIntent"
  description = "Collect person demographic information"

  sample_utterance {
    utterance = "My name is {FirstName} {LastName}"
  }
  sample_utterance {
    utterance = "{FirstName}"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# Complete Survey Intent
resource "aws_lexv2models_intent" "complete_survey" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "CompleteSurveyIntent"
  description = "Complete the census survey"

  sample_utterance {
    utterance = "That's everyone"
  }
  sample_utterance {
    utterance = "We're done"
  }
  sample_utterance {
    utterance = "Finish"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# Schedule Callback Intent
resource "aws_lexv2models_intent" "schedule_callback" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "ScheduleCallbackIntent"
  description = "Schedule a callback"

  sample_utterance {
    utterance = "Call me back"
  }
  sample_utterance {
    utterance = "Schedule a callback"
  }
  sample_utterance {
    utterance = "Not a good time"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# Speak to Agent Intent
resource "aws_lexv2models_intent" "speak_to_agent" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "SpeakToAgentIntent"
  description = "Request live agent"

  sample_utterance {
    utterance = "Speak to a person"
  }
  sample_utterance {
    utterance = "Human please"
  }
  sample_utterance {
    utterance = "Live agent"
  }
  sample_utterance {
    utterance = "Transfer me"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# Fallback Intent
resource "aws_lexv2models_intent" "fallback" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "FallbackIntent"
  description = "Handle unrecognized utterances"

  parent_intent_signature = "AMAZON.FallbackIntent"

  fulfillment_code_hook {
    enabled = true
  }
}

# Build the bot locale
resource "aws_lexv2models_bot_version" "v1" {
  bot_id = aws_lexv2models_bot.census_bot.id
  
  locale_specification = {
    "en_US" = {
      source_bot_version = "DRAFT"
    }
  }

  depends_on = [
    aws_lexv2models_intent.welcome,
    aws_lexv2models_intent.household_count,
    aws_lexv2models_intent.collect_person_info,
    aws_lexv2models_intent.complete_survey,
    aws_lexv2models_intent.schedule_callback,
    aws_lexv2models_intent.speak_to_agent,
    aws_lexv2models_intent.fallback,
    aws_lexv2models_slot_type.yes_no,
    aws_lexv2models_slot_type.relationship,
    aws_lexv2models_slot_type.sex,
    aws_lexv2models_slot_type.race,
    aws_lexv2models_slot_type.housing_tenure
  ]
}

# Bot Alias
resource "aws_lexv2models_bot_alias" "prod" {
  bot_id      = aws_lexv2models_bot.census_bot.id
  bot_version = aws_lexv2models_bot_version.v1.bot_version
  name        = "${var.environment}-alias"
  description = "${var.environment} alias for Census Enumerator bot"

  bot_alias_locale_settings {
    locale_id = "en_US"
    bot_alias_locale_setting {
      enabled = true
      code_hook_specification {
        lambda_code_hook {
          code_hook_interface_version = "1.0"
          lambda_arn                  = var.fulfillment_lambda_arn
        }
      }
    }
  }

  tags = var.tags
}
