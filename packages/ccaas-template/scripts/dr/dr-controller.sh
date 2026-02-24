#!/bin/bash
# =============================================================================
# Government CCaaS DR Controller
# =============================================================================
# Master script for all Disaster Recovery operations
# 
# Usage: ./dr-controller.sh <command> [options]
# 
# Commands:
#   status      - Check DR readiness status
#   sync        - Sync configuration to DR region
#   failover    - Execute full DR failover
#   failback    - Return to primary region
#   test        - Test DR procedures (dry run)
#   validate    - Validate current configuration
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
if [ -f "${SCRIPT_DIR}/dr-config.env" ]; then
  source "${SCRIPT_DIR}/dr-config.env"
else
  echo "ERROR: dr-config.env not found. Copy dr-config.env.example and configure."
  exit 1
fi

# Create log directory
LOG_DIR="${LOG_DIR:-/var/log/ccaas-dr}"
mkdir -p "${LOG_DIR}" 2>/dev/null || LOG_DIR="/tmp/ccaas-dr"
mkdir -p "${LOG_DIR}"

# =============================================================================
# Utility Functions
# =============================================================================

log() {
  local LEVEL="${2:-INFO}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${LEVEL}] $1" | tee -a "${LOG_DIR}/dr-$(date +%Y%m%d).log"
}

usage() {
  cat << EOF
Government CCaaS DR Controller

Usage: $0 <command> [options]

Commands:
  status          Check DR readiness status
  sync            Sync Connect configuration to DR region
  failover        Execute full DR failover
  failback        Return to primary region
  test            Test DR procedures (dry run)
  validate        Validate DR configuration

Options:
  --force         Skip confirmation prompts
  --help          Show this help message

Examples:
  $0 status                 # Check current DR status
  $0 sync                   # Sync config to DR
  $0 failover               # Execute failover with prompts
  $0 failover --force       # Execute failover without prompts
  $0 test                   # Dry run validation
  $0 failback               # Return to primary

Environment:
  PRIMARY_REGION: ${PRIMARY_REGION:-not set}
  DR_REGION:      ${DR_REGION:-not set}

EOF
}

check_prerequisites() {
  log "Checking prerequisites..."
  
  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    log "ERROR: AWS CLI not found" "ERROR"
    exit 1
  fi
  
  # Check AWS credentials
  if ! aws sts get-caller-identity &> /dev/null; then
    log "ERROR: AWS credentials not configured" "ERROR"
    exit 1
  fi
  
  # Check jq
  if ! command -v jq &> /dev/null; then
    log "WARNING: jq not found - some features limited" "WARN"
  fi
  
  log "Prerequisites OK"
}

# =============================================================================
# Status Command
# =============================================================================

cmd_status() {
  log "=== DR Status Check ===" "INFO"
  
  echo ""
  echo "┌────────────────────────────────────────────────────────────────┐"
  echo "│                    DR STATUS REPORT                            │"
  echo "├────────────────────────────────────────────────────────────────┤"
  echo ""
  
  # Account Info
  echo "AWS Account: $(aws sts get-caller-identity --query 'Account' --output text)"
  echo "Timestamp:   $(date)"
  echo ""
  
  # Primary Region
  echo "─── PRIMARY REGION (${PRIMARY_REGION}) ───"
  PRIMARY_STATUS=$(aws connect describe-instance \
    --instance-id "${PRIMARY_INSTANCE_ID}" \
    --region "${PRIMARY_REGION}" \
    --query 'Instance.InstanceStatus' \
    --output text 2>/dev/null || echo "UNREACHABLE")
  
  if [ "$PRIMARY_STATUS" == "ACTIVE" ]; then
    echo "  Connect Instance: ✅ ${PRIMARY_STATUS}"
  else
    echo "  Connect Instance: ❌ ${PRIMARY_STATUS}"
  fi
  
  # DR Region
  echo ""
  echo "─── DR REGION (${DR_REGION}) ───"
  DR_STATUS=$(aws connect describe-instance \
    --instance-id "${DR_INSTANCE_ID}" \
    --region "${DR_REGION}" \
    --query 'Instance.InstanceStatus' \
    --output text 2>/dev/null || echo "UNREACHABLE")
  
  if [ "$DR_STATUS" == "ACTIVE" ]; then
    echo "  Connect Instance: ✅ ${DR_STATUS}"
  else
    echo "  Connect Instance: ❌ ${DR_STATUS}"
  fi
  
  # DynamoDB Global Tables
  echo ""
  echo "─── DATA REPLICATION ───"
  REPLICAS=$(aws dynamodb describe-table \
    --table-name "${DYNAMODB_TABLE}" \
    --region "${PRIMARY_REGION}" \
    --query 'Table.Replicas[*].{Region:RegionName,Status:ReplicaStatus}' \
    --output text 2>/dev/null || echo "ERROR")
  
  if [ "$REPLICAS" != "ERROR" ]; then
    echo "  DynamoDB Global Table:"
    aws dynamodb describe-table \
      --table-name "${DYNAMODB_TABLE}" \
      --region "${PRIMARY_REGION}" \
      --query 'Table.Replicas[*].{Region:RegionName,Status:ReplicaStatus}' \
      --output table 2>/dev/null | tail -n +3
  else
    echo "  DynamoDB Global Table: ❌ Check failed"
  fi
  
  # S3 Replication
  echo ""
  REPL_STATUS=$(aws s3api get-bucket-replication \
    --bucket "${RECORDINGS_BUCKET}" \
    --query 'ReplicationConfiguration.Rules[0].Status' \
    --output text 2>/dev/null || echo "NOT_CONFIGURED")
  
  if [ "$REPL_STATUS" == "Enabled" ]; then
    echo "  S3 Replication:   ✅ ${REPL_STATUS}"
  else
    echo "  S3 Replication:   ⚠️  ${REPL_STATUS}"
  fi
  
  # Last Config Sync
  echo ""
  echo "─── CONFIGURATION SYNC ───"
  LAST_SYNC=$(aws s3 cp "s3://${CONFIG_BUCKET}/connect-config/LATEST" - 2>/dev/null || echo "NEVER")
  echo "  Last Sync: ${LAST_SYNC}"
  
  # Active Region
  echo ""
  echo "─── ACTIVE REGION ───"
  ACTIVE=$(aws ssm get-parameter \
    --name "/ccaas/active-region" \
    --region "${PRIMARY_REGION}" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "${PRIMARY_REGION}")
  echo "  Currently Active: ${ACTIVE}"
  
  echo ""
  echo "└────────────────────────────────────────────────────────────────┘"
  
  log "Status check complete"
}

# =============================================================================
# Sync Command
# =============================================================================

cmd_sync() {
  log "Starting configuration sync to DR region..."
  
  if [ -x "${SCRIPT_DIR}/sync-connect-config.sh" ]; then
    "${SCRIPT_DIR}/sync-connect-config.sh"
  else
    log "ERROR: sync-connect-config.sh not found or not executable" "ERROR"
    exit 1
  fi
  
  log "Configuration sync complete"
}

# =============================================================================
# Failover Command
# =============================================================================

cmd_failover() {
  local FORCE=$1
  
  log "!!! DISASTER RECOVERY FAILOVER INITIATED !!!" "CRITICAL"
  
  if [ "$FORCE" != "true" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  WARNING ⚠️                               ║"
    echo "║                                                                ║"
    echo "║   You are about to execute a DISASTER RECOVERY FAILOVER.      ║"
    echo "║                                                                ║"
    echo "║   This will:                                                   ║"
    echo "║   • Route all chat traffic to ${DR_REGION}                 ║"
    echo "║   • Activate DR Connect instance                              ║"
    echo "║   • Notify all agents to log into DR CCP                      ║"
    echo "║   • Update DNS records                                        ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    read -p "Type 'FAILOVER' to confirm: " CONFIRM
    if [ "$CONFIRM" != "FAILOVER" ]; then
      log "Failover aborted by user" "WARN"
      exit 1
    fi
  fi
  
  # Record failover start
  FAILOVER_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  log "Failover started at ${FAILOVER_START}"
  
  # Step 1: Infrastructure
  log "=== Phase 1: Infrastructure Failover ===" "INFO"
  if [ -x "${SCRIPT_DIR}/failover-1-infrastructure.sh" ]; then
    "${SCRIPT_DIR}/failover-1-infrastructure.sh"
  else
    log "ERROR: failover-1-infrastructure.sh not found" "ERROR"
    exit 1
  fi
  
  # Step 2: Connect
  log "=== Phase 2: Connect Failover ===" "INFO"
  if [ -x "${SCRIPT_DIR}/failover-2-connect.sh" ]; then
    "${SCRIPT_DIR}/failover-2-connect.sh"
  else
    log "ERROR: failover-2-connect.sh not found" "ERROR"
    exit 1
  fi
  
  # Step 3: Agents
  log "=== Phase 3: Agent Failover ===" "INFO"
  if [ -x "${SCRIPT_DIR}/failover-3-agents.sh" ]; then
    "${SCRIPT_DIR}/failover-3-agents.sh"
  else
    log "ERROR: failover-3-agents.sh not found" "ERROR"
    exit 1
  fi
  
  # Step 4: Validation
  log "=== Phase 4: Post-Failover Validation ===" "INFO"
  if [ -x "${SCRIPT_DIR}/validate-failover.sh" ]; then
    "${SCRIPT_DIR}/validate-failover.sh"
  else
    log "WARNING: validate-failover.sh not found - skipping validation" "WARN"
  fi
  
  FAILOVER_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  log "!!! FAILOVER COMPLETE at ${FAILOVER_END} !!!" "CRITICAL"
  
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                    ✅ FAILOVER COMPLETE                        ║"
  echo "╠════════════════════════════════════════════════════════════════╣"
  echo "║                                                                ║"
  echo "║   DR Region:     ${DR_REGION}                                ║"
  echo "║   DR CCP URL:    https://${DR_INSTANCE_ALIAS}.my.connect.aws/ccp-v2"
  echo "║                                                                ║"
  echo "║   MANUAL ACTIONS REQUIRED:                                     ║"
  echo "║   • Update customer-facing phone number communications        ║"
  echo "║   • Verify agents can log into DR CCP                         ║"
  echo "║   • Monitor call quality for 1 hour                           ║"
  echo "║                                                                ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
}

# =============================================================================
# Test Command
# =============================================================================

cmd_test() {
  log "=== DR TEST MODE (Dry Run) ===" "INFO"
  echo ""
  echo "Testing DR readiness without activating failover..."
  echo ""
  
  PASS=0
  FAIL=0
  
  test_check() {
    local NAME=$1
    local CMD=$2
    
    echo -n "  ${NAME}... "
    if eval "${CMD}" > /dev/null 2>&1; then
      echo "✅ PASS"
      ((PASS++))
    else
      echo "❌ FAIL"
      ((FAIL++))
    fi
  }
  
  echo "─── DR Instance Accessibility ───"
  test_check "DR Connect Instance" \
    "aws connect describe-instance --instance-id ${DR_INSTANCE_ID} --region ${DR_REGION}"
  
  test_check "DR Lambda Function" \
    "aws lambda get-function --function-name ${DR_LAMBDA_FUNCTION:-census-handler} --region ${DR_REGION}"
  
  test_check "DR DynamoDB Access" \
    "aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${DR_REGION}"
  
  if [ -n "${DR_LEX_BOT_ID}" ]; then
    test_check "DR Lex Bot" \
      "aws lexv2-models describe-bot --bot-id ${DR_LEX_BOT_ID} --region ${DR_REGION}"
  fi
  
  echo ""
  echo "─── Service Integration Tests ───"
  
  if [ -n "${DR_LEX_BOT_ID}" ] && [ -n "${DR_LEX_ALIAS_ID}" ]; then
    test_check "Lex Speech Recognition" \
      "aws lexv2-runtime recognize-text --bot-id ${DR_LEX_BOT_ID} --bot-alias-id ${DR_LEX_ALIAS_ID} --locale-id en_US --session-id test-$$ --text hello --region ${DR_REGION}"
  fi
  
  test_check "DynamoDB Read" \
    "aws dynamodb scan --table-name ${DYNAMODB_TABLE} --limit 1 --region ${DR_REGION}"
  
  echo ""
  echo "─── Cross-Region Replication ───"
  test_check "DynamoDB Global Tables" \
    "aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${PRIMARY_REGION} --query 'Table.Replicas'"
  
  test_check "S3 Bucket in DR" \
    "aws s3api head-bucket --bucket ${DR_RECORDINGS_BUCKET} --region ${DR_REGION}"
  
  echo ""
  echo "════════════════════════════════════════"
  echo "  TEST SUMMARY"
  echo "════════════════════════════════════════"
  echo "  Passed: ${PASS}"
  echo "  Failed: ${FAIL}"
  echo ""
  
  if [ ${FAIL} -gt 0 ]; then
    log "DR test completed with ${FAIL} failures" "WARN"
    exit 1
  else
    log "DR test completed - all checks passed" "INFO"
    exit 0
  fi
}

# =============================================================================
# Validate Command
# =============================================================================

cmd_validate() {
  log "Validating DR configuration..."
  
  if [ -x "${SCRIPT_DIR}/validate-failover.sh" ]; then
    "${SCRIPT_DIR}/validate-failover.sh"
  else
    log "ERROR: validate-failover.sh not found" "ERROR"
    exit 1
  fi
}

# =============================================================================
# Failback Command
# =============================================================================

cmd_failback() {
  log "Starting failback to primary region..."
  
  if [ -x "${SCRIPT_DIR}/failback.sh" ]; then
    "${SCRIPT_DIR}/failback.sh"
  else
    log "ERROR: failback.sh not found" "ERROR"
    exit 1
  fi
}

# =============================================================================
# Main
# =============================================================================

main() {
  local COMMAND=$1
  shift || true
  
  local FORCE="false"
  
  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force)
        FORCE="true"
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        shift
        ;;
    esac
  done
  
  case "$COMMAND" in
    status)
      check_prerequisites
      cmd_status
      ;;
    sync)
      check_prerequisites
      cmd_sync
      ;;
    failover)
      check_prerequisites
      cmd_failover "$FORCE"
      ;;
    failback)
      check_prerequisites
      cmd_failback
      ;;
    test)
      check_prerequisites
      cmd_test
      ;;
    validate)
      check_prerequisites
      cmd_validate
      ;;
    --help|-h|help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
