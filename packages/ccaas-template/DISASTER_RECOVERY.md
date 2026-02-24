# Disaster Recovery Guide

> **Government CCaaS in a Box** - Comprehensive DR Procedures for Amazon Connect Across FedRAMP Regions

This document provides disaster recovery procedures, automation scripts, and runbooks for migrating or failing over Government CCaaS in a Box between AWS FedRAMP-authorized regions.

---

## Table of Contents

1. [DR Strategy Overview](#dr-strategy-overview)
2. [FedRAMP Regions Reference](#fedramp-regions-reference)
3. [Recovery Time Objectives (RTO/RPO)](#recovery-time-objectives)
4. [Pre-Disaster Preparation](#pre-disaster-preparation)
5. [DR Procedures](#dr-procedures)
6. [Automated Failover Scripts](#automated-failover-scripts)
7. [Post-Failover Validation](#post-failover-validation)
8. [Failback Procedures](#failback-procedures)
9. [DR Testing Schedule](#dr-testing-schedule)

---

## DR Strategy Overview

### Amazon Connect DR Limitations

**Critical Understanding:** Amazon Connect instances **cannot be replicated or migrated** natively. DR requires:

1. **Pre-provisioned standby instance** in DR region
2. **Configuration export/import** (phone numbers, flows, users)
3. **Data replication** (DynamoDB Global Tables, S3 Cross-Region)
4. **Phone number failover** (toll-free reconditioning or new numbers)

### DR Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DISASTER RECOVERY ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   PRIMARY REGION (us-east-1)              DR REGION (us-west-2)              │
│   ═══════════════════════════             ═══════════════════════            │
│                                                                              │
│   ┌─────────────────────┐                 ┌─────────────────────┐           │
│   │  CONNECT INSTANCE   │                 │  CONNECT INSTANCE   │           │
│   │  (ACTIVE)           │                 │  (WARM STANDBY)     │           │
│   │                     │  ──Config───▶   │                     │           │
│   │  Phone: +1-888-xxx  │                 │  Phone: +1-888-yyy  │           │
│   │  Users: 100 active  │                 │  Users: Synced      │           │
│   │  Queues: Configured │                 │  Queues: Configured │           │
│   └─────────────────────┘                 └─────────────────────┘           │
│            │                                         │                       │
│            ▼                                         ▼                       │
│   ┌─────────────────────┐                 ┌─────────────────────┐           │
│   │     DYNAMODB        │═══Global═══▶   │     DYNAMODB        │           │
│   │  (Primary Writer)   │    Tables      │   (DR Replica)      │           │
│   └─────────────────────┘                 └─────────────────────┘           │
│            │                                         │                       │
│            ▼                                         ▼                       │
│   ┌─────────────────────┐                 ┌─────────────────────┐           │
│   │        S3           │═══Cross════▶   │        S3           │           │
│   │  (Recordings)       │   Region       │   (Replicated)      │           │
│   │                     │   Repl.        │                     │           │
│   └─────────────────────┘                 └─────────────────────┘           │
│                                                                              │
│            │                                         │                       │
│            ▼                                         ▼                       │
│   ┌─────────────────────────────────────────────────────────────────┐       │
│   │                     ROUTE 53 (DNS FAILOVER)                      │       │
│   │                                                                  │       │
│   │   chat.agency.gov ──────▶  Primary ALB (us-east-1)              │       │
│   │         │                                                        │       │
│   │         └─── Failover ──▶  DR ALB (us-west-2)                    │       │
│   │                                                                  │       │
│   │   Voice: Toll-free reconditioning / new number announcement     │       │
│   │                                                                  │       │
│   └─────────────────────────────────────────────────────────────────┘       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## FedRAMP Regions Reference

### FedRAMP High Regions (AWS GovCloud)

| Region | Location | Connect Available | Recommended Use |
|--------|----------|-------------------|-----------------|
| `us-gov-west-1` | Oregon | ✅ Yes | Primary for FedRAMP High |
| `us-gov-east-1` | Virginia | ✅ Yes | DR for FedRAMP High |

### FedRAMP Moderate Regions (AWS Commercial)

| Region | Location | Connect Available | Contact Lens | Recommended Use |
|--------|----------|-------------------|--------------|-----------------|
| `us-east-1` | Virginia | ✅ Yes | ✅ Yes | Primary for FedRAMP Moderate |
| `us-west-2` | Oregon | ✅ Yes | ✅ Yes | DR for FedRAMP Moderate |
| `us-east-2` | Ohio | ✅ Yes | ❌ Limited | Secondary option |

### Region Pair Recommendations

| Authorization Level | Primary | DR | Distance |
|--------------------|---------|-----|----------|
| FedRAMP High | us-gov-west-1 | us-gov-east-1 | ~2,400 miles |
| FedRAMP Moderate | us-east-1 | us-west-2 | ~2,400 miles |
| Cost-Optimized | us-east-1 | us-east-2 | ~400 miles |

---

## Recovery Time Objectives

### Target Objectives

| Component | RTO | RPO | Notes |
|-----------|-----|-----|-------|
| **Voice (AI Agent)** | 30 min | 0 | Requires new phone number announcement |
| **Voice (Human Agents)** | 1-4 hours | 0 | Agent workstation reconfiguration |
| **Chat** | 15 min | 0 | DNS failover automated |
| **Survey Data** | 0 | < 1 min | DynamoDB Global Tables |
| **Historical Recordings** | 1-2 hours | 15 min | S3 Cross-Region Replication |
| **Metrics/Reports** | 4-8 hours | N/A | Historical data rebuilt |

### RTO Breakdown by Tier

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        RECOVERY TIME BREAKDOWN                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  T+0:00  ──▶  Disaster Declared                                            │
│               │                                                             │
│  T+0:05  ──▶  │  Run DR decision script (validate outage)                  │
│               │                                                             │
│  T+0:10  ──▶  │  Execute failover-1-infrastructure.sh                      │
│               │  ├── Promote DynamoDB replica                              │
│               │  ├── Update Route 53 (chat failover)                       │
│               │  └── Activate DR Lambdas                                   │
│               │                                                             │
│  T+0:15  ──▶  │  ✅ CHAT OPERATIONAL                                       │
│               │                                                             │
│  T+0:20  ──▶  │  Execute failover-2-connect.sh                             │
│               │  ├── Validate DR Connect instance                          │
│               │  ├── Sync latest user states                               │
│               │  └── Enable queues                                         │
│               │                                                             │
│  T+0:30  ──▶  │  ✅ AI VOICE AGENT OPERATIONAL (DR numbers)                │
│               │                                                             │
│  T+0:45  ──▶  │  Execute failover-3-agents.sh                              │
│               │  ├── Notify agents of DR activation                         │
│               │  ├── Provision DR CCP access                               │
│               │  └── Update IVR announcements                              │
│               │                                                             │
│  T+1:00  ──▶  │  ✅ HUMAN AGENTS OPERATIONAL                               │
│               │                                                             │
│  T+1:00  ──▶  │  Post-failover validation                                  │
│  to           │  ├── Test sample calls                                     │
│  T+2:00  ──▶  │  ├── Verify data replication                               │
│               │  └── Confirm monitoring active                             │
│               │                                                             │
│  T+2:00  ──▶  │  ✅ FULL OPERATIONS IN DR REGION                           │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Pre-Disaster Preparation

### 1. Enable DynamoDB Global Tables

```hcl
# terraform/modules/dynamodb/main.tf

resource "aws_dynamodb_table" "census_responses" {
  name             = "${var.name_prefix}-census-responses"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "caseId"
  range_key        = "timestamp"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  # Enable Global Tables replication
  replica {
    region_name = var.dr_region
    kms_key_arn = var.dr_kms_key_arn
    
    # Enable point-in-time recovery in DR region
    point_in_time_recovery = true
  }
  
  attribute {
    name = "caseId"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
  
  tags = var.tags
}
```

### 2. Enable S3 Cross-Region Replication

```hcl
# terraform/modules/s3/replication.tf

resource "aws_s3_bucket_replication_configuration" "recordings_replication" {
  bucket = aws_s3_bucket.recordings.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "recordings-dr-replication"
    status = "Enabled"

    filter {
      prefix = ""  # Replicate all objects
    }

    destination {
      bucket        = var.dr_bucket_arn
      storage_class = "STANDARD"
      
      encryption_configuration {
        replica_kms_key_id = var.dr_kms_key_arn
      }
      
      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
      
      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}
```

### 3. Create DR Connect Instance

```bash
#!/bin/bash
# scripts/dr/setup-dr-connect-instance.sh
# Run ONCE during initial DR setup to create standby instance

set -e

DR_REGION="${DR_REGION:-us-west-2}"
INSTANCE_ALIAS="${INSTANCE_ALIAS:-ccaas-dr}"

echo "Creating DR Connect instance in ${DR_REGION}..."

# Create the DR Connect instance
INSTANCE_ID=$(aws connect create-instance \
  --identity-management-type "CONNECT_MANAGED" \
  --instance-alias "${INSTANCE_ALIAS}" \
  --inbound-calls-enabled \
  --outbound-calls-enabled \
  --region "${DR_REGION}" \
  --query 'Id' \
  --output text)

echo "DR Connect Instance created: ${INSTANCE_ID}"

# Wait for instance to be active
echo "Waiting for instance to become active..."
aws connect wait instance-status-active \
  --instance-id "${INSTANCE_ID}" \
  --region "${DR_REGION}"

# Enable Contact Lens
aws connect update-instance-attribute \
  --instance-id "${INSTANCE_ID}" \
  --attribute-type "CONTACT_LENS" \
  --value "true" \
  --region "${DR_REGION}"

# Enable chat
aws connect update-instance-attribute \
  --instance-id "${INSTANCE_ID}" \
  --attribute-type "CHAT" \
  --value "true" \
  --region "${DR_REGION}"

echo "DR Instance ready: ${INSTANCE_ID}"
echo "Store this Instance ID in your DR configuration."
```

### 4. Export/Sync Connect Configuration

```bash
#!/bin/bash
# scripts/dr/sync-connect-config.sh
# Run REGULARLY (daily via cron) to sync config to DR

set -e

PRIMARY_REGION="${PRIMARY_REGION:-us-east-1}"
DR_REGION="${DR_REGION:-us-west-2}"
PRIMARY_INSTANCE_ID="${PRIMARY_INSTANCE_ID}"
DR_INSTANCE_ID="${DR_INSTANCE_ID}"
CONFIG_BUCKET="${CONFIG_BUCKET:-ccaas-dr-config}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
EXPORT_DIR="/tmp/connect-export-${TIMESTAMP}"
mkdir -p "${EXPORT_DIR}"

echo "=== Exporting Connect Configuration ==="
echo "Primary: ${PRIMARY_INSTANCE_ID} in ${PRIMARY_REGION}"
echo "DR: ${DR_INSTANCE_ID} in ${DR_REGION}"

# Export Hours of Operation
echo "Exporting Hours of Operation..."
aws connect list-hours-of-operations \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'HoursOfOperationSummaryList' \
  --output json > "${EXPORT_DIR}/hours-of-operations.json"

# Export Queues
echo "Exporting Queues..."
aws connect list-queues \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --queue-types "STANDARD" \
  --query 'QueueSummaryList' \
  --output json > "${EXPORT_DIR}/queues.json"

# Export Routing Profiles
echo "Exporting Routing Profiles..."
aws connect list-routing-profiles \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'RoutingProfileSummaryList' \
  --output json > "${EXPORT_DIR}/routing-profiles.json"

# Export Users (without passwords)
echo "Exporting Users..."
aws connect list-users \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'UserSummaryList' \
  --output json > "${EXPORT_DIR}/users.json"

# Export Security Profiles
echo "Exporting Security Profiles..."
aws connect list-security-profiles \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'SecurityProfileSummaryList' \
  --output json > "${EXPORT_DIR}/security-profiles.json"

# Export Contact Flows - Full content
echo "Exporting Contact Flows..."
FLOWS=$(aws connect list-contact-flows \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'ContactFlowSummaryList[*].Id' \
  --output text)

mkdir -p "${EXPORT_DIR}/contact-flows"
for FLOW_ID in ${FLOWS}; do
  aws connect describe-contact-flow \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --contact-flow-id "${FLOW_ID}" \
    --region "${PRIMARY_REGION}" \
    --output json > "${EXPORT_DIR}/contact-flows/${FLOW_ID}.json"
done

# Export Quick Connects
echo "Exporting Quick Connects..."
aws connect list-quick-connects \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'QuickConnectSummaryList' \
  --output json > "${EXPORT_DIR}/quick-connects.json"

# Export Prompts
echo "Exporting Prompts list..."
aws connect list-prompts \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'PromptSummaryList' \
  --output json > "${EXPORT_DIR}/prompts.json"

# Create manifest
echo "Creating export manifest..."
cat > "${EXPORT_DIR}/manifest.json" << EOF
{
  "exportTimestamp": "${TIMESTAMP}",
  "primaryRegion": "${PRIMARY_REGION}",
  "primaryInstanceId": "${PRIMARY_INSTANCE_ID}",
  "drRegion": "${DR_REGION}",
  "drInstanceId": "${DR_INSTANCE_ID}",
  "files": [
    "hours-of-operations.json",
    "queues.json",
    "routing-profiles.json",
    "users.json",
    "security-profiles.json",
    "quick-connects.json",
    "prompts.json"
  ],
  "contactFlowCount": $(ls ${EXPORT_DIR}/contact-flows | wc -l | tr -d ' ')
}
EOF

# Upload to S3
echo "Uploading to S3..."
aws s3 sync "${EXPORT_DIR}" "s3://${CONFIG_BUCKET}/connect-config/${TIMESTAMP}/" \
  --region "${PRIMARY_REGION}"

# Update latest pointer
echo "${TIMESTAMP}" | aws s3 cp - "s3://${CONFIG_BUCKET}/connect-config/LATEST" \
  --region "${PRIMARY_REGION}"

echo "=== Export Complete ==="
echo "Configuration backed up to: s3://${CONFIG_BUCKET}/connect-config/${TIMESTAMP}/"

# Cleanup
rm -rf "${EXPORT_DIR}"
```

### 5. Setup Route 53 Health Checks

```hcl
# terraform/modules/dr/route53.tf

resource "aws_route53_health_check" "primary_connect" {
  fqdn              = "${var.primary_connect_instance_alias}.my.connect.aws"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.name_prefix}-primary-health-check"
  }
}

resource "aws_route53_record" "chat_failover_primary" {
  zone_id = var.route53_zone_id
  name    = "chat.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary_connect.id

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "chat_failover_secondary" {
  zone_id = var.route53_zone_id
  name    = "chat.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  alias {
    name                   = var.dr_alb_dns_name
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = true
  }
}
```

---

## DR Procedures

### Procedure 1: Declare Disaster

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    DISASTER DECLARATION PROCEDURE                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TRIGGER CONDITIONS (any one):                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ □ AWS status page shows Connect outage in primary region (>30 min)  │   │
│  │ □ All Connect API calls failing (5xx errors) for >15 minutes        │   │
│  │ □ No calls completing successfully for >10 minutes                  │   │
│  │ □ AWS declares regional service event                               │   │
│  │ □ Physical disaster affecting AWS region data centers               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  DECISION TREE:                                                             │
│                                                                             │
│  Is Connect working in primary region?                                      │
│      │                                                                      │
│      ├─ YES ──▶ Do NOT declare disaster. Investigate specific issue.       │
│      │                                                                      │
│      └─ NO ──▶ Has it been down >15 minutes?                               │
│                    │                                                        │
│                    ├─ NO ──▶ Wait. Check AWS status. Continue monitoring.  │
│                    │                                                        │
│                    └─ YES ──▶ DECLARE DISASTER. Proceed to failover.       │
│                                                                             │
│  AUTHORIZATION REQUIRED:                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • On-call lead approves failover initiation                         │   │
│  │ • Notify stakeholders: Ops team, Agency contacts, Leadership        │   │
│  │ • Document decision time and rationale                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Procedure 2: Execute Failover

**Step 2.1: Infrastructure Failover**

```bash
#!/bin/bash
# scripts/dr/failover-1-infrastructure.sh

set -e

echo "=============================================="
echo "  DISASTER RECOVERY - INFRASTRUCTURE FAILOVER"
echo "=============================================="
echo "Started at: $(date)"
echo ""

DR_REGION="${DR_REGION:-us-west-2}"
PRIMARY_REGION="${PRIMARY_REGION:-us-east-1}"

# Confirm execution
read -p "CONFIRM: Execute infrastructure failover to ${DR_REGION}? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "=== Step 1: Verify DR Region Services ==="
aws sts get-caller-identity --region "${DR_REGION}"

echo ""
echo "=== Step 2: Promote DynamoDB Global Tables (if needed) ==="
# DynamoDB Global Tables auto-promote on regional failure
# This step verifies the DR replica is accessible
echo "Verifying DynamoDB tables in DR region..."
aws dynamodb describe-table \
  --table-name "${DYNAMODB_TABLE}" \
  --region "${DR_REGION}" \
  --query 'Table.TableStatus'

echo ""
echo "=== Step 3: Update Parameter Store for Region ==="
aws ssm put-parameter \
  --name "/ccaas/active-region" \
  --value "${DR_REGION}" \
  --type String \
  --overwrite \
  --region "${DR_REGION}"

echo ""
echo "=== Step 4: Update Route 53 Health Check (Force Failover) ==="
# Disable primary health check to force DNS failover
HEALTH_CHECK_ID="${PRIMARY_HEALTH_CHECK_ID}"
aws route53 update-health-check \
  --health-check-id "${HEALTH_CHECK_ID}" \
  --disabled

echo "Route 53 failover triggered. Chat traffic will shift in ~60 seconds."

echo ""
echo "=== Step 5: Activate DR Lambda Functions ==="
# Update Lambda environment to use DR resources
for FUNC in census-handler census-fulfillment; do
  aws lambda update-function-configuration \
    --function-name "${FUNC}" \
    --environment "Variables={ACTIVE_REGION=${DR_REGION},DYNAMODB_TABLE=${DYNAMODB_TABLE}}" \
    --region "${DR_REGION}"
done

echo ""
echo "=== Step 6: Verify DR Lex Bot ==="
aws lexv2-runtime recognize-text \
  --bot-id "${DR_LEX_BOT_ID}" \
  --bot-alias-id "${DR_LEX_ALIAS_ID}" \
  --locale-id "en_US" \
  --session-id "dr-test-$(date +%s)" \
  --text "Hello" \
  --region "${DR_REGION}" \
  --query 'messages[0].content'

echo ""
echo "=============================================="
echo "  INFRASTRUCTURE FAILOVER COMPLETE"
echo "=============================================="
echo "Completed at: $(date)"
echo ""
echo "NEXT STEPS:"
echo "  1. Run: ./failover-2-connect.sh"
echo "  2. Run: ./failover-3-agents.sh"
```

**Step 2.2: Connect Failover**

```bash
#!/bin/bash
# scripts/dr/failover-2-connect.sh

set -e

echo "=============================================="
echo "  DISASTER RECOVERY - CONNECT FAILOVER"
echo "=============================================="
echo "Started at: $(date)"
echo ""

DR_REGION="${DR_REGION:-us-west-2}"
DR_INSTANCE_ID="${DR_INSTANCE_ID}"
CONFIG_BUCKET="${CONFIG_BUCKET:-ccaas-dr-config}"

echo "=== Step 1: Get Latest Configuration Backup ==="
LATEST_BACKUP=$(aws s3 cp "s3://${CONFIG_BUCKET}/connect-config/LATEST" - --region "${DR_REGION}")
echo "Using backup from: ${LATEST_BACKUP}"

echo ""
echo "=== Step 2: Verify DR Instance Status ==="
INSTANCE_STATUS=$(aws connect describe-instance \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'Instance.InstanceStatus' \
  --output text)

if [ "$INSTANCE_STATUS" != "ACTIVE" ]; then
  echo "ERROR: DR Connect instance not active. Status: ${INSTANCE_STATUS}"
  exit 1
fi
echo "DR Instance Status: ${INSTANCE_STATUS}"

echo ""
echo "=== Step 3: Enable DR Queues ==="
# Get all queues and enable them
QUEUE_IDS=$(aws connect list-queues \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --queue-types "STANDARD" \
  --query 'QueueSummaryList[*].Id' \
  --output text)

for QUEUE_ID in ${QUEUE_IDS}; do
  echo "Enabling queue: ${QUEUE_ID}"
  aws connect update-queue-status \
    --instance-id "${DR_INSTANCE_ID}" \
    --queue-id "${QUEUE_ID}" \
    --status "ENABLED" \
    --region "${DR_REGION}" 2>/dev/null || echo "Queue already enabled"
done

echo ""
echo "=== Step 4: Associate Lambda with DR Instance ==="
aws connect associate-lambda-function \
  --instance-id "${DR_INSTANCE_ID}" \
  --function-arn "arn:aws:lambda:${DR_REGION}:${AWS_ACCOUNT_ID}:function:census-handler" \
  --region "${DR_REGION}" 2>/dev/null || echo "Lambda already associated"

echo ""
echo "=== Step 5: Associate Lex Bot with DR Instance ==="
aws connect associate-bot \
  --instance-id "${DR_INSTANCE_ID}" \
  --lex-v2-bot "AliasArn=arn:aws:lex:${DR_REGION}:${AWS_ACCOUNT_ID}:bot-alias/${DR_LEX_BOT_ID}/${DR_LEX_ALIAS_ID}" \
  --region "${DR_REGION}" 2>/dev/null || echo "Lex bot already associated"

echo ""
echo "=== Step 6: Verify Phone Number Routing ==="
aws connect list-phone-numbers \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'PhoneNumberSummaryList[*].{Number:PhoneNumber,Flow:ContactFlowId}' \
  --output table

echo ""
echo "=== Step 7: Publish DR Contact Flow ==="
# Get the main contact flow and ensure it's published
MAIN_FLOW_ID=$(aws connect list-contact-flows \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query "ContactFlowSummaryList[?Name=='Census-Inbound-Flow'].Id" \
  --output text)

if [ -n "$MAIN_FLOW_ID" ]; then
  echo "Main contact flow ID: ${MAIN_FLOW_ID}"
  # Contact flows should already be published, but verify
  aws connect describe-contact-flow \
    --instance-id "${DR_INSTANCE_ID}" \
    --contact-flow-id "${MAIN_FLOW_ID}" \
    --region "${DR_REGION}" \
    --query 'ContactFlow.State'
fi

echo ""
echo "=============================================="
echo "  CONNECT FAILOVER COMPLETE"
echo "=============================================="
echo "Completed at: $(date)"
echo ""
echo "DR Connect Instance: ${DR_INSTANCE_ID}"
echo "DR Region: ${DR_REGION}"
echo ""
echo "NEXT STEPS:"
echo "  1. Run: ./failover-3-agents.sh"
echo "  2. Test AI calls to DR phone number"
echo "  3. Notify stakeholders of new phone numbers"
```

**Step 2.3: Agent Failover**

```bash
#!/bin/bash
# scripts/dr/failover-3-agents.sh

set -e

echo "=============================================="
echo "  DISASTER RECOVERY - AGENT FAILOVER"
echo "=============================================="
echo "Started at: $(date)"
echo ""

DR_REGION="${DR_REGION:-us-west-2}"
DR_INSTANCE_ID="${DR_INSTANCE_ID}"
DR_INSTANCE_ALIAS="${DR_INSTANCE_ALIAS:-ccaas-dr}"
NOTIFICATION_SNS_TOPIC="${NOTIFICATION_SNS_TOPIC}"

echo "=== Step 1: Get DR CCP URL ==="
DR_CCP_URL="https://${DR_INSTANCE_ALIAS}.my.connect.aws/ccp-v2"
echo "DR CCP URL: ${DR_CCP_URL}"

echo ""
echo "=== Step 2: Reset Agent Passwords (if needed) ==="
echo "NOTE: Agents may need password resets if not using SSO."
echo "Skipping automatic password reset for security."

echo ""
echo "=== Step 3: Verify Agent Accounts ==="
AGENT_COUNT=$(aws connect list-users \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(UserSummaryList)' \
  --output text)
echo "Agents in DR instance: ${AGENT_COUNT}"

echo ""
echo "=== Step 4: Update Agent Status (Set Available) ==="
# Get all agent user IDs
USER_IDS=$(aws connect list-users \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'UserSummaryList[*].Id' \
  --output text)

# Note: Agent status is managed by agents logging in
echo "Agents will set themselves available upon login to DR CCP."

echo ""
echo "=== Step 5: Send Agent Notifications ==="
if [ -n "${NOTIFICATION_SNS_TOPIC}" ]; then
  cat << EOF | aws sns publish \
    --topic-arn "${NOTIFICATION_SNS_TOPIC}" \
    --subject "URGENT: Contact Center DR Failover - Action Required" \
    --message file:///dev/stdin \
    --region "${DR_REGION}"
DISASTER RECOVERY ACTIVATED

The contact center has failed over to the DR region.

IMMEDIATE ACTION REQUIRED:
1. Log in to the DR Contact Control Panel (CCP):
   ${DR_CCP_URL}

2. Use your same username and password

3. Set your status to "Available" once logged in

4. Update your phone number display if needed

NEW CUSTOMER PHONE NUMBERS:
- AI Census Line: [UPDATE WITH DR NUMBER]
- General Support: [UPDATE WITH DR NUMBER]

Please confirm receipt with your supervisor.

Activated at: $(date)
DR Region: ${DR_REGION}
EOF
  echo "Agent notification sent via SNS."
else
  echo "WARNING: No SNS topic configured. Notify agents manually."
fi

echo ""
echo "=== Step 6: Update IVR Announcement ==="
echo "Creating disaster announcement prompt..."
# This would be pre-recorded, but here's how to upload if needed:
# aws connect create-prompt \
#   --instance-id "${DR_INSTANCE_ID}" \
#   --name "DR-Announcement" \
#   --s3-uri "s3://${CONFIG_BUCKET}/prompts/dr-announcement.wav" \
#   --region "${DR_REGION}"

echo ""
echo "=============================================="
echo "  AGENT FAILOVER COMPLETE"
echo "=============================================="
echo "Completed at: $(date)"
echo ""
echo "SUMMARY:"
echo "  DR CCP URL: ${DR_CCP_URL}"
echo "  Agents Available: ${AGENT_COUNT}"
echo ""
echo "MANUAL ACTIONS REQUIRED:"
echo "  1. Verify agents can log in to DR CCP"
echo "  2. Update public-facing phone numbers on website"
echo "  3. Send customer communications if needed"
echo "  4. Begin post-failover validation checklist"
```

---

## Automated Failover Scripts

### Master DR Controller Script

```bash
#!/bin/bash
# scripts/dr/dr-controller.sh
# Master script for DR operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/ccaas-dr"
mkdir -p "${LOG_DIR}"

# Source configuration
source "${SCRIPT_DIR}/dr-config.env"

usage() {
  cat << EOF
Government CCaaS DR Controller

Usage: $0 <command> [options]

Commands:
  status          Check DR readiness status
  sync            Sync configuration to DR region
  failover        Execute full DR failover
  failback        Return to primary region
  test            Test DR procedures (dry run)
  validate        Validate DR configuration

Options:
  --force         Skip confirmation prompts
  --region        Override DR region

Examples:
  $0 status
  $0 sync
  $0 failover --force
  $0 test
EOF
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_DIR}/dr-$(date +%Y%m%d).log"
}

check_status() {
  log "=== DR Status Check ==="
  
  echo ""
  echo "PRIMARY REGION: ${PRIMARY_REGION}"
  echo "DR REGION: ${DR_REGION}"
  echo ""
  
  # Check primary Connect
  echo "--- Primary Connect Instance ---"
  aws connect describe-instance \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --region "${PRIMARY_REGION}" \
    --query 'Instance.{Status:InstanceStatus,Alias:InstanceAlias}' \
    --output table 2>/dev/null || echo "PRIMARY UNREACHABLE"
  
  # Check DR Connect
  echo ""
  echo "--- DR Connect Instance ---"
  aws connect describe-instance \
    --instance-id "${DR_INSTANCE_ID}" \
    --region "${DR_REGION}" \
    --query 'Instance.{Status:InstanceStatus,Alias:InstanceAlias}' \
    --output table 2>/dev/null || echo "DR UNREACHABLE"
  
  # Check DynamoDB replication
  echo ""
  echo "--- DynamoDB Global Tables ---"
  aws dynamodb describe-table \
    --table-name "${DYNAMODB_TABLE}" \
    --region "${PRIMARY_REGION}" \
    --query 'Table.Replicas[*].{Region:RegionName,Status:ReplicaStatus}' \
    --output table 2>/dev/null || echo "DYNAMODB CHECK FAILED"
  
  # Check S3 replication
  echo ""
  echo "--- S3 Replication Status ---"
  aws s3api get-bucket-replication \
    --bucket "${RECORDINGS_BUCKET}" \
    --query 'ReplicationConfiguration.Rules[0].Status' \
    --output text 2>/dev/null || echo "REPLICATION NOT CONFIGURED"
  
  # Check last config sync
  echo ""
  echo "--- Last Configuration Sync ---"
  LAST_SYNC=$(aws s3 cp "s3://${CONFIG_BUCKET}/connect-config/LATEST" - 2>/dev/null || echo "NEVER")
  echo "Last sync: ${LAST_SYNC}"
  
  echo ""
  log "Status check complete"
}

do_sync() {
  log "Starting configuration sync to DR region..."
  "${SCRIPT_DIR}/sync-connect-config.sh"
  log "Configuration sync complete"
}

do_failover() {
  FORCE=$1
  
  log "!!! DISASTER RECOVERY FAILOVER INITIATED !!!"
  
  if [ "$FORCE" != "true" ]; then
    echo ""
    echo "WARNING: You are about to execute a DISASTER RECOVERY FAILOVER."
    echo "This will:"
    echo "  - Route all chat traffic to ${DR_REGION}"
    echo "  - Activate DR Connect instance"
    echo "  - Notify all agents to log into DR CCP"
    echo ""
    read -p "Type 'FAILOVER' to confirm: " CONFIRM
    if [ "$CONFIRM" != "FAILOVER" ]; then
      echo "Aborted."
      exit 1
    fi
  fi
  
  log "Executing infrastructure failover..."
  "${SCRIPT_DIR}/failover-1-infrastructure.sh"
  
  log "Executing Connect failover..."
  "${SCRIPT_DIR}/failover-2-connect.sh"
  
  log "Executing agent failover..."
  "${SCRIPT_DIR}/failover-3-agents.sh"
  
  log "Running post-failover validation..."
  "${SCRIPT_DIR}/validate-failover.sh"
  
  log "!!! FAILOVER COMPLETE !!!"
  echo ""
  echo "IMPORTANT: Update customer-facing phone numbers and communications."
}

do_test() {
  log "=== DR TEST MODE (Dry Run) ==="
  echo ""
  echo "This will test DR procedures WITHOUT activating failover."
  echo ""
  
  # Test DR instance connectivity
  echo "Testing DR Connect instance..."
  aws connect describe-instance \
    --instance-id "${DR_INSTANCE_ID}" \
    --region "${DR_REGION}" > /dev/null && echo "✅ DR Connect instance accessible" || echo "❌ DR Connect instance FAILED"
  
  # Test DR Lambda
  echo "Testing DR Lambda functions..."
  aws lambda invoke \
    --function-name "census-handler" \
    --region "${DR_REGION}" \
    --payload '{"test": true}' \
    /tmp/lambda-test-output.json > /dev/null 2>&1 && echo "✅ DR Lambda accessible" || echo "❌ DR Lambda FAILED"
  
  # Test DR DynamoDB
  echo "Testing DR DynamoDB..."
  aws dynamodb describe-table \
    --table-name "${DYNAMODB_TABLE}" \
    --region "${DR_REGION}" > /dev/null && echo "✅ DR DynamoDB accessible" || echo "❌ DR DynamoDB FAILED"
  
  # Test DR Lex
  echo "Testing DR Lex bot..."
  aws lexv2-runtime recognize-text \
    --bot-id "${DR_LEX_BOT_ID}" \
    --bot-alias-id "${DR_LEX_ALIAS_ID}" \
    --locale-id "en_US" \
    --session-id "test-$(date +%s)" \
    --text "test" \
    --region "${DR_REGION}" > /dev/null 2>&1 && echo "✅ DR Lex bot accessible" || echo "❌ DR Lex bot FAILED"
  
  echo ""
  log "DR test complete"
}

case "$1" in
  status)
    check_status
    ;;
  sync)
    do_sync
    ;;
  failover)
    FORCE="false"
    [[ "$2" == "--force" ]] && FORCE="true"
    do_failover "$FORCE"
    ;;
  test)
    do_test
    ;;
  *)
    usage
    exit 1
    ;;
esac
```

### DR Configuration File

```bash
# scripts/dr/dr-config.env
# Environment configuration for DR scripts

# Primary Region Configuration
export PRIMARY_REGION="us-east-1"
export PRIMARY_INSTANCE_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export PRIMARY_INSTANCE_ALIAS="census-ccaas"

# DR Region Configuration
export DR_REGION="us-west-2"
export DR_INSTANCE_ID="yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
export DR_INSTANCE_ALIAS="census-ccaas-dr"

# Shared Resources
export AWS_ACCOUNT_ID="123456789012"
export DYNAMODB_TABLE="census-responses"
export RECORDINGS_BUCKET="census-recordings-primary"
export DR_RECORDINGS_BUCKET="census-recordings-dr"
export CONFIG_BUCKET="ccaas-dr-config"

# Lex Configuration
export PRIMARY_LEX_BOT_ID="AAAAAAAAAA"
export PRIMARY_LEX_ALIAS_ID="BBBBBBBBBB"
export DR_LEX_BOT_ID="CCCCCCCCCC"
export DR_LEX_ALIAS_ID="DDDDDDDDDD"

# Notification
export NOTIFICATION_SNS_TOPIC="arn:aws:sns:us-west-2:123456789012:ccaas-alerts"
export PRIMARY_HEALTH_CHECK_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Timeouts and Retries
export API_TIMEOUT=30
export MAX_RETRIES=3
```

---

## Post-Failover Validation

### Validation Checklist Script

```bash
#!/bin/bash
# scripts/dr/validate-failover.sh

set -e

source "$(dirname "$0")/dr-config.env"

echo "=============================================="
echo "  POST-FAILOVER VALIDATION"
echo "=============================================="
echo ""

PASS=0
FAIL=0

check() {
  local NAME=$1
  local CMD=$2
  
  echo -n "Checking ${NAME}... "
  if eval "${CMD}" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((PASS++))
  else
    echo "❌ FAIL"
    ((FAIL++))
  fi
}

echo "=== Infrastructure Checks ==="
check "DR Connect Instance" \
  "aws connect describe-instance --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION}"

check "DR Lambda Function" \
  "aws lambda get-function --function-name census-handler --region ${DR_REGION}"

check "DynamoDB Table" \
  "aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${DR_REGION}"

check "DR Lex Bot" \
  "aws lexv2-models describe-bot --bot-id ${DR_LEX_BOT_ID} --region ${DR_REGION}"

echo ""
echo "=== Service Health Checks ==="

check "Lex Voice Recognition" \
  "aws lexv2-runtime recognize-text --bot-id ${DR_LEX_BOT_ID} --bot-alias-id ${DR_LEX_ALIAS_ID} --locale-id en_US --session-id test-$$ --text hello --region ${DR_REGION}"

check "DynamoDB Read" \
  "aws dynamodb scan --table-name ${DYNAMODB_TABLE} --limit 1 --region ${DR_REGION}"

check "DynamoDB Write" \
  "aws dynamodb put-item --table-name ${DYNAMODB_TABLE} --item '{\"caseId\":{\"S\":\"DR-TEST-\$$\"},\"timestamp\":{\"S\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"},\"status\":{\"S\":\"TEST\"}}' --region ${DR_REGION}"

echo ""
echo "=== Connect Resource Checks ==="

QUEUE_COUNT=$(aws connect list-queues --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION} --query 'length(QueueSummaryList)' --output text)
check "Queues Configured (${QUEUE_COUNT} found)" \
  "[ ${QUEUE_COUNT} -gt 0 ]"

USER_COUNT=$(aws connect list-users --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION} --query 'length(UserSummaryList)' --output text)
check "Users Configured (${USER_COUNT} found)" \
  "[ ${USER_COUNT} -gt 0 ]"

FLOW_COUNT=$(aws connect list-contact-flows --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION} --query 'length(ContactFlowSummaryList)' --output text)
check "Contact Flows (${FLOW_COUNT} found)" \
  "[ ${FLOW_COUNT} -gt 0 ]"

PHONE_COUNT=$(aws connect list-phone-numbers --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION} --query 'length(PhoneNumberSummaryList)' --output text)
check "Phone Numbers (${PHONE_COUNT} found)" \
  "[ ${PHONE_COUNT} -gt 0 ]"

echo ""
echo "=============================================="
echo "  VALIDATION SUMMARY"
echo "=============================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo ""

if [ ${FAIL} -gt 0 ]; then
  echo "⚠️  WARNING: Some checks failed. Review and remediate."
  exit 1
else
  echo "✅ All checks passed. DR is operational."
  exit 0
fi
```

### Test Call Procedure

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    POST-FAILOVER TEST CALLS                                 │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. AI AGENT TEST (Voice)                                                  │
│     Call: [DR Phone Number]                                                │
│     Expected: AI greets, asks address verification                         │
│     Complete: Short survey (1 person) to verify data saves                 │
│     Check: DynamoDB for new record                                         │
│                                                                             │
│  2. AI AGENT TEST (Chat)                                                   │
│     URL: https://chat.[domain]/                                            │
│     Expected: Route to DR instance via DNS failover                        │
│     Complete: Short survey via chat                                        │
│     Check: DynamoDB for new record                                         │
│                                                                             │
│  3. ESCALATION TEST                                                        │
│     Say: "I want to speak to an agent"                                     │
│     Expected: Transfer to queue, hold music                                │
│     Verify: Agent CCP shows call in queue                                  │
│                                                                             │
│  4. AGENT CALL TEST                                                        │
│     Agent: Accept call from queue                                          │
│     Complete: Brief interaction                                            │
│     Verify: Recording appears in S3 (after ~5 min)                         │
│                                                                             │
│  5. CALLBACK TEST                                                          │
│     Say: "I'd like a callback"                                             │
│     Expected: Callback scheduled, saved to DynamoDB                        │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Failback Procedures

### When to Failback

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    FAILBACK DECISION CRITERIA                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  DO NOT FAILBACK if:                                                        │
│  □ Primary region still unstable                                           │
│  □ AWS has not declared "Service Restored"                                 │
│  □ Less than 4 hours since primary came back online                        │
│  □ Peak calling hours (unless emergency)                                   │
│  □ Team not available to monitor                                           │
│                                                                             │
│  DO FAILBACK when:                                                          │
│  ☑ Primary region stable for 4+ hours                                      │
│  ☑ AWS declares full service restoration                                   │
│  ☑ Off-peak hours (if possible)                                            │
│  ☑ Full team available for monitoring                                      │
│  ☑ Stakeholder approval received                                           │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Failback Script

```bash
#!/bin/bash
# scripts/dr/failback.sh

set -e

source "$(dirname "$0")/dr-config.env"

echo "=============================================="
echo "  FAILBACK TO PRIMARY REGION"
echo "=============================================="
echo ""
echo "This will return operations to ${PRIMARY_REGION}."
echo ""

read -p "Confirm primary region ${PRIMARY_REGION} is stable? (yes/no): " CONFIRM1
[ "$CONFIRM1" != "yes" ] && exit 1

read -p "Type 'FAILBACK' to proceed: " CONFIRM2
[ "$CONFIRM2" != "FAILBACK" ] && exit 1

echo ""
echo "=== Step 1: Verify Primary Region Health ==="
aws connect describe-instance \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'Instance.InstanceStatus'

echo ""
echo "=== Step 2: Sync Recent Data to Primary ==="
# DynamoDB Global Tables sync automatically
echo "DynamoDB: Global Tables auto-syncing..."
sleep 5

echo ""
echo "=== Step 3: Re-enable Primary Health Check ==="
aws route53 update-health-check \
  --health-check-id "${PRIMARY_HEALTH_CHECK_ID}" \
  --no-disabled

echo "Route 53 will begin routing to primary in ~60 seconds..."

echo ""
echo "=== Step 4: Update Parameter Store ==="
aws ssm put-parameter \
  --name "/ccaas/active-region" \
  --value "${PRIMARY_REGION}" \
  --type String \
  --overwrite \
  --region "${PRIMARY_REGION}"

echo ""
echo "=== Step 5: Monitor Traffic Shift ==="
echo "Waiting 2 minutes for DNS propagation..."
sleep 120

echo ""
echo "=== Step 6: Notify Agents ==="
if [ -n "${NOTIFICATION_SNS_TOPIC}" ]; then
  aws sns publish \
    --topic-arn "${NOTIFICATION_SNS_TOPIC}" \
    --subject "Contact Center Returning to Primary Region" \
    --message "Operations are returning to primary region. Log in to primary CCP: https://${PRIMARY_INSTANCE_ALIAS}.my.connect.aws/ccp-v2" \
    --region "${PRIMARY_REGION}"
fi

echo ""
echo "=============================================="
echo "  FAILBACK COMPLETE"
echo "=============================================="
echo ""
echo "Primary CCP URL: https://${PRIMARY_INSTANCE_ALIAS}.my.connect.aws/ccp-v2"
echo ""
echo "MANUAL ACTIONS:"
echo "  1. Update customer communications with primary phone numbers"
echo "  2. Verify agents logging into primary CCP"
echo "  3. Monitor call quality for 1 hour"
echo "  4. Schedule post-incident review"
```

---

## DR Testing Schedule

### Recommended Testing Frequency

| Test Type | Frequency | Duration | Impact |
|-----------|-----------|----------|--------|
| **DR Readiness Check** | Daily (automated) | 5 min | None |
| **Configuration Sync Test** | Weekly | 15 min | None |
| **Partial Failover (non-prod)** | Monthly | 2 hours | Dev/Test only |
| **Full DR Exercise** | Quarterly | 4 hours | Planned maintenance |
| **Unannounced DR Test** | Annually | 4 hours | Brief service impact |

### Quarterly DR Exercise Template

```
┌────────────────────────────────────────────────────────────────────────────┐
│             QUARTERLY DR EXERCISE RUNBOOK                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PREPARATION (Week Before)                                                  │
│  □ Schedule maintenance window                                              │
│  □ Notify stakeholders                                                      │
│  □ Brief operations team                                                    │
│  □ Verify DR scripts are current                                           │
│  □ Confirm DR phone numbers active                                         │
│                                                                             │
│  EXERCISE DAY                                                               │
│                                                                             │
│  T-1:00  □ Final readiness check (./dr-controller.sh status)               │
│  T-0:30  □ Brief team, assign roles                                        │
│  T-0:15  □ Notify stakeholders exercise starting                           │
│  T-0:00  □ EXECUTE FAILOVER (./dr-controller.sh failover)                  │
│  T+0:15  □ Validate DR services operational                                │
│  T+0:30  □ Test sample calls/chats                                         │
│  T+1:00  □ Agent login test to DR CCP                                      │
│  T+1:30  □ Document any issues                                             │
│  T+2:00  □ EXECUTE FAILBACK (./dr-controller.sh failback)                  │
│  T+2:15  □ Validate primary services operational                           │
│  T+2:30  □ Test sample calls/chats                                         │
│  T+3:00  □ Exercise complete - brief stakeholders                          │
│                                                                             │
│  POST-EXERCISE                                                              │
│  □ Document lessons learned                                                │
│  □ Update runbooks as needed                                               │
│  □ File exercise report                                                    │
│  □ Schedule remediation for any gaps                                       │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Terraform DR Module

### DR Infrastructure as Code

```hcl
# terraform/modules/dr/main.tf

# =============================================================================
# DISASTER RECOVERY MODULE
# Provisions DR infrastructure in secondary region
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.0"
      configuration_aliases = [aws.dr]
    }
  }
}

# -----------------------------------------------------------------------------
# DynamoDB Global Table Replica
# -----------------------------------------------------------------------------
# Note: Replica is configured in the main dynamodb module using replica block

# -----------------------------------------------------------------------------
# S3 Replication Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "dr_recordings" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-recordings-dr"

  tags = merge(var.tags, {
    Purpose = "DR-Recordings"
  })
}

resource "aws_s3_bucket_versioning" "dr_recordings" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr_recordings.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dr_recordings" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr_recordings.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.dr_kms_key_arn
    }
  }
}

# -----------------------------------------------------------------------------
# DR Lambda Functions
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "dr_census_handler" {
  provider      = aws.dr
  function_name = "${var.name_prefix}-census-handler"
  role          = aws_iam_role.dr_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30
  memory_size   = 256

  s3_bucket = var.lambda_deployment_bucket
  s3_key    = var.lambda_deployment_key

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      ACTIVE_REGION  = var.dr_region
      IS_DR          = "true"
    }
  }

  vpc_config {
    subnet_ids         = var.dr_subnet_ids
    security_group_ids = var.dr_security_group_ids
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DR Lex Bot
# -----------------------------------------------------------------------------
resource "aws_lexv2models_bot" "dr_census_bot" {
  provider                      = aws.dr
  name                          = "${var.name_prefix}-census-bot-dr"
  role_arn                      = aws_iam_role.dr_lex_role.arn
  data_privacy {
    child_directed = false
  }
  idle_session_ttl_in_seconds = 300
  type                        = "Bot"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DR KMS Key
# -----------------------------------------------------------------------------
resource "aws_kms_key" "dr_primary" {
  provider                 = aws.dr
  description              = "DR Primary encryption key"
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  multi_region             = true

  tags = merge(var.tags, {
    Purpose = "DR-Encryption"
  })
}

# -----------------------------------------------------------------------------
# DR Config S3 Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "dr_config" {
  provider = aws.dr
  bucket   = "${var.name_prefix}-dr-config"

  tags = merge(var.tags, {
    Purpose = "DR-Configuration"
  })
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "dr_recordings_bucket" {
  value = aws_s3_bucket.dr_recordings.id
}

output "dr_recordings_bucket_arn" {
  value = aws_s3_bucket.dr_recordings.arn
}

output "dr_kms_key_arn" {
  value = aws_kms_key.dr_primary.arn
}

output "dr_lambda_function_arn" {
  value = aws_lambda_function.dr_census_handler.arn
}

output "dr_config_bucket" {
  value = aws_s3_bucket.dr_config.id
}
```

### DR Variables

```hcl
# terraform/modules/dr/variables.tf

variable "name_prefix" {
  description = "Prefix for all DR resources"
  type        = string
}

variable "dr_region" {
  description = "DR region"
  type        = string
  default     = "us-west-2"
}

variable "dr_kms_key_arn" {
  description = "KMS key ARN in DR region"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "lambda_deployment_bucket" {
  description = "S3 bucket containing Lambda code"
  type        = string
}

variable "lambda_deployment_key" {
  description = "S3 key for Lambda deployment package"
  type        = string
}

variable "dr_subnet_ids" {
  description = "Subnet IDs in DR region for Lambda VPC config"
  type        = list(string)
  default     = []
}

variable "dr_security_group_ids" {
  description = "Security group IDs in DR region"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for all DR resources"
  type        = map(string)
  default     = {}
}
```

---

## Summary: DR Quick Reference

### Phone Numbers to Update

| Use | Primary Number | DR Number |
|-----|----------------|-----------|
| Main AI Line | +1-888-XXX-XXXX | +1-888-YYY-YYYY |
| Escalation | +1-888-XXX-XXXY | +1-888-YYY-YYYZ |
| Spanish Line | +1-888-XXX-XXXZ | +1-888-YYY-YYZZ |

### Key URLs

| Resource | Primary | DR |
|----------|---------|-----|
| Agent CCP | https://ccaas.my.connect.aws/ccp-v2 | https://ccaas-dr.my.connect.aws/ccp-v2 |
| Chat Widget | https://chat.agency.gov | https://chat.agency.gov (auto-failover) |
| Admin Console | Connect Console (us-east-1) | Connect Console (us-west-2) |

### Emergency Contacts

| Role | Contact |
|------|---------|
| DR Lead | [Name, Phone] |
| AWS TAM | [Name, Phone] |
| Agency IT | [Name, Phone] |
| Operations | [Name, Phone] |

---

**Last Updated:** February 2026

**Related Documentation:**
- [SERVICE_QUOTAS_AND_LIMITS.md](SERVICE_QUOTAS_AND_LIMITS.md) - Quota planning
- [FEDRAMP_COMPLIANCE.md](FEDRAMP_COMPLIANCE.md) - Security controls
- [README.md](README.md) - Project overview
