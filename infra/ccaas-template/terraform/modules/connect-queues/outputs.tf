# =============================================================================
# Amazon Connect Queues Module - Outputs
# =============================================================================

# Queue IDs
output "ai_self_service_queue_id" {
  description = "AI Self-Service queue ID"
  value       = aws_connect_queue.ai_self_service.queue_id
}

output "general_inquiries_queue_id" {
  description = "General Inquiries queue ID"
  value       = aws_connect_queue.general_inquiries.queue_id
}

output "live_agents_queue_id" {
  description = "Live Agents queue ID"
  value       = aws_connect_queue.live_agents.queue_id
}

output "specialists_queue_id" {
  description = "Specialists queue ID"
  value       = aws_connect_queue.specialists.queue_id
}

output "supervisors_queue_id" {
  description = "Supervisors queue ID"
  value       = aws_connect_queue.supervisors.queue_id
}

output "callbacks_queue_id" {
  description = "Callbacks queue ID"
  value       = aws_connect_queue.callbacks.queue_id
}

output "language_support_queue_id" {
  description = "Language Support queue ID"
  value       = aws_connect_queue.language_support.queue_id
}

# Queue ARNs
output "ai_self_service_queue_arn" {
  description = "AI Self-Service queue ARN"
  value       = aws_connect_queue.ai_self_service.arn
}

output "live_agents_queue_arn" {
  description = "Live Agents queue ARN"
  value       = aws_connect_queue.live_agents.arn
}

output "supervisors_queue_arn" {
  description = "Supervisors queue ARN"
  value       = aws_connect_queue.supervisors.arn
}

output "specialists_queue_arn" {
  description = "Specialists queue ARN"
  value       = aws_connect_queue.specialists.arn
}

# Routing Profile IDs
output "ai_agent_routing_profile_id" {
  description = "AI Agent routing profile ID"
  value       = aws_connect_routing_profile.ai_agent.routing_profile_id
}

output "general_agent_routing_profile_id" {
  description = "General Agent routing profile ID"
  value       = aws_connect_routing_profile.general_agent.routing_profile_id
}

output "specialist_routing_profile_id" {
  description = "Specialist routing profile ID"
  value       = aws_connect_routing_profile.specialist.routing_profile_id
}

output "supervisor_routing_profile_id" {
  description = "Supervisor routing profile ID"
  value       = aws_connect_routing_profile.supervisor.routing_profile_id
}

output "language_support_routing_profile_id" {
  description = "Language Support routing profile ID"
  value       = aws_connect_routing_profile.language_support.routing_profile_id
}

# All queue IDs as a map for easy reference
output "all_queue_ids" {
  description = "Map of all queue names to IDs"
  value = {
    ai_self_service   = aws_connect_queue.ai_self_service.queue_id
    general_inquiries = aws_connect_queue.general_inquiries.queue_id
    live_agents       = aws_connect_queue.live_agents.queue_id
    specialists       = aws_connect_queue.specialists.queue_id
    supervisors       = aws_connect_queue.supervisors.queue_id
    callbacks         = aws_connect_queue.callbacks.queue_id
    language_support  = aws_connect_queue.language_support.queue_id
  }
}
# Queue IDs map (alternate naming for compatibility)
output "queue_ids" {
  description = "Map of queue names to IDs"
  value = {
    "Census-AI-Self-Service"     = aws_connect_queue.ai_self_service.queue_id
    "Census-General-Inquiries"   = aws_connect_queue.general_inquiries.queue_id
    "Census-Live-Agents"         = aws_connect_queue.live_agents.queue_id
    "Census-Specialists"         = aws_connect_queue.specialists.queue_id
    "Census-Supervisors"         = aws_connect_queue.supervisors.queue_id
    "Census-Callbacks"           = aws_connect_queue.callbacks.queue_id
    "Census-Language-Support"    = aws_connect_queue.language_support.queue_id
  }
}

# All routing profile IDs as a map
output "routing_profile_ids" {
  description = "Map of routing profile names to IDs"
  value = {
    "Census-AI-Agent"          = aws_connect_routing_profile.ai_agent.routing_profile_id
    "Census-General-Agent"     = aws_connect_routing_profile.general_agent.routing_profile_id
    "Census-Specialist"        = aws_connect_routing_profile.specialist.routing_profile_id
    "Census-Supervisor"        = aws_connect_routing_profile.supervisor.routing_profile_id
    "Census-Language-Support"  = aws_connect_routing_profile.language_support.routing_profile_id
  }
}