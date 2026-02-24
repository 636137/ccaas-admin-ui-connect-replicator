import { type WizardStepProps } from '@/types/wizard'
import { getModelById } from '@/config/bedrock-models'
import { Check, Download, FileCode, Package, AlertCircle } from 'lucide-react'
import { useState } from 'react'
import { apiClient } from '@/services/api'

export function ReviewStep({ config }: WizardStepProps) {
  const [isGenerating, setIsGenerating] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const model = getModelById(config.aiModel.bedrockModelId)

  const handleDownload = async () => {
    setIsGenerating(true)
    setError(null)
    
    try {
      await apiClient.downloadPackage(config, `${config.basic.projectName}-${config.basic.environment}`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate package')
      console.error('Package generation error:', err)
    } finally {
      setIsGenerating(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Review Configuration</h2>
        <p className="text-sm text-gray-500">Review your settings and generate the deployment package.</p>
      </div>

      {/* Summary */}
      <div className="grid gap-4 md:grid-cols-2">
        <div className="p-4 rounded-lg border border-gray-200 bg-white">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wide mb-3">Basic Info</h3>
          <dl className="space-y-2">
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Project Name</dt>
              <dd className="text-sm font-medium text-gray-900">{config.basic.projectName}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Environment</dt>
              <dd className="text-sm font-medium text-gray-900">{config.basic.environment}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Owner</dt>
              <dd className="text-sm font-medium text-gray-900">{config.basic.owner || '-'}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Mode</dt>
              <dd className="text-sm font-medium text-gray-900 capitalize">{config.mode}</dd>
            </div>
          </dl>
        </div>

        <div className="p-4 rounded-lg border border-gray-200 bg-white">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wide mb-3">Infrastructure</h3>
          <dl className="space-y-2">
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">AWS Region</dt>
              <dd className="text-sm font-medium text-gray-900">{config.basic.awsRegion}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">AI Model</dt>
              <dd className="text-sm font-medium text-gray-900 truncate" title={model?.name}>
                {model?.name || config.aiModel.bedrockModelId}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Connect Instance</dt>
              <dd className="text-sm font-medium text-gray-900">
                {config.connect.createConnectInstance ? (config.connect.connectInstanceAlias || 'New') : 'Existing'}
              </dd>
            </div>
          </dl>
        </div>

        <div className="p-4 rounded-lg border border-gray-200 bg-white md:col-span-2">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wide mb-3">Security & Compliance</h3>
          <div className="flex gap-4 flex-wrap">
            <div className="flex items-center gap-2">
              <div className={`rounded-full p-1 ${config.security.enableFedRampCompliance ? 'bg-green-100' : 'bg-gray-100'}`}>
                <Check className={`h-4 w-4 ${config.security.enableFedRampCompliance ? 'text-green-600' : 'text-gray-400'}`} />
              </div>
              <span className="text-sm text-gray-700">FedRAMP Compliance</span>
            </div>
            <div className="flex items-center gap-2">
              <div className={`rounded-full p-1 ${config.waf?.enableWaf ? 'bg-green-100' : 'bg-gray-100'}`}>
                <Check className={`h-4 w-4 ${config.waf?.enableWaf ? 'text-green-600' : 'text-gray-400'}`} />
              </div>
              <span className="text-sm text-gray-700">WAF Protection</span>
            </div>
            {config.mode === 'comprehensive' && (
              <>
                <div className="flex items-center gap-2">
                  <div className={`rounded-full p-1 ${config.vpc ? 'bg-green-100' : 'bg-gray-100'}`}>
                    <Check className={`h-4 w-4 ${config.vpc ? 'text-green-600' : 'text-gray-400'}`} />
                  </div>
                  <span className="text-sm text-gray-700">VPC Configuration</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className={`rounded-full p-1 ${config.backup?.enableBackup ? 'bg-green-100' : 'bg-gray-100'}`}>
                    <Check className={`h-4 w-4 ${config.backup?.enableBackup ? 'text-green-600' : 'text-gray-400'}`} />
                  </div>
                  <span className="text-sm text-gray-700">AWS Backup</span>
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Package Contents */}
      <div className="p-4 rounded-lg border border-blue-200 bg-blue-50">
        <h3 className="font-medium text-blue-900 mb-2 flex items-center gap-2">
          <Package className="h-5 w-5" /> Deployment Package Contents
        </h3>
        <p className="text-sm text-blue-800 mb-3">
          The generated package will include all files needed for deployment:
        </p>
        <ul className="space-y-1 text-sm text-blue-800">
          <li className="flex items-center gap-2">
            <FileCode className="h-4 w-4" />
            <code className="font-mono">terraform.tfvars</code> - Infrastructure variables
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="h-4 w-4" />
            <code className="font-mono">agent-configuration-bedrock.json</code> - Bedrock agent config
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="h-4 w-4" />
            <code className="font-mono">agent-configuration-connect.json</code> - Connect agent config
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="h-4 w-4" />
            <code className="font-mono">lex-bot-definition.json</code> - Lex bot definition
          </li>
          <li className="flex items-center gap-2">
            <FileCode className="h-4 w-4" />
            <code className="font-mono">README.md</code> - Deployment instructions
          </li>
        </ul>
      </div>

      {/* Error Display */}
      {error && (
        <div className="p-4 rounded-lg border border-red-200 bg-red-50 flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="font-medium text-red-900">Generation Failed</h3>
            <p className="text-sm text-red-800 mt-1">{error}</p>
          </div>
        </div>
      )}

      {/* Download Button */}
      <div className="flex justify-center pt-4">
        <button
          onClick={handleDownload}
          disabled={isGenerating}
          className="flex items-center gap-2 px-6 py-3 text-base font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isGenerating ? (
            <>
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
              Generating Package...
            </>
          ) : (
            <>
              <Download className="h-5 w-5" />
              Download Deployment Package
            </>
          )}
        </button>
      </div>

      {/* Next Steps */}
      <div className="p-4 rounded-lg border border-gray-200 bg-gray-50">
        <h3 className="font-medium text-gray-900 mb-2">Next Steps</h3>
        <ol className="list-decimal list-inside space-y-1 text-sm text-gray-700">
          <li>Download the deployment package</li>
          <li>Extract the ZIP file to your working directory</li>
          <li>Review the generated <code className="font-mono">README.md</code> for deployment instructions</li>
          <li>Initialize Terraform: <code className="font-mono bg-white px-1 rounded">terraform init</code></li>
          <li>Review the plan: <code className="font-mono bg-white px-1 rounded">terraform plan</code></li>
          <li>Deploy: <code className="font-mono bg-white px-1 rounded">terraform apply</code></li>
        </ol>
      </div>
    </div>
  )
}
