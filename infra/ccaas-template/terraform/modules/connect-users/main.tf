# =============================================================================
# Amazon Connect Users Module
# =============================================================================
#
# WHAT: Creates test users (agents and supervisor) for Census Enumerator
# WHY: Need users to handle escalations and test the system
#
# USERS CREATED:
# - 5 Test Agents (Census Enumerators)
# - 1 Test Supervisor
#
# NOTE: Uses CONNECT_MANAGED identity. For production, integrate with SAML/AD.
# =============================================================================

# -----------------------------------------------------------------------------
# Security Profiles
# -----------------------------------------------------------------------------

# Agent Security Profile
resource "aws_connect_security_profile" "agent" {
  instance_id = var.instance_id
  name        = "Census-Agent-Profile"
  description = "Security profile for Census Enumerator agents"

  permissions = [
    # Basic agent permissions
    "BasicAgentAccess",
    "OutboundCallAccess",
    
    # Contact Control Panel (CCP)
    "AccessContactControlPanel",
    
    # Contact handling
    "ContactSearch",
    "ContactSearch.ByAgent",
    "ContactSearch.ByContactId",
    
    # Voice and chat
    "VoiceId.DescribeFraudster",
    
    # Quick connects
    "TransferDestinations",
    
    # Agent status
    "AgentStates.View",
  ]

  tags = var.tags
}

# Supervisor Security Profile
resource "aws_connect_security_profile" "supervisor" {
  instance_id = var.instance_id
  name        = "Census-Supervisor-Profile"
  description = "Security profile for Census supervisors with monitoring capabilities"

  permissions = [
    # All agent permissions
    "BasicAgentAccess",
    "OutboundCallAccess",
    "AccessContactControlPanel",
    "ContactSearch",
    "ContactSearch.ByAgent",
    "ContactSearch.ByContactId",
    "TransferDestinations",
    "AgentStates.View",
    
    # Supervisor permissions
    "ManagerListenIn",
    "ManagerBargeIn",
    "ManagerSilentMonitor",
    
    # Real-time monitoring
    "RealTimeContactMonitoring",
    "AccessMetrics",
    "AgentActivityAudit",
    
    # Reporting
    "MetricsReports",
    "HistoricalReports",
    "ScheduledReports",
    "LoginLogoutReports",
    
    # Quality management
    "ContactRecording.Access",
    "ContactRecording.Review",
    "ContactLens.ViewContactAnalysis",
    "ContactEvaluation.FormDesigner",
    "ContactEvaluation.ConfigureEvaluation",
    "ContactEvaluation.Evaluate",
    
    # User management (view only)
    "Users.View",
    "AgentStates.Manage",
    
    # Queue management
    "QueuesAndRoutingProfiles.View",
  ]

  tags = var.tags
}

# Admin Security Profile (for initial setup)
resource "aws_connect_security_profile" "admin" {
  instance_id = var.instance_id
  name        = "Census-Admin-Profile"
  description = "Full admin access for Census system configuration"

  permissions = [
    # All Permissions
    "Admin",
  ]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Test Agents (5 agents)
# -----------------------------------------------------------------------------

resource "aws_connect_user" "agents" {
  count = 5

  instance_id = var.instance_id
  name        = "census-agent-${count.index + 1}"

  identity_info {
    first_name = "Agent"
    last_name  = "${count.index + 1}"
    email      = var.agent_emails[count.index]
  }

  phone_config {
    phone_type                    = "SOFT_PHONE"
    auto_accept                   = false
    after_contact_work_time_limit = 60
  }

  routing_profile_id   = var.agent_routing_profile_id
  security_profile_ids = [aws_connect_security_profile.agent.security_profile_id]

  tags = merge(var.tags, {
    Role       = "Agent"
    AgentIndex = count.index + 1
  })
}

# -----------------------------------------------------------------------------
# Test Supervisor (1 supervisor)
# -----------------------------------------------------------------------------

resource "aws_connect_user" "supervisor" {
  instance_id = var.instance_id
  name        = "census-supervisor-1"

  identity_info {
    first_name = "Supervisor"
    last_name  = "One"
    email      = var.supervisor_email
  }

  phone_config {
    phone_type                    = "SOFT_PHONE"
    auto_accept                   = false
    after_contact_work_time_limit = 120
  }

  routing_profile_id   = var.supervisor_routing_profile_id
  security_profile_ids = [aws_connect_security_profile.supervisor.security_profile_id]

  tags = merge(var.tags, {
    Role = "Supervisor"
  })
}

# -----------------------------------------------------------------------------
# Agent Hierarchy Groups (for organization and reporting)
# -----------------------------------------------------------------------------

resource "aws_connect_user_hierarchy_group" "census_bureau" {
  instance_id = var.instance_id
  name        = "Census-Bureau"

  tags = var.tags
}

resource "aws_connect_user_hierarchy_group" "enumerators" {
  instance_id    = var.instance_id
  name           = "Enumerators"
  parent_group_id = aws_connect_user_hierarchy_group.census_bureau.hierarchy_group_id

  tags = var.tags
}

resource "aws_connect_user_hierarchy_group" "supervisors" {
  instance_id    = var.instance_id
  name           = "Supervisors"
  parent_group_id = aws_connect_user_hierarchy_group.census_bureau.hierarchy_group_id

  tags = var.tags
}

resource "aws_connect_user_hierarchy_group" "specialists" {
  instance_id    = var.instance_id
  name           = "Specialists"
  parent_group_id = aws_connect_user_hierarchy_group.census_bureau.hierarchy_group_id

  tags = var.tags
}
