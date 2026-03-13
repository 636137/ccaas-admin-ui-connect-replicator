import { type WizardStepProps } from '@/types/wizard'
import { Shield, AlertTriangle } from 'lucide-react'

export function SecurityStep({ config, onChange }: WizardStepProps) {
  const isGovCloud = config.basic.awsRegion.startsWith('us-gov-')

  const updateSecurity = (updates: Partial<typeof config.security>) => {
    onChange({ ...config, security: { ...config.security, ...updates } })
  }

  const updateWaf = (enabled: boolean) => {
    onChange({ 
      ...config, 
      waf: enabled ? { enableWaf: true } : undefined 
    })
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Security Configuration</h2>
        <p className="text-sm text-gray-500">Configure security and compliance settings for your deployment.</p>
      </div>

      {/* FedRAMP Compliance */}
      <div className={`p-4 rounded-lg border-2 transition-colors ${
        config.security.enableFedRampCompliance 
          ? 'border-green-500 bg-green-50' 
          : 'border-gray-200'
      }`}>
        <div className="flex items-start justify-between">
          <div className="flex items-start gap-3">
            <Shield className={`h-6 w-6 mt-0.5 ${config.security.enableFedRampCompliance ? 'text-green-600' : 'text-gray-400'}`} />
            <div>
              <h3 className="font-medium text-gray-900">FedRAMP Compliance Mode</h3>
              <p className="text-sm text-gray-500 mt-1">
                Enable FedRAMP security controls including encryption, audit logging, and compliance monitoring.
              </p>
              {config.security.enableFedRampCompliance && (
                <div className="mt-3 text-sm text-green-700">
                  <p className="font-medium">Includes:</p>
                  <ul className="list-disc list-inside mt-1 space-y-1">
                    <li>KMS encryption for all data at rest</li>
                    <li>VPC with private subnets</li>
                    <li>CloudTrail audit logging</li>
                    <li>AWS Config compliance rules</li>
                    <li>AWS Backup automated backups</li>
                    <li>IAM least-privilege policies</li>
                  </ul>
                </div>
              )}
            </div>
          </div>
          <button
            type="button"
            onClick={() => updateSecurity({ enableFedRampCompliance: !config.security.enableFedRampCompliance })}
            className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 ${
              config.security.enableFedRampCompliance ? 'bg-green-600' : 'bg-gray-200'
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                config.security.enableFedRampCompliance ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
      </div>

      {/* WAF Protection */}
      <div className={`p-4 rounded-lg border-2 transition-colors ${
        config.waf?.enableWaf 
          ? 'border-blue-500 bg-blue-50' 
          : 'border-gray-200'
      }`}>
        <div className="flex items-start justify-between">
          <div>
            <h3 className="font-medium text-gray-900">AWS WAF Protection</h3>
            <p className="text-sm text-gray-500 mt-1">
              Enable Web Application Firewall with managed rule sets for DDoS and attack protection.
            </p>
          </div>
          <button
            type="button"
            onClick={() => updateWaf(!config.waf?.enableWaf)}
            className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${
              config.waf?.enableWaf ? 'bg-blue-600' : 'bg-gray-200'
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                config.waf?.enableWaf ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
      </div>

      {/* GovCloud Notice */}
      {isGovCloud && (
        <div className="p-4 rounded-lg border border-amber-200 bg-amber-50 flex items-start gap-3">
          <AlertTriangle className="h-5 w-5 text-amber-600 flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="font-medium text-amber-800">GovCloud Deployment</h3>
            <p className="text-sm text-amber-700 mt-1">
              You're deploying to AWS GovCloud ({config.basic.awsRegion}). FedRAMP compliance mode is highly recommended for government workloads.
            </p>
          </div>
        </div>
      )}

      {/* MVP mode notice */}
      {config.mode === 'mvp' && (
        <div className="p-4 rounded-lg border border-gray-200 bg-gray-50">
          <p className="text-sm text-gray-600">
            <span className="font-medium">MVP Mode:</span> Additional security options (VPC CIDR, KMS key rotation, log retention) are available in Comprehensive mode.
          </p>
        </div>
      )}
    </div>
  )
}
