# Government CCaaS Admin UI - Setup Guide

This guide covers installation, configuration, and usage of the Government CCaaS Admin UI.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js 18+** - [Download from nodejs.org](https://nodejs.org/)
- **npm** (comes with Node.js)
- **Git** (optional, for cloning the repository)

Verify your installation:
```bash
node -v  # Should show v18.0.0 or higher
npm -v   # Should show 8.0.0 or higher
```

## Quick Start

### Option 1: Automated Installation (Recommended)

Run the installation script from the project root:

```bash
./install.sh
```

This script will:
- Check Node.js version requirements
- Install all root dependencies
- Install UI package dependencies
- Install API package dependencies
- Install required packages (archiver, zod, etc.)

### Option 2: Manual Installation

If the automated script doesn't work, install manually:

```bash
# Install root dependencies
npm install

# Install UI package dependencies
cd packages/ui
npm install
cd ../..

# Install API package dependencies
cd packages/api
npm install
cd ../..

# Install archiver for package generation
npm install -w packages/api archiver @types/archiver
```

### Option 3: Using npm Script

```bash
npm run install:all
```

## Development

### Start Both UI and API Together

```bash
npm run dev
```

This starts:
- **UI**: http://localhost:5173
- **API**: http://localhost:3001

### Start Services Individually

```bash
# UI only
npm run dev:ui

# API only
npm run dev:api
```

## Project Structure

```
ccaas-admin-ui/
├── packages/
│   ├── ui/                    # React + TypeScript + Vite frontend
│   │   ├── src/
│   │   │   ├── components/    # Reusable UI components
│   │   │   ├── pages/         # Page components
│   │   │   │   └── wizard/    # 12 configuration wizard steps
│   │   │   ├── services/      # API client, validation
│   │   │   ├── types/         # TypeScript type definitions
│   │   │   └── config/        # Bedrock models, AWS regions
│   │   └── package.json
│   ├── api/                   # Express + TypeScript backend
│   │   ├── src/
│   │   │   ├── routes/        # API endpoints
│   │   │   ├── services/      # Config generation, templates
│   │   │   └── templates/     # JSON config templates
│   │   └── package.json
│   └── ccaas-template/        # Terraform modules and configs
│       ├── terraform/         # Infrastructure as Code
│       ├── lambda/            # Lambda functions
│       ├── lex-bot/           # Lex bot definitions
│       └── scripts/           # DR and validation scripts
├── package.json               # Root workspace config
├── install.sh                 # Installation script
└── SETUP.md                   # This file
```

## Using the Configuration Wizard

### 1. Access the UI

Navigate to http://localhost:5173 in your browser.

### 2. Choose Your Mode

- **MVP Mode** (6 steps): Quick setup with essential configuration
- **Comprehensive Mode** (12 steps): Full configuration with all options

### 3. Complete the Wizard Steps

#### MVP Mode Steps:
1. **Basic Info**: Project name, environment, owner email
2. **Region & Model**: AWS region, Claude AI model
3. **Connect**: Amazon Connect instance configuration
4. **Security**: FedRAMP compliance, WAF
5. **Users**: Agent and supervisor emails (MVP has simplified user config)
6. **Review**: Download deployment package

#### Comprehensive Mode Additional Steps:
7. **Users**: Full agent/supervisor configuration with multiple accounts
8. **Lex Bot**: Voice settings, locale, NLU threshold
9. **Lambda**: Runtime, timeout, memory configuration
10. **DynamoDB**: Billing mode, encryption, backup
11. **VPC**: Network configuration, CIDR, subnets
12. **Monitoring**: CloudWatch logs, SNS alerts
13. **Backup**: AWS Backup configuration

### 4. Download Deployment Package

On the Review step, click **"Download Deployment Package"** to generate a ZIP file containing:

- `terraform.tfvars` - All infrastructure variables (50+ parameters)
- `agent-configuration-bedrock.json` - Bedrock agent configuration
- `agent-configuration-connect.json` - Connect agent configuration
- `lex-bot-definition.json` - Lex bot specification
- `README.md` - Deployment instructions

## Deploying the Infrastructure

After downloading the package:

1. **Extract the ZIP file**:
   ```bash
   unzip census-ccaas-prod.zip -d census-deployment
   cd census-deployment
   ```

2. **Copy Terraform modules**:
   ```bash
   cp -r ../packages/ccaas-template/terraform .
   ```

3. **Move tfvars to terraform directory**:
   ```bash
   mv terraform.tfvars terraform/
   cd terraform
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Review the plan**:
   ```bash
   terraform plan -var-file=terraform.tfvars
   ```

6. **Deploy**:
   ```bash
   terraform apply -var-file=terraform.tfvars
   ```

7. **Save outputs**:
   ```bash
   terraform output > ../deployment-outputs.txt
   ```

## Configuration Details

### AWS Regions Supported

**Americas**:
- us-east-1 (N. Virginia) - Recommended
- us-west-2 (Oregon)
- us-east-2 (Ohio)
- us-gov-west-1 (GovCloud West)
- us-gov-east-1 (GovCloud East)
- ca-central-1 (Canada)
- sa-east-1 (São Paulo)

**Europe**:
- eu-west-1 (Ireland)
- eu-central-1 (Frankfurt)

**Asia Pacific**:
- ap-northeast-1 (Tokyo)
- ap-southeast-1 (Singapore)
- ap-southeast-2 (Sydney)

### Claude AI Models

The wizard displays only models available in your selected region:

- **Claude 3.5 Sonnet v2** (Recommended) - Best performance
- **Claude 3.5 Haiku** - Fast and cost-effective
- **Claude 3 Opus** - Premium tier
- **Claude 3 Sonnet** - Standard tier

### FedRAMP Compliance Mode

When enabled, includes:
- KMS encryption for all data at rest
- VPC with private subnets
- CloudTrail audit logging (90-day retention)
- AWS Config compliance rules
- AWS Backup automated backups
- IAM least-privilege policies
- Enhanced monitoring and alerting

### WAF Protection

AWS WAF with managed rule sets:
- Core Rule Set (CRS)
- Known Bad Inputs
- Amazon IP Reputation List
- Rate limiting (2000 requests per 5 minutes)

## API Endpoints

The API server provides these endpoints:

### Generate Package
```
POST /api/package/generate
Content-Type: application/json

{
  "mode": "comprehensive",
  "basic": { ... },
  "aiModel": { ... },
  "connect": { ... },
  ...
}
```

Returns ZIP file stream with all deployment files.

### Check Prerequisites
```
GET /api/prerequisites/check
```

Returns terraform and AWS CLI availability status.

## Troubleshooting

### Install Script Fails

**Problem**: `./install.sh` shows "permission denied"

**Solution**:
```bash
chmod +x install.sh
./install.sh
```

### Node.js Version Too Old

**Problem**: "Node.js version must be 18 or higher"

**Solution**: Update Node.js from https://nodejs.org/ or use nvm:
```bash
nvm install 18
nvm use 18
```

### Port Already in Use

**Problem**: "Port 5173 is already in use"

**Solution**: Kill the process or use a different port:
```bash
# Find process
lsof -ti:5173

# Kill it
kill -9 <PID>

# Or change port in packages/ui/vite.config.ts
```

### TypeScript Errors

**Problem**: Type errors in the UI

**Solution**: Ensure all dependencies are installed:
```bash
npm run install:all
```

### API Not Responding

**Problem**: UI shows "Failed to generate package"

**Solution**:
1. Check API is running: `curl http://localhost:3001/api/health`
2. Check API logs in the terminal
3. Restart API: `npm run dev:api`

### Terraform Apply Fails

**Problem**: Deployment fails with AWS errors

**Solution**:
1. Verify AWS credentials: `aws sts get-caller-identity`
2. Check service quotas in your AWS account
3. Review terraform plan before applying
4. Check the generated README.md in the package

## Development Workflow

### Adding a New Wizard Step

1. Create the component in `packages/ui/src/pages/wizard/NewStep.tsx`
2. Import `WizardStepProps` from `@/types/wizard`
3. Add the step config to `ConfigWizard.tsx`
4. Update the type definitions in `packages/ui/src/types/wizard.ts`
5. Update validation schema in `packages/ui/src/services/validation.ts`

### Modifying Terraform Variables

1. Update `packages/ui/src/types/terraform.ts`
2. Update the Zod schema in `packages/ui/src/services/validation.ts`
3. Update `packages/api/src/services/generator.ts`
4. Update the Terraform variables in `packages/ccaas-template/terraform/variables.tf`

### Testing the Package Generation

```bash
# Start the dev servers
npm run dev

# In the UI, complete the wizard and download package

# Extract and test
unzip /path/to/downloaded/package.zip
cd extracted-package
terraform init
terraform plan
```

## Production Build

### Build All Packages

```bash
npm run build
```

This creates:
- UI production build in `packages/ui/dist`
- API production build in `packages/api/dist`

### Run Production UI

```bash
cd packages/ui
npm run preview
```

### Run Production API

```bash
cd packages/api
npm start
```

## Support

For issues or questions:

1. Check this documentation
2. Review error messages in browser console and terminal
3. Check [IMPLEMENTATION.md](./IMPLEMENTATION.md) for technical details
4. Review the generated package README.md for deployment guidance

## Security Considerations

- Never commit AWS credentials to version control
- Use IAM roles with least-privilege permissions
- Enable FedRAMP compliance for government workloads
- Review generated terraform.tfvars before deployment
- Use GovCloud regions for sensitive government data
- Enable CloudTrail logging for audit compliance

## License

MIT
