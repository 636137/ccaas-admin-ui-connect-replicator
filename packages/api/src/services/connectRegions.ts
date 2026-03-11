export type AwsRegion = {
  code: string
  name: string
  partition?: 'aws' | 'aws-us-gov'
}

// Intentionally kept as a simple curated list (no AWS API exists to list regions).
// You can add/remove regions as needed for your org.
export const ALL_REGIONS: AwsRegion[] = [
  { code: 'us-east-1', name: 'US East (N. Virginia)' },
  { code: 'us-east-2', name: 'US East (Ohio)' },
  { code: 'us-west-1', name: 'US West (N. California)' },
  { code: 'us-west-2', name: 'US West (Oregon)' },

  { code: 'af-south-1', name: 'Africa (Cape Town)' },

  { code: 'ap-east-1', name: 'Asia Pacific (Hong Kong)' },
  { code: 'ap-south-1', name: 'Asia Pacific (Mumbai)' },
  { code: 'ap-south-2', name: 'Asia Pacific (Hyderabad)' },
  { code: 'ap-southeast-1', name: 'Asia Pacific (Singapore)' },
  { code: 'ap-southeast-2', name: 'Asia Pacific (Sydney)' },
  { code: 'ap-southeast-3', name: 'Asia Pacific (Jakarta)' },
  { code: 'ap-southeast-4', name: 'Asia Pacific (Melbourne)' },
  { code: 'ap-northeast-1', name: 'Asia Pacific (Tokyo)' },
  { code: 'ap-northeast-2', name: 'Asia Pacific (Seoul)' },
  { code: 'ap-northeast-3', name: 'Asia Pacific (Osaka)' },

  { code: 'ca-central-1', name: 'Canada (Central)' },

  { code: 'eu-central-1', name: 'Europe (Frankfurt)' },
  { code: 'eu-central-2', name: 'Europe (Zurich)' },
  { code: 'eu-west-1', name: 'Europe (Ireland)' },
  { code: 'eu-west-2', name: 'Europe (London)' },
  { code: 'eu-west-3', name: 'Europe (Paris)' },
  { code: 'eu-north-1', name: 'Europe (Stockholm)' },
  { code: 'eu-south-1', name: 'Europe (Milan)' },
  { code: 'eu-south-2', name: 'Europe (Spain)' },

  { code: 'il-central-1', name: 'Israel (Tel Aviv)' },

  { code: 'me-south-1', name: 'Middle East (Bahrain)' },
  { code: 'me-central-1', name: 'Middle East (UAE)' },

  { code: 'sa-east-1', name: 'South America (São Paulo)' },

  // GovCloud
  { code: 'us-gov-west-1', name: 'AWS GovCloud (US-West)', partition: 'aws-us-gov' },
  { code: 'us-gov-east-1', name: 'AWS GovCloud (US-East)', partition: 'aws-us-gov' },
]

export const GLOBAL_RESILIENCY_REGION_TARGETS: Record<string, string[]> = {
  // Per AWS Connect Global Resiliency docs.
  'us-east-1': ['us-west-2'],
  'us-west-2': ['us-east-1'],
  'eu-central-1': ['eu-west-2'],
  'eu-west-2': ['eu-central-1'],
  'ap-northeast-1': ['ap-northeast-3'],
}
