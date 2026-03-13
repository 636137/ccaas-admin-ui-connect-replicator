/**
 * Bedrock Claude Model Configuration
 * Updated: February 2026
 * 
 * This file contains all available Claude models in Amazon Bedrock
 * with their regional availability and capabilities.
 */

export type ModelTier = 'economy' | 'standard' | 'premium' | 'flagship';
export type InputModality = 'text' | 'image';

export interface BedrockModel {
  id: string;
  name: string;
  version: string;
  tier: ModelTier;
  description: string;
  regions: string[];
  govCloudRegions: string[];
  inputModalities: InputModality[];
  outputModalities: string[];
  streaming: boolean;
  recommended?: boolean;
  inferenceParametersLink?: string;
}

// All AWS regions for reference
export const ALL_COMMERCIAL_REGIONS = [
  'af-south-1', 'ap-east-2', 'ap-northeast-1', 'ap-northeast-2', 'ap-northeast-3',
  'ap-south-1', 'ap-south-2', 'ap-southeast-1', 'ap-southeast-2', 'ap-southeast-3',
  'ap-southeast-4', 'ap-southeast-5', 'ap-southeast-7', 'ca-central-1', 'ca-west-1',
  'eu-central-1', 'eu-central-2', 'eu-north-1', 'eu-south-1', 'eu-south-2',
  'eu-west-1', 'eu-west-2', 'eu-west-3', 'il-central-1', 'me-central-1', 'me-south-1',
  'mx-central-1', 'sa-east-1', 'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'
] as const;

export const GOV_CLOUD_REGIONS = ['us-gov-west-1', 'us-gov-east-1'] as const;

// Wide regional availability (31+ regions)
const WIDE_REGIONAL_SUPPORT = [
  'af-south-1', 'ap-east-2', 'ap-northeast-1', 'ap-northeast-2', 'ap-northeast-3',
  'ap-south-1', 'ap-south-2', 'ap-southeast-1', 'ap-southeast-2', 'ap-southeast-3',
  'ap-southeast-4', 'ap-southeast-5', 'ap-southeast-7', 'ca-central-1', 'ca-west-1',
  'eu-central-1', 'eu-central-2', 'eu-north-1', 'eu-south-1', 'eu-south-2',
  'eu-west-1', 'eu-west-2', 'eu-west-3', 'il-central-1', 'me-central-1', 'me-south-1',
  'mx-central-1', 'sa-east-1', 'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'
];

/**
 * All available Claude models in Amazon Bedrock
 * Sorted by tier (economy → flagship) then by version (newest first)
 */
export const CLAUDE_MODELS: BedrockModel[] = [
  // Economy Tier - Haiku Models
  {
    id: 'anthropic.claude-3-haiku-20240307-v1:0',
    name: 'Claude 3 Haiku',
    version: '3.0',
    tier: 'economy',
    description: 'Fast, compact model for quick responses. Best for high-volume, simple tasks.',
    regions: [
      'ap-northeast-1', 'ap-northeast-2', 'ap-south-1', 'ap-southeast-1', 'ap-southeast-2',
      'ca-central-1', 'eu-central-1', 'eu-central-2', 'eu-west-1', 'eu-west-2', 'eu-west-3',
      'sa-east-1', 'us-east-1', 'us-west-2'
    ],
    govCloudRegions: ['us-gov-west-1'],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },
  {
    id: 'anthropic.claude-3-5-haiku-20241022-v1:0',
    name: 'Claude 3.5 Haiku',
    version: '3.5',
    tier: 'economy',
    description: 'Improved speed and accuracy over Claude 3 Haiku. Better reasoning.',
    regions: ['us-west-2', 'us-east-1', 'us-east-2'],
    govCloudRegions: [],
    inputModalities: ['text'],
    outputModalities: ['text'],
    streaming: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },
  {
    id: 'anthropic.claude-haiku-4-5-20251001-v1:0',
    name: 'Claude Haiku 4.5',
    version: '4.5',
    tier: 'economy',
    description: 'Latest Haiku with enhanced reasoning and vision. Best economy choice.',
    regions: WIDE_REGIONAL_SUPPORT,
    govCloudRegions: [],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },

  // Standard Tier - Sonnet Models
  {
    id: 'anthropic.claude-sonnet-4-20250514-v1:0',
    name: 'Claude Sonnet 4',
    version: '4.0',
    tier: 'standard',
    description: 'Balanced performance and cost. Strong reasoning and coding.',
    regions: [
      'ap-east-2', 'ap-northeast-1', 'ap-northeast-2', 'ap-northeast-3', 'ap-south-1',
      'ap-south-2', 'ap-southeast-1', 'ap-southeast-2', 'ap-southeast-3', 'ap-southeast-4',
      'ap-southeast-5', 'ap-southeast-7', 'eu-central-1', 'eu-north-1', 'eu-south-1',
      'eu-south-2', 'eu-west-1', 'eu-west-3', 'il-central-1', 'me-central-1',
      'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'
    ],
    govCloudRegions: [],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },
  {
    id: 'anthropic.claude-sonnet-4-5-20250929-v1:0',
    name: 'Claude Sonnet 4.5',
    version: '4.5',
    tier: 'standard',
    description: 'RECOMMENDED: Best balance of capability, speed, and cost for AI agents. Wide regional and GovCloud support.',
    regions: WIDE_REGIONAL_SUPPORT,
    govCloudRegions: ['us-gov-west-1', 'us-gov-east-1'],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true,
    recommended: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },
  {
    id: 'anthropic.claude-sonnet-4-6',
    name: 'Claude Sonnet 4.6',
    version: '4.6',
    tier: 'standard',
    description: 'Latest Sonnet with improved accuracy and speed. Enhanced tool use.',
    regions: WIDE_REGIONAL_SUPPORT,
    govCloudRegions: [],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true
  },

  // Premium/Flagship Tier - Opus Models
  {
    id: 'anthropic.claude-opus-4-1-20250805-v1:0',
    name: 'Claude Opus 4.1',
    version: '4.1',
    tier: 'premium',
    description: 'High capability model for complex reasoning and analysis.',
    regions: ['us-east-1', 'us-east-2', 'us-west-2'],
    govCloudRegions: [],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },
  {
    id: 'anthropic.claude-opus-4-5-20251101-v1:0',
    name: 'Claude Opus 4.5',
    version: '4.5',
    tier: 'flagship',
    description: 'Most capable model. Best for complex multi-step reasoning and research.',
    regions: WIDE_REGIONAL_SUPPORT,
    govCloudRegions: [],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true,
    inferenceParametersLink: 'https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-anthropic-claude-messages.html'
  },
  {
    id: 'anthropic.claude-opus-4-6-v1',
    name: 'Claude Opus 4.6',
    version: '4.6',
    tier: 'flagship',
    description: 'Latest flagship model. Maximum capability for most demanding tasks.',
    regions: WIDE_REGIONAL_SUPPORT,
    govCloudRegions: [],
    inputModalities: ['text', 'image'],
    outputModalities: ['text'],
    streaming: true
  }
];

/**
 * Get the default recommended model
 */
export const DEFAULT_MODEL = CLAUDE_MODELS.find(m => m.recommended) || CLAUDE_MODELS[4];

/**
 * Get models available in a specific region
 */
export function getModelsForRegion(region: string): BedrockModel[] {
  const isGovCloud = region.startsWith('us-gov-');
  
  return CLAUDE_MODELS.filter(model => {
    if (isGovCloud) {
      return model.govCloudRegions.includes(region);
    }
    return model.regions.includes(region);
  });
}

/**
 * Get model by ID
 */
export function getModelById(modelId: string): BedrockModel | undefined {
  return CLAUDE_MODELS.find(m => m.id === modelId);
}

/**
 * Get models filtered by tier
 */
export function getModelsByTier(tier: ModelTier): BedrockModel[] {
  return CLAUDE_MODELS.filter(m => m.tier === tier);
}

/**
 * Check if a model supports a specific region
 */
export function isModelAvailableInRegion(modelId: string, region: string): boolean {
  const model = getModelById(modelId);
  if (!model) return false;
  
  const isGovCloud = region.startsWith('us-gov-');
  if (isGovCloud) {
    return model.govCloudRegions.includes(region);
  }
  return model.regions.includes(region);
}

/**
 * Get tier display info
 */
export const TIER_INFO: Record<ModelTier, { label: string; color: string; description: string }> = {
  economy: {
    label: 'Economy',
    color: 'green',
    description: 'Fast, cost-effective. Best for simple tasks.'
  },
  standard: {
    label: 'Standard',
    color: 'blue',
    description: 'Balanced performance. Best for most use cases.'
  },
  premium: {
    label: 'Premium',
    color: 'purple',
    description: 'High capability. Best for complex tasks.'
  },
  flagship: {
    label: 'Flagship',
    color: 'amber',
    description: 'Maximum capability. Best for demanding tasks.'
  }
};

/**
 * All model IDs for Terraform validation
 */
export const ALL_MODEL_IDS = CLAUDE_MODELS.map(m => m.id);
