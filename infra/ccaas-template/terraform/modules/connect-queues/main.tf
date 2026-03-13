# =============================================================================
# Amazon Connect Queues Module
# =============================================================================
#
# WHAT: Creates realistic queues for Census Enumerator operations
# WHY: Proper queue structure enables efficient routing, reporting, and escalation
#
# QUEUE STRUCTURE:
# - Census-AI-Self-Service: AI-handled surveys (no agents)
# - Census-General-Inquiries: General questions, routed to any agent
# - Census-Live-Agents: Escalations from AI requiring human assistance
# - Census-Specialists: Complex cases (custody, military, group quarters)
# - Census-Supervisors: Complaints, quality issues, escalations
# - Census-Callbacks: Scheduled callback queue
# - Census-Language-Support: Non-English language assistance
# =============================================================================

# -----------------------------------------------------------------------------
# AI Self-Service Queue (no live agents)
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "ai_self_service" {
  instance_id           = var.instance_id
  name                  = "Census-AI-Self-Service"
  description           = "AI-handled census surveys - no agent routing needed"
  hours_of_operation_id = var.always_open_hours_id

  # No max contacts since AI handles everything
  max_contacts = 0

  tags = merge(var.tags, {
    QueueType = "AI-Self-Service"
  })
}

# -----------------------------------------------------------------------------
# General Inquiries Queue
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "general_inquiries" {
  instance_id           = var.instance_id
  name                  = "Census-General-Inquiries"
  description           = "General census questions and information requests"
  hours_of_operation_id = var.census_hours_id

  # Standard queue settings
  max_contacts = 10

  outbound_caller_config {
    outbound_caller_id_name      = "US Census Bureau"
    outbound_caller_id_number_id = var.outbound_caller_id
  }

  tags = merge(var.tags, {
    QueueType = "General"
    Priority  = "Normal"
  })
}

# -----------------------------------------------------------------------------
# Live Agents Queue - Escalations from AI
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "live_agents" {
  instance_id           = var.instance_id
  name                  = "Census-Live-Agents"
  description           = "Human agent assistance - escalations from AI and constituent requests"
  hours_of_operation_id = var.census_hours_id

  max_contacts = 15

  outbound_caller_config {
    outbound_caller_id_name      = "US Census Bureau"
    outbound_caller_id_number_id = var.outbound_caller_id
  }

  tags = merge(var.tags, {
    QueueType = "Escalation"
    Priority  = "High"
  })
}

# -----------------------------------------------------------------------------
# Specialists Queue - Complex cases
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "specialists" {
  instance_id           = var.instance_id
  name                  = "Census-Specialists"
  description           = "Complex census cases: shared custody, military, college students, group quarters"
  hours_of_operation_id = var.census_hours_id

  max_contacts = 8

  outbound_caller_config {
    outbound_caller_id_name      = "Census Specialist"
    outbound_caller_id_number_id = var.outbound_caller_id
  }

  tags = merge(var.tags, {
    QueueType = "Specialist"
    Priority  = "Normal"
  })
}

# -----------------------------------------------------------------------------
# Supervisors Queue - Complaints and quality issues
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "supervisors" {
  instance_id           = var.instance_id
  name                  = "Census-Supervisors"
  description           = "Supervisor queue for complaints, quality issues, and high-priority escalations"
  hours_of_operation_id = var.census_hours_id

  max_contacts = 5

  outbound_caller_config {
    outbound_caller_id_name      = "Census Supervisor"
    outbound_caller_id_number_id = var.outbound_caller_id
  }

  tags = merge(var.tags, {
    QueueType = "Supervisor"
    Priority  = "Critical"
  })
}

# -----------------------------------------------------------------------------
# Callbacks Queue
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "callbacks" {
  instance_id           = var.instance_id
  name                  = "Census-Callbacks"
  description           = "Scheduled callbacks for constituents who requested follow-up"
  hours_of_operation_id = var.census_hours_id

  max_contacts = 20

  outbound_caller_config {
    outbound_caller_id_name      = "US Census Bureau Callback"
    outbound_caller_id_number_id = var.outbound_caller_id
  }

  tags = merge(var.tags, {
    QueueType = "Callback"
    Priority  = "Normal"
  })
}

# -----------------------------------------------------------------------------
# Language Support Queue
# -----------------------------------------------------------------------------
resource "aws_connect_queue" "language_support" {
  instance_id           = var.instance_id
  name                  = "Census-Language-Support"
  description           = "Multi-language support for non-English speaking constituents"
  hours_of_operation_id = var.census_hours_id

  max_contacts = 10

  outbound_caller_config {
    outbound_caller_id_name      = "Census Language Services"
    outbound_caller_id_number_id = var.outbound_caller_id
  }

  tags = merge(var.tags, {
    QueueType = "Language-Support"
    Priority  = "Normal"
  })
}

# -----------------------------------------------------------------------------
# Routing Profiles
# -----------------------------------------------------------------------------

# AI Agent Routing Profile (no queues - AI handles everything)
resource "aws_connect_routing_profile" "ai_agent" {
  instance_id               = var.instance_id
  name                      = "Census-AI-Agent-Profile"
  description               = "Routing profile for AI agent - no queue routing needed"
  default_outbound_queue_id = aws_connect_queue.ai_self_service.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 5
  }

  tags = var.tags
}

# General Agent Routing Profile
resource "aws_connect_routing_profile" "general_agent" {
  instance_id               = var.instance_id
  name                      = "Census-General-Agent-Profile"
  description               = "Routing profile for general census enumerator agents"
  default_outbound_queue_id = aws_connect_queue.callbacks.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 3
  }

  # Queue assignments with priorities
  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.live_agents.queue_id
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.general_inquiries.queue_id
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 3
    queue_id = aws_connect_queue.callbacks.queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.live_agents.queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.general_inquiries.queue_id
  }

  tags = var.tags
}

# Specialist Routing Profile
resource "aws_connect_routing_profile" "specialist" {
  instance_id               = var.instance_id
  name                      = "Census-Specialist-Profile"
  description               = "Routing profile for census specialists handling complex cases"
  default_outbound_queue_id = aws_connect_queue.callbacks.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 2
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.specialists.queue_id
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.live_agents.queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.specialists.queue_id
  }

  tags = var.tags
}

# Supervisor Routing Profile
resource "aws_connect_routing_profile" "supervisor" {
  instance_id               = var.instance_id
  name                      = "Census-Supervisor-Profile"
  description               = "Routing profile for census supervisors"
  default_outbound_queue_id = aws_connect_queue.callbacks.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 3
  }

  # Supervisors can handle all queues
  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.supervisors.queue_id
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.specialists.queue_id
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 3
    queue_id = aws_connect_queue.live_agents.queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.supervisors.queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.live_agents.queue_id
  }

  tags = var.tags
}

# Language Support Routing Profile
resource "aws_connect_routing_profile" "language_support" {
  instance_id               = var.instance_id
  name                      = "Census-Language-Support-Profile"
  description               = "Routing profile for multilingual support agents"
  default_outbound_queue_id = aws_connect_queue.callbacks.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = 3
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.language_support.queue_id
  }

  queue_configs {
    channel  = "CHAT"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.language_support.queue_id
  }

  tags = var.tags
}
