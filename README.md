# Government CCaaS Admin UI

**An intuitive web-based configuration generator for deploying AI-powered government contact centers on AWS with one click.**

---

## 📋 Table of Contents

- [What This Project Does](#-what-this-project-does)
- [Why It Exists](#-why-it-exists)
- [How It Works](#-how-it-works)
- [Key Features](#-key-features)
- [Getting Started](#-getting-started)
- [Detailed Usage Guide](#-detailed-usage-guide)
- [Configuration Options](#-configuration-options)
- [Project Architecture](#-project-architecture)
- [API Reference](#-api-reference)
- [Claude AI Models](#-claude-ai-models)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 What This Project Does

This is a **Government CCaaS Admin UI** - a modern web application that simplifies the deployment of complex cloud infrastructure for government contact centers. It provides:

1. **Interactive Configuration Wizard** - A step-by-step interface to configure your entire contact center deployment without touching infrastructure code
2. **Automatic Code Generation** - Converts your configuration choices into production-ready Terraform code, JSON configurations, and deployment scripts
3. **Pre-built Infrastructure Templates** - Includes all the AWS resources needed: Amazon Connect (contact center), Lex (chatbot), Lambda (serverless functions), DynamoDB (database), etc.
4. **AI-Powered Agents** - Integrates with Claude on Amazon Bedrock to enable intelligent, conversational contact center agents
5. **FedRAMP Compliance** - Built-in support for government compliance requirements with optional security controls

**In short:** Point, click, configure, download, deploy. No Terraform expertise needed.

---

## 💡 Why It Exists

Deploying a production government contact center is complex:
- **Many services** - Connect, Lex, Lambda, DynamoDB, VPC, KMS, WAF, CloudTrail, etc.
- **Security requirements** - FedRAMP compliance, encryption, audit logs, network isolation
- **Configuration overhead** - Hundreds of parameters to configure correctly
- **Deployment challenges** - Infrastructure as Code requires DevOps expertise

**This project solves these problems** by:
- ✅ Abstracting AWS complexity into a simple UI
- ✅ Enforcing security best practices by default
- ✅ Generating production-ready code automatically
- ✅ Supporting both quick deployments (MVP mode) and full control (Comprehensive mode)
- ✅ Enabling non-technical users to deploy sophisticated infrastructure

---

## 🔧 How It Works

### The Deployment Flow

```
User fills out Configuration Wizard
           ↓
  Validates inputs in real-time
           ↓
  Submits configuration to API
           ↓
  Backend generates all deployment files:
    - terraform.tfvars (infrastructure variables)
    - agent-configuration-bedrock.json
    - agent-configuration-connect.json
    - lex-bot-definition.json
    - README.md (deployment guide)
           ↓
  Files packaged in ZIP download
           ↓
  User downloads and extracts locally
           ↓
  User runs: terraform init → terraform plan → terraform apply
           ↓
  AWS resources created and configured automatically
           ↓
  Contact center is live and ready to receive calls
```

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              User's Browser                             │
│  ┌───────────────────────────────────────────────────┐  │
│  │    React UI (Vite)                                │  │
│  │  - Configuration Wizard                           │  │
│  │  - Step-by-step validation                        │  │
│  │  - Model selection with filtering                 │  │
│  │  - Real-time error checking                       │  │
│  └──────────────────┬──────────────────────────────┘  │
│                     │ (HTTP)                           │
└─────────────────────┼───────────────────────────────────┘
                      │
┌─────────────────────┼───────────────────────────────────┐
│      Local Machine  │                                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │    Express API Server (Node.js)                   │  │
│  │  - Receives configuration                         │  │
│  │  - Validates data integrity                       │  │
│  │  - Generates configuration files                  │  │
│  │  - Creates ZIP deployment package                 │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │    Downloaded & Extracted ZIP                     │  │
│  │  - terraform.tfvars                               │  │
│  │  - agent-config*.json                             │  │
│  │  - lex-bot-definition.json                        │  │
│  │  - README.md                                      │  │
│  │  - Terraform modules (from ccaas-template/)       │  │
│  └────────────┬─────────────────────────────────────┘  │
│               │ terraform init/plan/apply              │
└───────────────┼─────────────────────────────────────────┘
                │
┌───────────────┼──────────────────────────────────────┐
│     AWS Cloud │                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Amazon Connect (Contact Center)                 │ │
│  │ • Instance, Phone Numbers, Contact Flows       │ │
│  │ • Agent Profiles, Security Profiles            │ │
│  └─────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Amazon Lex (Chatbot)                            │ │
│  │ • Bot Configuration, Intents, Slots           │ │
│  │ • Lambda Integration                            │ │
│  └─────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Amazon Bedrock (AI)                             │ │
│  │ • Claude Model Access, Agent Prompts           │ │
│  └─────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────┐ │
│  │ AWS Lambda (Processing)                         │ │
│  │ • Data transformation, API calls               │ │
│  └─────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────┐ │
│  │ DynamoDB (Database)                             │ │
│  │ • Response storage, Analytics                   │ │
│  └─────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Network & Security                              │ │
│  │ • VPC, Security Groups, WAF, KMS, CloudTrail   │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

---

## ✨ Key Features

- **🧙 Configuration Wizard** - Step-by-step guided setup (no code experience required)
  - **MVP Mode**: Essential settings only (~5 minutes to complete)
  - **Comprehensive Mode**: Full control over 50+ parameters for advanced users

- **🤖 Claude AI Model Selection** - Choose from 9 available Claude models with:
  - Real-time availability filtering by AWS region
  - GovCloud support detection
  - Performance tier information (Economy → Flagship)
  - Input modality support (text, images, etc.)

- **📦 Automatic Code Generation** - Produces deployment-ready files:
  - `terraform.tfvars` - All infrastructure variables
  - `agent-configuration-bedrock.json` - Bedrock agent settings
  - `agent-configuration-connect.json` - Connect integration
  - `lex-bot-definition.json` - Chatbot configuration
  - `README.md` - Step-by-step deployment guide

- **🔒 FedRAMP Compliance** - Optional government compliance controls:
  - 90+ day audit log retention
  - KMS encryption for sensitive data
  - WAF (Web Application Firewall) rules
  - VPC isolation for network security
  - CloudTrail logging for compliance audits

- **🌍 Multi-Region Support** - Deploy to any AWS region including GovCloud

- **🧬 Connect Replicator (Global Resiliency)** - Browse regions/instances and trigger `ReplicateInstance` via a guided UI at `/connect`

- **✅ Real-Time Validation** - Prevents invalid configurations before download

- **📊 Flexible Deployment Options**
  - Create new Amazon Connect instance or use existing
  - Custom VPC configuration or use default
  - Enable/disable advanced security features
  - Backup and disaster recovery settings

---

## 🚀 Getting Started

### Prerequisites

Before you start, ensure you have:

- **Node.js 18.x or higher** - [https://nodejs.org/](https://nodejs.org/)
- **npm 9.x or higher** - Comes with Node.js
- **Git** - For cloning the repository
- **AWS Account** - For deploying infrastructure (not needed just to run the UI)
- **Terraform 1.5+** - For deploying (only needed after downloading configuration)

**Verify prerequisites:**
```bash
node --version        # Should be v18+
npm --version         # Should be 9+
terraform --version   # Only if you plan to deploy
```

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/636137/ccaas-admin-ui.git
   cd ccaas-admin-ui
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```
   This installs both frontend and backend dependencies.

3. **Start development servers:**
   ```bash
   npm run dev
   ```
   
   You should see:
   ```
   ✓ UI running at:  http://localhost:3000
   ✓ API running at: http://localhost:3001
   ```

4. **Open your browser:**
   Navigate to [http://localhost:3000](http://localhost:3000)

That's it! You're ready to use the configuration wizard.

---

## 📖 Detailed Usage Guide

### Step 1: Launch the Configuration Wizard

Visit http://localhost:3000 - You'll see the Configuration Wizard home page.

### Step 2: Select Deployment Mode

Choose between two modes:

**MVP Mode** (Recommended for getting started)
- Fast (~5 minutes)
- 7 essential steps
- Smart defaults for optional settings
- Perfect for development, testing, or quick production deployments
- Can always upgrade to comprehensive later

**Comprehensive Mode** (For advanced users)
- 12 detailed steps
- Full control over 50+ parameters
- Customize VPC, security, monitoring, backup, everything
- Recommended for production deployments with specific requirements

### Step 3: Fill Out Configuration Steps

Each mode has specific steps:

#### MVP Mode Steps:

1. **Basic Info**
   - **Project Name**: How to identify your deployment (e.g., "CensusBot2024", "GovConnect")
   - **Environment**: dev, staging, or prod
   - **Owner**: Email or team responsible for this deployment
   - **Mode**: MVP or Comprehensive

2. **Region & Model**
   - **AWS Region**: Where infrastructure will be deployed
   - **AI Model**: Select Claude model (Sonnet 4.5 recommended for balance of cost and capability)

3. **Amazon Connect**
   - **Create New Instance**: Toggle to create new or use existing
   - **Instance Alias**: Unique name for your contact center (auto-filled from project name)

4. **Users**
   - **Agent Emails**: Contact center agent email addresses
   - **Supervisor Email**: Supervisor account email

5. **Security**
   - **FedRAMP Compliance**: Toggle for government compliance controls
   - **WAF Protection**: Toggle for Web Application Firewall
   - **KMS Encryption**: Toggle for data encryption

6. **Review**
   - Review all settings
   - Click **Download Deployment Package**

#### Comprehensive Mode includes all MVP steps plus:

7. **Lex Bot Configuration** - Chatbot settings (voice, locale, confidence threshold)
8. **Lambda Functions** - Serverless backend (runtime, timeout, memory)
9. **DynamoDB** - Database (billing mode, encryption, backup)
10. **VPC Configuration** - Network (new/existing VPC, subnets, ACLs)
11. **Monitoring & Logging** - CloudWatch (log retention, alarms)
12. **Backup & DR** - Disaster recovery (backup retention, cross-region copy)

### Step 4: Download Configuration Package

After reviewing your configuration, click the **Download Deployment Package** button.

A ZIP file will download containing all deployment files:
```
ccaas-deployment-prod.zip
├── terraform.tfvars           # Infrastructure variables
├── agent-configuration-bedrock.json
├── agent-configuration-connect.json
├── lex-bot-definition.json
└── README.md                  # Deployment instructions
```

### Step 5: Deploy to AWS

1. **Extract the ZIP file:**
   ```bash
   unzip ccaas-deployment-prod.zip
   cd ccaas-deployment-prod
   ```

2. **Review the configuration:**
   ```bash
   cat terraform.tfvars
   ```
   Make any adjustments if needed.

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Preview what will be created:**
   ```bash
   terraform plan
   ```
   Review the output to ensure everything looks correct.

5. **Deploy to AWS:**
   ```bash
   terraform apply
   ```
   You'll be prompted to confirm. Type `yes` to proceed.

6. **Wait for deployment:**
   - Typically takes 5-10 minutes
   - Terraform will show progress as resources are created
   - At the end, it will display outputs (instance ID, URLs, etc.)

7. **Verify deployment:**
   ```bash
   # Check Amazon Connect instance
   aws connect describe-instance --instance-id <instance-id> --region <your-region>
   
   # Check Lex bot
   aws lexv2-models describe-bot --bot-id <bot-id>
   ```

---

## ⚙️ Configuration Options

### MVP Mode (Essential)
### MVP Mode (Essential)

These settings control the core deployment:

| Setting | Options | Default | Impact |
|---------|---------|---------|--------|
| **Project Name** | Any string (letters, numbers, hyphens) | Required | Used for resource naming and identification |
| **Environment** | dev, staging, prod | dev | Affects naming, tagging, and resource sizing |
| **Owner** | Email address | - | Used for billing and notifications |
| **AWS Region** | Any AWS region | us-east-1 | Where all resources will be created |
| **Claude Model** | 9 available models | Claude Sonnet 4.5 | AI capability, speed, and cost |
| **Create Connect Instance** | true/false | true | Create new instance or use existing |
| **Connect Alias** | Unique name | Project name | Identifier for your contact center |
| **Agent Emails** | List of emails | [] | Test users who can handle calls |
| **Supervisor Email** | Email address | - | Account for monitoring and reporting |
| **FedRAMP Compliance** | true/false | false | Enable government compliance controls |
| **WAF Protection** | true/false | false | Enable firewall for protection |
| **KMS Encryption** | true/false | true | Encrypt sensitive data at rest |

### Comprehensive Mode (Advanced)

Includes all MVP settings plus ~40 additional options:

- **Lex Configuration**: Voice, locale, NLU confidence thresholds
- **Lambda Settings**: Runtime, timeout, memory allocation
- **DynamoDB**: Billing mode, encryption, point-in-time recovery
- **VPC & Networking**: VPC creation, subnets, availability zones, NAT gateways
- **Advanced Security**: KMS administrators, audit log retention, security notifications
- **Monitoring**: CloudWatch dashboard, alarm configuration, log retention
- **Backup & DR**: Backup retention, cross-region replication, disaster recovery vaults
- **Validation Module**: AI accuracy thresholds, latency targets

---

## 🏗️ Project Architecture

### File Structure

```
ccaas-admin-ui/
├── packages/
│   ├── ui/                          # React Frontend (Port 3000)
│   │   ├── src/
│   │   │   ├── App.tsx              # Main router
│   │   │   ├── components/ui/       # Reusable UI components (buttons, forms, etc.)
│   │   │   ├── config/
│   │   │   │   └── bedrock-models.ts    # Claude model definitions & availability
│   │   │   ├── pages/
│   │   │   │   ├── ConfigWizard.tsx     # Main wizard container
│   │   │   │   ├── wizard/              # Wizard step components
│   │   │   │   │   ├── BasicInfoStep.tsx
│   │   │   │   │   ├── RegionModelStep.tsx
│   │   │   │   │   ├── ConnectStep.tsx
│   │   │   │   │   ├── SecurityStep.tsx
│   │   │   │   │   └── ReviewStep.tsx
│   │   │   │   └── DeploymentsPage.tsx  # View past deployments
│   │   │   ├── services/
│   │   │   │   ├── api.ts           # API client for backend
│   │   │   │   └── validation.ts    # Form validation logic
│   │   │   ├── types/
│   │   │   │   ├── wizard.ts        # TypeScript types for config
│   │   │   │   ├── config.ts        # AWS config types
│   │   │   │   └── terraform.ts     # Terraform types
│   │   │   ├── main.tsx             # React entry point
│   │   │   └── index.css            # Global styles
│   │   ├── vite.config.ts           # Vite React config
│   │   ├── tailwind.config.js       # Tailwind CSS config
│   │   └── package.json
│   │
│   ├── api/                         # Express Backend (Port 3001)
│   │   ├── src/
│   │   │   ├── index.ts             # Express server setup
│   │   │   ├── routes/
│   │   │   │   ├── package.ts       # POST /api/package/generate
│   │   │   │   ├── deploy.ts        # Deployment endpoints
│   │   │   │   ├── config.ts        # Config validation endpoints
│   │   │   │   └── prerequisites.ts # Prerequisites checking
│   │   │   └── services/
│   │   │       ├── generator.ts     # Generate terraform.tfvars
│   │   │       └── template.service.ts  # JSON template generation
│   │   └── package.json
│   │
│   └── ccaas-template/              # Pre-built Infrastructure (from MarcS-CensusDemo)
│       ├── terraform/
│       │   ├── main.tf              # Main infrastructure definition
│       │   ├── variables.tf         # Variable declarations
│       │   ├── outputs.tf           # Output values
│       │   ├── modules/
│       │   │   ├── connect/         # Amazon Connect module
│       │   │   ├── lex/             # Lex bot module
│       │   │   ├── lambda/          # Lambda functions
│       │   │   ├── dynamodb/        # DynamoDB tables
│       │   │   ├── vpc/             # VPC networking
│       │   │   ├── security/        # KMS, WAF, security
│       │   │   ├── monitoring/      # CloudWatch
│       │   │   ├── backup/          # Backup & FR
│       │   │   └── iam/             # IAM roles
│       │   └── fedramp.tf           # FedRAMP config
│       ├── lambda/                  # Lambda code
│       │   ├── index.js
│       │   └── package.json
│       ├── lex-bot/                 # Lex definitions
│       │   └── bot-definition.json
│       └── scripts/                 # Deployment scripts
│           ├── validate.sh
│           └── dr/                  # Disaster recovery
│
├── package.json                     # Monorepo root (runs both UI + API)
├── README.md                        # This file
└── .gitignore
```

### Technology Stack

**Frontend:**
- **React 18** - UI framework
- **TypeScript** - Type safety and IDE support
- **Vite** - Ultra-fast build tool (~350ms startup)
- **Tailwind CSS** - Utility-first styling
- **Radix UI** - Headless, accessible component library
- **React Router** - SPA navigation
- **React Hook Form + Zod** - Form validation with inference

**Backend:**
- **Express.js** - Node.js web framework
- **TypeScript** - Type-safe backend code
- **tsx watch** - File watching for development
- **Archiver** - ZIP file creation for downloads

**DevOps & Infrastructure:**
- **Terraform 1.5+** - Infrastructure as Code
- **AWS Services** - Connect, Lex, Bedrock, Lambda, DynamoDB, VPC, KMS, WAF, etc.
- **Docker** - Containerization (optional, for CI/CD)

---

## 🔌 API Reference

### Health Check
```
GET /api/health
Response: { "status": "ok", "timestamp": "2026-02-24T..." }
```

### Amazon Connect Replicator (Global Resiliency)
These endpoints power the UI at: `GET /connect`

```
GET /api/connect/regions
Response: { regions: [...], globalResiliencyTargets: { "us-east-1": ["us-west-2"], ... } }

GET /api/connect/instances?region=us-east-1
GET /api/connect/instance?region=us-east-1&instanceId=<uuid-or-arn>
GET /api/connect/replication-status?region=us-west-2&instanceId=<uuid>

POST /api/connect/snapshot
Body: { "region": "us-east-1", "instanceId": "<uuid-or-arn>" }

POST /api/connect/replicate
Body: {
  "sourceRegion": "us-east-1",
  "targetRegion": "us-west-2",
  "instanceId": "<uuid-or-arn>",
  "replicaAlias": "my-replica-alias"
}
```

Notes:
- `ReplicateInstance` is access-gated by AWS and may return errors like "AWS account not allowlisted" until enabled.
- Source instance must be `ACTIVE` and `SAML` identity-managed for Global Resiliency replication.

### Generate Deployment Package
```
POST /api/package/generate
Content-Type: application/json

Body: {
  "config": {
    "mode": "mvp" | "comprehensive",
    "basic": {
      "projectName": "CensusBot",
      "environment": "dev" | "staging" | "prod",
      "owner": "user@example.gov",
      "awsRegion": "us-east-1"
    },
    "aiModel": {
      "bedrockModelId": "anthropic.claude-sonnet-4-5-20250929-v1:0"
    },
    // ... other optional config sections
  }
}

Response: ZIP file download with:
- terraform.tfvars
- agent-configuration-*.json
- lex-bot-definition.json
- README.md
```

### Error Responses
- `400 Bad Request` - Invalid configuration
- `500 Internal Server Error` - Generation failed
- Response includes `error` and `message` fields

---

## 🤖 Claude AI Models

Available models (February 2026) with regional support:

| Model | Tier | Input | Regions | GovCloud |
|-------|------|-------|---------|----------|
| Claude 3 Haiku | Economy | Text, Image | Multi | us-gov-west-1 |
| Claude 3.5 Haiku | Economy | Text | Multi | - |
| Claude Haiku 4.5 | Economy | Text, Image | Multi | - |
| Claude Sonnet 4 | Standard | Text, Image | Multi | - |
| **Claude Sonnet 4.5** | Standard | Text, Image | Multi | us-gov-west-1, us-gov-east-1 |
| Claude Sonnet 4.6 | Standard | Text, Image | Multi | - |
| Claude Opus 4.1 | Premium | Text, Image | Multi | - |
| Claude Opus 4.5 | Flagship | Text, Image | Multi | - |
| Claude Opus 4.6 | Flagship | Text, Image | Multi | - |

**Recommendations:**
- **For government deployments**: Claude Sonnet 4.5 (has GovCloud support + good balance)
- **For cost-sensitive**: Claude Haiku 4.5 (economy tier, fast)
- **For maximum capability**: Claude Opus 4.5 (best reasoning, higher cost)

**Note:** Model availability varies by region. The UI automatically filters models for the selected region.

---

## 🐛 Troubleshooting

### Server Won't Start

**Problem:** `Port 3000 already in use`
```bash
# Kill process using port
lsof -ti:3000 | xargs kill -9

# Try again
npm run dev
```

**Problem:** `npm ERR! code ENOENT`
```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### API Connection Failed

**Problem:** `ECONNREFUSED 127.0.0.1:3001`
- API server not running
- Solution: In another terminal, run `source ~/.nvm/nvm.sh && npm run dev:api`

### Package Download Hangs

**Problem:** Download doesn't complete
- Check browser console (F12) for errors
- Verify API is running: `curl http://localhost:3001/api/health`
- Try a simpler configuration (fewer optional fields)

### Terraform Apply Fails

**Problem:** `AWS credentials not found`
```bash
# Configure AWS credentials
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

**Problem:** `connect_instance_alias` is invalid
- Must be lowercase, alphanumeric + hyphens
- Cannot start/end with hyphen
- Max 63 characters
- Solution: The UI auto-sanitizes this from your project name

### DynamoDB Errors

**Problem:** `Quota exceeded for provisioned throughput`
- Billing mode set to PROVISIONED instead of PAY_PER_REQUEST
- Solution: Use "Standard" tier in comprehensive mode or MVP defaults (uses PAY_PER_REQUEST)

### FedRAMP Compliance Issues

**Problem:** `audit_log_retention_days` too low
- FedRAMP requires minimum 90 days
- Solution: Set audit log retention to 90+ days in Security step

---

## 📚 Development

### Start in Development Mode

```bash
# All servers with hot reload
npm run dev

# Or separately:
# Terminal 1: UI development server
npm run dev:ui

# Terminal 2: API development server  
npm run dev:api
```

### Build for Production

```bash
# Build both frontend and backend
npm run build

# Output goes to packages/ui/dist and packages/api/dist
```

### Run Tests

```bash
npm run lint     # Check code quality
npm run test     # Run test suite (if available)
```

### Debugging

Enable verbose logging:
```bash
# Backend
DEBUG=* npm run dev:api

# Frontend (browser console via F12)
```

---

## 🔐 Security Considerations

This tool generates infrastructure code - security is critical:

1. **Configuration Secrets**: Never commit generated `terraform.tfvars` containing credentials or sensitive data to Git
2. **AWS Credentials**: Use IAM roles when possible, avoid hardcoding credentials
3. **State File**: Terraform state files contain sensitive data - secure the generated deployment directory
4. **Access Control**: Restrict who can download deployment packages
5. **Audit Logging**: Enable CloudTrail in AWS to log all infrastructure changes

---

## 📝 License

**Maximus Proprietary**

This software is proprietary to Maximus Federal Services, LLC. Unauthorized access, use, or distribution is prohibited.

**No License is Granted.** This software is for authorized Maximus personnel only. Not for public use.

© 2026 Maximus Federal Services, LLC. All rights reserved.

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add improvement'`)
4. Push to branch (`git push origin feature/improvement`)
5. Create Pull Request

---

## 📞 Support

- **Issues**: Report bugs on [GitHub Issues](https://github.com/636137/ccaas-admin-ui/issues)
- **Docs**: See [./packages/ccaas-template/](./packages/ccaas-template/) for infrastructure documentation
- **AWS Docs**: [Amazon Connect](https://docs.aws.amazon.com/connect/), [Bedrock](https://docs.aws.amazon.com/bedrock/), [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

---

## 🔗 Related Resources

- **Government CCaaS in a Box** - Base infrastructure template: [./packages/ccaas-template/](./packages/ccaas-template/)
- **AWS Services Documentation**:
  - [Amazon Connect](https://docs.aws.amazon.com/connect/)
  - [Amazon Bedrock](https://docs.aws.amazon.com/bedrock/)
  - [Amazon Lex](https://docs.aws.amazon.com/lex/)
  - [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- **Claude Documentation**: [anthropic.com](https://docs.anthropic.com/)
- **Terraform AWS Provider**: [registry.terraform.io/providers/hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest)

---

**Last Updated:** February 24, 2026

<!-- BEGIN COPILOT CUSTOM AGENTS -->
## GitHub Copilot Custom Agents (Maximus Internal)

This repository includes **GitHub Copilot custom agent profiles** under `.github/agents/` to speed up planning, documentation, and safe reviews.

### Included agents
- `implementation-planner` — Creates detailed implementation plans and technical specifications for this repository.
- `readme-creator` — Improves README and adjacent documentation without modifying production code.
- `security-auditor` — Performs a read-only security review (secrets risk, risky patterns) and recommends fixes.
- `amazon-connect-solution-engineer` — Designs and integrates Amazon Connect solutions for this repository (IAM-safe, CX/ops focused).
- `amazon-connect-replication-engineer` — Plans and validates Amazon Connect replication/migration workflows across instances (API-level, dependency-aware).

### How to invoke

- **GitHub.com (Copilot coding agent):** select the agent from the agent dropdown (or assign it to an issue) after the `.agent.md` files are on the default branch.
- **GitHub Copilot CLI:** from the repo folder, run `/agent` and select one of the agents, or run:
  - `copilot --agent <agent-file-base-name> --prompt "<your prompt>"`
- **IDEs:** open Copilot Chat and choose the agent from the agents dropdown (supported IDEs), backed by the `.github/agents/*.agent.md` files.

References:
- Custom agents configuration: https://docs.github.com/en/copilot/reference/custom-agents-configuration
- Creating custom agents: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-custom-agents
<!-- END COPILOT CUSTOM AGENTS -->
