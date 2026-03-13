# Service Quotas and Limits Guide

> **Government CCaaS in a Box** - AWS Service Quotas, Amazon Connect Limits, and Multi-Tenant Considerations

This document outlines critical service quotas, limits, and "gotchas" for deploying Government CCaaS in a Box at scale.

---

## Table of Contents

1. [AWS Account-Level Service Quotas](#aws-account-level-service-quotas)
2. [Amazon Connect Specific Limits](#amazon-connect-specific-limits)
3. [Single Government Entity Deployment](#single-government-entity-deployment)
4. [Multi-Tenant Deployment](#multi-tenant-deployment-multiple-government-entities)
5. [Multi-Tenant Resource Tagging Strategy](#multi-tenant-resource-tagging-strategy)
6. [Critical Gotchas](#critical-gotchas)
7. [Quota Increase Request Process](#quota-increase-request-process)
8. [Monitoring Quota Usage](#monitoring-quota-usage)

---

## AWS Account-Level Service Quotas

### Amazon Connect

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Connect instances per account | 2 | ✅ Yes | Request increase for multi-tenant |
| Concurrent active calls per instance | 100 | ✅ Yes | Critical for sizing |
| Concurrent active chats per instance | 1,000 | ✅ Yes | Chat is less resource-intensive |
| Concurrent active tasks per instance | 2,500 | ✅ Yes | |
| Phone numbers per instance | 50 | ✅ Yes | Toll-free and DID combined |
| Contact flows per instance | 100 | ✅ Yes | Includes all flow types |
| Prompts per instance | 500 | ✅ Yes | Audio prompts (greetings, etc.) |
| Queues per instance | 50 | ✅ Yes | Critical for multi-tenant |
| Quick connects per instance | 100 | ✅ Yes | |
| Routing profiles per instance | 100 | ✅ Yes | |
| Hours of operation per instance | 100 | ✅ Yes | |
| Users (agents) per instance | 500 | ✅ Yes | Critical for large deployments |
| Security profiles per instance | 100 | ✅ Yes | |
| Agent hierarchy groups per instance | 50 | ✅ Yes | |
| Lambda functions per instance | 50 | ✅ Yes | |
| Lex bots per instance | 50 | ✅ Yes | |
| Contact flow modules per instance | 200 | ✅ Yes | |

### Amazon Lex V2

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Bots per account | 100 | ✅ Yes | |
| Aliases per bot | 100 | ✅ Yes | |
| Intents per bot locale | 200 | ✅ Yes | Survey intents can add up |
| Slot types per bot locale | 200 | ✅ Yes | |
| Utterances per intent | 1,500 | ✅ Yes | |
| Concurrent conversations | 1,000 | ✅ Yes | Match to Connect concurrency |
| Voice requests per second | 25 | ✅ Yes | **CRITICAL** - often a bottleneck |
| Text requests per second | 50 | ✅ Yes | For chat channel |

### Amazon Bedrock

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Claude 3 Sonnet - Input TPM | 400,000 | ✅ Yes | Tokens per minute |
| Claude 3 Sonnet - Output TPM | 80,000 | ✅ Yes | |
| Claude 3 Sonnet - Requests/min | 1,000 | ✅ Yes | |
| Bedrock Agents per account | 10 | ✅ Yes | Request increase early |
| Agent aliases per agent | 10 | ✅ Yes | |
| Action groups per agent | 20 | ❌ No | Hard limit |
| Knowledge bases per account | 50 | ✅ Yes | |

### AWS Lambda

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Concurrent executions (account) | 1,000 | ✅ Yes | Shared across all functions |
| Function memory | 128 MB - 10,240 MB | N/A | |
| Function timeout | 15 minutes max | N/A | Connect flows timeout at 20-30s |
| Deployment package size | 50 MB (zip), 250 MB (unzipped) | ❌ No | |
| Environment variables | 4 KB total | ❌ No | |
| /tmp directory storage | 10,240 MB | N/A | |
| Layers per function | 5 | ❌ No | |

### Amazon DynamoDB

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Tables per account per region | 2,500 | ✅ Yes | |
| Account max read capacity units | 80,000 | ✅ Yes | On-demand scales automatically |
| Account max write capacity units | 80,000 | ✅ Yes | |
| Maximum item size | 400 KB | ❌ No | Hard limit |
| Partition key length | 2,048 bytes | ❌ No | |
| Sort key length | 1,024 bytes | ❌ No | |
| Local secondary indexes per table | 5 | ❌ No | |
| Global secondary indexes per table | 20 | ❌ No | |
| Projected attributes per index | 100 | ❌ No | |

### Amazon S3

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Buckets per account | 100 | ✅ Yes | |
| Objects per bucket | Unlimited | N/A | |
| Object size | 5 TB max | ❌ No | |
| PUT/COPY/POST requests | 3,500/sec/prefix | N/A | Scale by using more prefixes |
| GET/HEAD requests | 5,500/sec/prefix | N/A | |

### AWS KMS

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Customer managed keys per account | 100,000 | N/A | Effectively unlimited |
| Cryptographic operations/sec | 5,500-30,000 | ✅ Yes | Varies by key type |
| Aliases per account | 10,000 | ✅ Yes | |
| Grants per key | 50,000 | N/A | |

### Amazon CloudWatch

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Dashboards per account | 5,000 | N/A | |
| Alarms per account per region | 5,000 | ✅ Yes | |
| Metrics per PutMetricData request | 1,000 | ❌ No | |
| Log groups per account | 1,000,000 | N/A | |
| Log events per PutLogEvents request | 10,000 | ❌ No | |

### AWS WAF

| Resource | Default Limit | Adjustable | Notes |
|----------|--------------|------------|-------|
| Web ACLs per account per region | 100 | ✅ Yes | |
| Rules per web ACL | 1,500 WCUs | ✅ Yes | Web ACL Capacity Units |
| Rate-based rules per web ACL | 10 | ✅ Yes | |
| IP sets per account per region | 100 | ✅ Yes | |
| IPs per IP set | 10,000 | ✅ Yes | |

---

## Amazon Connect Specific Limits

### Contact Flow Limits

| Limit | Value | Impact |
|-------|-------|--------|
| Maximum contact flow size | 1 MB | Complex flows may need to be split |
| Maximum blocks per flow | 500 | Use flow modules for large surveys |
| Lambda timeout in flow | 20 seconds | Long operations must be async |
| Loop iterations max | 100 | Limit on household member iteration |
| Contact attributes size | 32 KB total | All attributes combined |
| Single attribute value | 32 KB | |
| Custom attribute count | No hard limit | But total size capped at 32 KB |

### Agent and Queue Limits

| Limit | Value | Impact |
|-------|-------|--------|
| Queues an agent can be assigned | 50 | Via routing profile |
| Skills per agent | 100 | For skill-based routing |
| Contacts per agent (concurrent) | 1-10 voice, 1-10 chat/task | Configurable per routing profile |
| Queue priority levels | 1-99 | Lower number = higher priority |
| Tags per resource | 50 | For cost allocation |

### Recording and Storage Limits

| Limit | Value | Impact |
|-------|-------|--------|
| Recording retention | 24 months in Connect | Export to S3 for longer |
| Screen recording per agent | 8 hours/day max | |
| Recorded call export delay | ~5 minutes | Not real-time |
| CTR (Contact Trace Record) retention | 24 months | Export for compliance |

### API Limits (Relevant for Automation)

| API Operation | Requests/Second | Burst | Notes |
|---------------|-----------------|-------|-------|
| StartOutboundVoiceContact | 25 | 50 | Outbound dialing |
| GetCurrentMetricData | 5 | 8 | Real-time metrics |
| GetMetricData | 5 | 8 | Historical metrics |
| SearchContacts | 2 | 2 | Search/analytics |
| CreateUser | 2 | 2 | Agent provisioning |
| UpdateContactAttributes | 100 | 100 | During contact |
| ListPhoneNumbers | 5 | 5 | |
| AssociatePhoneNumberContactFlow | 2 | 2 | |

### Contact Lens Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Categories per rule | 100 | |
| Custom vocabulary entries | 500 | Per locale |
| Rules per instance | 500 | Across all types |
| Real-time alert delay | 5-10 seconds | Not instantaneous |

---

## Single Government Entity Deployment

### Recommended Quotas for Single Entity

For a single government agency running CCaaS in a Box:

#### Small Agency (< 50 agents, < 5,000 contacts/month)
```
Connect concurrent calls:        100  (default sufficient)
Connect users:                   100
Queues:                          20
Lambda concurrent executions:    500
DynamoDB RCU/WCU:               On-demand
Lex voice requests/sec:         25  (default may need increase)
Bedrock requests/min:           500
```

#### Medium Agency (50-200 agents, 5,000-50,000 contacts/month)
```
Connect concurrent calls:        500  (request increase)
Connect users:                   500
Queues:                          50
Phone numbers:                   100
Lambda concurrent executions:    1,000
DynamoDB RCU/WCU:               On-demand
Lex voice requests/sec:         100  (request increase)
Bedrock requests/min:           2,000  (request increase)
```

#### Large Agency (200+ agents, 50,000+ contacts/month)
```
Connect concurrent calls:        2,000+ (request increase)
Connect users:                   2,000+
Queues:                          100+
Phone numbers:                   500+
Lambda concurrent executions:    5,000+
DynamoDB RCU/WCU:               On-demand (monitor hot partitions)
Lex voice requests/sec:         500+  (request increase)
Bedrock requests/min:           10,000+ (request increase)
```

### Single Entity Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    SINGLE AGENCY DEPLOYMENT                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              AMAZON CONNECT INSTANCE                      │  │
│   │                                                          │  │
│   │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │  │
│   │  │ Queue 1 │  │ Queue 2 │  │ Queue 3 │  │  AI Bot │    │  │
│   │  │ General │  │ Spanish │  │ Escalate│  │ Census  │    │  │
│   │  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │  │
│   │                                                          │  │
│   │  Agents: 50-500          Phone Numbers: 10-100          │  │
│   │  Concurrent Calls: 100-2,000                            │  │
│   └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    SHARED SERVICES                        │  │
│   │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐        │  │
│   │  │DynamoDB│  │ Lambda │  │  Lex   │  │Bedrock │        │  │
│   │  │1 Table │  │2 Funcs │  │ 1 Bot  │  │1 Agent │        │  │
│   │  └────────┘  └────────┘  └────────┘  └────────┘        │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Multi-Tenant Deployment (Multiple Government Entities)

### Architecture Options

#### Option 1: Separate Connect Instances per Tenant (Recommended for Government)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SEPARATE INSTANCES (RECOMMENDED)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │  AGENCY A INSTANCE │  │  AGENCY B INSTANCE │  │  AGENCY C INSTANCE │    │
│  │                    │  │                    │  │                    │    │
│  │  - Own phone #s    │  │  - Own phone #s    │  │  - Own phone #s    │    │
│  │  - Own agents      │  │  - Own agents      │  │  - Own agents      │    │
│  │  - Own queues      │  │  - Own queues      │  │  - Own queues      │    │
│  │  - Own recordings  │  │  - Own recordings  │  │  - Own recordings  │    │
│  │                    │  │                    │  │                    │    │
│  │  DynamoDB: AgencyA │  │  DynamoDB: AgencyB │  │  DynamoDB: AgencyC │    │
│  │  Bedrock: AgentA   │  │  Bedrock: AgentB   │  │  Bedrock: AgentC   │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  PROS:                           CONS:                                       │
│  ✅ Complete data isolation      ❌ Higher base cost (~$0.10/day/instance)  │
│  ✅ Independent scaling          ❌ More infrastructure to manage           │
│  ✅ Agency-specific compliance   ❌ Need quota increase (>2 instances)      │
│  ✅ Simpler billing separation   ❌ Phone number inventory per instance     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Option 2: Shared Connect Instance (Multi-Tenant)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SHARED INSTANCE (MULTI-TENANT)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    SINGLE CONNECT INSTANCE                              │ │
│  │                                                                         │ │
│  │   Agency A                Agency B                Agency C             │ │
│  │  ┌─────────┐            ┌─────────┐            ┌─────────┐            │ │
│  │  │Queue-A1 │            │Queue-B1 │            │Queue-C1 │            │ │
│  │  │Queue-A2 │            │Queue-B2 │            │Queue-C2 │            │ │
│  │  │Agents A │            │Agents B │            │Agents C │            │ │
│  │  │Phones A │            │Phones B │            │Phones C │            │ │
│  │  └─────────┘            └─────────┘            └─────────┘            │ │
│  │                                                                         │ │
│  │  TENANT ISOLATION VIA:                                                  │ │
│  │  • Security profiles (who sees what)                                   │ │
│  │  • Contact attributes (tenant_id on every contact)                     │ │
│  │  • Queue naming conventions (AGENCY-A-*, AGENCY-B-*)                   │ │
│  │  • Hierarchies (agency → division → team)                              │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                               │                                              │
│                               ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    SHARED BACKEND WITH PARTITIONING                     │ │
│  │                                                                         │ │
│  │  DynamoDB: Single table with tenant_id partition key                   │ │
│  │  Example: PK = "AGENCY-A#CASE-123", SK = "PERSON#1"                    │ │
│  │                                                                         │ │
│  │  S3: Separate prefixes per tenant                                      │ │
│  │  Example: s3://recordings/agency-a/2024/03/15/call-123.wav            │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  PROS:                           CONS:                                       │
│  ✅ Lower base infrastructure    ❌ Complex security configuration          │
│  ✅ Easier capacity management   ❌ Noisy neighbor risk                     │
│  ✅ Simpler quota management     ❌ Shared phone number pool                │
│  ✅ One deployment to maintain   ❌ Data isolation concerns for gov         │
│                                  ❌ Cross-agency visibility risks           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Multi-Tenant Quota Planning

For a shared instance serving multiple agencies:

```
# Example: 5 agencies, 100 agents each, 500 total

Connect Instance Limits Required:
  Users:                    500+ (500 default may be sufficient)
  Queues:                   50+ (10 per agency × 5 = 50)
  Routing Profiles:         25+ (5 per agency × 5 = 25)
  Phone Numbers:            100+ (20 per agency × 5 = 100)
  Security Profiles:        25+ (5 per agency × 5 = 25)
  Contact Flows:            50+ (10 per agency × 5 = 50)
  
  CRITICAL: Concurrent calls must handle peak across ALL agencies
  Concurrent Calls:         500+ (100 per agency peak assumed)
  
Backend Quotas (Shared):
  Lambda Concurrent:        2,000+ (account-wide, not per-function)
  DynamoDB:                 On-demand (auto-scales, watch hot partitions)
  Lex Voice Requests/Sec:   100+ (25 default × 5 agencies = need 125+)
  Bedrock Requests/Min:     2,000+ (peak across all agencies)
```

### Multi-Tenant Security Considerations

| Concern | Mitigation |
|---------|------------|
| **Agent sees other agency's data** | Security profiles limit queue/metric visibility |
| **Cross-agency call transfers** | Restrict quick connects per security profile |
| **Recording access** | S3 bucket policies with tenant prefixes |
| **DynamoDB data leakage** | Always filter by tenant_id in queries |
| **Metrics/reports** | Dashboard filters, saved reports per agency |
| **Contact search** | Add tenant_id as required search parameter |

### Multi-Tenant Terraform Configuration

```hcl
# Example: Multi-tenant module structure
variable "tenants" {
  type = map(object({
    name               = string
    phone_number_count = number
    agent_count        = number
    queues             = list(string)
  }))
  default = {
    "agency-a" = {
      name               = "Agency A - Census Bureau"
      phone_number_count = 20
      agent_count        = 100
      queues             = ["general", "spanish", "escalation"]
    }
    "agency-b" = {
      name               = "Agency B - Social Security"
      phone_number_count = 30
      agent_count        = 150
      queues             = ["retirement", "disability", "medicare"]
    }
  }
}

# Create queues with tenant prefix
resource "aws_connect_queue" "tenant_queues" {
  for_each = { for item in flatten([
    for tenant_key, tenant in var.tenants : [
      for queue in tenant.queues : {
        tenant_key = tenant_key
        queue_name = queue
        tenant     = tenant
      }
    ]
  ]) : "${item.tenant_key}-${item.queue_name}" => item }

  name        = upper("${each.value.tenant_key}-${each.value.queue_name}")
  instance_id = aws_connect_instance.this.id
  
  tags = {
    Tenant = each.value.tenant_key
  }
}
```

---

## Multi-Tenant Resource Tagging Strategy

Proper tagging is **essential** for multi-tenant Government CCaaS deployments. Tags enable cost allocation, access control, compliance reporting, and operational automation.

### Mandatory Tag Schema

Every resource MUST have these tags:

| Tag Key | Description | Example Values | Used For |
|---------|-------------|----------------|----------|
| `Tenant` | Primary tenant/agency identifier | `agency-census`, `agency-ssa`, `agency-va` | Cost allocation, access control |
| `Environment` | Deployment environment | `production`, `staging`, `development` | Environment separation |
| `Project` | Project/program name | `ccaas-gov`, `census-2030`, `va-helpdesk` | Cost tracking |
| `CostCenter` | Financial cost center | `CC-12345`, `CENSUS-OPS-001` | Chargeback, billing |
| `DataClassification` | Data sensitivity level | `public`, `pii`, `phi`, `fedramp-high` | Compliance, security |
| `Owner` | Team or individual owner | `census-tech-team`, `john.smith@agency.gov` | Accountability |
| `ManagedBy` | How resource is managed | `terraform`, `console`, `cloudformation` | Automation tracking |
| `CreatedDate` | Resource creation date | `2026-02-08` | Lifecycle management |

### AWS Cost Allocation Tags

Enable these tags as **Cost Allocation Tags** in AWS Billing:

```bash
# Enable cost allocation tags via CLI
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status TagKey=Tenant,Status=Active \
                                TagKey=CostCenter,Status=Active \
                                TagKey=Environment,Status=Active \
                                TagKey=Project,Status=Active
```

> **Note:** Cost allocation tags take 24 hours to appear in Cost Explorer after activation.

### Terraform Tagging Implementation

#### Default Tags Provider Configuration

```hcl
# terraform/providers.tf
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project          = "Government-CCaaS"
      Environment      = var.environment
      ManagedBy        = "terraform"
      Repository       = "github.com/org/ccaas-gov"
      DeploymentDate   = timestamp()
    }
  }
}
```

#### Tenant-Specific Tag Module

```hcl
# terraform/modules/tagging/main.tf

variable "tenant_id" {
  description = "Tenant identifier"
  type        = string
}

variable "tenant_name" {
  description = "Human-readable tenant name"
  type        = string
}

variable "cost_center" {
  description = "Financial cost center for billing"
  type        = string
}

variable "data_classification" {
  description = "Data sensitivity classification"
  type        = string
  default     = "pii"
  validation {
    condition     = contains(["public", "pii", "phi", "fedramp-high"], var.data_classification)
    error_message = "Must be: public, pii, phi, or fedramp-high"
  }
}

variable "owner" {
  description = "Team or individual owner"
  type        = string
}

locals {
  common_tags = {
    Tenant             = var.tenant_id
    TenantName         = var.tenant_name
    CostCenter         = var.cost_center
    DataClassification = var.data_classification
    Owner              = var.owner
    CreatedDate        = formatdate("YYYY-MM-DD", timestamp())
  }
}

output "tags" {
  value = local.common_tags
}
```

#### Using Tags Across Resources

```hcl
# terraform/main.tf

module "tenant_tags" {
  source = "./modules/tagging"
  
  tenant_id           = "agency-census"
  tenant_name         = "U.S. Census Bureau"
  cost_center         = "CENSUS-CC-2030"
  data_classification = "pii"
  owner               = "census-contact-center-team"
}

# Apply to Connect resources
resource "aws_connect_queue" "survey_queue" {
  name        = "CENSUS-Survey-Queue"
  instance_id = aws_connect_instance.main.id
  
  tags = merge(module.tenant_tags.tags, {
    ResourceType = "connect-queue"
    QueueType    = "survey"
  })
}

# Apply to Lambda functions
resource "aws_lambda_function" "survey_handler" {
  function_name = "census-survey-handler"
  # ... other config
  
  tags = merge(module.tenant_tags.tags, {
    ResourceType = "lambda"
    Purpose      = "survey-response-handler"
  })
}

# Apply to DynamoDB tables
resource "aws_dynamodb_table" "survey_responses" {
  name = "census-survey-responses"
  # ... other config
  
  tags = merge(module.tenant_tags.tags, {
    ResourceType = "dynamodb"
    TableType    = "survey-data"
  })
}

# Apply to S3 buckets
resource "aws_s3_bucket" "recordings" {
  bucket = "gov-ccaas-census-recordings"
  
  tags = merge(module.tenant_tags.tags, {
    ResourceType = "s3"
    BucketType   = "call-recordings"
  })
}
```

### Tag-Based Access Control (ABAC)

Use tags for fine-grained access control:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowTenantResourceAccess",
      "Effect": "Allow",
      "Action": [
        "connect:Describe*",
        "connect:List*",
        "connect:Get*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Tenant": "${aws:PrincipalTag/Tenant}"
        }
      }
    },
    {
      "Sid": "AllowDynamoDBTenantAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Tenant": "${aws:PrincipalTag/Tenant}"
        }
      }
    },
    {
      "Sid": "AllowS3TenantBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::gov-ccaas-*-recordings",
        "arn:aws:s3:::gov-ccaas-*-recordings/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Tenant": "${aws:PrincipalTag/Tenant}"
        }
      }
    }
  ]
}
```

### Tag-Based Resource Groups

Organize resources by tenant using AWS Resource Groups:

```hcl
# terraform/modules/tenant/resource_group.tf

resource "aws_resourcegroups_group" "tenant" {
  name        = "tenant-${var.tenant_id}-resources"
  description = "All resources for tenant ${var.tenant_name}"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Tenant"
          Values = [var.tenant_id]
        }
      ]
    })
  }

  tags = {
    Tenant      = var.tenant_id
    Purpose     = "resource-organization"
    ManagedBy   = "terraform"
  }
}
```

### AWS Organizations Tag Policies

Enforce tagging compliance across accounts:

```json
{
  "tags": {
    "Tenant": {
      "tag_key": {
        "@@assign": "Tenant"
      },
      "enforced_for": {
        "@@assign": [
          "connect:instance",
          "connect:queue",
          "lambda:function",
          "dynamodb:table",
          "s3:bucket",
          "kms:key"
        ]
      }
    },
    "DataClassification": {
      "tag_key": {
        "@@assign": "DataClassification"
      },
      "tag_value": {
        "@@assign": ["public", "pii", "phi", "fedramp-high"]
      },
      "enforced_for": {
        "@@assign": [
          "dynamodb:table",
          "s3:bucket",
          "lambda:function"
        ]
      }
    },
    "CostCenter": {
      "tag_key": {
        "@@assign": "CostCenter"
      },
      "enforced_for": {
        "@@assign": [
          "connect:instance",
          "lambda:function",
          "dynamodb:table",
          "s3:bucket"
        ]
      }
    }
  }
}
```

### Tagging Automation Scripts

#### Audit Untagged Resources

```bash
#!/bin/bash
# scripts/audit-tags.sh

echo "=== Untagged or Non-Compliant Resources ==="

# Check Lambda functions
echo -e "\n--- Lambda Functions Missing Tenant Tag ---"
aws lambda list-functions --query 'Functions[?!Tags.Tenant].FunctionName' --output table

# Check DynamoDB tables
echo -e "\n--- DynamoDB Tables Missing Tenant Tag ---"
for table in $(aws dynamodb list-tables --query 'TableNames[]' --output text); do
  tags=$(aws dynamodb list-tags-of-resource \
    --resource-arn "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${table}" \
    --query "Tags[?Key=='Tenant'].Value" --output text)
  if [ -z "$tags" ]; then
    echo "  - $table"
  fi
done

# Check S3 buckets
echo -e "\n--- S3 Buckets Missing Tenant Tag ---"
for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  tags=$(aws s3api get-bucket-tagging --bucket "$bucket" 2>/dev/null | \
    jq -r '.TagSet[] | select(.Key=="Tenant") | .Value')
  if [ -z "$tags" ]; then
    echo "  - $bucket"
  fi
done

# Check Connect queues
echo -e "\n--- Connect Queues Missing Tenant Tag ---"
for instance in $(aws connect list-instances --query 'InstanceSummaryList[].Id' --output text); do
  for queue in $(aws connect list-queues --instance-id "$instance" \
    --query 'QueueSummaryList[].Id' --output text); do
    tags=$(aws connect list-tags-for-resource \
      --resource-arn "arn:aws:connect:${AWS_REGION}:${AWS_ACCOUNT_ID}:instance/${instance}/queue/${queue}" \
      --query "tags.Tenant" --output text)
    if [ "$tags" == "None" ] || [ -z "$tags" ]; then
      echo "  - Instance: $instance, Queue: $queue"
    fi
  done
done
```

#### Auto-Tag Non-Compliant Resources

```bash
#!/bin/bash
# scripts/auto-tag.sh - Add missing mandatory tags

TENANT="${1:-unknown}"
COST_CENTER="${2:-UNASSIGNED}"
OWNER="${3:-platform-team}"

echo "=== Auto-tagging untagged resources ==="
echo "Tenant: $TENANT"
echo "CostCenter: $COST_CENTER"
echo "Owner: $OWNER"

# Tag Lambda functions
for func in $(aws lambda list-functions --query 'Functions[?!Tags.Tenant].FunctionArn' --output text); do
  echo "Tagging Lambda: $func"
  aws lambda tag-resource --resource "$func" \
    --tags "Tenant=$TENANT,CostCenter=$COST_CENTER,Owner=$OWNER,DataClassification=pii"
done

# Tag DynamoDB tables
for table in $(aws dynamodb list-tables --query 'TableNames[]' --output text); do
  arn="arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${table}"
  existing=$(aws dynamodb list-tags-of-resource --resource-arn "$arn" \
    --query "Tags[?Key=='Tenant'].Value" --output text)
  if [ -z "$existing" ]; then
    echo "Tagging DynamoDB: $table"
    aws dynamodb tag-resource --resource-arn "$arn" \
      --tags Key=Tenant,Value=$TENANT \
             Key=CostCenter,Value=$COST_CENTER \
             Key=Owner,Value=$OWNER \
             Key=DataClassification,Value=pii
  fi
done
```

### Cost Allocation Reporting

Generate per-tenant cost reports:

```bash
#!/bin/bash
# scripts/tenant-cost-report.sh

START_DATE="${1:-$(date -v-30d +%Y-%m-%d)}"
END_DATE="${2:-$(date +%Y-%m-%d)}"

echo "=== Tenant Cost Report ($START_DATE to $END_DATE) ==="

# Get costs grouped by Tenant tag
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics "BlendedCost" "UnblendedCost" "UsageQuantity" \
  --group-by Type=TAG,Key=Tenant \
  --query 'ResultsByTime[].Groups[].{Tenant: Keys[0], Cost: Metrics.BlendedCost.Amount}' \
  --output table

echo -e "\n=== Service Breakdown by Tenant ==="

for tenant in agency-census agency-ssa agency-va; do
  echo -e "\n--- $tenant ---"
  aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity MONTHLY \
    --metrics "BlendedCost" \
    --filter "{\"Tags\": {\"Key\": \"Tenant\", \"Values\": [\"$tenant\"]}}" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[].Groups[].{Service: Keys[0], Cost: Metrics.BlendedCost.Amount}' \
    --output table
done
```

### Tagging Best Practices Summary

| Best Practice | Description |
|---------------|-------------|
| **Tag Early** | Apply tags at resource creation, not after |
| **Automate** | Use Terraform default_tags and modules |
| **Enforce** | Use AWS Organizations tag policies |
| **Audit** | Run weekly compliance checks |
| **Document** | Maintain tag schema documentation |
| **Standardize** | Use consistent naming (lowercase, hyphens) |
| **Cost Tags** | Activate cost allocation tags in Billing |
| **ABAC** | Use tags for access control policies |
| **Groups** | Create Resource Groups per tenant |
| **Review** | Monthly tag policy compliance review |

### Tag Values Standardization

```
# Recommended tag value formats:

Tenant:             lowercase, hyphenated (agency-census, agency-ssa)
Environment:        lowercase (production, staging, development, dr)
CostCenter:         uppercase with hyphens (CC-12345, CENSUS-OPS-001)
DataClassification: lowercase (public, pii, phi, fedramp-high)
Owner:              lowercase, hyphenated (census-tech-team)
ManagedBy:          lowercase (terraform, console, cloudformation)
CreatedDate:        ISO format (2026-02-08)
```

---

## Critical Gotchas

### 🚨 Category 1: Showstoppers (Can Block Deployment)

| Gotcha | Impact | Mitigation |
|--------|--------|------------|
| **Lex voice requests/sec (25 default)** | AI calls fail under load | Request increase to 100+ BEFORE go-live |
| **Connect instances (2 per account)** | Can't deploy multi-tenant separate instances | Request increase 4-6 weeks before needed |
| **Bedrock model access** | AI doesn't work at all | Request Claude access immediately |
| **Phone number availability** | No numbers to claim | Check inventory in region; toll-free easier |
| **Lambda concurrent executions (1,000 account)** | Other apps affected | Reserve capacity or dedicated account |

### 🚨 Category 2: Performance Killers

| Gotcha | Impact | Mitigation |
|--------|--------|------------|
| **DynamoDB hot partitions** | Throttling, failed saves | Use tenant_id + caseId as composite key |
| **Lambda cold starts** | 2-5 second delay | Use provisioned concurrency ($) or keep warm |
| **Lex slot resolution timeout** | Caller hears silence | Set timeout; use fallback prompts |
| **Bedrock throttling** | AI responses fail | Implement exponential backoff |
| **S3 prefix throttling** | Recording upload failures | Use date-based prefixes |

### 🚨 Category 3: Compliance/Security Risks

| Gotcha | Impact | Mitigation |
|--------|--------|------------|
| **CloudTrail logs disabled by default** | No audit trail | Enable in Terraform (done in FedRAMP module) |
| **Default encryption keys** | AWS-managed, not customer | Create CMKs (done in FedRAMP module) |
| **VPC endpoints not configured** | Traffic goes over internet | Deploy VPC module with endpoints |
| **IAM policies too permissive** | Security finding | Use least-privilege (review IAM module) |
| **Recording retention** | Only 24 months native | Export to S3 with lifecycle policy |

### 🚨 Category 4: Operational Surprises

| Gotcha | Impact | Mitigation |
|--------|--------|------------|
| **Phone number porting takes 2-4 weeks** | Delayed launch | Start porting process early |
| **Contact Lens not in all regions** | Features unavailable | Verify region support before design |
| **Outbound caller ID requirements** | Calls blocked/flagged | Register with carriers (STIR/SHAKEN) |
| **Agent status sync delay** | Wrong agent availability shown | Account for 5-10s propagation |
| **Real-time metrics lag** | Dashboard shows stale data | Use GetCurrentMetricData with retry |

### 🚨 Category 5: Cost Surprises

| Gotcha | Impact | Mitigation |
|--------|--------|------------|
| **Telephony charges are per-minute** | Higher costs than expected | AI handles more, humans less = savings |
| **Chat contacts billed per message** | Long chats add up | Set conversation time limits |
| **Data transfer out charges** | Exports cost money | Process in-region; use VPC endpoints |
| **Provisioned concurrency** | $15+/month per function | Use only for production |
| **WAF request fees** | Per-million requests | Baseline at ~$6/million |

### 🚨 Category 6: Multi-Tenant Specific

| Gotcha | Impact | Mitigation |
|--------|--------|------------|
| **Noisy neighbor in shared instance** | Agency A surge affects Agency B | Monitor per-tenant; have capacity buffer |
| **Queue limit (50 default)** | Can't add more agencies | Request increase; consolidate queues |
| **Security profile complexity** | Hard to maintain | Automate with Terraform |
| **Cost attribution** | Can't bill per agency | Use tags religiously; AWS Cost Allocation Tags |
| **Audit separation** | Mixed logs | Filter by tenant_id; consider separate CloudTrail trails |
| **Shared bot confusion** | AI responds with wrong agency context | Include tenant context in every prompt |

---

## Quota Increase Request Process

### How to Request Quota Increases

1. **AWS Console Method:**
   ```
   AWS Console → Service Quotas → Amazon Connect
   → Select quota → Request quota increase
   → Provide business justification
   ```

2. **AWS CLI Method:**
   ```bash
   aws service-quotas request-service-quota-increase \
     --service-code connect \
     --quota-code L-8E309C4C \
     --desired-value 500
   ```

3. **Terraform Method:**
   ```hcl
   resource "aws_servicequotas_service_quota" "connect_concurrent_calls" {
     quota_code   = "L-8E309C4C"
     service_code = "connect"
     value        = 500
   }
   ```

### Quota Codes Reference

| Service | Quota | Code |
|---------|-------|------|
| Connect | Concurrent calls | L-8E309C4C |
| Connect | Users per instance | L-F5FEC574 |
| Connect | Phone numbers | L-C4FE7B79 |
| Connect | Queues | L-B15FC19B |
| Lambda | Concurrent executions | L-B99A9384 |
| Lex | Voice requests/sec | L-05BCE0FB |
| Bedrock | Claude requests/min | L-ABCD1234 |

### Timeline for Quota Increases

| Quota Type | Typical Approval Time | Notes |
|------------|----------------------|-------|
| Soft limits (auto-approve) | Minutes to hours | Most compute/storage |
| Connect instances | 1-3 business days | Requires review |
| Connect concurrent calls (large) | 1-2 weeks | Capacity planning |
| Bedrock model access | Minutes (often instant) | One-time |
| Lex voice requests | 1-3 days | Often auto-approved |
| GovCloud quotas | 1-2 weeks | Extra scrutiny |

---

## Monitoring Quota Usage

### CloudWatch Dashboard for Quotas

```hcl
# terraform/modules/monitoring/quota_dashboard.tf

resource "aws_cloudwatch_dashboard" "quota_monitoring" {
  dashboard_name = "${var.name_prefix}-quota-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Connect Concurrent Calls"
          metrics = [
            ["AWS/Connect", "ConcurrentCalls", "InstanceId", var.connect_instance_id]
          ]
          period = 60
          stat   = "Maximum"
          annotations = {
            horizontal = [
              {
                label = "Quota (${var.concurrent_calls_quota})"
                value = var.concurrent_calls_quota
                color = "#ff0000"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Concurrent Executions"
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions"]
          ]
          period = 60
          stat   = "Maximum"
          annotations = {
            horizontal = [
              {
                label = "Quota (1000)"
                value = 1000
                color = "#ff0000"
              }
            ]
          }
        }
      }
    ]
  })
}
```

### Quota Alarms

```hcl
# Alert when reaching 80% of quota
resource "aws_cloudwatch_metric_alarm" "concurrent_calls_high" {
  alarm_name          = "${var.name_prefix}-high-concurrent-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConcurrentCalls"
  namespace           = "AWS/Connect"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.concurrent_calls_quota * 0.8
  alarm_description   = "Concurrent calls above 80% of quota"

  dimensions = {
    InstanceId = var.connect_instance_id
  }

  alarm_actions = [var.alert_sns_topic_arn]
}
```

### Quota Usage Report Script

```bash
#!/bin/bash
# scripts/check_quotas.sh - Check current quota usage

echo "=== Amazon Connect Quotas ==="
aws service-quotas get-service-quota \
  --service-code connect \
  --quota-code L-8E309C4C \
  --query '{Quota: QuotaName, Value: Value}' \
  --output table

echo ""
echo "=== Current Usage ==="
aws connect get-current-metric-data \
  --instance-id $CONNECT_INSTANCE_ID \
  --filters "Queues=$QUEUE_ID" \
  --current-metrics "Name=AGENTS_ONLINE" "Name=CONTACTS_IN_QUEUE" \
  --query 'MetricResults[*].Collections[*].{Metric: Metric.Name, Value: Value}' \
  --output table

echo ""
echo "=== Lambda Concurrent Executions ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Maximum \
  --query 'Datapoints | max_by(@, &Maximum).Maximum' \
  --output text

echo ""
echo "=== Lex Request Rate ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/LexV2 \
  --metric-name RecognizeUtteranceRequestCount \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Sum \
  --query 'Datapoints | sort_by(@, &Timestamp) | [-1].Sum' \
  --output text
```

---

## Summary: Quota Planning Checklist

### Before Deployment

- [ ] Request Amazon Bedrock Claude model access
- [ ] Request Connect instance quota increase (if multi-tenant separate)
- [ ] Request Lex voice requests/sec increase (25 → 100+)
- [ ] Verify phone number inventory in target region
- [ ] Request Lambda concurrent execution increase if sharing account

### During Deployment

- [ ] Enable Service Quotas alarms
- [ ] Deploy CloudWatch dashboard for quota monitoring
- [ ] Configure auto-scaling where available (DynamoDB On-Demand)

### For Multi-Tenant

- [ ] Document tenant isolation strategy
- [ ] Create security profiles per tenant
- [ ] Establish queue naming conventions
- [ ] Set up cost allocation tags
- [ ] Plan capacity buffer (20% overhead minimum)

### Ongoing Operations

- [ ] Weekly quota usage review
- [ ] Monthly capacity planning review
- [ ] Quarterly quota increase requests (ahead of growth)
- [ ] Document and track all quota increases

---

**Last Updated:** February 2026

**Related Documentation:**
- [AWS Service Quotas Documentation](https://docs.aws.amazon.com/servicequotas/latest/userguide/intro.html)
- [Amazon Connect Service Quotas](https://docs.aws.amazon.com/connect/latest/adminguide/amazon-connect-service-limits.html)
- [FEDRAMP_COMPLIANCE.md](FEDRAMP_COMPLIANCE.md) - Security controls
- [DISASTER_RECOVERY.md](DISASTER_RECOVERY.md) - DR procedures
