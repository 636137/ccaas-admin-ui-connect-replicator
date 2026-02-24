import { type WizardData } from '../ConfigWizard'
import { 
  CLAUDE_MODELS, 
  TIER_INFO, 
  getModelsForRegion,
  DEFAULT_MODEL 
} from '@/config/bedrock-models'
import { Check, AlertTriangle } from 'lucide-react'

interface StepProps {
  data: WizardData
  updateData: (updates: Partial<WizardData>) => void
}

const AWS_REGIONS = [
  { value: 'us-east-1', label: 'US East (N. Virginia)', recommended: true },
  { value: 'us-west-2', label: 'US West (Oregon)' },
  { value: 'us-east-2', label: 'US East (Ohio)' },
  { value: 'us-gov-west-1', label: 'AWS GovCloud (US-West)', govCloud: true },
  { value: 'us-gov-east-1', label: 'AWS GovCloud (US-East)', govCloud: true },
  { value: 'eu-west-1', label: 'Europe (Ireland)' },
  { value: 'eu-central-1', label: 'Europe (Frankfurt)' },
  { value: 'ap-northeast-1', label: 'Asia Pacific (Tokyo)' },
  { value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)' },
  { value: 'ap-southeast-2', label: 'Asia Pacific (Sydney)' },
  { value: 'ca-central-1', label: 'Canada (Central)' },
  { value: 'sa-east-1', label: 'South America (São Paulo)' },
]

export function RegionModelStep({ data, updateData }: StepProps) {
  const availableModels = getModelsForRegion(data.awsRegion)
  const isModelAvailable = availableModels.some(m => m.id === data.bedrockModelId)
  
  // Reset model if not available in selected region
  const handleRegionChange = (region: string) => {
    updateData({ awsRegion: region })
    const modelsInRegion = getModelsForRegion(region)
    if (!modelsInRegion.some(m => m.id === data.bedrockModelId)) {
      // Select recommended model or first available
      const recommended = modelsInRegion.find(m => m.recommended)
      updateData({ bedrockModelId: recommended?.id || modelsInRegion[0]?.id || DEFAULT_MODEL.id })
    }
  }

  const tierColors: Record<string, string> = {
    economy: 'border-green-300 bg-green-50',
    standard: 'border-blue-300 bg-blue-50',
    premium: 'border-purple-300 bg-purple-50',
    flagship: 'border-amber-300 bg-amber-50',
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Region & AI Model</h2>
        <p className="text-sm text-gray-500">Select your deployment region and Claude AI model.</p>
      </div>

      {/* Region Selection */}
      <div>
        <label htmlFor="region" className="block text-sm font-medium text-gray-700 mb-1">
          AWS Region *
        </label>
        <select
          id="region"
          value={data.awsRegion}
          onChange={(e) => handleRegionChange(e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <optgroup label="Americas">
            {AWS_REGIONS.filter(r => r.value.startsWith('us-') || r.value.startsWith('ca-') || r.value.startsWith('sa-'))
              .map(r => (
                <option key={r.value} value={r.value}>
                  {r.label} {r.recommended ? '(Recommended)' : ''} {r.govCloud ? '🔒' : ''}
                </option>
              ))}
          </optgroup>
          <optgroup label="Europe">
            {AWS_REGIONS.filter(r => r.value.startsWith('eu-'))
              .map(r => (
                <option key={r.value} value={r.value}>{r.label}</option>
              ))}
          </optgroup>
          <optgroup label="Asia Pacific">
            {AWS_REGIONS.filter(r => r.value.startsWith('ap-'))
              .map(r => (
                <option key={r.value} value={r.value}>{r.label}</option>
              ))}
          </optgroup>
        </select>
        {data.awsRegion.startsWith('us-gov-') && (
          <p className="mt-1 text-xs text-amber-600 flex items-center gap-1">
            <AlertTriangle className="h-3 w-3" /> GovCloud region - limited model availability
          </p>
        )}
      </div>

      {/* Model Selection */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-3">
          Claude AI Model * ({availableModels.length} available in {data.awsRegion})
        </label>
        
        {!isModelAvailable && data.bedrockModelId && (
          <div className="mb-3 p-3 rounded-lg bg-amber-50 border border-amber-200 text-sm text-amber-800">
            Selected model is not available in this region. Please choose another.
          </div>
        )}

        <div className="space-y-3">
          {availableModels.map((model) => {
            const tierInfo = TIER_INFO[model.tier]
            const isSelected = data.bedrockModelId === model.id
            
            return (
              <button
                key={model.id}
                type="button"
                onClick={() => updateData({ bedrockModelId: model.id })}
                className={`w-full text-left rounded-lg border-2 p-4 transition-all ${
                  isSelected 
                    ? 'border-blue-500 ring-2 ring-blue-200' 
                    : `${tierColors[model.tier]} hover:border-gray-400`
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <h4 className="font-medium text-gray-900">{model.name}</h4>
                      <span className={`text-xs px-2 py-0.5 rounded-full ${
                        model.tier === 'economy' ? 'bg-green-200 text-green-800' :
                        model.tier === 'standard' ? 'bg-blue-200 text-blue-800' :
                        model.tier === 'premium' ? 'bg-purple-200 text-purple-800' :
                        'bg-amber-200 text-amber-800'
                      }`}>
                        {tierInfo.label}
                      </span>
                      {model.recommended && (
                        <span className="text-xs px-2 py-0.5 rounded-full bg-blue-600 text-white">
                          Recommended
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-600 mt-1">{model.description}</p>
                    <code className="text-xs text-gray-500 mt-2 block">{model.id}</code>
                  </div>
                  {isSelected && (
                    <div className="flex-shrink-0 ml-4">
                      <div className="rounded-full bg-blue-500 p-1">
                        <Check className="h-4 w-4 text-white" />
                      </div>
                    </div>
                  )}
                </div>
              </button>
            )
          })}
        </div>

        {availableModels.length === 0 && (
          <p className="text-sm text-red-600">No Claude models available in this region.</p>
        )}
      </div>
    </div>
  )
}
