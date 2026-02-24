# DynamoDB Module - Main

resource "aws_dynamodb_table" "census_responses" {
  name         = "${var.name_prefix}-census-responses"
  billing_mode = var.billing_mode
  hash_key     = "caseId"
  range_key    = "timestamp"

  attribute {
    name = "caseId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "confirmationNumber"
    type = "S"
  }

  # Global Secondary Index for status queries
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # Global Secondary Index for confirmation number lookups
  global_secondary_index {
    name            = "confirmation-index"
    hash_key        = "confirmationNumber"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-census-responses"
  })
}

resource "aws_dynamodb_table" "census_addresses" {
  name         = "${var.name_prefix}-census-addresses"
  billing_mode = var.billing_mode
  hash_key     = "addressId"

  attribute {
    name = "addressId"
    type = "S"
  }

  attribute {
    name = "phoneNumber"
    type = "S"
  }

  attribute {
    name = "zipCode"
    type = "S"
  }

  # Global Secondary Index for phone number lookups
  global_secondary_index {
    name            = "phoneNumber-index"
    hash_key        = "phoneNumber"
    projection_type = "ALL"
  }

  # Global Secondary Index for zip code queries
  global_secondary_index {
    name            = "zipCode-index"
    hash_key        = "zipCode"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.kms_key_arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-census-addresses"
  })
}

resource "aws_dynamodb_table" "census_callbacks" {
  name         = "${var.name_prefix}-census-callbacks"
  billing_mode = var.billing_mode
  hash_key     = "callbackId"
  range_key    = "scheduledTime"

  attribute {
    name = "callbackId"
    type = "S"
  }

  attribute {
    name = "scheduledTime"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # Global Secondary Index for status queries
  global_secondary_index {
    name            = "callback-status-index"
    hash_key        = "status"
    range_key       = "scheduledTime"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.kms_key_arn
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-census-callbacks"
  })
}
