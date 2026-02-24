# Agent Configuration Options Comparison

> **WHAT THIS FILE IS:** Side-by-side comparison of the two deployment architectures for the Census Enumerator AI Agent.
> 
> **WHY IT MATTERS:** You need to choose between Amazon Bedrock Agent (more flexible, more components) or Amazon Connect Native AI Agent (simpler, fewer services). This guide helps you decide.
> 
> **TL;DR:** 
> - **Bedrock Agent** → Best if you want to reuse the agent across multiple channels or need advanced orchestration
> - **Connect Native** → Best if you're Connect-only and want the simplest possible setup

---

## Quick Comparison

| Feature | Bedrock Agent | Connect Native AI Agent |
|---------|---------------|------------------------|
| **Config File** | `agent-configuration-bedrock.json` | `agent-configuration-connect.json` |
| **Primary Service** | Amazon Bedrock Agents | Amazon Connect AI Agents |
| **NLU Layer** | Amazon Lex V2 | Built-in Connect NLU |
| **AI Model** | Any Bedrock model | Bedrock models via Connect |
| **Flexibility** | High (standalone) | Medium (Connect-centric) |
| **Setup Complexity** | More components | Simpler (fewer services) |
| **Best For** | Multi-channel, reusable agents | Connect-first deployments |

---

## Option 1: Amazon Bedrock Agent

**File:** `agent-configuration-bedrock.json`

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Amazon Connect  │────▶│  Amazon Lex V2  │────▶│ Amazon Bedrock  │
│  (Voice/Chat)   │     │    (NLU/Dialog) │     │     Agent       │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                        ┌─────────────────┐     ┌────────▼────────┐
                        │    DynamoDB     │◀────│     Lambda      │
                        │   (Storage)     │     │   (Actions)     │
                        └─────────────────┘     └─────────────────┘
```

### When to Choose

✅ **Choose Bedrock Agent if you:**
- Want a reusable AI agent across multiple channels (Connect, web, mobile)
- Need advanced action orchestration and agent reasoning
- Want to use Bedrock Agent features like knowledge bases, code interpretation
- Have existing investment in Bedrock Agents
- Need granular control over the AI agent's behavior
- Want to integrate with non-Connect applications later

### Key Components

| Component | Purpose |
|-----------|---------|
| **Amazon Lex V2** | Natural language understanding, dialog management |
| **Amazon Bedrock Agent** | AI reasoning, action orchestration |
| **Action Groups** | Define callable functions (verify address, save data) |
| **Guardrails** | Content filtering, PII protection at Bedrock level |
| **Lambda** | Execute backend actions |

### Configuration Structure

```json
{
  "agentConfiguration": {
    "foundationModel": "anthropic.claude-3-sonnet...",
    "instruction": "...",
    "promptOverrideConfiguration": {...}
  },
  "actionGroups": [
    {
      "actionGroupName": "CensusSurveyActions",
      "actions": [...]
    }
  ],
  "guardrails": {
    "contentPolicyConfig": {...},
    "sensitiveInformationPolicyConfig": {...},
    "topicPolicyConfig": {...}
  }
}
```

### Deployment

Uses Terraform modules:
- `modules/lex/` - Lex bot with Bedrock integration
- `modules/bedrock/` - Bedrock guardrails
- `modules/lambda/` - Action handlers

---

## Option 2: Amazon Connect Native AI Agent

**File:** `agent-configuration-connect.json`

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Amazon Connect                        │
│  ┌─────────────┐     ┌─────────────────────────────┐   │
│  │ Contact Flow│────▶│    Native AI Agent          │   │
│  │ (Voice/Chat)│     │  ┌─────────────────────┐    │   │
│  └─────────────┘     │  │ Bedrock (embedded)  │    │   │
│                      │  └─────────────────────┘    │   │
│                      │  ┌─────────────────────┐    │   │
│                      │  │ Self-Service Actions│    │   │
│                      │  └──────────┬──────────┘    │   │
│                      └─────────────┼───────────────┘   │
└────────────────────────────────────┼───────────────────┘
                                     │
                        ┌────────────▼────────────┐
                        │         Lambda          │
                        │       (Actions)         │
                        └────────────┬────────────┘
                                     │
                        ┌────────────▼────────────┐
                        │        DynamoDB         │
                        └─────────────────────────┘
```

### When to Choose

✅ **Choose Connect Native AI Agent if you:**
- Are building primarily for Amazon Connect
- Want simpler architecture with fewer AWS services
- Need tight integration with Connect features (Contact Lens, routing)
- Prefer Connect's native escalation and transfer capabilities
- Want unified management within the Connect console
- Are already invested in Amazon Connect ecosystem

### Key Components

| Component | Purpose |
|-----------|---------|
| **Connect AI Agent** | Unified AI handling within Connect |
| **Self-Service Actions** | Lambda-backed actions for data operations |
| **Contact Lens** | Built-in analytics, sentiment, categorization |
| **Routing Profiles** | Native queue management and escalation |
| **Contact Attributes** | Session state management |

### Configuration Structure

```json
{
  "connectConfiguration": {
    "instanceId": "...",
    "agentType": "AI_AGENT",
    "channels": ["VOICE", "CHAT"]
  },
  "aiAgentSettings": {
    "modelConfiguration": {...},
    "voiceSettings": {...}
  },
  "systemPrompt": {
    "role": "...",
    "instructions": [...]
  },
  "selfServiceActions": [...],
  "escalationSettings": {...},
  "guardrails": {...}
}
```

### Deployment

Primarily uses Amazon Connect APIs and console:
- Create AI Agent in Connect console
- Configure Self-Service Actions
- Set up Routing Profiles and Queues
- Associate with Contact Flows

---

## Feature Comparison Detail

### Natural Language Understanding

| Aspect | Bedrock Agent | Connect Native |
|--------|---------------|----------------|
| Intent Recognition | Lex V2 intents | Connect built-in NLU |
| Slot Filling | Lex slots with types | Action parameters |
| Dialog Management | Lex + Bedrock Agent | Connect AI Agent |
| Multi-turn Context | Bedrock Agent memory | Contact attributes |

### Voice Configuration

| Aspect | Bedrock Agent | Connect Native |
|--------|---------------|----------------|
| Voice Engine | Lex → Polly | Connect → Polly |
| Voice Selection | In Lex locale config | In AI Agent settings |
| SSML Support | Via Lex responses | Via Connect prompts |
| Barge-in | Lex configuration | Connect flow settings |

### Escalation & Transfer

| Aspect | Bedrock Agent | Connect Native |
|--------|---------------|----------------|
| Transfer Method | Contact flow block | Built-in escalation |
| Queue Selection | Manual in flow | Configured triggers |
| Agent Whisper | Separate flow needed | Integrated |
| Context Passing | Lambda → attributes | Automatic |

### Analytics & Monitoring

| Aspect | Bedrock Agent | Connect Native |
|--------|---------------|----------------|
| Conversation Logs | CloudWatch + Lex | Contact Lens |
| Sentiment Analysis | Custom implementation | Built-in |
| Theme Detection | Custom | Built-in |
| Dashboards | Custom CloudWatch | Connect Analytics |

---

## Migration Path

### Bedrock Agent → Connect Native

1. Map Lex intents to AI Agent system prompt
2. Convert action groups to self-service actions
3. Migrate guardrails to Connect guardrail config
4. Update contact flow to use AI Agent block

### Connect Native → Bedrock Agent

1. Create Lex bot with intents from system prompt
2. Create Bedrock Agent with action groups
3. Set up guardrails in Bedrock
4. Update contact flow to use Lex bot

---

## Recommendations

| Scenario | Recommended Option |
|----------|-------------------|
| New Connect deployment | **Connect Native** |
| Multi-channel requirement | **Bedrock Agent** |
| Existing Lex investment | **Bedrock Agent** |
| Simplest setup | **Connect Native** |
| Maximum flexibility | **Bedrock Agent** |
| Connect analytics focus | **Connect Native** |
| Reusable AI component | **Bedrock Agent** |

---

## Files Reference

| File | Description |
|------|-------------|
| `agent-configuration-bedrock.json` | Bedrock Agent configuration |
| `agent-configuration-connect.json` | Connect Native AI Agent configuration |
| `lex-bot/` | Lex bot definition (for Bedrock option) |
| `terraform/modules/lex/` | Terraform for Lex (Bedrock option) |
| `contact-flow.json` | Connect flow (works with both) |
