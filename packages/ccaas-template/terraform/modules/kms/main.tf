# =============================================================================
# KMS Encryption Module - FedRAMP Compliant Key Management
# =============================================================================
#
# WHAT: Creates Customer Managed Keys (CMKs) for all service encryption
# WHY: FedRAMP requires encryption at rest with customer-controlled keys
#
# FEDRAMP CONTROLS ADDRESSED:
# - SC-12: Cryptographic Key Establishment and Management
# - SC-13: Cryptographic Protection
# - SC-28: Protection of Information at Rest
#
# KEYS CREATED:
# - Primary key for general encryption (DynamoDB, S3, etc.)
# - Connect-specific key for recordings and transcripts
# - CloudWatch Logs key for log encryption
# - Secrets key for sensitive configuration data
# =============================================================================

# -----------------------------------------------------------------------------
# Primary Encryption Key - Used for DynamoDB, S3, and general encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "primary" {
  description             = "${var.name_prefix} Primary Encryption Key"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true  # FedRAMP requires annual key rotation
  
  # Key policy allowing key administration and usage
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "primary-key-policy"
    Statement = [
      # Allow root account full access (required)
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Allow key administrators
      {
        Sid    = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = var.key_administrators
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      # Allow service usage
      {
        Sid    = "AllowServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = [
            "dynamodb.amazonaws.com",
            "s3.amazonaws.com",
            "lambda.amazonaws.com",
            "logs.amazonaws.com",
            "connect.amazonaws.com"
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = var.account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-primary-key"
    Purpose    = "Primary encryption for all services"
    Compliance = "FedRAMP-SC-12,SC-13,SC-28"
  })
}

resource "aws_kms_alias" "primary" {
  name          = "alias/${var.name_prefix}-primary"
  target_key_id = aws_kms_key.primary.key_id
}

# -----------------------------------------------------------------------------
# Connect Recordings Key - Specific key for voice recordings and transcripts
# -----------------------------------------------------------------------------
resource "aws_kms_key" "connect" {
  description             = "${var.name_prefix} Connect Recordings Encryption Key"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "connect-key-policy"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowConnectService"
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = var.account_id
          }
        }
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-connect-key"
    Purpose    = "Connect recordings and transcripts encryption"
    Compliance = "FedRAMP-SC-28"
  })
}

resource "aws_kms_alias" "connect" {
  name          = "alias/${var.name_prefix}-connect"
  target_key_id = aws_kms_key.connect.key_id
}

# -----------------------------------------------------------------------------
# CloudWatch Logs Key - For encrypted log storage
# -----------------------------------------------------------------------------
resource "aws_kms_key" "logs" {
  description             = "${var.name_prefix} CloudWatch Logs Encryption Key"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "logs-key-policy"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-logs-key"
    Purpose    = "CloudWatch Logs encryption"
    Compliance = "FedRAMP-AU-9"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# -----------------------------------------------------------------------------
# Secrets Key - For Secrets Manager and sensitive configuration
# -----------------------------------------------------------------------------
resource "aws_kms_key" "secrets" {
  description             = "${var.name_prefix} Secrets Encryption Key"
  deletion_window_in_days = var.key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "secrets-key-policy"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManager"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-secrets-key"
    Purpose    = "Secrets Manager encryption"
    Compliance = "FedRAMP-SC-12"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}
