# Census Enumerator AI Agent - Terraform Deployment

> **WHAT THIS DOES:** Deploys ALL AWS infrastructure for the Census Enumerator AI Agent in ~5-10 minutes.
> 
> **WHY TERRAFORM:** Infrastructure as Code means reproducible deployments, version control, and easy teardown.

## Prerequisites

| Requirement | Why |
|-------------|-----|
| AWS CLI configured | Authentication for deployments |
| Terraform >= 1.5.0 | IaC tool |
| Node.js >= 18 | Lambda runtime |
| Amazon Bedrock access | AI model access must be enabled in your AWS account |
| Amazon Connect instance | Must exist before running Terraform |

## Quick Start (5 minutes)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # Create config file
# EDIT terraform.tfvars with your values
terraform init                                  # Download providers
terraform plan                                  # Preview what will be created
terraform apply                                 # Deploy everything
```

## What Gets Created

| Resource | Purpose |
|----------|---------|
| **DynamoDB Tables** (2) | Store survey responses and address lookups |
| **Lambda Functions** (2) | Backend logic + Lex fulfillment |
| **IAM Roles** (3) | Permissions for Lambda, Lex, Connect |
| **Lex Bot** (1) | Natural language understanding |
| **Bedrock Guardrails** (1) | Content/PII filtering |
| **CloudWatch Dashboard** (1) | Monitoring |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Amazon Connect                          │
│  ┌─────────────┐    ┌───────────────┐    ┌─────────────────┐   │
│  │ Phone/Chat  │───▶│ Contact Flow  │───▶│  Lex Bot/Agent  │   │
│  └─────────────┘    └───────────────┘    └────────┬────────┘   │
└──────────────────────────────────────────────────┼─────────────┘
                                                   │
                      ┌────────────────────────────┼────────────┐
                      │                            ▼            │
                      │  ┌──────────────────────────────────┐   │
                      │  │         Amazon Lex V2            │   │
                      │  │   ┌──────────┐  ┌──────────┐     │   │
                      │  │   │ Intents  │  │  Slots   │     │   │
                      │  │   └──────────┘  └──────────┘     │   │
                      │  │        │                         │   │
                      │  │        ▼                         │   │
                      │  │   ┌──────────────────────────┐   │   │
                      │  │   │  Bedrock (Generative AI) │   │   │
                      │  │   │  Ruth Voice (Generative) │   │   │
                      │  │   └──────────────────────────┘   │   │
                      │  └─────────────┬────────────────────┘   │
                      │                │                        │
                      │                ▼                        │
                      │  ┌──────────────────────────────────┐   │
                      │  │        Lambda Functions          │   │
                      │  │  ┌─────────────┐  ┌───────────┐  │   │
                      │  │  │ Fulfillment │  │  Backend  │  │   │
                      │  │  └─────────────┘  └───────────┘  │   │
                      │  └─────────────┬────────────────────┘   │
                      │                │                        │
                      │                ▼                        │
                      │  ┌──────────────────────────────────┐   │
                      │  │          DynamoDB Tables         │   │
                      │  │  ┌───────────┐  ┌───────────┐    │   │
                      │  │  │ Responses │  │ Addresses │    │   │
                      │  │  └───────────┘  └───────────┘    │   │
                      │  └──────────────────────────────────┘   │
                      │                                         │
                      │  ┌──────────────────────────────────┐   │
                      │  │       Bedrock Guardrails         │   │
                      │  │  (Content/PII/Topic Filtering)   │   │
                      │  └──────────────────────────────────┘   │
                      │                                         │
                      └─────────────────────────────────────────┘
```

## Module Structure

```
terraform/
├── main.tf                    # Orchestrates all modules
├── variables.tf               # Input variables (customize here)
├── outputs.tf                 # Resource IDs/ARNs after deploy
├── terraform.tfvars.example   # Sample configuration
└── modules/
    ├── dynamodb/              # Survey data storage
    ├── iam/                   # Service permissions
    ├── lambda/                # Backend functions
    ├── lex/                   # NLU bot
    ├── bedrock/               # AI guardrails
    └── monitoring/            # CloudWatch dashboards
```
    │   └── outputs.tf
    ├── lex/                   # Lex bot configuration
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── bedrock/               # Bedrock guardrails
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── monitoring/            # CloudWatch dashboards & alarms
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Resources Created

| Resource | Description |
|----------|-------------|
| **DynamoDB Tables** | CensusResponses, CensusAddresses, CensusCallbacks |
| **Lambda Functions** | Fulfillment handler, Backend processor |
| **Lex Bot** | Census Enumerator bot with en_US locale |
| **Lex Slot Types** | YesNo, Relationship, Sex, Race, HousingTenure |
| **Lex Intents** | Welcome, HouseholdCount, CollectPersonInfo, etc. |
| **Bedrock Guardrail** | Content filtering, PII blocking, topic denial |
| **IAM Roles** | Lambda execution, Lex service, Connect service |
| **CloudWatch** | Dashboard, alarms, metric filters |

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `environment` | Environment name | `dev` |
| `bedrock_model_id` | Bedrock model for AI | `anthropic.claude-3-sonnet` |
| `lex_voice_id` | Amazon Polly voice | `Ruth` |

### Security Options

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_kms_encryption` | Enable KMS for encryption | `true` |
| `dynamodb_enable_encryption` | Encrypt DynamoDB at rest | `true` |
| `dynamodb_enable_point_in_time_recovery` | Enable PITR | `true` |

## Outputs

After deployment, Terraform will output:

```hcl
lex_bot_id              = "BOT_ID"
lex_bot_alias_arn       = "arn:aws:lex:region:account:bot-alias/..."
lambda_fulfillment_arn  = "arn:aws:lambda:region:account:function:..."
dynamodb_census_responses_table = "census-enumerator-dev-census-responses"
cloudwatch_dashboard_url = "https://console.aws.amazon.com/..."
```

## Integrating with Amazon Connect

After deployment:

1. **Associate Lex Bot**:
   ```bash
   aws connect associate-lex-bot \
     --instance-id YOUR_CONNECT_INSTANCE_ID \
     --lex-bot Name=census-enumerator-dev-bot,LexRegion=us-east-1
   ```

2. **Import Contact Flow**:
   - Use the `contact-flow.json` from the project root
   - Update ARNs with Terraform outputs

3. **Claim Phone Number**:
   - Associate with the Census contact flow

4. **Configure Chat Widget**:
   - Use the instance ID and contact flow ID

## Destroying Resources

```bash
# Remove all created resources
terraform destroy
```

⚠️ **Warning**: This will delete all data in DynamoDB tables!

## Remote State (Optional)

For team collaboration, configure remote state in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "census-enumerator/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## Cost Estimation

| Service | Estimated Monthly Cost |
|---------|----------------------|
| DynamoDB (on-demand) | ~$1-10 (based on usage) |
| Lambda | ~$0.20 per million invocations |
| Lex | $0.004/text, $0.0065/speech |
| Bedrock | ~$0.003/1K input, $0.015/1K output |
| CloudWatch | ~$3-10 |

## Troubleshooting

### Common Issues

1. **Bedrock Access Denied**
   - Ensure model access is enabled in Bedrock console
   - Check IAM permissions

2. **Lex Build Failures**
   - Verify all slot types are created before intents
   - Check for naming conflicts

3. **Lambda Timeouts**
   - Increase `lambda_timeout` variable
   - Check DynamoDB throughput

### Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/census-enumerator-dev-fulfillment --follow

# View Lex conversation logs (if enabled)
aws logs tail /aws/lex/census-enumerator-dev-bot --follow
```

## Support

For issues with this Terraform configuration:
1. Check CloudWatch logs
2. Review Terraform state
3. Verify IAM permissions
4. Contact AWS Support for service-specific issues
