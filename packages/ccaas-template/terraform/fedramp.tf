# =============================================================================
# FedRAMP Compliance Modules
# =============================================================================
#
# WHAT: Deploys all FedRAMP compliance infrastructure
# WHY: Government CCaaS requires FedRAMP authorization
#
# FEDRAMP CONTROL FAMILIES ADDRESSED:
# - AC: Access Control
# - AU: Audit and Accountability
# - CA: Security Assessment and Authorization
# - CM: Configuration Management
# - CP: Contingency Planning
# - IA: Identification and Authentication
# - IR: Incident Response
# - SC: System and Communications Protection
# - SI: System and Information Integrity
#
# TOGGLE: Set enable_fedramp_compliance = false to disable all FedRAMP modules
# =============================================================================

# =============================================================================
# MODULE: KMS - Customer Managed Encryption Keys
# FedRAMP Controls: SC-12, SC-13, SC-28
# =============================================================================
module "kms" {
  source = "./modules/kms"
  count  = var.enable_fedramp_compliance ? 1 : 0

  name_prefix        = local.name_prefix
  account_id         = data.aws_caller_identity.current.account_id
  aws_region         = var.aws_region
  key_administrators = var.kms_key_administrators
  
  tags = local.common_tags
}

# =============================================================================
# MODULE: CloudTrail - Audit Logging
# FedRAMP Controls: AU-2, AU-3, AU-4, AU-6, AU-7, AU-9, AU-11, AU-12
# =============================================================================
module "cloudtrail" {
  source = "./modules/cloudtrail"
  count  = var.enable_fedramp_compliance ? 1 : 0

  name_prefix          = local.name_prefix
  account_id           = data.aws_caller_identity.current.account_id
  aws_region           = var.aws_region
  kms_key_arn          = module.kms[0].primary_key_arn
  logs_kms_key_arn     = module.kms[0].logs_key_arn
  log_retention_days   = var.audit_log_retention_days
  alarm_sns_topic_arns = var.security_notification_arns
  
  tags = local.common_tags

  depends_on = [module.kms]
}

# =============================================================================
# MODULE: VPC - Network Segmentation and PrivateLink
# FedRAMP Controls: SC-7, SC-8, AC-4, SC-22
# =============================================================================
module "vpc" {
  source = "./modules/vpc"
  count  = var.enable_fedramp_compliance && var.deploy_in_vpc ? 1 : 0

  name_prefix                = local.name_prefix
  aws_region                 = var.aws_region
  vpc_cidr                   = var.vpc_cidr
  availability_zones         = var.availability_zones
  enable_nat_gateway         = var.enable_nat_gateway
  single_nat_gateway         = var.single_nat_gateway
  enable_interface_endpoints = var.enable_vpc_endpoints
  logs_kms_key_arn           = var.enable_fedramp_compliance ? module.kms[0].logs_key_arn : ""
  
  tags = local.common_tags

  depends_on = [module.kms]
}

# =============================================================================
# MODULE: WAF - Web Application Firewall
# FedRAMP Controls: SC-5, SC-7, SI-3, SI-4
# =============================================================================
module "waf" {
  source = "./modules/waf"
  count  = var.enable_fedramp_compliance && var.enable_waf ? 1 : 0

  name_prefix            = local.name_prefix
  aws_region             = var.aws_region
  scope                  = "REGIONAL"
  rate_limit_threshold   = var.waf_rate_limit
  enable_geo_restriction = var.waf_geo_restriction
  allowed_countries      = var.waf_allowed_countries
  logs_kms_key_arn       = var.enable_fedramp_compliance ? module.kms[0].logs_key_arn : ""
  alarm_sns_topic_arns   = var.security_notification_arns
  
  tags = local.common_tags

  depends_on = [module.kms]
}

# =============================================================================
# MODULE: AWS Config - Continuous Compliance Monitoring
# FedRAMP Controls: CA-7, CM-2, CM-3, CM-6, SC-28, SI-2
# =============================================================================
module "config_rules" {
  source = "./modules/config-rules"
  count  = var.enable_fedramp_compliance ? 1 : 0

  name_prefix = local.name_prefix
  account_id  = data.aws_caller_identity.current.account_id
  aws_region  = var.aws_region
  kms_key_arn = module.kms[0].primary_key_arn
  
  tags = local.common_tags

  depends_on = [module.kms]
}

# =============================================================================
# MODULE: AWS Backup - Disaster Recovery
# FedRAMP Controls: CP-9, CP-10, CP-6
# =============================================================================
module "backup" {
  source = "./modules/backup"
  count  = var.enable_fedramp_compliance && var.enable_backup ? 1 : 0

  name_prefix                = local.name_prefix
  account_id                 = data.aws_caller_identity.current.account_id
  aws_region                 = var.aws_region
  kms_key_arn                = module.kms[0].primary_key_arn
  enable_cross_region_backup = var.enable_cross_region_backup
  dr_vault_arn               = var.dr_vault_arn
  backup_admin_role_arns     = var.backup_admin_role_arns
  dynamodb_table_arns        = module.dynamodb.table_arns
  report_bucket_name         = var.enable_fedramp_compliance ? module.cloudtrail[0].s3_bucket_name : ""
  
  tags = local.common_tags

  depends_on = [module.kms, module.cloudtrail, module.dynamodb]
}

# =============================================================================
# SNS Topic for Security Notifications
# =============================================================================
resource "aws_sns_topic" "security_alerts" {
  count             = var.enable_fedramp_compliance ? 1 : 0
  name              = "${local.name_prefix}-security-alerts"
  kms_master_key_id = module.kms[0].primary_key_arn

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-security-alerts"
    Compliance = "FedRAMP-IR-4,IR-6"
  })
}

# Email subscription for security alerts
resource "aws_sns_topic_subscription" "security_email" {
  count     = var.enable_fedramp_compliance && var.security_contact_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.security_contact_email
}
