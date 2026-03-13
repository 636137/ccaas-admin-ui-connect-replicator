import { Routes, Route, useNavigate } from 'react-router-dom'
import { useState } from 'react'
import { ChevronRight, ChevronLeft, Check } from 'lucide-react'
import type { WizardConfig } from '../types'
import { getDefaultWizardConfig } from '../services/validation'

// Wizard Steps
import { BasicInfoStep } from './wizard/BasicInfoStep'
import { RegionModelStep } from './wizard/RegionModelStep'
import { ConnectStep } from './wizard/ConnectStep'
import UsersStep from './wizard/UsersStep'
import LexStep from './wizard/LexStep'
import LambdaStep from './wizard/LambdaStep'
import DynamoDBStep from './wizard/DynamoDBStep'
import VPCStep from './wizard/VPCStep'
import { SecurityStep } from './wizard/SecurityStep'
import MonitoringStep from './wizard/MonitoringStep'
import BackupStep from './wizard/BackupStep'
import { ReviewStep } from './wizard/ReviewStep'

interface WizardStep {
  id: string
  name: string
  path: string
  showInMvp: boolean
  component: React.ComponentType<any>
}

const STEPS: WizardStep[] = [
  { id: 'basic', name: 'Basic Info', path: '', showInMvp: true, component: BasicInfoStep },
  { id: 'region', name: 'Region & Model', path: 'region', showInMvp: true, component: RegionModelStep },
  { id: 'connect', name: 'Connect', path: 'connect', showInMvp: true, component: ConnectStep },
  { id: 'users', name: 'Users', path: 'users', showInMvp: true, component: UsersStep },
  { id: 'lex', name: 'Lex Bot', path: 'lex', showInMvp: false, component: LexStep },
  { id: 'lambda', name: 'Lambda', path: 'lambda', showInMvp: false, component: LambdaStep },
  { id: 'dynamodb', name: 'DynamoDB', path: 'dynamodb', showInMvp: false, component: DynamoDBStep },
  { id: 'vpc', name: 'VPC', path: 'vpc', showInMvp: false, component: VPCStep },
  { id: 'security', name: 'Security', path: 'security', showInMvp: true, component: SecurityStep },
  { id: 'monitoring', name: 'Monitoring', path: 'monitoring', showInMvp: false, component: MonitoringStep },
  { id: 'backup', name: 'Backup', path: 'backup', showInMvp: false, component: BackupStep },
  { id: 'review', name: 'Review', path: 'review', showInMvp: true, component: ReviewStep },
]

export function ConfigWizard() {
  const [config, setConfig] = useState<WizardConfig>(getDefaultWizardConfig())
  const [currentStep, setCurrentStep] = useState(0)
  const navigate = useNavigate()

  const updateConfig = (updates: Partial<WizardConfig>) => {
    setConfig(prev => ({ ...prev, ...updates }))
  }

  // Filter steps based on mode
  const visibleSteps = config.mode === 'mvp' 
    ? STEPS.filter(step => step.showInMvp)
    : STEPS

  const nextStep = () => {
    if (currentStep < visibleSteps.length - 1) {
      setCurrentStep(currentStep + 1)
      navigate(`/wizard/${visibleSteps[currentStep + 1].path}`)
    }
  }

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1)
      navigate(`/wizard/${visibleSteps[currentStep - 1].path}`)
    }
  }

  const goToStep = (index: number) => {
    setCurrentStep(index)
    navigate(`/wizard/${visibleSteps[index].path}`)
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Configuration Wizard</h1>
        <p className="mt-2 text-gray-600">
          Configure your Government CCaaS deployment step by step.
        </p>
      </div>

      {/* Mode Toggle */}
      <div className="mb-6 flex items-center gap-4">
        <span className="text-sm font-medium text-gray-700">Mode:</span>
        <div className="flex rounded-lg border border-gray-200 p-1">
          <button
            onClick={() => updateConfig({ mode: 'mvp' })}
            className={`px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              config.mode === 'mvp'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            MVP ({visibleSteps.length} steps)
          </button>
          <button
            onClick={() => updateConfig({ mode: 'comprehensive' })}
            className={`px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              config.mode === 'comprehensive'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            Comprehensive (12 steps)
          </button>
        </div>
        <span className="text-xs text-gray-500">
          {config.mode === 'mvp' 
            ? 'Essential settings only' 
            : 'Full control over all configuration options'}
        </span>
      </div>

      {/* Progress Steps */}
      <nav aria-label="Progress" className="mb-8">
        <ol className="flex items-center overflow-x-auto">
          {visibleSteps.map((step, index) => (
            <li key={step.id} className={`relative ${index !== visibleSteps.length - 1 ? 'pr-8 sm:pr-20 flex-1' : ''}`}>
              <button
                onClick={() => goToStep(index)}
                className="group flex items-center"
              >
                <span className="flex items-center">
                  <span
                    className={`flex h-10 w-10 items-center justify-center rounded-full border-2 transition-colors ${
                      index < currentStep
                        ? 'bg-blue-600 border-blue-600'
                        : index === currentStep
                        ? 'border-blue-600 bg-white'
                        : 'border-gray-300 bg-white'
                    }`}
                  >
                    {index < currentStep ? (
                      <Check className="h-5 w-5 text-white" />
                    ) : (
                      <span className={index === currentStep ? 'text-blue-600' : 'text-gray-500'}>
                        {index + 1}
                      </span>
                    )}
                  </span>
                </span>
                <span className="ml-3 text-sm font-medium text-gray-900 hidden sm:block whitespace-nowrap">
                  {step.name}
                </span>
              </button>
              {index !== visibleSteps.length - 1 && (
                <div className="absolute top-5 left-10 -ml-px h-0.5 w-full bg-gray-200 sm:left-20" />
              )}
            </li>
          ))}
        </ol>
      </nav>

      {/* Step Content */}
      <div className="mt-8">
        <Routes>
          {visibleSteps.map((step) => {
            const StepComponent = step.component
            return (
              <Route
                key={step.id}
                path={step.path}
                element={
                  <StepComponent
                    config={config}
                    onChange={updateConfig}
                    onNext={nextStep}
                    onPrevious={prevStep}
                  />
                }
              />
            )
          })}
        </Routes>
      </div>
    </div>
  )
}

// Legacy export for backward compatibility
export type WizardData = WizardConfig
