#!/bin/bash
# =============================================================================
# Failover Phase 3: Agent Notification and Activation
# =============================================================================
# Notifies agents, provides DR CCP access info, and updates IVR
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
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AGENTS] $1"
}

log "=============================================="
log "  PHASE 3: AGENT FAILOVER"
log "=============================================="

# -----------------------------------------------------------------------------
# Step 1: Generate DR CCP URL
# -----------------------------------------------------------------------------
log ""
log "=== Step 1: DR CCP Information ==="

DR_CCP_URL="https://${DR_INSTANCE_ALIAS}.my.connect.aws/ccp-v2"
DR_ADMIN_URL="https://${DR_REGION}.console.aws.amazon.com/connect/home?region=${DR_REGION}#/instance/${DR_INSTANCE_ID}"

log "DR CCP URL:   ${DR_CCP_URL}"
log "DR Admin URL: ${DR_ADMIN_URL}"

# -----------------------------------------------------------------------------
# Step 2: Get Agent Count
# -----------------------------------------------------------------------------
log ""
log "=== Step 2: Agent Inventory ==="

USER_COUNT=$(aws connect list-users \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'length(UserSummaryList)' \
  --output text)

log "Total agents in DR instance: ${USER_COUNT}"

# List agents (first 20)
log "Agent list (first 20):"
aws connect list-users \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'UserSummaryList[0:20].{Username:Username,Id:Id}' \
  --output table

# -----------------------------------------------------------------------------
# Step 3: Get DR Phone Numbers for Customer Communication
# -----------------------------------------------------------------------------
log ""
log "=== Step 3: DR Phone Numbers ==="

DR_PHONE_NUMBERS=$(aws connect list-phone-numbers \
  --instance-id "${DR_INSTANCE_ID}" \
  --region "${DR_REGION}" \
  --query 'PhoneNumberSummaryList[*].PhoneNumber' \
  --output text)

log "DR Phone Numbers:"
for PHONE in ${DR_PHONE_NUMBERS}; do
  log "  ${PHONE}"
done

# -----------------------------------------------------------------------------
# Step 4: Send Agent Notifications via SNS
# -----------------------------------------------------------------------------
log ""
log "=== Step 4: Send Agent Notifications ==="

if [ -n "${NOTIFICATION_SNS_TOPIC}" ]; then
  NOTIFICATION_MESSAGE=$(cat << EOF
==========================================================
        DISASTER RECOVERY ACTIVATED - ACTION REQUIRED
==========================================================

The contact center has failed over to the DR region.

-----------------------------------------------------------
IMMEDIATE ACTION REQUIRED FOR ALL AGENTS:
-----------------------------------------------------------

1. LOG IN TO DR CONTACT CONTROL PANEL (CCP):
   ${DR_CCP_URL}

2. Use your SAME username and password

3. Set your status to "Available" once logged in

4. If you cannot log in, contact your supervisor

-----------------------------------------------------------
NEW CUSTOMER PHONE NUMBERS:
-----------------------------------------------------------
${DR_PHONE_NUMBERS:-Please contact supervisor for DR numbers}

-----------------------------------------------------------
IMPORTANT NOTES:
-----------------------------------------------------------
• All active calls in the primary region may have been lost
• Customer data is synchronized and available
• Chat customers will be automatically routed to DR
• Voice customers should be directed to new phone numbers

-----------------------------------------------------------
DR Details:
-----------------------------------------------------------
DR Region:      ${DR_REGION}
Activated At:   $(date)
DR Instance:    ${DR_INSTANCE_ALIAS}

Please confirm receipt with your supervisor immediately.

==========================================================
EOF
)

  aws sns publish \
    --topic-arn "${NOTIFICATION_SNS_TOPIC}" \
    --subject "URGENT: Contact Center DR Failover - Action Required" \
    --message "${NOTIFICATION_MESSAGE}" \
    --region "${DR_REGION}"
  
  log "Agent notification sent via SNS"
else
  log "WARNING: NOTIFICATION_SNS_TOPIC not set"
  log "Please notify agents manually with the following information:"
  echo ""
  echo "============================================"
  echo "  AGENT NOTIFICATION - COPY AND DISTRIBUTE"
  echo "============================================"
  echo ""
  echo "DR CCP URL: ${DR_CCP_URL}"
  echo ""
  echo "DR Phone Numbers:"
  for PHONE in ${DR_PHONE_NUMBERS}; do
    echo "  ${PHONE}"
  done
  echo ""
  echo "============================================"
fi

# -----------------------------------------------------------------------------
# Step 5: Send Email Notification (if configured)
# -----------------------------------------------------------------------------
log ""
log "=== Step 5: Email Notification ==="

if [ -n "${NOTIFICATION_EMAIL}" ]; then
  # Using SES if available
  EMAIL_BODY=$(cat << EOF
<html>
<body style="font-family: Arial, sans-serif;">
<h1 style="color: red;">⚠️ DISASTER RECOVERY ACTIVATED</h1>

<p>The contact center has failed over to the DR region at <strong>$(date)</strong>.</p>

<h2>Agent Instructions:</h2>
<ol>
<li>Log in to the DR CCP: <a href="${DR_CCP_URL}">${DR_CCP_URL}</a></li>
<li>Use your same username and password</li>
<li>Set your status to "Available"</li>
</ol>

<h2>New Customer Phone Numbers:</h2>
<ul>
$(for PHONE in ${DR_PHONE_NUMBERS}; do echo "<li>${PHONE}</li>"; done)
</ul>

<h2>Technical Details:</h2>
<table border="1" cellpadding="5">
<tr><td>DR Region</td><td>${DR_REGION}</td></tr>
<tr><td>DR Instance</td><td>${DR_INSTANCE_ALIAS}</td></tr>
<tr><td>Activation Time</td><td>$(date -u +%Y-%m-%dT%H:%M:%SZ)</td></tr>
</table>

<p style="color: red;"><strong>Please confirm receipt with your supervisor.</strong></p>

</body>
</html>
EOF
)

  # Attempt SES send (will fail gracefully if not configured)
  aws ses send-email \
    --from "noreply@${DOMAIN_NAME:-agency.gov}" \
    --to "${NOTIFICATION_EMAIL}" \
    --subject "URGENT: Contact Center DR Failover Activated" \
    --html "${EMAIL_BODY}" \
    --region "${DR_REGION}" 2>/dev/null || log "Note: SES email not sent (not configured)"
else
  log "Note: NOTIFICATION_EMAIL not configured"
fi

# -----------------------------------------------------------------------------
# Step 6: Log Failover Event
# -----------------------------------------------------------------------------
log ""
log "=== Step 6: Log Failover Event ==="

# Create failover record in DynamoDB for audit
FAILOVER_RECORD=$(cat << EOF
{
  "eventId": {"S": "FAILOVER-$(date +%Y%m%d-%H%M%S)"},
  "timestamp": {"S": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"},
  "eventType": {"S": "DR_FAILOVER"},
  "fromRegion": {"S": "${PRIMARY_REGION}"},
  "toRegion": {"S": "${DR_REGION}"},
  "drInstanceId": {"S": "${DR_INSTANCE_ID}"},
  "agentCount": {"N": "${USER_COUNT}"},
  "status": {"S": "COMPLETED"}
}
EOF
)

# Store in DR events table if it exists
aws dynamodb put-item \
  --table-name "${DYNAMODB_TABLE%-responses}-events" \
  --item "${FAILOVER_RECORD}" \
  --region "${DR_REGION}" 2>/dev/null || log "Note: Events table not configured"

log "Failover event logged"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log ""
log "=============================================="
log "  AGENT FAILOVER COMPLETE"
log "=============================================="
log ""
log "DR CCP URL:         ${DR_CCP_URL}"
log "Agents Available:   ${USER_COUNT}"
log "Notification Sent:  $([ -n "${NOTIFICATION_SNS_TOPIC}" ] && echo "Yes (SNS)" || echo "Manual required")"
log ""
log "=============================================="
log "  IMPORTANT MANUAL ACTIONS"
log "=============================================="
log ""
log "1. ☐ Verify agents can log into DR CCP"
log "2. ☐ Update website/IVR with new phone numbers"
log "3. ☐ Send customer communication if needed"
log "4. ☐ Monitor call quality for first hour"
log "5. ☐ Document any issues for post-incident review"
log ""
log "Next step: Run validate-failover.sh to verify all systems"
