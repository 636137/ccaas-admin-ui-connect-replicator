# =============================================================================
# WAF Module - FedRAMP Compliant Web Application Firewall
# =============================================================================
#
# WHAT: Creates AWS WAF rules for web application protection
# WHY: FedRAMP requires protection against common web attacks
#
# FEDRAMP CONTROLS ADDRESSED:
# - SC-5: Denial of Service Protection
# - SC-7: Boundary Protection
# - SI-3: Malicious Code Protection
# - SI-4: Information System Monitoring
#
# RULES INCLUDED:
# - AWS Managed Rules (OWASP Top 10, Known Bad Inputs, etc.)
# - Rate limiting for DDoS protection
# - IP reputation filtering
# - SQL injection protection
# - Cross-site scripting (XSS) protection
# =============================================================================

# -----------------------------------------------------------------------------
# WAF Web ACL
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-waf"
  description = "FedRAMP compliant WAF for Census Enumerator application"
  scope       = var.scope  # REGIONAL for API Gateway/ALB, CLOUDFRONT for CloudFront

  default_action {
    allow {}
  }

  # CloudWatch metrics
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf-metrics"
    sampled_requests_enabled   = true
  }

  # Rule 1: AWS Managed Rules - Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed Rules - SQL Injection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: AWS Managed Rules - Linux OS vulnerabilities
  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-linux-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: AWS Managed Rules - Amazon IP Reputation List
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: AWS Managed Rules - Anonymous IP List (Tor, VPNs, Proxies)
  rule {
    name     = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-anon-ip"
      sampled_requests_enabled   = true
    }
  }

  # Rule 7: Rate Limiting - DDoS Protection
  rule {
    name     = "RateLimitRule"
    priority = 7

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_threshold
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 8: Geographic Restriction (US-only for government applications)
  dynamic "rule" {
    for_each = var.enable_geo_restriction ? [1] : []
    
    content {
      name     = "GeoRestriction"
      priority = 8

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = var.allowed_countries
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 9: Block requests with invalid/missing headers
  rule {
    name     = "BlockMissingHostHeader"
    priority = 9

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          byte_match_statement {
            search_string = var.expected_host_header
            field_to_match {
              single_header {
                name = "host"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-host-validation"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-waf"
    Compliance = "FedRAMP-SC-5,SC-7,SI-3,SI-4"
  })
}

# -----------------------------------------------------------------------------
# WAF Logging to CloudWatch
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-waf-logs"
    Compliance = "FedRAMP-AU-2,AU-6"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  # Redact sensitive fields from logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  # Log filter - only log blocked requests and rate-limited requests
  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"
      
      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }

    filter {
      behavior = "KEEP"
      
      condition {
        action_condition {
          action = "COUNT"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}

# -----------------------------------------------------------------------------
# IP Sets for Custom Blocking/Allowing
# -----------------------------------------------------------------------------

# Blocked IP Set (for known bad actors)
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "${var.name_prefix}-blocked-ips"
  description        = "IP addresses blocked from accessing the application"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.blocked_ip_addresses

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-blocked-ips"
  })
}

# Allowed IP Set (for trusted sources like government networks)
resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "${var.name_prefix}-allowed-ips"
  description        = "Trusted IP addresses (government networks, etc.)"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.allowed_ip_addresses

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-allowed-ips"
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for WAF Events
# -----------------------------------------------------------------------------

# Alarm: High block rate
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.name_prefix}-waf-high-block-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.block_alarm_threshold
  alarm_description   = "High number of WAF blocked requests - potential attack"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SI-4,IR-4"
  })
}

# Alarm: Rate limit breaches  
resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_breaches" {
  alarm_name          = "${var.name_prefix}-waf-rate-limit-breach"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Rate limit breach detected - possible DDoS attack"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = var.aws_region
    Rule   = "RateLimitRule"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-5,IR-4"
  })
}
