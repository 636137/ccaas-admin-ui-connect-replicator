import { type WizardData } from '../ConfigWizard'
import { getModelById } from '@/config/bedrock-models'
import { Check, Copy, Download, FileCode } from 'lucide-react'
import { useState } from 'react'

interface ReviewStepProps {
  data: WizardData
}

export function ReviewStep({ data }: ReviewStepProps) {
  const [copied, setCopied] = useState(false)
  const model = getModelById(data.bedrockModelId)

  const terraformConfig = generateTerraformConfig(data)

  const handleCopy = () => {
    navigator.clipboard.writeText(terraformConfig)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleDownload = () => {
    const blob = new Blob([terraformConfig], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'terraform.tfvars'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Review Configuration</h2>
        <p className="text-sm text-gray-500">Review your settings and generate the configuration files.</p>
      </div>

      {/* Summary */}
      <div className="grid gap-4 md:grid-cols-2">
        <div className="p-4 rounded-lg border border-gray-200 bg-white">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wide mb-3">Basic Info</h3>
          <dl className="space-y-2">
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Project Name</dt>
              <dd className="text-sm font-medium text-gray-900">{data.projectName}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Environment</dt>
              <dd className="text-sm font-medium text-gray-900">{data.environment}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Owner</dt>
              <dd className="text-sm font-medium text-gray-900">{data.owner || '-'}</dd>
            </div>
          </dl>
        </div>

        <div className="p-4 rounded-lg border border-gray-200 bg-white">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wide mb-3">Infrastructure</h3>
          <dl className="space-y-2">
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">AWS Region</dt>
              <dd className="text-sm font-medium text-gray-900">{data.awsRegion}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">AI Model</dt>
              <dd className="text-sm font-medium text-gray-900">{model?.name || data.bedrockModelId}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-sm text-gray-600">Connect Instance</dt>
              <dd className="text-sm font-medium text-gray-900">
                {data.createConnectInstance ? data.connectInstanceAlias || 'New' : 'Existing'}
              </dd>
            </div>
          </dl>
        </div>

        <div className="p-4 rounded-lg border border-gray-200 bg-white md:col-span-2">
          <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wide mb-3">Security</h3>
          <div className="flex gap-4">
            <div className="flex items-center gap-2">
              <div className={`rounded-full p-1 ${data.enableFedrampCompliance ? 'bg-green-100' : 'bg-gray-100'}`}>
                <Check className={`h-4 w-4 ${data.enableFedrampCompliance ? 'text-green-600' : 'text-gray-400'}`} />
              </div>
              <span className="text-sm text-gray-700">FedRAMP Compliance</span>
            </div>
            <div className="flex items-center gap-2">
              <div className={`rounded-full p-1 ${data.enableWaf ? 'bg-green-100' : 'bg-gray-100'}`}>
                <Check className={`h-4 w-4 ${data.enableWaf ? 'text-green-600' : 'text-gray-400'}`} />
              </div>
              <span className="text-sm text-gray-700">WAF Protection</span>
            </div>
          </div>
        </div>
      </div>

      {/* Generated Config */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-sm font-medium text-gray-900 flex items-center gap-2">
            <FileCode className="h-4 w-4" /> terraform.tfvars
          </h3>
          <div className="flex gap-2">
            <button
              onClick={handleCopy}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              {copied ? <Check className="h-4 w-4 text-green-600" /> : <Copy className="h-4 w-4" />}
              {copied ? 'Copied!' : 'Copy'}
            </button>
            <button
              onClick={handleDownload}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
            >
              <Download className="h-4 w-4" /> Download
            </button>
          </div>
        </div>
        <pre className="p-4 rounded-lg bg-gray-900 text-gray-100 text-sm overflow-x-auto font-mono">
          {terraformConfig}
        </pre>
      </div>
    </div>
  )
}

function generateTerraformConfig(data: WizardData): string {
  return `# Government CCaaS in a Box - Terraform Configuration
# Generated: ${new Date().toISOString()}
# Mode: ${data.mode.toUpperCase()}

# ============================================
# Basic Configuration
# ============================================
aws_region   = "${data.awsRegion}"
environment  = "${data.environment}"
project_name = "${data.projectName}"
owner        = "${data.owner}"

# ============================================
# Amazon Connect
# ============================================
create_connect_instance = ${data.createConnectInstance}
${data.connectInstanceAlias ? `connect_instance_alias  = "${data.connectInstanceAlias}"` : '# connect_instance_alias  = "your-instance-alias"'}

# ============================================
# AI / Bedrock Configuration
# ============================================
bedrock_model_id = "${data.bedrockModelId}"

# ============================================
# Security & Compliance
# ============================================
enable_fedramp_compliance = ${data.enableFedrampCompliance}
enable_waf                = ${data.enableWaf}
${data.enableFedrampCompliance ? `
# FedRAMP compliance enables these additional features:
# - KMS encryption for data at rest
# - VPC with private subnets
# - CloudTrail audit logging
# - AWS Config compliance rules
# - Automated backups` : ''}
`
}
