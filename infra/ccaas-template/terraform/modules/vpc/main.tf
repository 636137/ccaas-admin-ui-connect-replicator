# =============================================================================
# VPC Module - FedRAMP Compliant Network Architecture
# =============================================================================
#
# WHAT: Creates secure VPC with private subnets and VPC endpoints
# WHY: FedRAMP requires network segmentation and encrypted transit
#
# FEDRAMP CONTROLS ADDRESSED:
# - SC-7: Boundary Protection
# - SC-8: Transmission Confidentiality and Integrity
# - AC-4: Information Flow Enforcement
# - SC-22: Architecture and Provisioning for Name/Address Resolution Service
#
# ARCHITECTURE:
# - 3 Availability Zones for high availability
# - Private subnets for Lambda and internal resources
# - Public subnets (optional) for NAT Gateway
# - VPC Endpoints (PrivateLink) for AWS service access
# - VPC Flow Logs for network monitoring
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-vpc"
    Compliance = "FedRAMP-SC-7"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway (for public subnets if enabled)
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# -----------------------------------------------------------------------------
# Subnets - Private (for Lambda, internal resources)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-private-${var.availability_zones[count.index]}"
    Type       = "Private"
    Compliance = "FedRAMP-SC-7"
  })
}

# -----------------------------------------------------------------------------
# Subnets - Public (for NAT Gateway if enabled)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = var.enable_nat_gateway ? length(var.availability_zones) : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index + length(var.availability_zones))
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false  # FedRAMP: No auto-assign public IPs

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${var.availability_zones[count.index]}"
    Type = "Public"
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT Gateways (for outbound internet access from private subnets)
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Private route table
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
    Type = "Private"
  })
}

# Route to NAT Gateway for private subnets (if NAT enabled)
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Private subnet associations
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Public route table
resource "aws_route_table" "public" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
    Type = "Public"
  })
}

# Public subnet associations
resource "aws_route_table_association" "public" {
  count          = var.enable_nat_gateway ? length(var.availability_zones) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# -----------------------------------------------------------------------------
# Security Group for VPC Endpoints
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-vpc-endpoints-sg"
    Compliance = "FedRAMP-SC-7"
  })
}

# -----------------------------------------------------------------------------
# Security Group for Lambda Functions
# -----------------------------------------------------------------------------
resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS outbound (if NAT enabled)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-lambda-sg"
    Compliance = "FedRAMP-SC-7"
  })
}

# -----------------------------------------------------------------------------
# VPC Endpoints (PrivateLink) - Interface Endpoints
# =============================================================================
# These allow Lambda and other resources to access AWS services without
# going over the public internet (FedRAMP SC-7, SC-8 compliance)
# -----------------------------------------------------------------------------

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-dynamodb-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-s3-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# Lambda Interface Endpoint
resource "aws_vpc_endpoint" "lambda" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-lambda-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-secrets-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# KMS Interface Endpoint
resource "aws_vpc_endpoint" "kms" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-kms-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-logs-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# Bedrock Runtime Interface Endpoint
resource "aws_vpc_endpoint" "bedrock_runtime" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-bedrock-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# SNS Interface Endpoint
resource "aws_vpc_endpoint" "sns" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-sns-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# STS Interface Endpoint (for IAM role assumption)
resource "aws_vpc_endpoint" "sts" {
  count               = var.enable_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-sts-endpoint"
    Compliance = "FedRAMP-SC-8"
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs - Network traffic monitoring
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name_prefix}-flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-vpc-flow-logs"
    Compliance = "FedRAMP-AU-12,SI-4"
  })
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60  # 1 minute intervals for near real-time monitoring

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-vpc-flow-log"
    Compliance = "FedRAMP-AU-12,SI-4"
  })
}

# -----------------------------------------------------------------------------
# Network ACLs - Additional layer of network security
# -----------------------------------------------------------------------------
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow inbound HTTPS from VPC
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 443
    to_port    = 443
  }

  # Allow inbound ephemeral ports (for return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow outbound HTTPS
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow outbound ephemeral ports
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-private-nacl"
    Compliance = "FedRAMP-SC-7"
  })
}
