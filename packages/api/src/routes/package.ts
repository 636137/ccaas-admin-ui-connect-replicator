import { Router, Request, Response } from 'express'
import archiver from 'archiver'
import { generateTerraformConfig } from '../services/generator'
import {
  generateAgentConfigBedrock,
  generateAgentConfigConnect,
  generateLexBotDefinition,
  generateReadme
} from '../services/template.service'

const router = Router()

interface WizardConfig {
  mode: string
  basic: {
    projectName: string
    environment: string
    owner: string
    awsRegion: string
  }
  aiModel: {
    bedrockModelId: string
  }
  connect: {
    createConnectInstance: boolean
    connectInstanceAlias: string
  }
  users: {
    agentEmails: string[]
    supervisorEmail: string
  }
  lex: {
    voiceId: string
    locale: string
    nluConfidenceThreshold: number
  }
  lambda: {
    runtime: string
    timeout: number
    memorySize: number
  }
  dynamodb: {
    billingMode: string
    enableEncryption: boolean
    enablePointInTimeRecovery: boolean
  }
  vpc: {
    useExistingVpc: boolean
    vpcCidr?: string
    vpcId?: string
    subnetIds?: string[]
    securityGroupIds?: string[]
    availabilityZones?: string[]
    enableNatGateway?: boolean
    singleNatGateway?: boolean
    enableVpcEndpoints: boolean
  }
  security: {
    enableFedRampCompliance: boolean
    enableWaf: boolean
    enableKmsEncryption: boolean
    kmsKeyArn?: string
    securityContactEmail?: string
    auditLogRetentionDays: number
    deployInVpc: boolean
    kmsKeyAdministrators?: string[]
    securityNotificationArns?: string[]
  }
  waf: {
    rateLimit: number
    enableGeoRestriction: boolean
    allowedCountries: string[]
    ipWhitelist?: string[]
  }
  monitoring: {
    alarmSnsTopicArn?: string
    enableDetailedMonitoring: boolean
    logRetentionDays: number
  }
  backup: {
    enableBackup: boolean
    enableCrossRegionBackup: boolean
    drVaultArn?: string
    backupAdminRoleArns?: string[]
  }
  validation: {
    enableValidationModule: boolean
    validationNotificationEmail?: string
    aiAccuracyThreshold: number
    aiLatencyThreshold: number
  }
}

/**
 * Generate deployment package (zip file)
 */
router.post('/generate', async (req: Request, res: Response) => {
  try {
    const { config } = req.body as { config: WizardConfig }

    if (!config || !config.basic || !config.aiModel) {
      return res.status(400).json({
        error: 'Invalid configuration',
        message: 'Missing required configuration sections'
      })
    }

    // Provide defaults for optional sections - merge with provided config to fill missing values
    const wafDefaults = { rateLimit: 2000, enableGeoRestriction: false, allowedCountries: ['US'] }
    const waf = { ...wafDefaults, ...(config.waf || {}) }
    
    const monitoringDefaults = { enableDetailedMonitoring: true, logRetentionDays: 90 }
    const monitoring = { ...monitoringDefaults, ...(config.monitoring || {}) }
    
    const backupDefaults = { enableBackup: true, enableCrossRegionBackup: false }
    const backup = { ...backupDefaults, ...(config.backup || {}) }
    
    const validationDefaults = { enableValidationModule: false, aiAccuracyThreshold: 85, aiLatencyThreshold: 5000 }
    const validation = { ...validationDefaults, ...(config.validation || {}) }
    
    const securityDefaults = { enableFedRampCompliance: false, enableWaf: false, enableKmsEncryption: true, auditLogRetentionDays: 365, deployInVpc: true }
    const security = { ...securityDefaults, ...(config.security || {}) }
    
    const vpcDefaults = { useExistingVpc: false, vpcCidr: '10.0.0.0/16', enableVpcEndpoints: true, availabilityZones: [`${config.basic.awsRegion}a`, `${config.basic.awsRegion}b`], enableNatGateway: true, singleNatGateway: false }
    const vpc = { ...vpcDefaults, ...(config.vpc || {}) }
    
    const connectDefaults = { createConnectInstance: true, connectInstanceAlias: '' }
    const connect = { ...connectDefaults, ...(config.connect || {}) }
    
    const usersDefaults = { agentEmails: [], supervisorEmail: '' }
    const users = { ...usersDefaults, ...(config.users || {}) }
    
    const lexDefaults = { voiceId: 'Joanna', locale: 'en_US', nluConfidenceThreshold: 0.4 }
    const lex = { ...lexDefaults, ...(config.lex || {}) }
    
    const lambdaDefaults = { runtime: 'nodejs18.x', timeout: 30, memorySize: 256 }
    const lambda = { ...lambdaDefaults, ...(config.lambda || {}) }
    
    const dynamodbDefaults = { billingMode: 'PAY_PER_REQUEST', enableEncryption: true, enablePointInTimeRecovery: true }
    const dynamodb = { ...dynamodbDefaults, ...(config.dynamodb || {}) }

    // Derive Connect alias from project name if not provided, sanitized for AWS requirements
    const sanitizedProjectName = config.basic.projectName.toLowerCase().replace(/[^a-z0-9-]/g, '-').replace(/^-|-$/g, '')
    const connectAlias = connect.connectInstanceAlias || sanitizedProjectName || 'ccaas-instance'
    
    // Filter out empty emails
    const filteredAgentEmails = users.agentEmails.filter((email: string) => email && email.trim() !== '')
    const filteredSupervisorEmail = users.supervisorEmail?.trim() || ''

    // Flatten config for generator functions
    const flatConfig = {
      mode: config.mode,
      projectName: config.basic.projectName,
      environment: config.basic.environment,
      owner: config.basic.owner,
      awsRegion: config.basic.awsRegion,
      bedrockModelId: config.aiModel.bedrockModelId,
      createConnectInstance: connect.createConnectInstance,
      connectInstanceAlias: connectAlias,
      agentEmails: filteredAgentEmails,
      supervisorEmail: filteredSupervisorEmail,
      lexVoiceId: lex.voiceId,
      lexLocale: lex.locale,
      lexNluConfidenceThreshold: lex.nluConfidenceThreshold,
      lambdaRuntime: lambda.runtime,
      lambdaTimeout: lambda.timeout,
      lambdaMemorySize: lambda.memorySize,
      dynamodbBillingMode: dynamodb.billingMode,
      dynamodbEnableEncryption: dynamodb.enableEncryption,
      dynamodbEnablePointInTimeRecovery: dynamodb.enablePointInTimeRecovery,
      vpcUseExisting: vpc.useExistingVpc,
      vpcCidr: vpc.vpcCidr || '10.0.0.0/16',
      vpcId: vpc.vpcId,
      vpcSubnetIds: vpc.subnetIds,
      vpcSecurityGroupIds: vpc.securityGroupIds,
      vpcAvailabilityZones: vpc.availabilityZones?.length ? vpc.availabilityZones : [`${config.basic.awsRegion}a`, `${config.basic.awsRegion}b`],
      vpcEnableNatGateway: vpc.enableNatGateway,
      vpcSingleNatGateway: vpc.singleNatGateway,
      vpcEnableVpcEndpoints: vpc.enableVpcEndpoints,
      enableFedrampCompliance: security.enableFedRampCompliance,
      enableWaf: security.enableWaf,
      enableKmsEncryption: security.enableKmsEncryption,
      kmsKeyArn: security.kmsKeyArn,
      securityContactEmail: security.securityContactEmail && security.securityContactEmail !== 'undefined' ? security.securityContactEmail : '',
      auditLogRetentionDays: security.auditLogRetentionDays,
      deployInVpc: security.deployInVpc,
      kmsKeyAdministrators: security.kmsKeyAdministrators,
      securityNotificationArns: security.securityNotificationArns,
      wafRateLimit: waf.rateLimit,
      wafEnableGeoRestriction: waf.enableGeoRestriction,
      wafAllowedCountries: waf.allowedCountries,
      wafIpWhitelist: waf.ipWhitelist,
      alarmSnsTopicArn: monitoring.alarmSnsTopicArn,
      enableDetailedMonitoring: monitoring.enableDetailedMonitoring,
      logRetentionDays: monitoring.logRetentionDays,
      enableBackup: backup.enableBackup,
      enableCrossRegionBackup: backup.enableCrossRegionBackup,
      drVaultArn: backup.drVaultArn,
      backupAdminRoleArns: backup.backupAdminRoleArns,
      enableValidationModule: validation.enableValidationModule,
      validationNotificationEmail: validation.validationNotificationEmail,
      aiAccuracyThreshold: validation.aiAccuracyThreshold,
      aiLatencyThreshold: validation.aiLatencyThreshold,
    }

    // Generate all files
    const tfvars = generateTerraformConfig(flatConfig)
    const bedrockConfig = generateAgentConfigBedrock(flatConfig)
    const connectConfig = generateAgentConfigConnect(flatConfig)
    const lexConfig = generateLexBotDefinition(flatConfig)
    const readme = generateReadme(flatConfig)

    // Create zip archive
    const archive = archiver('zip', {
      zlib: { level: 9 } // Maximum compression
    })

    // Set response headers
    const filename = `${config.basic.projectName}-${config.basic.environment}-deployment.zip`
    res.setHeader('Content-Type', 'application/zip')
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`)

    // Pipe archive to response
    archive.pipe(res)

    // Add files to archive
    archive.append(tfvars, { name: 'terraform.tfvars' })
    archive.append(bedrockConfig, { name: 'agent-configuration-bedrock.json' })
    archive.append(connectConfig, { name: 'agent-configuration-connect.json' })
    archive.append(lexConfig, { name: 'lex-bot-definition.json' })
    archive.append(readme, { name: 'README.md' })

    // Finalize archive
    await archive.finalize()

  } catch (error) {
    console.error('Error generating package:', error)
    res.status(500).json({
      error: 'Generation failed',
      message: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

export default router
