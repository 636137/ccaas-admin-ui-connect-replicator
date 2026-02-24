import { type WizardData } from '../ConfigWizard'

interface StepProps {
  data: WizardData
  updateData: (updates: Partial<WizardData>) => void
}

export function ConnectStep({ data, updateData }: StepProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Amazon Connect Setup</h2>
        <p className="text-sm text-gray-500">Configure your contact center instance settings.</p>
      </div>

      {/* Create Instance Toggle */}
      <div className="p-4 rounded-lg border border-gray-200 bg-gray-50">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-medium text-gray-900">Create New Connect Instance</h3>
            <p className="text-sm text-gray-500">Create a new Amazon Connect instance for this deployment</p>
          </div>
          <button
            type="button"
            onClick={() => updateData({ createConnectInstance: !data.createConnectInstance })}
            className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${
              data.createConnectInstance ? 'bg-blue-600' : 'bg-gray-200'
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                data.createConnectInstance ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
      </div>

      {/* Instance Alias */}
      {data.createConnectInstance && (
        <div>
          <label htmlFor="instanceAlias" className="block text-sm font-medium text-gray-700 mb-1">
            Connect Instance Alias *
          </label>
          <input
            type="text"
            id="instanceAlias"
            value={data.connectInstanceAlias}
            onChange={(e) => updateData({ connectInstanceAlias: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="census-contact-center"
          />
          <p className="mt-1 text-xs text-gray-500">
            Unique identifier for your Connect instance (lowercase, hyphens allowed, 1-64 chars)
          </p>
        </div>
      )}

      {!data.createConnectInstance && (
        <div className="p-4 rounded-lg border border-amber-200 bg-amber-50">
          <p className="text-sm text-amber-800">
            You'll need to provide an existing Connect instance ID and ARN in the generated configuration.
          </p>
        </div>
      )}

      {/* Additional Options (shown in comprehensive mode) */}
      {data.mode === 'comprehensive' && (
        <div className="space-y-4 pt-4 border-t border-gray-200">
          <h3 className="font-medium text-gray-900">Additional Connect Options</h3>
          
          <div className="grid gap-4 md:grid-cols-2">
            <div className="p-4 rounded-lg border border-gray-200">
              <h4 className="text-sm font-medium text-gray-700 mb-2">Contact Flows</h4>
              <p className="text-xs text-gray-500">
                Custom contact flows will be created automatically based on the census agent template.
              </p>
            </div>
            
            <div className="p-4 rounded-lg border border-gray-200">
              <h4 className="text-sm font-medium text-gray-700 mb-2">Lex Bot Integration</h4>
              <p className="text-xs text-gray-500">
                A Lex bot will be created and associated with your Connect instance for AI interactions.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
