/**
 * Template service for generating parameterized JSON configuration files
 */

interface TemplateInput {
  projectName: string
  environment: string
  awsRegion: string
  bedrockModelId: string
  lexVoiceId: string
  lambdaRuntime: string
}

/**
 * Generate Bedrock agent configuration JSON
 */
export function generateAgentConfigBedrock(input: TemplateInput): string {
  const config = {
    agentName: `${input.projectName}-census-agent`,
    foundationModel: input.bedrockModelId,
    instruction: `You are an AI census agent for the US Census Bureau. Your role is to collect census data 
from respondents in a friendly, professional manner. Follow the survey questions precisely and record 
accurate responses. Maintain confidentiality and explain data privacy protections when asked.`,
    description: `AI Census Agent for ${input.projectName} (${input.environment})`,
    idleSessionTTLInSeconds: 600,
    agentResourceRoleArn: `arn:aws:iam::ACCOUNT_ID:role/${input.projectName}-bedrock-agent-role`,
    actionGroups: [
      {
        actionGroupName: 'CensusDataCollection',
        description: 'Actions for collecting and validating census data',
        actionGroupExecutor: {
          lambda: `arn:aws:lambda:${input.awsRegion}:ACCOUNT_ID:function:${input.projectName}-census-handler`
        },
        apiSchema: {
          payload: JSON.stringify({
            openapi: '3.0.0',
            info: {
              title: 'Census Data Collection API',
              version: '1.0.0'
            },
            paths: {
              '/collect-response': {
                post: {
                  description: 'Collect and store a census response',
                  parameters: [],
                  requestBody: {
                    required: true,
                    content: {
                      'application/json': {
                        schema: {
                          type: 'object',
                          properties: {
                            questionId: { type: 'string' },
                            response: { type: 'string' },
                            sessionId: { type: 'string' }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          })
        }
      }
    ],
    tags: {
      Environment: input.environment,
      Project: input.projectName,
      ManagedBy: 'Terraform'
    }
  }

  return JSON.stringify(config, null, 2)
}

/**
 * Generate Connect agent configuration JSON
 */
export function generateAgentConfigConnect(input: TemplateInput): string {
  const config = {
    instanceId: 'CONNECT_INSTANCE_ID', // Replaced after Terraform apply
    name: `${input.projectName}-census-agent`,
    description: `AI Census Agent for Amazon Connect`,
    modelId: input.bedrockModelId,
    voiceId: input.lexVoiceId,
    configuration: {
      idleSessionTTLInSeconds: 600,
      enableLiveAgentHandoff: true,
      guardrails: {
        enablePIIRedaction: true,
        blockedPhrases: ['social security number', 'SSN', 'credit card'],
        contentFilters: {
          hate: 'HIGH',
          insults: 'MEDIUM',
          sexual: 'HIGH',
          violence: 'HIGH'
        }
      }
    },
    integrations: [
      {
        type: 'LAMBDA',
        lambdaFunctionArn: `arn:aws:lambda:${input.awsRegion}:ACCOUNT_ID:function:${input.projectName}-census-handler`,
        description: 'Census data collection handler'
      },
      {
        type: 'LEX',
        lexBotId: 'LEX_BOT_ID', // Replaced after Terraform apply
        lexBotAliasId: 'LEX_BOT_ALIAS_ID',
        description: 'Lex bot for natural language understanding'
      }
    ],
    tags: {
      Environment: input.environment,
      Project: input.projectName
    }
  }

  return JSON.stringify(config, null, 2)
}

/**
 * Generate Lex bot definition JSON
 */
export function generateLexBotDefinition(input: TemplateInput): string {
  const config = {
    name: `${input.projectName}-census-bot`,
    description: `Census data collection bot for ${input.projectName}`,
    roleArn: `arn:aws:iam::ACCOUNT_ID:role/${input.projectName}-lex-bot-role`,
    dataPrivacy: {
      childDirected: false
    },
    idleSessionTTLInSeconds: 600,
    botTags: {
      Environment: input.environment,
      Project: input.projectName,
      ManagedBy: 'Terraform'
    },
    voiceSettings: {
      voiceId: input.lexVoiceId
    },
    botLocales: [
      {
        localeId: 'en_US',
        description: 'English (US) locale for census bot',
        nluIntentConfidenceThreshold: 0.40,
        voiceSettings: {
          voiceId: input.lexVoiceId
        }
      }
    ]
  }

  return JSON.stringify(config, null, 2)
}

/**
 * Generate README with deployment instructions
 */
export function generateReadme(input: TemplateInput): string {
  return `# ${input.projectName} - CCaaS Deployment Package

**Generated:** ${new Date().toISOString()}  
**Environment:** ${input.environment}  
**Region:** ${input.awsRegion}  
**Model:** ${input.bedrockModelId}  

## Overview

This package contains all configuration files needed to deploy a Government Contact Center as a Service (CCaaS) 
using Amazon Connect, Bedrock, and Lex.

## Package Contents

\`\`\`
terraform.tfvars                    - Terraform variable values
agent-configuration-bedrock.json   - Bedrock agent configuration
agent-configuration-connect.json   - Connect agent configuration  
lex-bot-definition.json            - Lex bot definition
README.md                          - This file
\`\`\`

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI** installed and configured
   \`\`\`bash
   aws --version
   aws configure
   \`\`\`

2. **Terraform** installed (v1.0+)
   \`\`\`bash
   terraform --version
   \`\`\`

3. **Bedrock Model Access** enabled in your AWS account
   - Navigate to AWS Bedrock console
   - Request access to: ${input.bedrockModelId}
   - Wait for approval (typically instant for public models)

4. **Sufficient AWS Quotas**
   - Amazon Connect instances: Default 2 per account
   - Lambda concurrent executions: Default 1000
   - VPC limit: Default 5 per region

## Deployment Steps

### Step 1: Prepare Terraform Template

1. Clone the CCaaS template repository:
   \`\`\`bash
   git clone https://github.com/636137/ccaas-admin-ui.git
   cd ccaas-admin-ui/packages/ccaas-template
   \`\`\`

2. Copy the generated \`terraform.tfvars\` to the terraform directory:
   \`\`\`bash
   cp /path/to/terraform.tfvars terraform/
   \`\`\`

### Step 2: Initialize Terraform

\`\`\`bash
cd terraform
terraform init
\`\`\`

### Step 3: Review Plan

\`\`\`bash
terraform plan
\`\`\`

Review the proposed infrastructure changes carefully.

### Step 4: Apply Configuration

\`\`\`bash
terraform apply
\`\`\`

Type \`yes\` when prompted. Deployment typically takes 10-15 minutes.

### Step 5: Capture Outputs

After successful deployment, capture important outputs:

\`\`\`bash
terraform output
\`\`\`

**Important Outputs:**
- \`connect_instance_id\` - Amazon Connect instance ID
- \`lambda_function_arn\` - Lambda function ARN
- \`lex_bot_id\` - Lex bot ID
- \`lex_bot_alias_id\` - Lex bot alias ID

### Step 6: Update JSON Configurations

Replace placeholders in JSON files with actual values from Terraform outputs:

1. **agent-configuration-connect.json**
   - Replace \`CONNECT_INSTANCE_ID\` with actual Connect instance ID
   - Replace \`LEX_BOT_ID\` and \`LEX_BOT_ALIAS_ID\`

2. **agent-configuration-bedrock.json & lex-bot-definition.json**
   - Replace \`ACCOUNT_ID\` with your AWS account ID

### Step 7: Configure Amazon Connect

1. Log in to Amazon Connect instance
2. Import contact flow from template
3. Assign agents from the configured email list
4. Test the flow with a test call

## Validation

After deployment, validate:

- [ ] Connect instance is active
- [ ] Lambda functions deployed successfully
- [ ] DynamoDB table created
- [ ] Lex bot published
- [ ] Agents can log in to Connect
- [ ] Test call flows correctly

## Troubleshooting

### Common Issues

**Issue: Terraform fails with "InvalidInput: Instance alias already exists"**
- Solution: Choose a different \`connect_instance_alias\` in terraform.tfvars

**Issue: Bedrock model not found**
- Solution: Ensure model access is enabled in Bedrock console for your region

**Issue: Lambda function fails to invoke**
- Solution: Check IAM role permissions and VPC configuration

### Support

For issues or questions:
- GitHub: https://github.com/636137/ccaas-admin-ui/issues
- Email: ${input.environment === 'prod' ? input.projectName : 'support'}@example.gov

## Cleanup

To destroy all resources:

\`\`\`bash
cd terraform
terraform destroy
\`\`\`

**Warning:** This will permanently delete all resources. Backup any data before destroying.

## Security Considerations

- All sensitive data is encrypted at rest using KMS
- Network traffic uses VPC private subnets
- CloudTrail logs all API calls
- Least-privilege IAM policies enforced
- Regular security patches via automated pipelines

## Compliance

This deployment ${input.environment === 'prod' ? 'includes' : 'may include'} FedRAMP compliance controls:
- Audit logging (CloudTrail + CloudWatch)
- Encryption (KMS for data at rest, TLS for data in transit)
- Access controls (IAM policies, VPC security groups)
- Monitoring (CloudWatch alarms, Config rules)
- Backup (AWS Backup with point-in-time recovery)

## Next Steps

After successful deployment:

1. Configure contact flows in Amazon Connect
2. Train agents on the census survey questions
3. Set up monitoring dashboards in CloudWatch
4. Schedule regular backup validations
5. Review security logs weekly

---

**Generated by CCaaS Admin UI**  
**Version:** 1.0.0  
**License:** MIT
`
}
