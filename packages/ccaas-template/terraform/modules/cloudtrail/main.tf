# =============================================================================
# CloudTrail Audit Module - FedRAMP Compliant Audit Logging
# =============================================================================
#
# WHAT: Creates comprehensive audit trail for all AWS API activity
# WHY: FedRAMP requires complete audit logging with integrity verification
#
# FEDRAMP CONTROLS ADDRESSED:
# - AU-2: Audit Events
# - AU-3: Content of Audit Records
# - AU-4: Audit Storage Capacity
# - AU-6: Audit Review, Analysis, and Reporting
# - AU-7: Audit Reduction and Report Generation
# - AU-9: Protection of Audit Information
# - AU-11: Audit Record Retention
# - AU-12: Audit Generation
#
# COMPONENTS:
# - CloudTrail trail with S3 storage
# - CloudWatch Logs integration
# - S3 bucket with lifecycle policies
# - Log file integrity validation
# - Encryption with customer-managed KMS key
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Bucket for CloudTrail Logs
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.name_prefix}-cloudtrail-${var.account_id}"

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-cloudtrail-logs"
    Purpose    = "CloudTrail audit log storage"
    Compliance = "FedRAMP-AU-4,AU-9,AU-11"
    DataClass  = "Sensitive"
  })
}

# Block all public access (FedRAMP requirement)
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for audit integrity
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for log retention (FedRAMP: minimum 1 year, recommended 7 years)
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "audit-log-retention"
    status = "Enabled"

    # Move to Intelligent-Tiering after 90 days
    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }

    # Move to Glacier after 1 year
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # Move to Deep Archive after 3 years
    transition {
      days          = 1095
      storage_class = "DEEP_ARCHIVE"
    }

    # Delete after 7 years (FedRAMP maximum retention)
    expiration {
      days = 2555
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Bucket policy allowing CloudTrail access
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/${var.name_prefix}-audit-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/${var.name_prefix}-audit-trail"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedTransport"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyIncorrectEncryptionHeader"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# Enable S3 bucket logging
resource "aws_s3_bucket_logging" "cloudtrail" {
  count = var.access_log_bucket_id != "" ? 1 : 0

  bucket        = aws_s3_bucket.cloudtrail.id
  target_bucket = var.access_log_bucket_id
  target_prefix = "cloudtrail-bucket-logs/"
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for CloudTrail
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-cloudtrail-logs"
    Compliance = "FedRAMP-AU-6,AU-7"
  })
}

# IAM role for CloudTrail to write to CloudWatch
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.name_prefix}-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.name_prefix}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudTrail Trail
# -----------------------------------------------------------------------------
resource "aws_cloudtrail" "main" {
  name                          = "${var.name_prefix}-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true  # FedRAMP requires multi-region
  enable_logging                = true

  # Log file integrity validation (FedRAMP AU-9 requirement)
  enable_log_file_validation = true

  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  # KMS encryption
  kms_key_id = var.kms_key_arn

  # Data events for S3 (all buckets)
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }

  # Data events for Lambda
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  # Data events for DynamoDB
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = ["arn:aws:dynamodb"]
    }
  }

  # Insights for anomaly detection
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-audit-trail"
    Compliance = "FedRAMP-AU-2,AU-3,AU-12"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# -----------------------------------------------------------------------------
# CloudWatch Metric Filters and Alarms for Security Events
# -----------------------------------------------------------------------------

# Metric filter: Unauthorized API calls
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${var.name_prefix}-unauthorized-api-calls"
  pattern        = "{ ($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied*\") }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.name_prefix}-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Multiple unauthorized API calls detected - potential security incident"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AU-6,IR-4"
  })
}

# Metric filter: Root account usage
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  name           = "${var.name_prefix}-root-account-usage"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  alarm_name          = "${var.name_prefix}-root-account-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Root account usage detected - immediate review required"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AC-6"
  })
}

# Metric filter: IAM policy changes
resource "aws_cloudwatch_log_metric_filter" "iam_policy_changes" {
  name           = "${var.name_prefix}-iam-policy-changes"
  pattern        = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy) }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_policy_changes" {
  alarm_name          = "${var.name_prefix}-iam-policy-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "IAM policy changes detected - review for compliance"
  alarm_actions       = var.alarm_sns_topic_arns

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AC-2,CM-3"
  })
}

# Metric filter: Security group changes
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  name           = "${var.name_prefix}-security-group-changes"
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "${var.name_prefix}-security-group-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Security group changes detected - verify authorization"
  alarm_actions       = var.alarm_sns_topic_arns

  tags = merge(var.tags, {
    Compliance = "FedRAMP-CM-3,SC-7"
  })
}

# Metric filter: Console login without MFA
resource "aws_cloudwatch_log_metric_filter" "console_login_without_mfa" {
  name           = "${var.name_prefix}-console-login-no-mfa"
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "ConsoleLoginWithoutMFA"
    namespace = "${var.name_prefix}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_login_without_mfa" {
  alarm_name          = "${var.name_prefix}-console-login-no-mfa"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsoleLoginWithoutMFA"
  namespace           = "${var.name_prefix}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Console login without MFA detected - FedRAMP violation"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  tags = merge(var.tags, {
    Compliance = "FedRAMP-IA-2"
  })
}
