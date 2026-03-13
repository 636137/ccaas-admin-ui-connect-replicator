# Validation Module for Government CCaaS in a Box

## Overview

The Validation Module provides automated testing and quality assurance for Government CCaaS deployments. It validates:

- **Functional Tests**: Amazon Connect, Lex, Lambda, and DynamoDB components
- **AI Quality**: Intent recognition accuracy, response latency, guardrail effectiveness
- **Security Compliance**: AWS Config conformance pack validation for FedRAMP

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Validation Module                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌─────────────────────────────────────┐   │
│  │  EventBridge │───▶│         Step Functions              │   │
│  │  Scheduler   │    │     (Validation Workflow)           │   │
│  └──────────────┘    └─────────────────────────────────────┘   │
│                                    │                            │
│                      ┌─────────────┼─────────────┐             │
│                      ▼             ▼             ▼             │
│              ┌───────────┐ ┌───────────┐ ┌───────────┐        │
│              │Orchestrator│ │AI Validator│ │ Report    │        │
│              │  Lambda   │ │  Lambda   │ │ Generator │        │
│              └───────────┘ └───────────┘ └───────────┘        │
│                      │             │             │             │
│                      ▼             ▼             ▼             │
│              ┌─────────────────────────────────────────┐       │
│              │            S3 Report Bucket             │       │
│              │  (JSON Results + HTML Reports)          │       │
│              └─────────────────────────────────────────┘       │
│                                    │                            │
│                                    ▼                            │
│              ┌─────────────────────────────────────────┐       │
│              │         CloudWatch Dashboard            │       │
│              │    + Alarms → SNS Notifications         │       │
│              └─────────────────────────────────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Cost Estimate

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| Step Functions | ~$5 | State transitions for daily runs |
| Lambda | ~$10 | 3 functions, ~100 invocations/month |
| S3 | ~$3 | Reports with 30-day retention |
| CloudWatch | ~$5 | Dashboard, metrics, logs |
| SNS | <$1 | Alert notifications |
| **Total** | **~$24/month** | Excludes AWS Config costs |

**Key Cost Savings:**
- Amazon Connect Native Testing is **FREE** (included with Connect)
- AWS Distributed Load Testing runs on-demand only (~$0.03/test)
- S3 lifecycle policies auto-delete old reports

## Quick Start

### 1. Enable the Module

Add to your `terraform/main.tf`:

```hcl
module "validation" {
  source = "./modules/validation"
  
  # Required
  project_name = var.project_name
  environment  = var.environment
  
  # Connect configuration
  connect_instance_id  = module.connect.instance_id
  connect_instance_arn = module.connect.instance_arn
  
  # Lex configuration
  lex_bot_id       = module.lex.bot_id
  lex_bot_alias_id = module.lex.bot_alias_id
  lex_locale_id    = "en_US"
  
  # Bedrock configuration (optional)
  bedrock_agent_id       = module.bedrock.agent_id
  bedrock_agent_alias_id = module.bedrock.agent_alias_id
  bedrock_guardrail_id   = module.bedrock.guardrail_id
  
  # Lambda functions to test
  lambda_arns = [
    module.lambda.census_handler_arn,
    module.lambda.webhook_handler_arn
  ]
  
  # DynamoDB tables to test
  dynamodb_table_names = [
    module.dynamodb.survey_responses_table_name,
    module.dynamodb.session_state_table_name
  ]
  
  # Optional: Notification settings
  notification_email = "alerts@agency.gov"
  
  # Optional: AI thresholds
  ai_accuracy_threshold = 0.85  # 85% intent accuracy
  ai_latency_threshold  = 3000  # 3 second max response time
  
  tags = var.tags
}
```

### 2. Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Run Validation

```bash
# Full validation suite
./scripts/validate.sh all

# Functional tests only
./scripts/validate.sh functional

# AI quality tests only
./scripts/validate.sh ai

# Security validation only
./scripts/validate.sh security

# Check recent status
./scripts/validate.sh status

# Download report
./scripts/validate.sh report
```

## Test Types

### Functional Tests (`orchestrator`)

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| `connect-instance-active` | Verify Connect instance is ACTIVE | Status = ACTIVE |
| `connect-contact-flows` | Check contact flows are published | At least 1 flow exists |
| `connect-queues` | Verify queues are configured | At least 1 queue exists |
| `connect-metrics-access` | Test real-time metrics API | API accessible |
| `lex-bot-available` | Check Lex bot status | Status = Available |
| `lex-bot-alias-available` | Check bot alias deployment | Status = Available |
| `lex-intents-configured` | Verify intents exist | At least 1 intent |
| `lambda-*-active` | Check Lambda function status | State = Active |
| `dynamodb-*-active` | Check DynamoDB table status | Status = ACTIVE |

### AI Validation Tests (`ai-validator`)

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| `lex-nlu-*` | Intent recognition for test utterances | Correct intent matched |
| `lex-nlu-overall-accuracy` | Overall NLU accuracy | ≥ 85% (configurable) |
| `bedrock-agent-*` | Agent response quality | Response contains expected keywords |
| `guardrail-*` | Content filtering tests | PII blocked, safe content passes |
| `guardrail-overall-effectiveness` | Overall guardrail performance | ≥ 90% effective |

### Security Validation (`orchestrator` with `testType: security`)

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| `fedramp-conformance-pack` | AWS Config FedRAMP compliance | No non-compliant resources |

## Scheduled Runs

The module configures three schedules by default:

| Schedule | Cron | Tests |
|----------|------|-------|
| Daily Functional | `0 6 * * ? *` | Connect, Lex, Lambda, DynamoDB |
| Weekly Load | `0 2 ? * SUN *` | Load testing (AWS Distributed Load Testing) |
| Daily Security | `0 5 * * ? *` | AWS Config compliance |

Customize schedules:

```hcl
module "validation" {
  # ...
  
  functional_test_schedule = "rate(12 hours)"  # Run every 12 hours
  load_test_schedule       = "cron(0 2 1 * ? *)"  # Monthly on 1st
  security_test_schedule   = "rate(6 hours)"  # Run every 6 hours
}
```

## Reports

### JSON Report Structure

```json
{
  "metadata": {
    "runId": "run-2024-01-15T06-00-00-abc123",
    "generatedAt": "2024-01-15T06:05:30.000Z",
    "environment": "production"
  },
  "summary": {
    "total": 25,
    "passed": 23,
    "failed": 1,
    "skipped": 1,
    "passRate": "92.00",
    "overallStatus": "FAILED"
  },
  "sections": {
    "functional": { ... },
    "ai": { 
      "metrics": {
        "intentAccuracy": "88.50",
        "averageLatency": 1250,
        "p95Latency": 2100,
        "guardrailEffectiveness": "100.00"
      }
    },
    "security": { ... }
  },
  "recommendations": [
    {
      "category": "AI Quality",
      "severity": "MEDIUM",
      "title": "AI Accuracy Below Threshold",
      "action": "Review Lex bot training data..."
    }
  ]
}
```

### HTML Report

Beautiful HTML reports are generated with:
- Visual status dashboard
- Test result tables
- AI metrics gauges
- Actionable recommendations

Download via CLI:
```bash
./scripts/validate.sh report
```

Or via AWS CLI:
```bash
aws s3 cp s3://your-bucket/latest/report.json - | jq -r '.htmlReport'
```

## CloudWatch Dashboard

The module creates a dashboard named `{project}-{env}-validation-dashboard` with:

- **Execution Summary**: Tests run, pass rate, duration trends
- **AI Metrics**: Accuracy gauge, latency percentiles, guardrail blocks
- **Lambda Health**: Invocations, errors, duration
- **Test Results**: Bar charts by test type

## Alarms

| Alarm | Condition | Action |
|-------|-----------|--------|
| `validation_failed` | Any failed test | SNS notification |
| `ai_accuracy_low` | Accuracy < threshold | SNS notification |
| `ai_latency_high` | Avg latency > threshold | SNS notification |
| `security_test_failed` | Security test fails | SNS notification |

## CI/CD Integration

### GitHub Actions

```yaml
name: Validation

on:
  workflow_dispatch:
  schedule:
    - cron: '0 6 * * *'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Run validation
        run: ./scripts/validate.sh all
      
      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: validation-report
          path: validation-report-*.html
```

### AWS CodePipeline

Add a validation stage after deployment:

```hcl
stage {
  name = "Validate"
  
  action {
    name            = "RunValidation"
    category        = "Invoke"
    owner           = "AWS"
    provider        = "StepFunctions"
    version         = "1"
    
    configuration = {
      StateMachineArn = module.validation.state_machine_arn
      Input          = "{\"source\": \"codepipeline\"}"
    }
  }
}
```

## Troubleshooting

### Common Issues

**"Could not load validation configuration"**
- Ensure validation module is deployed: `terraform output validation_state_machine_arn`
- Check AWS credentials are configured

**"Lex bot validation failed"**
- Verify bot is built and alias is deployed
- Check locale ID matches (default: en_US)

**"AI accuracy below threshold"**
- Review test utterances in `CENSUS_TEST_CASES`
- Add more training utterances to Lex bot
- Consider adjusting threshold for initial deployment

**"Guardrail tests failing"**
- Verify guardrail is deployed and not in DRAFT
- Check guardrail version matches configuration

### Debug Mode

Enable detailed logging:

```bash
export DEBUG=1
./scripts/validate.sh all
```

View Lambda logs:
```bash
aws logs tail /aws/lambda/ccaas-validation-orchestrator --follow
```

## Extending Tests

### Add Custom Test Cases

Edit `lambda/ai-validator/index.js`:

```javascript
const CENSUS_TEST_CASES = [
  // Add your test cases
  {
    id: 'custom-test',
    input: 'Your test utterance',
    expectedIntent: 'YourIntent',
    expectedKeywords: ['keyword1', 'keyword2'],
    category: 'custom'
  }
];
```

### Add New Test Types

1. Create new Lambda function in `lambda/` directory
2. Add function definition in `main.tf`
3. Add to Step Functions workflow
4. Update dashboard with new metrics

## Security Considerations

- **Encryption**: All S3 data encrypted with KMS
- **IAM**: Least-privilege roles for each Lambda
- **VPC**: Can be deployed in VPC for network isolation
- **Logging**: CloudTrail integration for audit trail
- **PII**: No sensitive data stored in test results

## Outputs

| Output | Description |
|--------|-------------|
| `state_machine_arn` | Step Functions state machine ARN |
| `orchestrator_function_name` | Orchestrator Lambda name |
| `ai_validator_function_name` | AI Validator Lambda name |
| `report_bucket_name` | S3 bucket for reports |
| `dashboard_url` | CloudWatch dashboard URL |
| `run_validation_command` | CLI command to run validation |

## Support

For issues or feature requests, open a GitHub issue at:
https://github.com/636137/MarcS-CensusDemo/issues
