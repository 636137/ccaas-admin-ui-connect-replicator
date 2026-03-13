#!/bin/bash
# =============================================================================
# Failback to Primary Region
# =============================================================================
# Returns operations from DR region back to primary region
# Run only after primary region is confirmed stable
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
if [ -f "${SCRIPT_DIR}/dr-config.env" ]; then
  source "${SCRIPT_DIR}/dr-config.env"
else
  echo "ERROR: dr-config.env not found"
  exit 1
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FAILBACK] $1"
}

log "=============================================="
log "  FAILBACK TO PRIMARY REGION"
log "=============================================="
log ""
log "Primary Region: ${PRIMARY_REGION}"
log "Current DR:     ${DR_REGION}"
log ""

# =============================================================================
# Pre-Failback Checks
# =============================================================================
log "=== Pre-Failback Checks ==="

# 1. Verify primary region is accessible
log "Checking primary region accessibility..."
PRIMARY_STATUS=$(aws connect describe-instance \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'Instance.InstanceStatus' \
  --output text 2>/dev/null || echo "UNREACHABLE")

if [ "$PRIMARY_STATUS" != "ACTIVE" ]; then
  log "ERROR: Primary Connect instance not active (Status: ${PRIMARY_STATUS})"
  log "Do NOT proceed with failback until primary is stable."
  exit 1
fi

log "Primary Connect instance: ${PRIMARY_STATUS}"

# 2. Check DynamoDB replication is healthy
log "Checking DynamoDB replication status..."
REPL_STATUS=$(aws dynamodb describe-table \
  --table-name "${DYNAMODB_TABLE}" \
  --region "${PRIMARY_REGION}" \
  --query "Table.Replicas[?RegionName=='${PRIMARY_REGION}'].ReplicaStatus" \
  --output text 2>/dev/null || echo "UNKNOWN")

log "DynamoDB primary replica status: ${REPL_STATUS}"

# =============================================================================
# Confirmation
# =============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    FAILBACK CONFIRMATION                       ║"
echo "║                                                                ║"
echo "║   You are about to return operations to the PRIMARY region.   ║"
echo "║                                                                ║"
echo "║   Before proceeding, confirm:                                  ║"
echo "║   □ Primary region has been stable for 4+ hours               ║"
echo "║   □ AWS has declared service fully restored                   ║"
echo "║   □ Operations team is available to monitor                   ║"
echo "║   □ Stakeholders have been notified                           ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

read -p "Has the primary region been stable for at least 4 hours? (yes/no): " CONFIRM1
if [ "$CONFIRM1" != "yes" ]; then
  log "Failback aborted - primary stability not confirmed"
  exit 1
fi

read -p "Type 'FAILBACK' to proceed: " CONFIRM2
if [ "$CONFIRM2" != "FAILBACK" ]; then
  log "Failback aborted by user"
  exit 1
fi

FAILBACK_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log ""
log "=== Starting Failback at ${FAILBACK_START} ==="

# =============================================================================
# Step 1: Verify Primary Region Services
# =============================================================================
log ""
log "=== Step 1: Verify Primary Region Services ==="

# Check Lambda functions
log "Checking primary Lambda functions..."
for FUNC in "census-handler" "census-fulfillment"; do
  FUNC_STATUS=$(aws lambda get-function \
    --function-name "${FUNC}" \
    --region "${PRIMARY_REGION}" \
    --query 'Configuration.State' \
    --output text 2>/dev/null || echo "NOT_FOUND")
  log "  ${FUNC}: ${FUNC_STATUS}"
done

# Check Lex bot
if [ -n "${PRIMARY_LEX_BOT_ID}" ]; then
  log "Checking primary Lex bot..."
  LEX_STATUS=$(aws lexv2-models describe-bot \
    --bot-id "${PRIMARY_LEX_BOT_ID}" \
    --region "${PRIMARY_REGION}" \
    --query 'botStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")
  log "  Lex bot: ${LEX_STATUS}"
fi

# =============================================================================
# Step 2: Re-enable Primary Health Check
# =============================================================================
log ""
log "=== Step 2: Re-enable DNS Health Check ==="

if [ -n "${PRIMARY_HEALTH_CHECK_ID}" ]; then
  aws route53 update-health-check \
    --health-check-id "${PRIMARY_HEALTH_CHECK_ID}" \
    --no-disabled
  
  log "Primary health check re-enabled"
  log "DNS will begin routing to primary region within 60 seconds"
else
  log "WARNING: No health check ID configured - update DNS manually"
fi

# =============================================================================
# Step 3: Update Active Region Parameter
# =============================================================================
log ""
log "=== Step 3: Update Active Region Parameter ==="

aws ssm put-parameter \
  --name "/ccaas/active-region" \
  --value "${PRIMARY_REGION}" \
  --type String \
  --overwrite \
  --region "${PRIMARY_REGION}"

aws ssm put-parameter \
  --name "/ccaas/active-region" \
  --value "${PRIMARY_REGION}" \
  --type String \
  --overwrite \
  --region "${DR_REGION}" 2>/dev/null || true

log "Active region parameter set to: ${PRIMARY_REGION}"

# =============================================================================
# Step 4: Update Primary Lambda Functions
# =============================================================================
log ""
log "=== Step 4: Update Primary Lambda Functions ==="

for FUNC in "census-handler" "census-fulfillment"; do
  if aws lambda get-function --function-name "${FUNC}" --region "${PRIMARY_REGION}" > /dev/null 2>&1; then
    aws lambda update-function-configuration \
      --function-name "${FUNC}" \
      --environment "Variables={ACTIVE_REGION=${PRIMARY_REGION},DYNAMODB_TABLE=${DYNAMODB_TABLE},IS_DR=false}" \
      --region "${PRIMARY_REGION}" > /dev/null 2>&1 || true
    log "  Updated: ${FUNC}"
  fi
done

# =============================================================================
# Step 5: Wait for DNS Propagation
# =============================================================================
log ""
log "=== Step 5: Wait for DNS Propagation ==="

log "Waiting 2 minutes for DNS changes to propagate..."
for i in {1..12}; do
  echo -n "."
  sleep 10
done
echo ""

log "DNS propagation period complete"

# =============================================================================
# Step 6: Notify Agents
# =============================================================================
log ""
log "=== Step 6: Notify Agents ==="

PRIMARY_CCP_URL="https://${PRIMARY_INSTANCE_ALIAS}.my.connect.aws/ccp-v2"

if [ -n "${NOTIFICATION_SNS_TOPIC}" ]; then
  NOTIFICATION_MESSAGE=$(cat << EOF
==========================================================
        RETURNING TO PRIMARY REGION
==========================================================

The contact center is returning to the primary region.

-----------------------------------------------------------
ACTION REQUIRED FOR ALL AGENTS:
-----------------------------------------------------------

1. LOG IN TO PRIMARY CCP:
   ${PRIMARY_CCP_URL}

2. Use your SAME username and password

3. Set your status to "Available"

-----------------------------------------------------------
PRIMARY PHONE NUMBERS:
-----------------------------------------------------------
[Use standard phone numbers - see documentation]

-----------------------------------------------------------
Details:
-----------------------------------------------------------
Primary Region: ${PRIMARY_REGION}
Failback Time:  $(date)

Thank you for your patience during the DR event.

==========================================================
EOF
)

  aws sns publish \
    --topic-arn "${NOTIFICATION_SNS_TOPIC}" \
    --subject "Contact Center Returning to Primary Region" \
    --message "${NOTIFICATION_MESSAGE}" \
    --region "${PRIMARY_REGION}"
  
  log "Agent notification sent"
else
  log "WARNING: No SNS topic - notify agents manually"
  echo ""
  echo "Primary CCP URL: ${PRIMARY_CCP_URL}"
fi

# =============================================================================
# Step 7: Log Failback Event
# =============================================================================
log ""
log "=== Step 7: Log Failback Event ==="

FAILBACK_RECORD=$(cat << EOF
{
  "eventId": {"S": "FAILBACK-$(date +%Y%m%d-%H%M%S)"},
  "timestamp": {"S": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"},
  "eventType": {"S": "DR_FAILBACK"},
  "fromRegion": {"S": "${DR_REGION}"},
  "toRegion": {"S": "${PRIMARY_REGION}"},
  "primaryInstanceId": {"S": "${PRIMARY_INSTANCE_ID}"},
  "status": {"S": "COMPLETED"}
}
EOF
)

aws dynamodb put-item \
  --table-name "${DYNAMODB_TABLE%-responses}-events" \
  --item "${FAILBACK_RECORD}" \
  --region "${PRIMARY_REGION}" 2>/dev/null || true

log "Failback event logged"

# =============================================================================
# Step 8: Validate Primary
# =============================================================================
log ""
log "=== Step 8: Quick Validation ==="

# Test primary Lambda
LAMBDA_TEST=$(aws lambda invoke \
  --function-name "census-handler" \
  --payload '{"action":"healthcheck"}' \
  --region "${PRIMARY_REGION}" \
  /tmp/failback-test.json 2>/dev/null && echo "OK" || echo "FAILED")
log "Primary Lambda test: ${LAMBDA_TEST}"

# Test primary DynamoDB
DB_TEST=$(aws dynamodb scan \
  --table-name "${DYNAMODB_TABLE}" \
  --limit 1 \
  --region "${PRIMARY_REGION}" > /dev/null 2>&1 && echo "OK" || echo "FAILED")
log "Primary DynamoDB test: ${DB_TEST}"

# =============================================================================
# Summary
# =============================================================================
FAILBACK_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log ""
log "=============================================="
log "  FAILBACK COMPLETE"
log "=============================================="
log ""
log "Start Time:     ${FAILBACK_START}"
log "End Time:       ${FAILBACK_END}"
log "Active Region:  ${PRIMARY_REGION}"
log ""
log "Primary CCP:    ${PRIMARY_CCP_URL}"
log ""
log "=============================================="
log "  POST-FAILBACK ACTIONS"
log "=============================================="
log ""
log "1. ☐ Verify agents can log into primary CCP"
log "2. ☐ Update customer communications with primary numbers"
log "3. ☐ Monitor call quality for 1 hour"
log "4. ☐ Verify all integrations working"
log "5. ☐ Schedule post-incident review (within 48 hours)"
log "6. ☐ Update DR documentation with lessons learned"
log ""
log "DR event concluded. Thank you for your response."
