import { type WizardData } from '../ConfigWizard'

interface StepProps {
  data: WizardData
  updateData: (updates: Partial<WizardData>) => void
}

export function BasicInfoStep({ data, updateData }: StepProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Basic Information</h2>
        <p className="text-sm text-gray-500">Configure the basic settings for your deployment.</p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <div>
          <label htmlFor="projectName" className="block text-sm font-medium text-gray-700 mb-1">
            Project Name *
          </label>
          <input
            type="text"
            id="projectName"
            value={data.projectName}
            onChange={(e) => updateData({ projectName: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="census-ccaas"
          />
          <p className="mt-1 text-xs text-gray-500">Used for resource naming (lowercase, hyphens allowed)</p>
        </div>

        <div>
          <label htmlFor="environment" className="block text-sm font-medium text-gray-700 mb-1">
            Environment *
          </label>
          <select
            id="environment"
            value={data.environment}
            onChange={(e) => updateData({ environment: e.target.value as 'dev' | 'staging' | 'prod' })}
            className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
          >
            <option value="dev">Development</option>
            <option value="staging">Staging</option>
            <option value="prod">Production</option>
          </select>
        </div>

        <div className="md:col-span-2">
          <label htmlFor="owner" className="block text-sm font-medium text-gray-700 mb-1">
            Owner Email *
          </label>
          <input
            type="email"
            id="owner"
            value={data.owner}
            onChange={(e) => updateData({ owner: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="admin@agency.gov"
          />
          <p className="mt-1 text-xs text-gray-500">Contact email for deployment notifications and alerts</p>
        </div>
      </div>
    </div>
  )
}
