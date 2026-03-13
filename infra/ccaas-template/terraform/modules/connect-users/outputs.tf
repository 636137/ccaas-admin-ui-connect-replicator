# =============================================================================
# Amazon Connect Users Module - Outputs
# =============================================================================

output "agent_security_profile_id" {
  description = "Agent security profile ID"
  value       = aws_connect_security_profile.agent.security_profile_id
}

output "supervisor_security_profile_id" {
  description = "Supervisor security profile ID"
  value       = aws_connect_security_profile.supervisor.security_profile_id
}

output "admin_security_profile_id" {
  description = "Admin security profile ID"
  value       = aws_connect_security_profile.admin.security_profile_id
}

output "agent_user_ids" {
  description = "List of agent user IDs"
  value       = [for agent in aws_connect_user.agents : agent.user_id]
}

output "agent_user_arns" {
  description = "List of agent user ARNs"
  value       = [for agent in aws_connect_user.agents : agent.arn]
}

output "supervisor_user_id" {
  description = "Supervisor user ID"
  value       = aws_connect_user.supervisor.user_id
}

output "supervisor_user_arn" {
  description = "Supervisor user ARN"
  value       = aws_connect_user.supervisor.arn
}

output "census_bureau_hierarchy_group_id" {
  description = "Census Bureau hierarchy group ID"
  value       = aws_connect_user_hierarchy_group.census_bureau.hierarchy_group_id
}

output "enumerators_hierarchy_group_id" {
  description = "Enumerators hierarchy group ID"
  value       = aws_connect_user_hierarchy_group.enumerators.hierarchy_group_id
}

output "supervisors_hierarchy_group_id" {
  description = "Supervisors hierarchy group ID"
  value       = aws_connect_user_hierarchy_group.supervisors.hierarchy_group_id
}

output "all_users" {
  description = "Map of all user names to IDs"
  value = merge(
    { for agent in aws_connect_user.agents : agent.name => agent.user_id },
    { (aws_connect_user.supervisor.name) = aws_connect_user.supervisor.user_id }
  )
}
output "security_profile_ids" {
  description = "Map of security profile names to IDs"
  value = {
    "Census-Agent"      = aws_connect_security_profile.agent.security_profile_id
    "Census-Supervisor" = aws_connect_security_profile.supervisor.security_profile_id
    "Census-Admin"      = aws_connect_security_profile.admin.security_profile_id
  }
}