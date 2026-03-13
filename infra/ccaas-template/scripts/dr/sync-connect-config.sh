#!/bin/bash
# =============================================================================
# Sync Connect Configuration to DR Region
# =============================================================================
# Exports Amazon Connect configuration from primary and stores in S3
# Run this regularly (daily) via cron or automation
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

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
EXPORT_DIR="/tmp/connect-export-${TIMESTAMP}"
mkdir -p "${EXPORT_DIR}"
mkdir -p "${EXPORT_DIR}/contact-flows"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "=== Connect Configuration Export ==="
log "Primary Instance: ${PRIMARY_INSTANCE_ID} in ${PRIMARY_REGION}"
log "Timestamp: ${TIMESTAMP}"

# -----------------------------------------------------------------------------
# Export Hours of Operation
# -----------------------------------------------------------------------------
log "Exporting Hours of Operation..."
aws connect list-hours-of-operations \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/hours-of-operations.json"

# Get detailed info for each
HOURS_IDS=$(aws connect list-hours-of-operations \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'HoursOfOperationSummaryList[*].Id' \
  --output text)

mkdir -p "${EXPORT_DIR}/hours-of-operations"
for HOURS_ID in ${HOURS_IDS}; do
  aws connect describe-hours-of-operation \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --hours-of-operation-id "${HOURS_ID}" \
    --region "${PRIMARY_REGION}" \
    --output json > "${EXPORT_DIR}/hours-of-operations/${HOURS_ID}.json" 2>/dev/null || true
done

# -----------------------------------------------------------------------------
# Export Queues
# -----------------------------------------------------------------------------
log "Exporting Queues..."
aws connect list-queues \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --queue-types "STANDARD" \
  --output json > "${EXPORT_DIR}/queues.json"

QUEUE_IDS=$(aws connect list-queues \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --queue-types "STANDARD" \
  --query 'QueueSummaryList[*].Id' \
  --output text)

mkdir -p "${EXPORT_DIR}/queues"
for QUEUE_ID in ${QUEUE_IDS}; do
  aws connect describe-queue \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --queue-id "${QUEUE_ID}" \
    --region "${PRIMARY_REGION}" \
    --output json > "${EXPORT_DIR}/queues/${QUEUE_ID}.json" 2>/dev/null || true
done

# -----------------------------------------------------------------------------
# Export Routing Profiles
# -----------------------------------------------------------------------------
log "Exporting Routing Profiles..."
aws connect list-routing-profiles \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/routing-profiles.json"

PROFILE_IDS=$(aws connect list-routing-profiles \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'RoutingProfileSummaryList[*].Id' \
  --output text)

mkdir -p "${EXPORT_DIR}/routing-profiles"
for PROFILE_ID in ${PROFILE_IDS}; do
  aws connect describe-routing-profile \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --routing-profile-id "${PROFILE_ID}" \
    --region "${PRIMARY_REGION}" \
    --output json > "${EXPORT_DIR}/routing-profiles/${PROFILE_ID}.json" 2>/dev/null || true
done

# -----------------------------------------------------------------------------
# Export Users (without passwords)
# -----------------------------------------------------------------------------
log "Exporting Users..."
aws connect list-users \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/users.json"

USER_IDS=$(aws connect list-users \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --query 'UserSummaryList[*].Id' \
  --output text)

mkdir -p "${EXPORT_DIR}/users"
for USER_ID in ${USER_IDS}; do
  aws connect describe-user \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --user-id "${USER_ID}" \
    --region "${PRIMARY_REGION}" \
    --output json > "${EXPORT_DIR}/users/${USER_ID}.json" 2>/dev/null || true
done

# -----------------------------------------------------------------------------
# Export Security Profiles
# -----------------------------------------------------------------------------
log "Exporting Security Profiles..."
aws connect list-security-profiles \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/security-profiles.json"

# -----------------------------------------------------------------------------
# Export Contact Flows (Full Content)
# -----------------------------------------------------------------------------
log "Exporting Contact Flows..."
FLOW_SUMMARY=$(aws connect list-contact-flows \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json)

echo "${FLOW_SUMMARY}" > "${EXPORT_DIR}/contact-flows-summary.json"

FLOW_IDS=$(echo "${FLOW_SUMMARY}" | jq -r '.ContactFlowSummaryList[].Id' 2>/dev/null || \
  aws connect list-contact-flows \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --region "${PRIMARY_REGION}" \
    --query 'ContactFlowSummaryList[*].Id' \
    --output text)

FLOW_COUNT=0
for FLOW_ID in ${FLOW_IDS}; do
  aws connect describe-contact-flow \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --contact-flow-id "${FLOW_ID}" \
    --region "${PRIMARY_REGION}" \
    --output json > "${EXPORT_DIR}/contact-flows/${FLOW_ID}.json" 2>/dev/null || true
  ((FLOW_COUNT++))
done
log "Exported ${FLOW_COUNT} contact flows"

# -----------------------------------------------------------------------------
# Export Contact Flow Modules
# -----------------------------------------------------------------------------
log "Exporting Contact Flow Modules..."
aws connect list-contact-flow-modules \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/contact-flow-modules.json" 2>/dev/null || echo '{"ContactFlowModulesSummaryList":[]}' > "${EXPORT_DIR}/contact-flow-modules.json"

# -----------------------------------------------------------------------------
# Export Quick Connects
# -----------------------------------------------------------------------------
log "Exporting Quick Connects..."
aws connect list-quick-connects \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/quick-connects.json"

# -----------------------------------------------------------------------------
# Export Prompts (List only - audio files stored separately)
# -----------------------------------------------------------------------------
log "Exporting Prompts list..."
aws connect list-prompts \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/prompts.json"

# -----------------------------------------------------------------------------
# Export Agent Statuses
# -----------------------------------------------------------------------------
log "Exporting Agent Statuses..."
aws connect list-agent-statuses \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/agent-statuses.json" 2>/dev/null || echo '{"AgentStatusSummaryList":[]}' > "${EXPORT_DIR}/agent-statuses.json"

# -----------------------------------------------------------------------------
# Export Phone Numbers
# -----------------------------------------------------------------------------
log "Exporting Phone Numbers..."
aws connect list-phone-numbers \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/phone-numbers.json"

# -----------------------------------------------------------------------------
# Export Lambda Function Associations
# -----------------------------------------------------------------------------
log "Exporting Lambda Function Associations..."
aws connect list-lambda-functions \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/lambda-functions.json" 2>/dev/null || echo '{"LambdaFunctions":[]}' > "${EXPORT_DIR}/lambda-functions.json"

# -----------------------------------------------------------------------------
# Export Lex Bot Associations
# -----------------------------------------------------------------------------
log "Exporting Lex Bot Associations..."
aws connect list-bots \
  --instance-id "${PRIMARY_INSTANCE_ID}" \
  --lex-version "V2" \
  --region "${PRIMARY_REGION}" \
  --output json > "${EXPORT_DIR}/lex-bots.json" 2>/dev/null || echo '{"LexBots":[]}' > "${EXPORT_DIR}/lex-bots.json"

# -----------------------------------------------------------------------------
# Create Manifest
# -----------------------------------------------------------------------------
log "Creating export manifest..."
cat > "${EXPORT_DIR}/manifest.json" << EOF
{
  "exportTimestamp": "${TIMESTAMP}",
  "exportDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "primaryRegion": "${PRIMARY_REGION}",
  "primaryInstanceId": "${PRIMARY_INSTANCE_ID}",
  "primaryInstanceAlias": "${PRIMARY_INSTANCE_ALIAS}",
  "drRegion": "${DR_REGION}",
  "drInstanceId": "${DR_INSTANCE_ID}",
  "drInstanceAlias": "${DR_INSTANCE_ALIAS}",
  "exportedResources": {
    "hoursOfOperations": $(cat "${EXPORT_DIR}/hours-of-operations.json" | jq '.HoursOfOperationSummaryList | length' 2>/dev/null || echo 0),
    "queues": $(cat "${EXPORT_DIR}/queues.json" | jq '.QueueSummaryList | length' 2>/dev/null || echo 0),
    "routingProfiles": $(cat "${EXPORT_DIR}/routing-profiles.json" | jq '.RoutingProfileSummaryList | length' 2>/dev/null || echo 0),
    "users": $(cat "${EXPORT_DIR}/users.json" | jq '.UserSummaryList | length' 2>/dev/null || echo 0),
    "securityProfiles": $(cat "${EXPORT_DIR}/security-profiles.json" | jq '.SecurityProfileSummaryList | length' 2>/dev/null || echo 0),
    "contactFlows": ${FLOW_COUNT},
    "quickConnects": $(cat "${EXPORT_DIR}/quick-connects.json" | jq '.QuickConnectSummaryList | length' 2>/dev/null || echo 0),
    "prompts": $(cat "${EXPORT_DIR}/prompts.json" | jq '.PromptSummaryList | length' 2>/dev/null || echo 0),
    "phoneNumbers": $(cat "${EXPORT_DIR}/phone-numbers.json" | jq '.PhoneNumberSummaryList | length' 2>/dev/null || echo 0)
  }
}
EOF

# -----------------------------------------------------------------------------
# Upload to S3
# -----------------------------------------------------------------------------
log "Uploading configuration to S3..."
aws s3 sync "${EXPORT_DIR}" "s3://${CONFIG_BUCKET}/connect-config/${TIMESTAMP}/" \
  --region "${PRIMARY_REGION}" \
  --sse aws:kms

# Update latest pointer
echo "${TIMESTAMP}" | aws s3 cp - "s3://${CONFIG_BUCKET}/connect-config/LATEST" \
  --region "${PRIMARY_REGION}"

# Keep last 30 backups
log "Cleaning old backups..."
aws s3 ls "s3://${CONFIG_BUCKET}/connect-config/" --region "${PRIMARY_REGION}" | \
  sort -r | \
  tail -n +31 | \
  awk '{print $2}' | \
  while read PREFIX; do
    if [ -n "$PREFIX" ] && [ "$PREFIX" != "LATEST" ]; then
      aws s3 rm "s3://${CONFIG_BUCKET}/connect-config/${PREFIX}" --recursive --region "${PRIMARY_REGION}" 2>/dev/null || true
    fi
  done

# -----------------------------------------------------------------------------
# Cleanup Local
# -----------------------------------------------------------------------------
rm -rf "${EXPORT_DIR}"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log "=== Export Complete ==="
log "Configuration backed up to: s3://${CONFIG_BUCKET}/connect-config/${TIMESTAMP}/"
log ""
log "Summary:"
cat << EOF
  Hours of Operation: $(cat "${EXPORT_DIR}/hours-of-operations.json" 2>/dev/null | jq '.HoursOfOperationSummaryList | length' 2>/dev/null || echo "N/A")
  Queues:             $(cat "${EXPORT_DIR}/queues.json" 2>/dev/null | jq '.QueueSummaryList | length' 2>/dev/null || echo "N/A")
  Routing Profiles:   $(cat "${EXPORT_DIR}/routing-profiles.json" 2>/dev/null | jq '.RoutingProfileSummaryList | length' 2>/dev/null || echo "N/A")
  Users:              $(cat "${EXPORT_DIR}/users.json" 2>/dev/null | jq '.UserSummaryList | length' 2>/dev/null || echo "N/A")
  Contact Flows:      ${FLOW_COUNT}
  Phone Numbers:      $(cat "${EXPORT_DIR}/phone-numbers.json" 2>/dev/null | jq '.PhoneNumberSummaryList | length' 2>/dev/null || echo "N/A")
EOF
