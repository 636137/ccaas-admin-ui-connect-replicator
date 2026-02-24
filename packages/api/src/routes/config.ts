import { Router } from 'express'
import { generateTerraformConfig } from '../services/generator.js'

export const configRoutes = Router()

// Generate terraform.tfvars
configRoutes.post('/terraform', (req, res) => {
  try {
    const config = generateTerraformConfig(req.body)
    res.json({ success: true, config })
  } catch (error) {
    res.status(400).json({ success: false, error: (error as Error).message })
  }
})

// Get available Claude models
configRoutes.get('/models', (_, res) => {
  res.json({
    models: [
      { id: 'anthropic.claude-3-haiku-20240307-v1:0', name: 'Claude 3 Haiku', tier: 'economy' },
      { id: 'anthropic.claude-3-5-haiku-20241022-v1:0', name: 'Claude 3.5 Haiku', tier: 'economy' },
      { id: 'anthropic.claude-haiku-4-5-20251001-v1:0', name: 'Claude Haiku 4.5', tier: 'economy' },
      { id: 'anthropic.claude-sonnet-4-20250514-v1:0', name: 'Claude Sonnet 4', tier: 'standard' },
      { id: 'anthropic.claude-sonnet-4-5-20250929-v1:0', name: 'Claude Sonnet 4.5', tier: 'standard', recommended: true },
      { id: 'anthropic.claude-sonnet-4-6', name: 'Claude Sonnet 4.6', tier: 'standard' },
      { id: 'anthropic.claude-opus-4-1-20250805-v1:0', name: 'Claude Opus 4.1', tier: 'premium' },
      { id: 'anthropic.claude-opus-4-5-20251101-v1:0', name: 'Claude Opus 4.5', tier: 'flagship' },
      { id: 'anthropic.claude-opus-4-6-v1', name: 'Claude Opus 4.6', tier: 'flagship' },
    ]
  })
})

// Validate configuration
configRoutes.post('/validate', (req, res) => {
  const errors: string[] = []
  const { projectName, environment, awsRegion, bedrockModelId } = req.body

  if (!projectName || projectName.length < 1) {
    errors.push('Project name is required')
  }
  if (!['dev', 'staging', 'prod'].includes(environment)) {
    errors.push('Invalid environment')
  }
  if (!awsRegion) {
    errors.push('AWS region is required')
  }
  if (!bedrockModelId) {
    errors.push('Bedrock model ID is required')
  }

  res.json({ valid: errors.length === 0, errors })
})
