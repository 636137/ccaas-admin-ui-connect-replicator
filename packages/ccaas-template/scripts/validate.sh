#!/bin/bash
# =============================================================================
# GOVERNMENT CCAAS VALIDATION CLI
# 
# WHAT: Command-line interface for running validation tests manually.
# 
# WHY: Enables operators to run validation tests on-demand, integrate with
#      CI/CD pipelines, and troubleshoot deployment issues.
# 
# USAGE:
#   ./validate.sh [command] [options]
#
# COMMANDS:
#   all          Run all validation tests
#   functional   Run functional tests only
#   ai           Run AI validation tests only
#   security     Run security validation only
#   status       Check status of recent validation runs
#   report       Generate and download latest report
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load Terraform outputs
load_config() {
    echo -e "${BLUE}Loading configuration from Terraform outputs...${NC}"
    cd "$PROJECT_ROOT/terraform"
    
    STATE_MACHINE_ARN=$(terraform output -raw validation_state_machine_arn 2>/dev/null || echo "")
    REPORT_BUCKET=$(terraform output -raw validation_report_bucket 2>/dev/null || echo "")
    ORCHESTRATOR_FUNCTION=$(terraform output -raw validation_orchestrator_function_name 2>/dev/null || echo "")
    AI_VALIDATOR_FUNCTION=$(terraform output -raw validation_ai_validator_function_name 2>/dev/null || echo "")
    
    if [ -z "$STATE_MACHINE_ARN" ]; then
        echo -e "${RED}Error: Could not load validation configuration. Is the validation module deployed?${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Configuration loaded successfully${NC}"
}

# Print banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🏛️  Government CCaaS Validation Suite            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Run full validation via Step Functions
run_all_validation() {
    echo -e "${YELLOW}Starting full validation suite...${NC}"
    
    EXECUTION_ARN=$(aws stepfunctions start-execution \
        --state-machine-arn "$STATE_MACHINE_ARN" \
        --name "manual-$(date +%Y%m%d-%H%M%S)" \
        --query 'executionArn' \
        --output text)
    
    echo -e "${BLUE}Execution started: ${EXECUTION_ARN}${NC}"
    echo ""
    
    # Wait for completion
    wait_for_execution "$EXECUTION_ARN"
}

# Run functional tests only
run_functional() {
    echo -e "${YELLOW}Running functional tests...${NC}"
    
    RESULT=$(aws lambda invoke \
        --function-name "$ORCHESTRATOR_FUNCTION" \
        --payload '{"testType": "functional"}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/functional-result.json 2>&1)
    
    display_lambda_result "/tmp/functional-result.json"
}

# Run AI validation tests
run_ai_validation() {
    echo -e "${YELLOW}Running AI validation tests...${NC}"
    
    RESULT=$(aws lambda invoke \
        --function-name "$AI_VALIDATOR_FUNCTION" \
        --payload '{}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/ai-result.json 2>&1)
    
    display_lambda_result "/tmp/ai-result.json"
}

# Run security validation
run_security_validation() {
    echo -e "${YELLOW}Running security validation...${NC}"
    
    RESULT=$(aws lambda invoke \
        --function-name "$ORCHESTRATOR_FUNCTION" \
        --payload '{"testType": "security"}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/security-result.json 2>&1)
    
    display_lambda_result "/tmp/security-result.json"
}

# Wait for Step Functions execution to complete
wait_for_execution() {
    local execution_arn=$1
    local status="RUNNING"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    
    echo -e "${BLUE}Waiting for execution to complete...${NC}"
    
    while [ "$status" == "RUNNING" ]; do
        printf "\r${spinner[$i]} Status: $status"
        i=$(( (i + 1) % ${#spinner[@]} ))
        
        status=$(aws stepfunctions describe-execution \
            --execution-arn "$execution_arn" \
            --query 'status' \
            --output text)
        
        sleep 2
    done
    
    printf "\r"
    
    if [ "$status" == "SUCCEEDED" ]; then
        echo -e "${GREEN}✓ Validation completed successfully!${NC}"
        
        # Get output
        OUTPUT=$(aws stepfunctions describe-execution \
            --execution-arn "$execution_arn" \
            --query 'output' \
            --output text)
        
        echo ""
        echo "Results Summary:"
        echo "$OUTPUT" | jq -r '.reportResults // empty' 2>/dev/null || echo "$OUTPUT" | head -20
    else
        echo -e "${RED}✗ Validation failed with status: $status${NC}"
        
        # Get error details
        aws stepfunctions describe-execution \
            --execution-arn "$execution_arn" \
            --query 'error' \
            --output text
    fi
}

# Display Lambda result
display_lambda_result() {
    local result_file=$1
    
    if [ -f "$result_file" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        
        local status=$(jq -r '.summary.overallStatus // "UNKNOWN"' "$result_file")
        local passed=$(jq -r '.summary.passed // 0' "$result_file")
        local failed=$(jq -r '.summary.failed // 0' "$result_file")
        local total=$(jq -r '.summary.total // 0' "$result_file")
        
        if [ "$status" == "PASSED" ]; then
            echo -e "${GREEN}✓ Status: $status${NC}"
        else
            echo -e "${RED}✗ Status: $status${NC}"
        fi
        
        echo "Tests: $passed passed, $failed failed, $total total"
        echo ""
        
        # Show failed tests
        if [ "$failed" -gt 0 ]; then
            echo -e "${RED}Failed Tests:${NC}"
            jq -r '.tests[] | select(.status == "FAILED") | "  - \(.testName): \(.error // .message // "Unknown error")"' "$result_file"
            echo ""
        fi
        
        echo "═══════════════════════════════════════════════════════════"
    else
        echo -e "${RED}Error: Could not read result file${NC}"
    fi
}

# Check recent validation status
check_status() {
    echo -e "${YELLOW}Recent validation executions:${NC}"
    echo ""
    
    aws stepfunctions list-executions \
        --state-machine-arn "$STATE_MACHINE_ARN" \
        --max-items 10 \
        --query 'executions[*].{Name:name,Status:status,Start:startDate,Stop:stopDate}' \
        --output table
}

# Download latest report
download_report() {
    echo -e "${YELLOW}Downloading latest validation report...${NC}"
    
    # Get latest report info
    LATEST=$(aws s3 cp "s3://$REPORT_BUCKET/latest/report.json" - 2>/dev/null || echo "")
    
    if [ -z "$LATEST" ]; then
        echo -e "${RED}No validation reports found. Run validation first.${NC}"
        exit 1
    fi
    
    RUN_ID=$(echo "$LATEST" | jq -r '.runId')
    HTML_KEY="results/$RUN_ID/validation-report.html"
    
    # Download HTML report
    LOCAL_FILE="./validation-report-$RUN_ID.html"
    aws s3 cp "s3://$REPORT_BUCKET/$HTML_KEY" "$LOCAL_FILE"
    
    echo -e "${GREEN}Report downloaded: $LOCAL_FILE${NC}"
    
    # Try to open in browser
    if command -v open &> /dev/null; then
        open "$LOCAL_FILE"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$LOCAL_FILE"
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  all          Run all validation tests (default)"
    echo "  functional   Run functional tests only"
    echo "  ai           Run AI validation tests only"
    echo "  security     Run security validation only"
    echo "  status       Check status of recent validation runs"
    echo "  report       Download latest validation report"
    echo "  help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all                Run complete validation suite"
    echo "  $0 ai                 Run AI quality tests"
    echo "  $0 status             Check recent run status"
    echo "  $0 report             Download and open latest report"
    echo ""
}

# Main
main() {
    print_banner
    
    COMMAND=${1:-all}
    
    case "$COMMAND" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            load_config
            ;;
    esac
    
    case "$COMMAND" in
        all)
            run_all_validation
            ;;
        functional)
            run_functional
            ;;
        ai)
            run_ai_validation
            ;;
        security)
            run_security_validation
            ;;
        status)
            check_status
            ;;
        report)
            download_report
            ;;
        *)
            echo -e "${RED}Unknown command: $COMMAND${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
