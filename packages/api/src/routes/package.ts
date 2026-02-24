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

    // Flatten config for generator functions
    const flatConfig = {
      mode: config.mode,
      projectName: config.basic.projectName,
      environment: config.basic.environment,
      owner: config.basic.owner,
      awsRegion: config.basic.awsRegion,
      bedrockModelId: config.aiModel.bedrockModelId,
      createConnectInstance: config.connect.createConnectInstance,
      connectInstanceAlias: config.connect.connectInstanceAlias,
      agentEmails: config.users.agentEmails,
      supervisorEmail: config.users.supervisorEmail,
      lexVoiceId: config.lex.voiceId,
      lexLocale: config.lex.locale,
      lexNluConfidenceThreshold: config.lex.nluConfidenceThreshold,
      lambdaRuntime: config.lambda.runtime,
      lambdaTimeout: config.lambda.timeout,
      lambdaMemorySize: config.lambda.memorySize,
      dynamodbBillingMode: config.dynamodb.billingMode,
      dynamodbEnableEncryption: config.dynamodb.enableEncryption,
      dynamodbEnablePointInTimeRecovery: config.dynamodb.enablePointInTimeRecovery,
      vpcUseExisting: config.vpc.useExistingVpc,
      vpcCidr: config.vpc.vpcCidr,
      vpcId: config.vpc.vpcId,
      vpcSubnetIds: config.vpc.subnetIds,
      vpcSecurityGroupIds: config.vpc.securityGroupIds,
      vpcAvailabilityZones: config.vpc.availabilityZones,
      vpcEnableNatGateway: config.vpc.enableNatGateway,
      vpcSingleNatGateway: config.vpc.singleNatGateway,
      vpcEnableVpcEndpoints: config.vpc.enableVpcEndpoints,
      enableFedrampCompliance: config.security.enableFedRampCompliance,
      enableWaf: config.security.enableWaf,
      enableKmsEncryption: config.security.enableKmsEncryption,
      kmsKeyArn: config.security.kmsKeyArn,
      securityContactEmail: config.security.securityContactEmail,
      auditLogRetentionDays: config.security.auditLogRetentionDays,
      deployInVpc: config.security.deployInVpc,
      kmsKeyAdministrators: config.security.kmsKeyAdministrators,
      securityNotificationArns: config.security.securityNotificationArns,
      wafRateLimit: config.waf.rateLimit,
      wafEnableGeoRestriction: config.waf.enableGeoRestriction,
      wafAllowedCountries: config.waf.allowedCountries,
      wafIpWhitelist: config.waf.ipWhitelist,
      alarmSnsTopicArn: config.monitoring.alarmSnsTopicArn,
      enableDetailedMonitoring: config.monitoring.enableDetailedMonitoring,
      logRetentionDays: config.monitoring.logRetentionDays,
      enableBackup: config.backup.enableBackup,
      enableCrossRegionBackup: config.backup.enableCrossRegionBackup,
      drVaultArn: config.backup.drVaultArn,
      backupAdminRoleArns: config.backup.backupAdminRoleArns,
      enableValidationModule: config.validation.enableValidationModule,
      validationNotificationEmail: config.validation.validationNotificationEmail,
      aiAccuracyThreshold: config.validation.aiAccuracyThreshold,
      aiLatencyThreshold: config.validation.aiLatencyThreshold,
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
