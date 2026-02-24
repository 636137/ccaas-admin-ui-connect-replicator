#!/bin/bash
# =============================================================================
# Failover Phase 1: Infrastructure
# =============================================================================
# Handles DNS failover, DynamoDB promotion, and Lambda activation in DR region
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
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFRA] $1"
}

log "=============================================="
log "  PHASE 1: INFRASTRUCTURE FAILOVER"
log "=============================================="

# -----------------------------------------------------------------------------
# Step 1: Verify DR Region Connectivity
# -----------------------------------------------------------------------------
log ""
log "=== Step 1: Verify DR Region Connectivity ==="

ACCOUNT_ID=$(aws sts get-caller-identity --region "${DR_REGION}" --query 'Account' --output text)
log "AWS Account: ${ACCOUNT_ID}"
log "DR Region:   ${DR_REGION}"

# Verify we can reach DR services
aws connect describe-instance \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'Instance.InstanceStatus' \
  --output text > /dev/null

log "DR Region connectivity: OK"

# -----------------------------------------------------------------------------
# Step 2: DynamoDB - Verify Global Tables
# -----------------------------------------------------------------------------
log ""
log "=== Step 2: Verify DynamoDB Global Tables ==="

# Check that DR replica is active
DR_TABLE_STATUS=$(aws dynamodb describe-table \
  --table-name "${DYNAMODB_TABLE}" \
  --region "${DR_REGION}" \
  --query 'Table.TableStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$DR_TABLE_STATUS" == "ACTIVE" ]; then
  log "DynamoDB table '${DYNAMODB_TABLE}' in ${DR_REGION}: ACTIVE"
else
  log "WARNING: DynamoDB table status: ${DR_TABLE_STATUS}"
fi

# Check replication status
REPL_STATUS=$(aws dynamodb describe-table \
  --table-name "${DYNAMODB_TABLE}" \
  --region "${PRIMARY_REGION}" \
  --query "Table.Replicas[?RegionName=='${DR_REGION}'].ReplicaStatus" \
  --output text 2>/dev/null || echo "UNKNOWN")

log "DynamoDB replication to ${DR_REGION}: ${REPL_STATUS}"

# For addresses table
if [ -n "${DYNAMODB_ADDRESSES_TABLE}" ]; then
  DR_ADDR_STATUS=$(aws dynamodb describe-table \
    --table-name "${DYNAMODB_ADDRESSES_TABLE}" \
    --region "${DR_REGION}" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null || echo "NOT_CONFIGURED")
  log "DynamoDB table '${DYNAMODB_ADDRESSES_TABLE}' in ${DR_REGION}: ${DR_ADDR_STATUS}"
fi

# -----------------------------------------------------------------------------
# Step 3: Update Active Region Parameter
# -----------------------------------------------------------------------------
log ""
log "=== Step 3: Update Active Region Parameter ==="

aws ssm put-parameter \
  --name "/ccaas/active-region" \
  --value "${DR_REGION}" \
  --type String \
  --overwrite \
  --region "${DR_REGION}"

log "Active region parameter set to: ${DR_REGION}"

# Also update in primary region (if accessible) for consistency
aws ssm put-parameter \
  --name "/ccaas/active-region" \
  --value "${DR_REGION}" \
  --type String \
  --overwrite \
  --region "${PRIMARY_REGION}" 2>/dev/null || log "Note: Could not update primary region parameter"

# -----------------------------------------------------------------------------
# Step 4: DNS Failover via Route 53
# -----------------------------------------------------------------------------
log ""
log "=== Step 4: DNS Failover ==="

if [ -n "${PRIMARY_HEALTH_CHECK_ID}" ]; then
  # Disable primary health check to force DNS failover
  aws route53 update-health-check \
    --health-check-id "${PRIMARY_HEALTH_CHECK_ID}" \
    --disabled
  
  log "Primary health check disabled - DNS failover triggered"
  log "Chat traffic will shift to DR region within 60 seconds"
else
  log "WARNING: PRIMARY_HEALTH_CHECK_ID not set - manual DNS update may be required"
fi

# -----------------------------------------------------------------------------
# Step 5: Activate DR Lambda Functions
# -----------------------------------------------------------------------------
log ""
log "=== Step 5: Activate DR Lambda Functions ==="

# Update Lambda environment variables to point to DR resources
LAMBDA_FUNCTIONS=("census-handler" "census-fulfillment")

for FUNC in "${LAMBDA_FUNCTIONS[@]}"; do
  FUNC_EXISTS=$(aws lambda get-function \
    --function-name "${FUNC}" \
    --region "${DR_REGION}" \
    --query 'Configuration.FunctionName' \
    --output text 2>/dev/null || echo "NOT_FOUND")
  
  if [ "$FUNC_EXISTS" != "NOT_FOUND" ]; then
    aws lambda update-function-configuration \
      --function-name "${FUNC}" \
      --environment "Variables={ACTIVE_REGION=${DR_REGION},DYNAMODB_TABLE=${DYNAMODB_TABLE},IS_DR=true}" \
      --region "${DR_REGION}" > /dev/null
    log "Updated Lambda function: ${FUNC}"
  else
    log "Lambda function ${FUNC} not found in DR region"
  fi
done

# -----------------------------------------------------------------------------
# Step 6: Verify DR Lex Bot
# -----------------------------------------------------------------------------
log ""
log "=== Step 6: Verify DR Lex Bot ==="

if [ -n "${DR_LEX_BOT_ID}" ] && [ -n "${DR_LEX_ALIAS_ID}" ]; then
  LEX_TEST=$(aws lexv2-runtime recognize-text \
    --bot-id "${DR_LEX_BOT_ID}" \
    --bot-alias-id "${DR_LEX_ALIAS_ID}" \
    --locale-id "en_US" \
    --session-id "dr-test-$(date +%s)" \
    --text "Hello" \
    --region "${DR_REGION}" \
    --query 'messages[0].content' \
    --output text 2>/dev/null || echo "FAILED")
  
  if [ "$LEX_TEST" != "FAILED" ]; then
    log "DR Lex bot test: PASSED"
  else
    log "WARNING: DR Lex bot test failed - check configuration"
  fi
else
  log "Note: DR Lex bot IDs not configured"
fi

# -----------------------------------------------------------------------------
# Step 7: Verify S3 Bucket Access
# -----------------------------------------------------------------------------
log ""
log "=== Step 7: Verify S3 Bucket Access ==="

if aws s3api head-bucket --bucket "${DR_RECORDINGS_BUCKET}" --region "${DR_REGION}" 2>/dev/null; then
  log "DR recordings bucket accessible: ${DR_RECORDINGS_BUCKET}"
else
  log "WARNING: Cannot access DR recordings bucket"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log ""
log "=============================================="
log "  INFRASTRUCTURE FAILOVER COMPLETE"
log "=============================================="
log ""
log "Active Region:    ${DR_REGION}"
log "DynamoDB Status:  ${DR_TABLE_STATUS}"
log "DNS Failover:     Triggered"
log ""
log "Next step: Run failover-2-connect.sh"
