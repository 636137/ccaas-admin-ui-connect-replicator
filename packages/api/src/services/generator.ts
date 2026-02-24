interface ConfigInput {
  projectName: string
  environment: string
  owner: string
  awsRegion: string
  bedrockModelId: string
  createConnectInstance: boolean
  connectInstanceAlias?: string
  enableFedrampCompliance: boolean
  enableWaf: boolean
  mode: string
}

export function generateTerraformConfig(input: ConfigInput): string {
  const {
    projectName,
    environment,
    owner,
    awsRegion,
    bedrockModelId,
    createConnectInstance,
    connectInstanceAlias,
    enableFedrampCompliance,
    enableWaf,
    mode,
  } = input

  return `# Government CCaaS in a Box - Terraform Configuration
# Generated: ${new Date().toISOString()}
# Mode: ${mode.toUpperCase()}

# ============================================
# Basic Configuration
# ============================================
aws_region   = "${awsRegion}"
environment  = "${environment}"
project_name = "${projectName}"
owner        = "${owner}"

# ============================================
# Amazon Connect
# ============================================
create_connect_instance = ${createConnectInstance}
${connectInstanceAlias ? `connect_instance_alias  = "${connectInstanceAlias}"` : '# connect_instance_alias  = "your-instance-alias"'}

# ============================================
# AI / Bedrock Configuration
# ============================================
bedrock_model_id = "${bedrockModelId}"

# ============================================
# Security & Compliance
# ============================================
enable_fedramp_compliance = ${enableFedrampCompliance}
enable_waf                = ${enableWaf}
${enableFedrampCompliance ? `
# FedRAMP compliance enables these additional features:
# - KMS encryption for data at rest
# - VPC with private subnets
# - CloudTrail audit logging
# - AWS Config compliance rules
# - Automated backups` : ''}
`
}

export function generateAgentConfig(input: ConfigInput): object {
  return {
    agentName: `${input.projectName}-census-agent`,
    foundationModel: input.bedrockModelId,
    idleSessionTTLInSeconds: 600,
    description: 'AI Census Agent for Government CCaaS',
  }
}
