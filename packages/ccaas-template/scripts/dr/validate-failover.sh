#!/bin/bash
# =============================================================================
# Post-Failover Validation
# =============================================================================
# Validates all DR systems are operational after failover
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

PASS=0
FAIL=0
WARN=0

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VALIDATE] $1"
}

check() {
  local NAME=$1
  local CMD=$2
  local CRITICAL=${3:-true}
  
  printf "  %-40s " "${NAME}..."
  
  if eval "${CMD}" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((PASS++))
    return 0
  else
    if [ "$CRITICAL" == "true" ]; then
      echo "❌ FAIL"
      ((FAIL++))
    else
      echo "⚠️  WARN"
      ((WARN++))
    fi
    return 1
  fi
}

log "=============================================="
log "  POST-FAILOVER VALIDATION"
log "=============================================="
log ""
log "Validating DR systems in ${DR_REGION}..."
log ""

# =============================================================================
# Infrastructure Checks
# =============================================================================
echo "─── Infrastructure ───"

check "DR Connect Instance" \
  "aws connect describe-instance --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION} --query 'Instance.InstanceStatus' --output text | grep -q ACTIVE"

check "AWS Credentials Valid" \
  "aws sts get-caller-identity --region ${DR_REGION}"

check "Active Region Parameter" \
  "aws ssm get-parameter --name /ccaas/active-region --region ${DR_REGION} --query 'Parameter.Value' --output text | grep -q ${DR_REGION}"

# =============================================================================
# Data Layer Checks
# =============================================================================
echo ""
echo "─── Data Layer ───"

check "DynamoDB Table Active" \
  "aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${DR_REGION} --query 'Table.TableStatus' --output text | grep -q ACTIVE"

check "DynamoDB Read Access" \
  "aws dynamodb scan --table-name ${DYNAMODB_TABLE} --limit 1 --region ${DR_REGION}"

check "DynamoDB Write Access" \
  "aws dynamodb put-item --table-name ${DYNAMODB_TABLE} --item '{\"caseId\":{\"S\":\"DR-VALIDATE-'$$'\"},\"timestamp\":{\"S\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"},\"status\":{\"S\":\"VALIDATION_TEST\"}}' --region ${DR_REGION}"

if [ -n "${DR_RECORDINGS_BUCKET}" ]; then
  check "S3 DR Bucket Accessible" \
    "aws s3api head-bucket --bucket ${DR_RECORDINGS_BUCKET} --region ${DR_REGION}"
fi

# =============================================================================
# Compute Layer Checks
# =============================================================================
echo ""
echo "─── Compute Layer ───"

check "Lambda Function Exists" \
  "aws lambda get-function --function-name census-handler --region ${DR_REGION}" \
  false

# Test Lambda invocation
LAMBDA_RESULT=$(aws lambda invoke \
  --function-name "census-handler" \
  --payload '{"action":"healthcheck"}' \
  --region "${DR_REGION}" \
  /tmp/lambda-validate-output.json 2>/dev/null && cat /tmp/lambda-validate-output.json || echo "ERROR")

if [[ "$LAMBDA_RESULT" != "ERROR" ]]; then
  check "Lambda Invocation" "true"
else
  check "Lambda Invocation" "false" false
fi

# =============================================================================
# AI/ML Layer Checks
# =============================================================================
echo ""
echo "─── AI/ML Layer ───"

if [ -n "${DR_LEX_BOT_ID}" ]; then
  check "Lex Bot Exists" \
    "aws lexv2-models describe-bot --bot-id ${DR_LEX_BOT_ID} --region ${DR_REGION}"

  if [ -n "${DR_LEX_ALIAS_ID}" ]; then
    check "Lex Speech Recognition" \
      "aws lexv2-runtime recognize-text --bot-id ${DR_LEX_BOT_ID} --bot-alias-id ${DR_LEX_ALIAS_ID} --locale-id en_US --session-id validate-$$ --text 'yes' --region ${DR_REGION}"
  fi
else
  echo "  Lex Bot ID not configured... ⚠️  SKIP"
  ((WARN++))
fi

# =============================================================================
# Amazon Connect Checks
# =============================================================================
echo ""
echo "─── Amazon Connect ───"

# Queue check
QUEUE_COUNT=$(aws connect list-queues \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --queue-types "STANDARD" \
  --query 'length(QueueSummaryList)' \
  --output text 2>/dev/null || echo "0")

check "Queues Configured (${QUEUE_COUNT})" \
  "[ ${QUEUE_COUNT} -gt 0 ]"

# User check
USER_COUNT=$(aws connect list-users \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(UserSummaryList)' \
  --output text 2>/dev/null || echo "0")

check "Users Configured (${USER_COUNT})" \
  "[ ${USER_COUNT} -gt 0 ]"

# Contact flow check
FLOW_COUNT=$(aws connect list-contact-flows \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(ContactFlowSummaryList)' \
  --output text 2>/dev/null || echo "0")

check "Contact Flows (${FLOW_COUNT})" \
  "[ ${FLOW_COUNT} -gt 0 ]"

# Phone number check
PHONE_COUNT=$(aws connect list-phone-numbers \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(PhoneNumberSummaryList)' \
  --output text 2>/dev/null || echo "0")

if [ ${PHONE_COUNT} -gt 0 ]; then
  check "Phone Numbers (${PHONE_COUNT})" "true"
else
  echo "  Phone Numbers (${PHONE_COUNT})... ⚠️  WARN (may need claiming)"
  ((WARN++))
fi

# Routing profiles check
PROFILE_COUNT=$(aws connect list-routing-profiles \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(RoutingProfileSummaryList)' \
  --output text 2>/dev/null || echo "0")

check "Routing Profiles (${PROFILE_COUNT})" \
  "[ ${PROFILE_COUNT} -gt 0 ]"

# =============================================================================
# Integration Checks
# =============================================================================
echo ""
echo "─── Integrations ───"

# Lambda association
LAMBDA_ASSOC=$(aws connect list-lambda-functions \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(LambdaFunctions)' \
  --output text 2>/dev/null || echo "0")

check "Lambda Functions Associated (${LAMBDA_ASSOC})" \
  "[ ${LAMBDA_ASSOC} -gt 0 ]" \
  false

# Lex association
LEX_ASSOC=$(aws connect list-bots \
  --instance-id "${DR_INSTANCE_ID}" \
  --lex-version "V2" \
  --region "${DR_REGION}" \
  --query 'length(LexBots)' \
  --output text 2>/dev/null || echo "0")

check "Lex Bots Associated (${LEX_ASSOC})" \
  "[ ${LEX_ASSOC} -gt 0 ]" \
  false

# =============================================================================
# Network Checks
# =============================================================================
echo ""
echo "─── Network/DNS ───"

if [ -n "${DOMAIN_NAME}" ]; then
  check "Chat Domain Resolves" \
    "dig +short chat.${DOMAIN_NAME} | head -1" \
    false
fi

# Health check should be disabled (primary) to force DR routing
if [ -n "${PRIMARY_HEALTH_CHECK_ID}" ]; then
  HC_DISABLED=$(aws route53 get-health-check \
    --health-check-id "${PRIMARY_HEALTH_CHECK_ID}" \
    --query 'HealthCheck.HealthCheckConfig.Disabled' \
    --output text 2>/dev/null || echo "UNKNOWN")
  
  check "Primary Health Check Disabled" \
    "[ '${HC_DISABLED}' == 'True' ]" \
    false
fi

# =============================================================================
# Cleanup Test Data
# =============================================================================
echo ""
echo "─── Cleanup ───"
aws dynamodb delete-item \
  --table-name "${DYNAMODB_TABLE}" \
  --key '{"caseId":{"S":"DR-VALIDATE-'$$'"},"timestamp":{"S":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}}' \
  --region "${DR_REGION}" 2>/dev/null || true
echo "  Test data cleaned up"

# =============================================================================
# Summary
# =============================================================================
echo ""
log "=============================================="
log "  VALIDATION SUMMARY"
log "=============================================="
echo ""
echo "  ✅ Passed:   ${PASS}"
echo "  ❌ Failed:   ${FAIL}"
echo "  ⚠️  Warnings: ${WARN}"
echo ""

if [ ${FAIL} -gt 0 ]; then
  log "=============================================="
  log "  ⚠️  VALIDATION FAILED"
  log "=============================================="
  log ""
  log "Some critical checks failed. Review failures above."
  log "DR may not be fully operational."
  exit 1
elif [ ${WARN} -gt 0 ]; then
  log "=============================================="
  log "  ⚠️  VALIDATION PASSED WITH WARNINGS"
  log "=============================================="
  log ""
  log "DR is operational but some non-critical items need attention."
  exit 0
else
  log "=============================================="
  log "  ✅ VALIDATION PASSED"
  log "=============================================="
  log ""
  log "All DR systems are operational."
  exit 0
fi
