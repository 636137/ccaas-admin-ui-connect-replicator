import { useState } from 'react'
import { 
  CLAUDE_MODELS, 
  TIER_INFO, 
  getModelsForRegion,
  type BedrockModel 
} from '@/config/bedrock-models'
import { Check, AlertCircle, ExternalLink } from 'lucide-react'

const COMMON_REGIONS = [
  { value: '', label: 'All Regions' },
  { value: 'us-east-1', label: 'US East (N. Virginia)' },
  { value: 'us-west-2', label: 'US West (Oregon)' },
  { value: 'us-gov-west-1', label: 'AWS GovCloud (US-West)' },
  { value: 'us-gov-east-1', label: 'AWS GovCloud (US-East)' },
  { value: 'eu-west-1', label: 'Europe (Ireland)' },
  { value: 'eu-central-1', label: 'Europe (Frankfurt)' },
  { value: 'ap-northeast-1', label: 'Asia Pacific (Tokyo)' },
  { value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)' },
]

export function ModelsPage() {
  const [selectedRegion, setSelectedRegion] = useState('')
  const [selectedTier, setSelectedTier] = useState<string>('')

  const filteredModels = CLAUDE_MODELS.filter(model => {
    if (selectedRegion) {
      const regionModels = getModelsForRegion(selectedRegion)
      if (!regionModels.find(m => m.id === model.id)) return false
    }
    if (selectedTier && model.tier !== selectedTier) return false
    return true
  })

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Claude AI Models</h1>
        <p className="mt-2 text-gray-600">
          Browse all available Claude models in Amazon Bedrock with regional availability.
        </p>
      </div>

      {/* Filters */}
      <div className="flex gap-4 mb-6">
        <select
          value={selectedRegion}
          onChange={(e) => setSelectedRegion(e.target.value)}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
        >
          {COMMON_REGIONS.map(r => (
            <option key={r.value} value={r.value}>{r.label}</option>
          ))}
        </select>

        <select
          value={selectedTier}
          onChange={(e) => setSelectedTier(e.target.value)}
          className="rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
        >
          <option value="">All Tiers</option>
          <option value="economy">Economy (Haiku)</option>
          <option value="standard">Standard (Sonnet)</option>
          <option value="premium">Premium (Opus)</option>
          <option value="flagship">Flagship (Opus)</option>
        </select>
      </div>

      {/* Models Grid */}
      <div className="grid gap-4">
        {filteredModels.map((model) => (
          <ModelCard key={model.id} model={model} />
        ))}
      </div>

      {filteredModels.length === 0 && (
        <div className="text-center py-12 text-gray-500">
          <AlertCircle className="h-12 w-12 mx-auto mb-4 text-gray-400" />
          <p>No models available for the selected filters.</p>
        </div>
      )}
    </div>
  )
}

function ModelCard({ model }: { model: BedrockModel }) {
  const tierInfo = TIER_INFO[model.tier]
  const tierColors: Record<string, string> = {
    economy: 'bg-green-100 text-green-800 border-green-200',
    standard: 'bg-blue-100 text-blue-800 border-blue-200',
    premium: 'bg-purple-100 text-purple-800 border-purple-200',
    flagship: 'bg-amber-100 text-amber-800 border-amber-200',
  }

  return (
    <div className={`rounded-xl border bg-white p-6 ${model.recommended ? 'border-blue-300 ring-2 ring-blue-100' : 'border-gray-200'}`}>
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-3 mb-2">
            <h3 className="text-lg font-semibold text-gray-900">{model.name}</h3>
            <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium border ${tierColors[model.tier]}`}>
              {tierInfo.label}
            </span>
            {model.recommended && (
              <span className="inline-flex items-center gap-1 rounded-full bg-blue-600 px-2.5 py-0.5 text-xs font-medium text-white">
                <Check className="h-3 w-3" /> Recommended
              </span>
            )}
          </div>
          
          <p className="text-sm text-gray-600 mb-4">{model.description}</p>
          
          <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-4 text-sm">
            <div>
              <p className="text-gray-500 text-xs uppercase tracking-wide mb-1">Model ID</p>
              <code className="text-xs bg-gray-100 px-2 py-1 rounded font-mono break-all">{model.id}</code>
            </div>
            <div>
              <p className="text-gray-500 text-xs uppercase tracking-wide mb-1">Input</p>
              <p className="text-gray-900">{model.inputModalities.join(', ')}</p>
            </div>
            <div>
              <p className="text-gray-500 text-xs uppercase tracking-wide mb-1">Regions</p>
              <p className="text-gray-900">{model.regions.length} commercial</p>
            </div>
            <div>
              <p className="text-gray-500 text-xs uppercase tracking-wide mb-1">GovCloud</p>
              <p className="text-gray-900">
                {model.govCloudRegions.length > 0 
                  ? model.govCloudRegions.join(', ') 
                  : 'Not available'}
              </p>
            </div>
          </div>
        </div>

        {model.inferenceParametersLink && (
          <a
            href={model.inferenceParametersLink}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1 text-sm text-blue-600 hover:text-blue-800"
          >
            Docs <ExternalLink className="h-4 w-4" />
          </a>
        )}
      </div>
    </div>
  )
}
