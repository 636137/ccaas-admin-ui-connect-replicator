# =============================================================================
# Amazon Connect Instance Module
# =============================================================================
#
# WHAT: Creates the Amazon Connect instance with all required features enabled
# WHY: Foundation for the contact center - required before queues, users, flows
#
# FEATURES ENABLED:
# - Contact Lens analytics (real-time and post-call)
# - Contact flow logs
# - Early media (for voice)
# - Multi-party calls/chat
# - Auto-resolve best voices
# =============================================================================

# -----------------------------------------------------------------------------
# Amazon Connect Instance
# -----------------------------------------------------------------------------
resource "aws_connect_instance" "main" {
  identity_management_type = var.identity_management_type
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
  instance_alias           = var.instance_alias

  # Enable all analytics and features
  contact_flow_logs_enabled      = true
  contact_lens_enabled           = true
  early_media_enabled            = true
  multi_party_conference_enabled = true
  auto_resolve_best_voices_enabled = true

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Instance Storage Config - S3 for recordings and transcripts
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "connect_storage" {
  bucket = "${var.name_prefix}-connect-storage-${var.name_suffix}"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-connect-storage"
  })
}

resource "aws_s3_bucket_versioning" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for Connect access
resource "aws_s3_bucket_policy" "connect_storage" {
  bucket = aws_s3_bucket.connect_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowConnectAccess"
        Effect    = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.connect_storage.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
          ArnLike = {
            "aws:SourceArn" = aws_connect_instance.main.arn
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Connect Instance Storage Configurations
# -----------------------------------------------------------------------------

# Call recordings storage
resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.id
      bucket_prefix = "CallRecordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn != "" ? var.kms_key_arn : "alias/aws/connect"
      }
    }
  }
}

# Chat transcripts storage
resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.id
      bucket_prefix = "ChatTranscripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn != "" ? var.kms_key_arn : "alias/aws/connect"
      }
    }
  }
}

# Contact Lens exports
resource "aws_connect_instance_storage_config" "contact_lens" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CONTACT_TRACE_RECORDS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.id
      bucket_prefix = "ContactLens"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn != "" ? var.kms_key_arn : "alias/aws/connect"
      }
    }
  }
}

# Scheduled reports
resource "aws_connect_instance_storage_config" "scheduled_reports" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "SCHEDULED_REPORTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = aws_s3_bucket.connect_storage.id
      bucket_prefix = "Reports"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.kms_key_arn != "" ? var.kms_key_arn : "alias/aws/connect"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Hours of Operation - Census Survey Hours
# -----------------------------------------------------------------------------
resource "aws_connect_hours_of_operation" "census_hours" {
  instance_id = aws_connect_instance.main.id
  name        = "Census-Survey-Hours"
  description = "Operating hours for Census Enumerator surveys - Extended hours for constituent convenience"
  time_zone   = "America/New_York"

  # Monday - Friday: 8 AM to 9 PM ET
  dynamic "config" {
    for_each = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
    content {
      day = config.value
      start_time {
        hours   = 8
        minutes = 0
      }
      end_time {
        hours   = 21
        minutes = 0
      }
    }
  }

  # Saturday: 9 AM to 5 PM ET
  config {
    day = "SATURDAY"
    start_time {
      hours   = 9
      minutes = 0
    }
    end_time {
      hours   = 17
      minutes = 0
    }
  }

  # Sunday: 12 PM to 5 PM ET
  config {
    day = "SUNDAY"
    start_time {
      hours   = 12
      minutes = 0
    }
    end_time {
      hours   = 17
      minutes = 0
    }
  }

  tags = var.tags
}

# 24/7 Hours for AI Agent (no live agents needed)
resource "aws_connect_hours_of_operation" "always_open" {
  instance_id = aws_connect_instance.main.id
  name        = "AI-Agent-24x7"
  description = "24/7 availability for AI-handled census surveys"
  time_zone   = "America/New_York"

  dynamic "config" {
    for_each = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
    content {
      day = config.value
      start_time {
        hours   = 0
        minutes = 0
      }
      end_time {
        hours   = 23
        minutes = 59
      }
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Quick Connect for transfers
# -----------------------------------------------------------------------------
resource "aws_connect_quick_connect" "supervisor_quick_connect" {
  instance_id = aws_connect_instance.main.id
  name        = "Census-Supervisor"
  description = "Quick connect to reach Census supervisor for escalations"

  quick_connect_config {
    quick_connect_type = "PHONE_NUMBER"
    phone_config {
      phone_number = var.supervisor_phone_number
    }
  }

  tags = var.tags
}
