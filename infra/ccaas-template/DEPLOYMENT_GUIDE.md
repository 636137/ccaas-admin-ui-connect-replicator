# Census Enumerator AI Agent - Amazon Connect Deployment Guide

## Overview

This guide walks you through deploying the Census Enumerator AI Agent in Amazon Connect for both voice and chat channels. The agent uses Amazon Bedrock for generative AI capabilities and can be deployed using Amazon Connect's native AI Agent features or Amazon Lex with Bedrock integration.

## Prerequisites

- AWS Account with Amazon Connect instance provisioned
- Amazon Bedrock access enabled in your region
- IAM permissions for Connect, Bedrock, Lambda, and DynamoDB
- (Optional) Amazon Lex bot for enhanced NLU capabilities

## Architecture Options

### Option 1: Amazon Connect AI Agents (Recommended)
Uses native Amazon Q in Connect / AI Agent capabilities for the most streamlined deployment.

### Option 2: Amazon Lex + Amazon Bedrock
Uses Amazon Lex for intent classification with Bedrock for generative responses.

---

## Deployment Steps

### Step 1: Configure Amazon Bedrock

1. **Enable Model Access**
   - Navigate to Amazon Bedrock console
   - Go to "Model access" in the left navigation
   - Request access to Claude 3 Sonnet (or your preferred model)
   - Wait for access approval (usually immediate)

2. **Create a Guardrail** (Optional but recommended)
   ```
   Name: CensusEnumeratorGuardrail
   Description: Guardrails for census survey agent
   ```
   
   Configure the guardrail using settings from `agent-configuration.json`:
   - Block PII: SSN, Credit Cards, Bank Accounts
   - Deny topics: Immigration status, Financial information, Political opinions
   - Content filters: High for hate/violence/sexual, Medium for insults

### Step 2: Set Up DynamoDB Tables

Create tables to store census responses:

```bash
# Census Responses Table
aws dynamodb create-table \
  --table-name CensusResponses \
  --attribute-definitions \
    AttributeName=caseId,AttributeType=S \
    AttributeName=timestamp,AttributeType=S \
  --key-schema \
    AttributeName=caseId,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

# Address Lookup Table  
aws dynamodb create-table \
  --table-name CensusAddresses \
  --attribute-definitions \
    AttributeName=addressId,AttributeType=S \
  --key-schema \
    AttributeName=addressId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 3: Deploy Lambda Functions

Deploy the Lambda functions for backend integration:

```bash
# Package and deploy Lambda
cd lambda/
zip -r census-agent-functions.zip .
aws lambda create-function \
  --function-name CensusAgentBackend \
  --runtime nodejs18.x \
  --handler index.handler \
  --zip-file fileb://census-agent-functions.zip \
  --role arn:aws:iam::YOUR_ACCOUNT:role/CensusAgentLambdaRole
```

### Step 4: Create Amazon Connect Contact Flow

1. **Import the Contact Flow**
   - Go to Amazon Connect console
   - Navigate to "Contact flows"
   - Click "Create contact flow"
   - Import `contact-flow.json`

2. **Configure Flow Blocks**
   - **Set working queue**: Assign to census enumerator queue
   - **Invoke AWS Lambda**: Point to your CensusAgentBackend function
   - **Get customer input**: Configure with AI Agent or Lex bot

### Step 5: Configure AI Agent (Option 1)

Using Amazon Q in Connect:

1. Navigate to Amazon Connect > AI Agents
2. Create new AI Agent:
   - **Name**: CensusEnumeratorAgent
   - **Model**: Claude 3 Sonnet
   - **System Prompt**: Copy from `agent-prompt.md`
   - **Guardrail**: Select CensusEnumeratorGuardrail

3. Configure Actions:
   - Import action definitions from `agent-configuration.json`
   - Connect each action to corresponding Lambda function

4. Deploy the agent and note the Agent ID

### Step 6: Configure Amazon Lex Bot (Option 2)

If using Lex for enhanced NLU:

1. **Create Lex Bot**
   ```
   Bot name: CensusEnumeratorBot
   Language: English (US)
   COPPA: No
   ```

2. **Create Intents**:
   - `ConfirmYes` - For affirmative responses
   - `ConfirmNo` - For negative responses
   - `ProvidePersonInfo` - For collecting person details
   - `ProvideAddress` - For address information
   - `RequestCallback` - For scheduling callbacks
   - `SpeakToAgent` - For escalation requests
   - `FallbackIntent` - For unrecognized inputs

3. **Configure Slot Types**:
   - `RelationshipType` - Enumeration of relationships
   - `RaceType` - Enumeration of race categories
   - `HousingTenure` - Enumeration of housing status

4. **Enable Bedrock Integration**:
   - Go to Bot Settings > Generative AI
   - Enable "Use generative AI for responses"
   - Select Claude 3 Sonnet model

### Step 7: Configure Phone Numbers (Voice)

1. Navigate to Amazon Connect > Phone numbers
2. Claim a toll-free number (recommended: 800 number)
3. Associate with Census Enumerator contact flow

### Step 8: Configure Chat Widget

1. Go to Amazon Connect > Chat
2. Create a new chat widget:
   ```javascript
   amazon_connect('chatWidget', {
     instanceId: 'your-instance-id',
     contactFlowId: 'your-contact-flow-id',
     region: 'us-east-1',
     translations: {
       en_US: {
         headerMessage: 'U.S. Census Bureau',
         welcomeMessage: 'Welcome to the Census Bureau chat. I\'m here to help you complete your census response.'
       }
     }
   });
   ```

3. Embed on your website or deploy standalone

---

## Channel-Specific Configurations

### Voice Configuration

1. **Speech Recognition Settings**
   - Enable automatic speech recognition
   - Set timeout: 4 seconds
   - Enable barge-in for natural conversation

2. **Text-to-Speech Settings**
   - Voice: Neural (Joanna or Matthew recommended)
   - Speaking rate: 95% (slightly slower for clarity)
   - Enable SSML for pronunciation control

3. **DTMF Configuration** (for touch-tone backup)
   - 1 = Yes
   - 2 = No
   - 0 = Speak to agent
   - 9 = Repeat last question

### Chat Configuration

1. **Rich Messaging**
   - Enable list picker for multiple choice questions
   - Enable quick replies for Yes/No questions
   - Support for emojis and formatting

2. **Typing Indicators**
   - Enable to show agent is processing

3. **Attachment Handling**
   - Disable (not needed for census)

---

## Testing

### Functional Testing

1. **Voice Testing**
   - Call the assigned number
   - Complete full survey flow
   - Test error handling and retries
   - Test escalation to live agent

2. **Chat Testing**
   - Use chat widget
   - Complete full survey flow
   - Test timeout handling
   - Test rich message rendering

### Edge Cases to Test

- [ ] Address verification failure
- [ ] Large household (10+ people)
- [ ] Language change request
- [ ] Multiple race selections
- [ ] Callback scheduling
- [ ] Mid-survey abandonment
- [ ] Return to incomplete survey
- [ ] Request for live agent

---

## Monitoring and Analytics

### CloudWatch Metrics

Configure dashboards for:
- Contact volume (voice vs chat)
- Average handling time
- Survey completion rate
- Escalation rate
- Error rate

### Contact Lens Integration

Enable Contact Lens for:
- Sentiment analysis
- Theme detection
- Automatic categorization

### Custom Metrics (via Lambda)

Track census-specific metrics:
- Responses per address attempt
- Household size distribution
- Completion rate by state
- Peak calling times

---

## Security Considerations

### Data Protection

1. **Encryption**
   - Enable encryption at rest for DynamoDB
   - Enable TLS for all API calls
   - Use KMS custom keys for sensitive data

2. **Access Control**
   - Implement least privilege IAM policies
   - Enable MFA for console access
   - Use VPC endpoints where possible

3. **Audit Logging**
   - Enable CloudTrail for all API calls
   - Enable Connect contact trace records
   - Retain logs per federal requirements

### Compliance

- Ensure FISMA compliance for federal systems
- Implement Title 13 data protections
- Regular security assessments

---

## Cost Estimation

| Component | Estimated Monthly Cost |
|-----------|----------------------|
| Amazon Connect (voice) | $0.018/min |
| Amazon Connect (chat) | $0.004/message |
| Amazon Bedrock (Claude) | ~$0.003/1K input, $0.015/1K output |
| DynamoDB | Pay per request (~$1.25/million writes) |
| Lambda | ~$0.20 per million invocations |

**Example**: 100,000 surveys/month @ 5 min avg = ~$9,000-15,000/month

---

## Support and Troubleshooting

### Common Issues

1. **Agent not responding**
   - Check Bedrock model access
   - Verify Lambda permissions
   - Check guardrail configuration

2. **Speech recognition errors**
   - Adjust timeout settings
   - Enable acoustic modeling
   - Consider custom vocabulary

3. **Survey data not saving**
   - Check DynamoDB permissions
   - Verify Lambda execution role
   - Check for throttling

### Escalation Path

1. Review CloudWatch logs
2. Check Contact Trace Records
3. Enable debug logging in Lambda
4. Contact AWS Support (Business/Enterprise)

---

## Appendix

### IAM Policy Template

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:ApplyGuardrail"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/CensusResponses",
        "arn:aws:dynamodb:*:*:table/CensusAddresses"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

### Environment Variables

```
CENSUS_TABLE_NAME=CensusResponses
ADDRESS_TABLE_NAME=CensusAddresses
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
GUARDRAIL_ID=your-guardrail-id
AWS_REGION=us-east-1
```
