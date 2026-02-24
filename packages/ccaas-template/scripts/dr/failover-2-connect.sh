#!/bin/bash
# =============================================================================
# Failover Phase 2: Amazon Connect
# =============================================================================
# Activates DR Connect instance, enables queues, and associates resources
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
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CONNECT] $1"
}

log "=============================================="
log "  PHASE 2: AMAZON CONNECT FAILOVER"
log "=============================================="

# -----------------------------------------------------------------------------
# Step 1: Get Latest Configuration Backup Info
# -----------------------------------------------------------------------------
log ""
log "=== Step 1: Configuration Backup Info ==="

LATEST_BACKUP=$(aws s3 cp "s3://${CONFIG_BUCKET}/connect-config/LATEST" - --region "${PRIMARY_REGION}" 2>/dev/null || echo "UNKNOWN")
log "Latest configuration backup: ${LATEST_BACKUP}"

# -----------------------------------------------------------------------------
# Step 2: Verify DR Connect Instance Status
# -----------------------------------------------------------------------------
log ""
log "=== Step 2: Verify DR Connect Instance ==="

INSTANCE_STATUS=$(aws connect describe-instance \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'Instance.InstanceStatus' \
  --output text)

if [ "$INSTANCE_STATUS" != "ACTIVE" ]; then
  log "ERROR: DR Connect instance not active. Status: ${INSTANCE_STATUS}"
  exit 1
fi

log "DR Instance ID:     ${DR_INSTANCE_ID}"
log "DR Instance Alias:  ${DR_INSTANCE_ALIAS}"
log "DR Instance Status: ${INSTANCE_STATUS}"

# Get instance ARN
INSTANCE_ARN=$(aws connect describe-instance \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'Instance.Arn' \
  --output text)
log "DR Instance ARN:    ${INSTANCE_ARN}"

# -----------------------------------------------------------------------------
# Step 3: Enable All Queues
# -----------------------------------------------------------------------------
log ""
log "=== Step 3: Enable Queues ==="

QUEUE_IDS=$(aws connect list-queues \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --queue-types "STANDARD" \
  --query 'QueueSummaryList[*].Id' \
  --output text)

QUEUE_COUNT=0
for QUEUE_ID in ${QUEUE_IDS}; do
  QUEUE_NAME=$(aws connect describe-queue \
    --instance-id "${DR_INSTANCE_ID}" \
    --queue-id "${QUEUE_ID}" \
    --region "${DR_REGION}" \
    --query 'Queue.Name' \
    --output text 2>/dev/null || echo "Unknown")
  
  aws connect update-queue-status \
    --instance-id "${DR_INSTANCE_ID}" \
    --queue-id "${QUEUE_ID}" \
    --status "ENABLED" \
    --region "${DR_REGION}" 2>/dev/null || true
  
  log "  Enabled queue: ${QUEUE_NAME}"
  ((QUEUE_COUNT++))
done

log "Total queues enabled: ${QUEUE_COUNT}"

# -----------------------------------------------------------------------------
# Step 4: Associate Lambda Functions
# -----------------------------------------------------------------------------
log ""
log "=== Step 4: Associate Lambda Functions ==="

LAMBDA_FUNCTIONS=("census-handler" "census-fulfillment")

for FUNC in "${LAMBDA_FUNCTIONS[@]}"; do
  LAMBDA_ARN="arn:aws:lambda:${DR_REGION}:${AWS_ACCOUNT_ID}:function:${FUNC}"
  
  # Check if function exists
  if aws lambda get-function --function-name "${FUNC}" --region "${DR_REGION}" > /dev/null 2>&1; then
    aws connect associate-lambda-function \
      --instance-id "${DR_INSTANCE_ID}" \
      --function-arn "${LAMBDA_ARN}" \
      --region "${DR_REGION}" 2>/dev/null || log "  Lambda ${FUNC} already associated"
    log "  Associated Lambda: ${FUNC}"
  else
    log "  Lambda ${FUNC} not found in DR region - skipping"
  fi
done

# -----------------------------------------------------------------------------
# Step 5: Associate Lex Bot
# -----------------------------------------------------------------------------
log ""
log "=== Step 5: Associate Lex Bot ==="

if [ -n "${DR_LEX_BOT_ID}" ] && [ -n "${DR_LEX_ALIAS_ID}" ]; then
  LEX_ALIAS_ARN="arn:aws:lex:${DR_REGION}:${AWS_ACCOUNT_ID}:bot-alias/${DR_LEX_BOT_ID}/${DR_LEX_ALIAS_ID}"
  
  aws connect associate-bot \
    --instance-id "${DR_INSTANCE_ID}" \
    --lex-v2-bot "AliasArn=${LEX_ALIAS_ARN}" \
    --region "${DR_REGION}" 2>/dev/null || log "  Lex bot already associated"
  
  log "  Associated Lex bot: ${DR_LEX_BOT_ID}"
else
  log "  Note: Lex bot IDs not configured - skipping"
fi

# -----------------------------------------------------------------------------
# Step 6: Verify Contact Flows
# -----------------------------------------------------------------------------
log ""
log "=== Step 6: Verify Contact Flows ==="

FLOW_COUNT=$(aws connect list-contact-flows \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(ContactFlowSummaryList)' \
  --output text)

log "Contact flows in DR instance: ${FLOW_COUNT}"

# Check for main inbound flow
MAIN_FLOW_ID=$(aws connect list-contact-flows \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --contact-flow-types "CONTACT_FLOW" \
  --query "ContactFlowSummaryList[?contains(Name, 'Inbound') || contains(Name, 'Census')].Id | [0]" \
  --output text 2>/dev/null || echo "")

if [ -n "$MAIN_FLOW_ID" ] && [ "$MAIN_FLOW_ID" != "None" ]; then
  FLOW_STATE=$(aws connect describe-contact-flow \
    --instance-id "${DR_INSTANCE_ID}" \
    --contact-flow-id "${MAIN_FLOW_ID}" \
    --region "${DR_REGION}" \
    --query 'ContactFlow.State' \
    --output text)
  log "Main contact flow state: ${FLOW_STATE}"
else
  log "Note: Main contact flow not identified - verify manually"
fi

# -----------------------------------------------------------------------------
# Step 7: Verify Phone Numbers
# -----------------------------------------------------------------------------
log ""
log "=== Step 7: Verify Phone Numbers ==="

aws connect list-phone-numbers \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'PhoneNumberSummaryList[*].{Number:PhoneNumber,Type:PhoneNumberType,Flow:ContactFlowId}' \
  --output table

PHONE_COUNT=$(aws connect list-phone-numbers \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(PhoneNumberSummaryList)' \
  --output text)

log "Phone numbers in DR instance: ${PHONE_COUNT}"

if [ "$PHONE_COUNT" -eq 0 ]; then
  log "WARNING: No phone numbers claimed in DR instance!"
  log "You will need to claim numbers or port numbers to DR instance."
fi

# -----------------------------------------------------------------------------
# Step 8: Verify Routing Profiles
# -----------------------------------------------------------------------------
log ""
log "=== Step 8: Verify Routing Profiles ==="

PROFILE_COUNT=$(aws connect list-routing-profiles \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(RoutingProfileSummaryList)' \
  --output text)

log "Routing profiles in DR instance: ${PROFILE_COUNT}"

# -----------------------------------------------------------------------------
# Step 9: Verify Users
# -----------------------------------------------------------------------------
log ""
log "=== Step 9: Verify Users ==="

USER_COUNT=$(aws connect list-users \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(UserSummaryList)' \
  --output text)

log "Users in DR instance: ${USER_COUNT}"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log ""
log "=============================================="
log "  CONNECT FAILOVER COMPLETE"
log "=============================================="
log ""
log "DR Connect Instance: ${DR_INSTANCE_ID}"
log "DR Region:           ${DR_REGION}"
log ""
log "Resources:"
log "  Queues:            ${QUEUE_COUNT} enabled"
log "  Contact Flows:     ${FLOW_COUNT}"
log "  Phone Numbers:     ${PHONE_COUNT}"
log "  Routing Profiles:  ${PROFILE_COUNT}"
log "  Users:             ${USER_COUNT}"
log ""
log "CCP URL: https://${DR_INSTANCE_ALIAS}.my.connect.aws/ccp-v2"
log ""
log "Next step: Run failover-3-agents.sh"
