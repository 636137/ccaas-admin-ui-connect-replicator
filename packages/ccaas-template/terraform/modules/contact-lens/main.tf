# =============================================================================
# Contact Lens Rules Module
# =============================================================================
#
# WHAT: Creates Contact Lens real-time and post-contact analytics rules
# WHY: Automated monitoring, alerting, and categorization for quality management
#
# RULE TYPES:
# - Real-Time Rules: Alert supervisors during live contacts
# - Post-Contact Rules: Categorize and analyze completed contacts
#
# CENSUS-SPECIFIC RULES:
# - Survey completion monitoring
# - Privacy/compliance violations
# - Sentiment/frustration detection
# - Quality scoring automation
# =============================================================================

# -----------------------------------------------------------------------------
# REAL-TIME RULES - Alert during live contacts
# -----------------------------------------------------------------------------

# Rule: Detect constituent frustration in real-time
resource "aws_connect_rule" "realtime_frustration_detected" {
  instance_id = var.instance_id
  name        = "Census-RT-Frustration-Detected"
  publish_status = "PUBLISH"
  
  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnRealTimeContactAnalysis"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Frustrated-Constituent"
    }

    # Alert supervisor via task
    task_actions {
      name        = "Frustrated Constituent Alert"
      description = "Constituent showing signs of frustration - may need supervisor intervention"
      
      contact_flow_id = var.alert_contact_flow_id
      
      references = {
        ContactId = {
          type  = "STRING"
          value = "$.ContactId"
        }
        AlertType = {
          type  = "STRING"
          value = "FRUSTRATION"
        }
      }
    }
  }

  tags = var.tags
}

# Rule: Detect request for live agent in real-time
resource "aws_connect_rule" "realtime_agent_request" {
  instance_id    = var.instance_id
  name           = "Census-RT-Agent-Request"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnRealTimeContactAnalysis"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Agent-Request"
    }
  }

  tags = var.tags
}

# Rule: Detect privacy-related concerns mentioned
resource "aws_connect_rule" "realtime_privacy_concern" {
  instance_id    = var.instance_id
  name           = "Census-RT-Privacy-Concern"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnRealTimeContactAnalysis"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Privacy-Concern-Raised"
    }

    # Send alert on privacy concerns
    send_notification_actions {
      content      = "Privacy concern detected in census call. ContactId: $.ContactId"
      content_type = "PLAIN_TEXT"
      delivery_method = "EMAIL"
      recipient {
        user_ids = var.supervisor_user_ids
      }
      subject = "[ALERT] Privacy Concern - Census Survey"
    }
  }

  tags = var.tags
}

# Rule: Real-time negative sentiment detection
resource "aws_connect_rule" "realtime_negative_sentiment" {
  instance_id    = var.instance_id
  name           = "Census-RT-Negative-Sentiment"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnRealTimeContactAnalysis"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Negative-Sentiment"
    }
  }

  tags = var.tags
}

# Rule: Detect survey completion intent
resource "aws_connect_rule" "realtime_survey_completing" {
  instance_id    = var.instance_id
  name           = "Census-RT-Survey-Completing"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnRealTimeContactAnalysis"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Survey-In-Progress"
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# POST-CONTACT RULES - Categorize after contact ends
# -----------------------------------------------------------------------------

# Rule: Survey completed successfully
resource "aws_connect_rule" "post_survey_completed" {
  instance_id    = var.instance_id
  name           = "Census-Post-Survey-Completed"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Survey-Completed"
    }
  }

  tags = var.tags
}

# Rule: Survey refused
resource "aws_connect_rule" "post_survey_refused" {
  instance_id    = var.instance_id
  name           = "Census-Post-Survey-Refused"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Survey-Refused"
    }
  }

  tags = var.tags
}

# Rule: Callback scheduled
resource "aws_connect_rule" "post_callback_scheduled" {
  instance_id    = var.instance_id
  name           = "Census-Post-Callback-Scheduled"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Callback-Scheduled"
    }
  }

  tags = var.tags
}

# Rule: Escalation occurred
resource "aws_connect_rule" "post_escalation" {
  instance_id    = var.instance_id
  name           = "Census-Post-Escalation-Occurred"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Escalation-Required"
    }
  }

  tags = var.tags
}

# Rule: Language barrier detected
resource "aws_connect_rule" "post_language_barrier" {
  instance_id    = var.instance_id
  name           = "Census-Post-Language-Barrier"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Language-Barrier"
    }
  }

  tags = var.tags
}

# Rule: Complex case identified (custody, military, college)
resource "aws_connect_rule" "post_complex_case" {
  instance_id    = var.instance_id
  name           = "Census-Post-Complex-Case"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Complex-Case"
    }
  }

  tags = var.tags
}

# Rule: Positive experience / Thank you
resource "aws_connect_rule" "post_positive_experience" {
  instance_id    = var.instance_id
  name           = "Census-Post-Positive-Experience"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Positive-Experience"
    }
  }

  tags = var.tags
}

# Rule: AI handled successfully (no escalation)
resource "aws_connect_rule" "post_ai_success" {
  instance_id    = var.instance_id
  name           = "Census-Post-AI-Success"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "AI-Handled-Successfully"
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# POST-CHAT RULES - For chat channel
# -----------------------------------------------------------------------------

# Rule: Chat survey completed
resource "aws_connect_rule" "post_chat_completed" {
  instance_id    = var.instance_id
  name           = "Census-Post-Chat-Completed"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostChatAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Chat-Survey-Completed"
    }
  }

  tags = var.tags
}

# Rule: Chat abandoned
resource "aws_connect_rule" "post_chat_abandoned" {
  instance_id    = var.instance_id
  name           = "Census-Post-Chat-Abandoned"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostChatAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Chat-Abandoned"
    }
  }

  tags = var.tags
}

# Rule: Chat escalated to agent
resource "aws_connect_rule" "post_chat_escalated" {
  instance_id    = var.instance_id
  name           = "Census-Post-Chat-Escalated"
  publish_status = "PUBLISH"

  function = "AssignContactCategory"

  trigger_event_source {
    event_source_name = "OnPostChatAnalysisAvailable"
  }

  actions {
    assign_contact_category_actions {
      category_name = "Chat-Escalated"
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Contact Categories (used by rules above)
# -----------------------------------------------------------------------------

resource "aws_connect_contact_category" "categories" {
  for_each = toset([
    # Real-time categories
    "Frustrated-Constituent",
    "Agent-Request",
    "Privacy-Concern-Raised",
    "Negative-Sentiment",
    "Survey-In-Progress",
    
    # Post-contact categories
    "Survey-Completed",
    "Survey-Refused",
    "Callback-Scheduled",
    "Escalation-Required",
    "Language-Barrier",
    "Complex-Case",
    "Positive-Experience",
    "AI-Handled-Successfully",
    
    # Chat categories
    "Chat-Survey-Completed",
    "Chat-Abandoned",
    "Chat-Escalated"
  ])

  instance_id = var.instance_id
  name        = each.value

  rule {
    name        = "auto-${lower(replace(each.value, "-", "_"))}"
    condition   = "$CustomerSentiment.Label == \"NEGATIVE\" OR $AgentSentiment.Label == \"NEGATIVE\""
    actions     = []
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Vocabulary for Census-specific terms
# -----------------------------------------------------------------------------

resource "aws_connect_vocabulary" "census_terms" {
  instance_id   = var.instance_id
  name          = "Census-Terminology"
  language_code = "en-US"
  content       = <<-EOT
    Phrase	IPA	SoundsLike	DisplayAs
    census	ˈsɛnsəs		Census
    enumerator	ɪˈn(j)uːməˌreɪtər		Enumerator
    constituent	kənˈstɪtjʊənt		Constituent
    Title 13	ˈtaɪtl θɜːˈtiːn		Title 13
    decennial	dɪˈsɛnɪəl		Decennial
    householder	ˈhaʊsˌhoʊldər		Householder
    Hispanic	hɪˈspænɪk		Hispanic
    Latino	ləˈtiːnoʊ		Latino
    multiracial	ˌmʌltɪˈreɪʃəl		Multiracial
  EOT

  tags = var.tags
}
