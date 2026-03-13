# =============================================================================
# AWS Backup Module - FedRAMP Compliant Backup and Disaster Recovery
# =============================================================================
#
# WHAT: Creates automated backup plans for all critical resources
# WHY: FedRAMP requires backup and recovery capabilities
#
# FEDRAMP CONTROLS ADDRESSED:
# - CP-9: Information System Backup
# - CP-10: Information System Recovery and Reconstitution
# - CP-6: Alternate Storage Site
#
# BACKUP STRATEGY:
# - Daily backups with 35-day retention
# - Monthly backups with 1-year retention
# - Cross-region copy for disaster recovery
# - Encrypted backups with customer-managed KMS key
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Backup Vault (Primary)
# -----------------------------------------------------------------------------
resource "aws_backup_vault" "primary" {
  name        = "${var.name_prefix}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-backup-vault"
    Purpose    = "Primary backup storage"
    Compliance = "FedRAMP-CP-9"
  })
}

# NOTE: Cross-region DR vault should be created separately in DR region
# or use AWS Backup's built-in cross-account/cross-region copy feature
# The copy_action in the backup plan handles cross-region replication automatically

# Vault access policy - restrict to specific IAM roles
resource "aws_backup_vault_policy" "primary" {
  backup_vault_name = aws_backup_vault.primary.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictVaultAccess"
        Effect = "Deny"
        Principal = "*"
        Action = [
          "backup:DeleteBackupVault",
          "backup:DeleteRecoveryPoint",
          "backup:UpdateRecoveryPointLifecycle"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = var.backup_admin_role_arns
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM Role for AWS Backup
# -----------------------------------------------------------------------------
resource "aws_iam_role" "backup" {
  name = "${var.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Custom policy for DynamoDB and S3 backups
resource "aws_iam_role_policy" "backup_custom" {
  name = "${var.name_prefix}-backup-custom-policy"
  role = aws_iam_role.backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:CreateBackup",
          "dynamodb:DeleteBackup",
          "dynamodb:DescribeBackup",
          "dynamodb:ListBackups",
          "dynamodb:RestoreTableFromBackup",
          "dynamodb:RestoreTableToPointInTime"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Backup Plan - Daily Backups
# -----------------------------------------------------------------------------
resource "aws_backup_plan" "daily" {
  name = "${var.name_prefix}-daily-backup"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 5 * * ? *)"  # Daily at 5 AM UTC
    start_window      = 60   # Start within 1 hour
    completion_window = 180  # Complete within 3 hours

    lifecycle {
      cold_storage_after = 30   # Move to cold storage after 30 days
      delete_after       = 35   # Delete after 35 days (FedRAMP minimum)
    }

    # Cross-region copy for DR (requires DR vault ARN to be provided)
    dynamic "copy_action" {
      for_each = var.enable_cross_region_backup && var.dr_vault_arn != "" ? [1] : []
      content {
        destination_vault_arn = var.dr_vault_arn
        lifecycle {
          cold_storage_after = 30
          delete_after       = 35
        }
      }
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Daily"
      Compliance = "FedRAMP-CP-9"
    })
  }

  # Weekly backup with longer retention
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 5 ? * SUN *)"  # Weekly on Sunday at 5 AM UTC
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = 30
      delete_after       = 90  # Keep weekly backups for 90 days
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Weekly"
      Compliance = "FedRAMP-CP-9"
    })
  }

  # Monthly backup with 1-year retention
  rule {
    rule_name         = "monthly-backup"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 5 1 * ? *)"  # First day of month at 5 AM UTC
    start_window      = 60
    completion_window = 180

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365  # Keep monthly backups for 1 year
    }

    dynamic "copy_action" {
      for_each = var.enable_cross_region_backup && var.dr_vault_arn != "" ? [1] : []
      content {
        destination_vault_arn = var.dr_vault_arn
        lifecycle {
          cold_storage_after = 30
          delete_after       = 365
        }
      }
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "Monthly"
      Compliance = "FedRAMP-CP-9"
    })
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-backup-plan"
    Compliance = "FedRAMP-CP-9,CP-10"
  })
}

# -----------------------------------------------------------------------------
# Backup Selection - Resources to backup
# -----------------------------------------------------------------------------
resource "aws_backup_selection" "all" {
  name         = "${var.name_prefix}-backup-selection"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup.arn

  # Backup all resources with specific tags
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  # Also backup resources by ARN
  resources = var.backup_resource_arns
}

# Backup selection for DynamoDB tables specifically
resource "aws_backup_selection" "dynamodb" {
  name         = "${var.name_prefix}-dynamodb-backup"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = var.dynamodb_table_arns
}

# -----------------------------------------------------------------------------
# Backup Notifications
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "backup_notifications" {
  name              = "${var.name_prefix}-backup-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backup-notifications"
  })
}

resource "aws_backup_vault_notifications" "primary" {
  backup_vault_name   = aws_backup_vault.primary.name
  sns_topic_arn       = aws_sns_topic.backup_notifications.arn
  backup_vault_events = [
    "BACKUP_JOB_STARTED",
    "BACKUP_JOB_COMPLETED",
    "BACKUP_JOB_FAILED",
    "RESTORE_JOB_STARTED",
    "RESTORE_JOB_COMPLETED",
    "RESTORE_JOB_FAILED",
    "COPY_JOB_STARTED",
    "COPY_JOB_SUCCESSFUL",
    "COPY_JOB_FAILED"
  ]
}

# SNS topic policy
resource "aws_sns_topic_policy" "backup_notifications" {
  arn = aws_sns_topic.backup_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.backup_notifications.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Backup Failures
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "backup_job_failed" {
  alarm_name          = "${var.name_prefix}-backup-job-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = 86400  # 24 hours
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "AWS Backup job failed - immediate investigation required"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]
  ok_actions          = [aws_sns_topic.backup_notifications.arn]

  dimensions = {
    BackupVaultName = aws_backup_vault.primary.name
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-CP-9"
  })
}

resource "aws_cloudwatch_metric_alarm" "backup_job_expired" {
  alarm_name          = "${var.name_prefix}-backup-job-expired"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfBackupJobsExpired"
  namespace           = "AWS/Backup"
  period              = 86400
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "AWS Backup job expired before completion"
  alarm_actions       = [aws_sns_topic.backup_notifications.arn]

  dimensions = {
    BackupVaultName = aws_backup_vault.primary.name
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-CP-9"
  })
}

# -----------------------------------------------------------------------------
# Report Plan - Backup Compliance Reports
# -----------------------------------------------------------------------------
resource "aws_backup_report_plan" "compliance" {
  name        = "${var.name_prefix}-backup-compliance-report"
  description = "FedRAMP compliance report for backup jobs"

  report_delivery_channel {
    s3_bucket_name = var.report_bucket_name
    s3_key_prefix  = "backup-reports"
    formats        = ["CSV", "JSON"]
  }

  report_setting {
    report_template = "BACKUP_JOB_REPORT"
    accounts        = [var.account_id]
    regions         = [var.aws_region]
  }

  tags = merge(var.tags, {
    Compliance = "FedRAMP-CP-9"
  })
}
