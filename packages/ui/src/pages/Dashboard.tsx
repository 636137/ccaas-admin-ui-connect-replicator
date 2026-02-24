import { Link } from 'react-router-dom'
import { Wand2, Cpu, Rocket, FileCode, Shield, Clock } from 'lucide-react'

export function Dashboard() {
  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Government CCaaS Admin</h1>
        <p className="mt-2 text-gray-600">
          Configure and deploy Amazon Connect contact centers with AI-powered census agents.
        </p>
      </div>

      {/* Quick Actions */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-8">
        <Link
          to="/wizard"
          className="group relative rounded-xl border border-gray-200 bg-white p-6 shadow-sm hover:border-blue-300 hover:shadow-md transition-all"
        >
          <div className="flex items-center gap-4">
            <div className="rounded-lg bg-blue-100 p-3 group-hover:bg-blue-200 transition-colors">
              <Wand2 className="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <h3 className="font-semibold text-gray-900">New Deployment</h3>
              <p className="text-sm text-gray-500">Start configuration wizard</p>
            </div>
          </div>
        </Link>

        <Link
          to="/models"
          className="group relative rounded-xl border border-gray-200 bg-white p-6 shadow-sm hover:border-blue-300 hover:shadow-md transition-all"
        >
          <div className="flex items-center gap-4">
            <div className="rounded-lg bg-purple-100 p-3 group-hover:bg-purple-200 transition-colors">
              <Cpu className="h-6 w-6 text-purple-600" />
            </div>
            <div>
              <h3 className="font-semibold text-gray-900">AI Models</h3>
              <p className="text-sm text-gray-500">Browse Claude models</p>
            </div>
          </div>
        </Link>

        <Link
          to="/deployments"
          className="group relative rounded-xl border border-gray-200 bg-white p-6 shadow-sm hover:border-blue-300 hover:shadow-md transition-all"
        >
          <div className="flex items-center gap-4">
            <div className="rounded-lg bg-green-100 p-3 group-hover:bg-green-200 transition-colors">
              <Rocket className="h-6 w-6 text-green-600" />
            </div>
            <div>
              <h3 className="font-semibold text-gray-900">Deployments</h3>
              <p className="text-sm text-gray-500">View active deployments</p>
            </div>
          </div>
        </Link>
      </div>

      {/* Features */}
      <h2 className="text-xl font-semibold text-gray-900 mb-4">Platform Features</h2>
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <div className="rounded-lg border border-gray-200 bg-white p-5">
          <FileCode className="h-8 w-8 text-blue-600 mb-3" />
          <h3 className="font-medium text-gray-900">Infrastructure as Code</h3>
          <p className="text-sm text-gray-500 mt-1">
            Generate Terraform configurations automatically from your selections.
          </p>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-5">
          <Shield className="h-8 w-8 text-green-600 mb-3" />
          <h3 className="font-medium text-gray-900">FedRAMP Compliance</h3>
          <p className="text-sm text-gray-500 mt-1">
            Built-in security controls for government deployments.
          </p>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-5">
          <Clock className="h-8 w-8 text-purple-600 mb-3" />
          <h3 className="font-medium text-gray-900">Quick Deployment</h3>
          <p className="text-sm text-gray-500 mt-1">
            MVP mode gets you started in under 5 minutes.
          </p>
        </div>
      </div>

      {/* Model Summary */}
      <div className="mt-8 rounded-xl border border-gray-200 bg-white p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Available Claude Models</h2>
        <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-lg bg-green-50 p-4 border border-green-200">
            <p className="text-2xl font-bold text-green-700">3</p>
            <p className="text-sm text-green-600">Economy (Haiku)</p>
          </div>
          <div className="rounded-lg bg-blue-50 p-4 border border-blue-200">
            <p className="text-2xl font-bold text-blue-700">3</p>
            <p className="text-sm text-blue-600">Standard (Sonnet)</p>
          </div>
          <div className="rounded-lg bg-purple-50 p-4 border border-purple-200">
            <p className="text-2xl font-bold text-purple-700">3</p>
            <p className="text-sm text-purple-600">Premium (Opus)</p>
          </div>
          <div className="rounded-lg bg-amber-50 p-4 border border-amber-200">
            <p className="text-2xl font-bold text-amber-700">2</p>
            <p className="text-sm text-amber-600">GovCloud Enabled</p>
          </div>
        </div>
      </div>
    </div>
  )
}
