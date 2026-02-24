import { Rocket, Clock, CheckCircle, XCircle } from 'lucide-react'

const mockDeployments = [
  {
    id: '1',
    name: 'census-ccaas-prod',
    environment: 'prod',
    region: 'us-east-1',
    model: 'Claude Sonnet 4.5',
    status: 'active',
    createdAt: '2026-02-20T10:30:00Z',
  },
  {
    id: '2',
    name: 'census-ccaas-staging',
    environment: 'staging',
    region: 'us-west-2',
    model: 'Claude Sonnet 4.5',
    status: 'active',
    createdAt: '2026-02-18T14:20:00Z',
  },
  {
    id: '3',
    name: 'census-ccaas-dev',
    environment: 'dev',
    region: 'us-east-1',
    model: 'Claude Haiku 4.5',
    status: 'pending',
    createdAt: '2026-02-24T08:00:00Z',
  },
]

export function DeploymentsPage() {
  return (
    <div>
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Deployments</h1>
          <p className="mt-2 text-gray-600">
            Manage your Government CCaaS deployments across environments.
          </p>
        </div>
        <a
          href="/wizard"
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
        >
          <Rocket className="h-4 w-4" /> New Deployment
        </a>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4 mb-8">
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <p className="text-2xl font-bold text-gray-900">3</p>
          <p className="text-sm text-gray-500">Total Deployments</p>
        </div>
        <div className="rounded-lg border border-green-200 bg-green-50 p-4">
          <p className="text-2xl font-bold text-green-700">2</p>
          <p className="text-sm text-green-600">Active</p>
        </div>
        <div className="rounded-lg border border-amber-200 bg-amber-50 p-4">
          <p className="text-2xl font-bold text-amber-700">1</p>
          <p className="text-sm text-amber-600">Pending</p>
        </div>
        <div className="rounded-lg border border-red-200 bg-red-50 p-4">
          <p className="text-2xl font-bold text-red-700">0</p>
          <p className="text-sm text-red-600">Failed</p>
        </div>
      </div>

      {/* Deployments Table */}
      <div className="rounded-xl border border-gray-200 bg-white overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Name
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Environment
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Region
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                AI Model
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Created
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {mockDeployments.map((deployment) => (
              <tr key={deployment.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <p className="text-sm font-medium text-gray-900">{deployment.name}</p>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                    deployment.environment === 'prod'
                      ? 'bg-red-100 text-red-800'
                      : deployment.environment === 'staging'
                      ? 'bg-amber-100 text-amber-800'
                      : 'bg-green-100 text-green-800'
                  }`}>
                    {deployment.environment}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {deployment.region}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {deployment.model}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <StatusBadge status={deployment.status} />
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {new Date(deployment.createdAt).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function StatusBadge({ status }: { status: string }) {
  switch (status) {
    case 'active':
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
          <CheckCircle className="h-3 w-3" /> Active
        </span>
      )
    case 'pending':
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-medium text-amber-800">
          <Clock className="h-3 w-3" /> Pending
        </span>
      )
    case 'failed':
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800">
          <XCircle className="h-3 w-3" /> Failed
        </span>
      )
    default:
      return null
  }
}
