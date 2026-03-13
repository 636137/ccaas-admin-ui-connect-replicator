# =============================================================================
# AWS Config Rules Module - FedRAMP Continuous Compliance
# =============================================================================
#
# WHAT: Creates AWS Config rules for continuous compliance monitoring
# WHY: FedRAMP requires continuous monitoring and compliance validation
#
# FEDRAMP CONTROLS ADDRESSED:
# - CA-7: Continuous Monitoring
# - CM-2: Baseline Configuration
# - CM-3: Configuration Change Control
# - CM-6: Configuration Settings
# - SC-28: Protection of Information at Rest
# - SI-2: Flaw Remediation
#
# RULES INCLUDED:
# - Encryption requirements
# - Access control validation
# - Network security checks
# - Logging requirements
# =============================================================================

# -----------------------------------------------------------------------------
# Config Recorder and Delivery Channel
# -----------------------------------------------------------------------------

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true
    recording_strategy {
      use_only = "ALL_SUPPORTED_RESOURCE_TYPES"
    }
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.name_prefix}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.id

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# S3 Bucket for Config
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "config" {
  bucket = "${var.name_prefix}-config-${var.account_id}"

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-config-bucket"
    Purpose    = "AWS Config configuration history"
    Compliance = "FedRAMP-CA-7"
  })
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${var.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role for Config
# -----------------------------------------------------------------------------
resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "${var.name_prefix}-config-s3-policy"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.config.arn}/*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl"
        ]
        Resource = aws_s3_bucket.config.arn
      }
    ]
  })
}

# =============================================================================
# CONFIG RULES - FedRAMP Compliance Checks
# =============================================================================

# -----------------------------------------------------------------------------
# Encryption Rules (SC-28)
# -----------------------------------------------------------------------------

# S3 bucket encryption
resource "aws_config_config_rule" "s3_bucket_server_side_encryption_enabled" {
  name        = "${var.name_prefix}-s3-encryption-enabled"
  description = "Checks if S3 buckets have server-side encryption enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-28"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# DynamoDB encryption
resource "aws_config_config_rule" "dynamodb_table_encrypted_kms" {
  name        = "${var.name_prefix}-dynamodb-kms-encryption"
  description = "Checks if DynamoDB tables are encrypted with KMS"

  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTED_KMS"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-28"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# EBS encryption
resource "aws_config_config_rule" "ec2_ebs_encryption_by_default" {
  name        = "${var.name_prefix}-ebs-encryption-default"
  description = "Checks if EBS encryption is enabled by default"

  source {
    owner             = "AWS"
    source_identifier = "EC2_EBS_ENCRYPTION_BY_DEFAULT"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-28"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# RDS encryption
resource "aws_config_config_rule" "rds_storage_encrypted" {
  name        = "${var.name_prefix}-rds-storage-encrypted"
  description = "Checks if RDS DB instances have storage encryption enabled"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-28"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# CloudWatch Logs encryption
resource "aws_config_config_rule" "cloudwatch_log_group_encrypted" {
  name        = "${var.name_prefix}-cwlogs-encrypted"
  description = "Checks if CloudWatch Log Groups are encrypted with KMS"

  source {
    owner             = "AWS"
    source_identifier = "CLOUDWATCH_LOG_GROUP_ENCRYPTED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-28"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# Access Control Rules (AC-2, AC-6)
# -----------------------------------------------------------------------------

# IAM root user MFA
resource "aws_config_config_rule" "root_account_mfa_enabled" {
  name        = "${var.name_prefix}-root-mfa-enabled"
  description = "Checks if root account has MFA enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-IA-2"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# IAM user MFA
resource "aws_config_config_rule" "iam_user_mfa_enabled" {
  name        = "${var.name_prefix}-iam-user-mfa"
  description = "Checks if IAM users have MFA enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-IA-2"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# No root access keys
resource "aws_config_config_rule" "iam_root_access_key_check" {
  name        = "${var.name_prefix}-no-root-access-key"
  description = "Checks if root account has access keys"

  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AC-6"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# Password policy
resource "aws_config_config_rule" "iam_password_policy" {
  name        = "${var.name_prefix}-iam-password-policy"
  description = "Checks if IAM password policy meets requirements"

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })

  tags = merge(var.tags, {
    Compliance = "FedRAMP-IA-5"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# Logging Rules (AU-2, AU-12)
# -----------------------------------------------------------------------------

# CloudTrail enabled
resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "${var.name_prefix}-cloudtrail-enabled"
  description = "Checks if CloudTrail is enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AU-2,AU-12"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# CloudTrail log file validation
resource "aws_config_config_rule" "cloudtrail_log_file_validation" {
  name        = "${var.name_prefix}-cloudtrail-validation"
  description = "Checks if CloudTrail log file validation is enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AU-9"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# S3 bucket logging
resource "aws_config_config_rule" "s3_bucket_logging_enabled" {
  name        = "${var.name_prefix}-s3-logging-enabled"
  description = "Checks if S3 bucket logging is enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LOGGING_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AU-2"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# VPC Flow Logs
resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  name        = "${var.name_prefix}-vpc-flow-logs"
  description = "Checks if VPC Flow Logs are enabled"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AU-12,SI-4"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# Network Security Rules (SC-7)
# -----------------------------------------------------------------------------

# Security groups - no unrestricted SSH
resource "aws_config_config_rule" "restricted_ssh" {
  name        = "${var.name_prefix}-restricted-ssh"
  description = "Checks if SSH is restricted in security groups"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-7"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# Security groups - no unrestricted RDP
resource "aws_config_config_rule" "restricted_rdp" {
  name        = "${var.name_prefix}-restricted-rdp"
  description = "Checks if RDP is restricted in security groups"

  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_INCOMING_TRAFFIC"
  }

  input_parameters = jsonencode({
    blockedPort1 = "3389"
  })

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-7"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# S3 public access
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name        = "${var.name_prefix}-s3-no-public-read"
  description = "Checks if S3 buckets prohibit public read access"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AC-3,SC-7"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  name        = "${var.name_prefix}-s3-no-public-write"
  description = "Checks if S3 buckets prohibit public write access"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-AC-3,SC-7"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# Lambda in VPC
resource "aws_config_config_rule" "lambda_inside_vpc" {
  name        = "${var.name_prefix}-lambda-in-vpc"
  description = "Checks if Lambda functions are deployed in VPC"

  source {
    owner             = "AWS"
    source_identifier = "LAMBDA_INSIDE_VPC"
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-SC-7"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# Remediation (optional auto-remediation)
# -----------------------------------------------------------------------------

# SNS Topic for Config notifications
resource "aws_sns_topic" "config_notifications" {
  name              = "${var.name_prefix}-config-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-config-notifications"
  })
}

# EventBridge rule for non-compliant resources
resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name        = "${var.name_prefix}-config-noncompliant"
  description = "Triggers on AWS Config non-compliant findings"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType       = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "config_noncompliant" {
  rule      = aws_cloudwatch_event_rule.config_noncompliant.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.config_notifications.arn
}

resource "aws_sns_topic_policy" "config_notifications" {
  arn = aws_sns_topic.config_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.config_notifications.arn
      }
    ]
  })
}
