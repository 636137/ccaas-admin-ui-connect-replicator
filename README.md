# Government CCaaS Admin UI

A React-based administrative interface for configuring and deploying **Government CCaaS in a Box** - an Amazon Connect contact center with AI-powered census agents.

## Features

- **Configuration Wizard**: Step-by-step deployment configuration
  - MVP Mode: Quick start with essential settings (~5 min)
  - Comprehensive Mode: Full control over all parameters
- **Claude Model Selection**: Browse all 9 available Claude models with regional availability
- **Terraform Generation**: Automatically generate `terraform.tfvars` files
- **FedRAMP Compliance**: Built-in security controls for government deployments
- **GovCloud Support**: Region-aware model filtering for GovCloud deployments

## Available Claude Models (February 2026)

| Model | Tier | GovCloud | Input |
|-------|------|----------|-------|
| Claude 3 Haiku | Economy | us-gov-west-1 | Text, Image |
| Claude 3.5 Haiku | Economy | - | Text |
| Claude Haiku 4.5 | Economy | - | Text, Image |
| Claude Sonnet 4 | Standard | - | Text, Image |
| **Claude Sonnet 4.5** | Standard | us-gov-west-1, us-gov-east-1 | Text, Image |
| Claude Sonnet 4.6 | Standard | - | Text, Image |
| Claude Opus 4.1 | Premium | - | Text, Image |
| Claude Opus 4.5 | Flagship | - | Text, Image |
| Claude Opus 4.6 | Flagship | - | Text, Image |

**Recommended**: Claude Sonnet 4.5 - Best balance of capability, speed, and cost for AI agents. Wide regional and GovCloud support.

## Project Structure

```
ccaas-admin-ui/
├── packages/
│   ├── ui/                    # React frontend (Vite + TypeScript)
│   │   ├── src/
│   │   │   ├── components/    # Shared UI components
│   │   │   ├── config/        # Configuration (bedrock-models.ts)
│   │   │   ├── pages/         # Page components
│   │   │   │   └── wizard/    # Configuration wizard steps
│   │   │   └── services/      # API services
│   │   └── package.json
│   │
│   ├── api/                   # Express backend
│   │   ├── src/
│   │   │   ├── routes/        # API endpoints
│   │   │   └── services/      # Config generators
│   │   └── package.json
│   │
│   └── ccaas-template/        # Clone of MarcS-CensusDemo
│       ├── terraform/         # Infrastructure as Code
│       ├── lambda/            # Lambda functions
│       └── lex-bot/           # Lex bot configuration
│
├── package.json               # Monorepo root
└── README.md
```

## Quick Start

### Prerequisites

- Node.js 18+
- npm 9+

### Installation

```bash
# Install dependencies
npm install

# Start development servers (UI + API)
npm run dev
```

The UI will be available at http://localhost:3000 and API at http://localhost:3001.

### Development Commands

```bash
# Start UI only
npm run dev:ui

# Start API only
npm run dev:api

# Build for production
npm run build

# Run linting
npm run lint
```

## Configuration Wizard

The wizard guides you through deployment configuration:

1. **Basic Info**: Project name, environment, owner
2. **Region & Model**: AWS region and Claude model selection
3. **Connect Setup**: Amazon Connect instance configuration
4. **Security**: FedRAMP compliance, WAF protection
5. **Review**: Generate and download configuration files

### MVP Mode (Default)

Essential settings only. Get started in under 5 minutes:
- 7 parameters
- Sensible defaults for all optional settings
- Recommended for development and testing

### Comprehensive Mode

Full control over all ~50+ parameters:
- All security configurations
- Custom VPC settings
- Load testing options
- Disaster recovery settings

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/config/models` | List available Claude models |
| POST | `/api/config/terraform` | Generate terraform.tfvars |
| POST | `/api/config/validate` | Validate configuration |
| GET | `/api/deploy` | List deployments |
| POST | `/api/deploy` | Create deployment |
| GET | `/api/deploy/:id` | Get deployment status |

## Technology Stack

**Frontend:**
- React 18
- TypeScript
- Vite
- Tailwind CSS
- Radix UI
- React Router
- React Hook Form + Zod

**Backend:**
- Express
- TypeScript
- Handlebars (templates)

## License

MIT

## Related

- [Government CCaaS in a Box](./packages/ccaas-template/) - The deployment template
- [Amazon Bedrock Claude Models](https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html)
