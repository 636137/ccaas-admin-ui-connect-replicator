import { Routes, Route, useNavigate } from 'react-router-dom'
import { useState } from 'react'
import { ChevronRight, ChevronLeft, Check } from 'lucide-react'

// Wizard Steps
import { BasicInfoStep } from './wizard/BasicInfoStep'
import { RegionModelStep } from './wizard/RegionModelStep'
import { ConnectStep } from './wizard/ConnectStep'
import { SecurityStep } from './wizard/SecurityStep'
import { ReviewStep } from './wizard/ReviewStep'

export interface WizardData {
  // Basic Info
  projectName: string
  environment: 'dev' | 'staging' | 'prod'
  owner: string
  
  // Region & Model
  awsRegion: string
  bedrockModelId: string
  
  // Connect
  createConnectInstance: boolean
  connectInstanceAlias: string
  
  // Security (optional)
  enableFedrampCompliance: boolean
  enableWaf: boolean
  
  // Mode
  mode: 'mvp' | 'comprehensive'
}

const defaultData: WizardData = {
  projectName: 'census-ccaas',
  environment: 'dev',
  owner: '',
  awsRegion: 'us-east-1',
  bedrockModelId: 'anthropic.claude-sonnet-4-5-20250929-v1:0',
  createConnectInstance: true,
  connectInstanceAlias: '',
  enableFedrampCompliance: false,
  enableWaf: false,
  mode: 'mvp',
}

const STEPS = [
  { id: 'basic', name: 'Basic Info', path: '' },
  { id: 'region', name: 'Region & Model', path: 'region' },
  { id: 'connect', name: 'Connect Setup', path: 'connect' },
  { id: 'security', name: 'Security', path: 'security' },
  { id: 'review', name: 'Review', path: 'review' },
]

export function ConfigWizard() {
  const [data, setData] = useState<WizardData>(defaultData)
  const [currentStep, setCurrentStep] = useState(0)
  const navigate = useNavigate()

  const updateData = (updates: Partial<WizardData>) => {
    setData(prev => ({ ...prev, ...updates }))
  }

  const nextStep = () => {
    if (currentStep < STEPS.length - 1) {
      setCurrentStep(currentStep + 1)
      navigate(`/wizard/${STEPS[currentStep + 1].path}`)
    }
  }

  const prevStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1)
      navigate(`/wizard/${STEPS[currentStep - 1].path}`)
    }
  }

  const goToStep = (index: number) => {
    setCurrentStep(index)
    navigate(`/wizard/${STEPS[index].path}`)
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
            onClick={() => updateData({ mode: 'mvp' })}
            className={`px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              data.mode === 'mvp'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            MVP (Quick Start)
          </button>
          <button
            onClick={() => updateData({ mode: 'comprehensive' })}
            className={`px-4 py-2 text-sm font-medium rounded-md transition-colors ${
              data.mode === 'comprehensive'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            Comprehensive
          </button>
        </div>
      </div>

      {/* Progress Steps */}
      <div className="mb-8">
        <nav aria-label="Progress">
          <ol className="flex items-center">
            {STEPS.map((step, index) => (
              <li key={step.id} className={`relative ${index !== STEPS.length - 1 ? 'pr-8 sm:pr-20 flex-1' : ''}`}>
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
                  <span className="ml-3 text-sm font-medium text-gray-900 hidden sm:block">
                    {step.name}
                  </span>
                </button>
                {index !== STEPS.length - 1 && (
                  <div className="absolute top-5 left-10 -ml-px h-0.5 w-full bg-gray-200 sm:left-20" />
                )}
              </li>
            ))}
          </ol>
        </nav>
      </div>

      {/* Step Content */}
      <div className="rounded-xl border border-gray-200 bg-white p-6 min-h-[400px]">
        <Routes>
          <Route path="" element={<BasicInfoStep data={data} updateData={updateData} />} />
          <Route path="region" element={<RegionModelStep data={data} updateData={updateData} />} />
          <Route path="connect" element={<ConnectStep data={data} updateData={updateData} />} />
          <Route path="security" element={<SecurityStep data={data} updateData={updateData} />} />
          <Route path="review" element={<ReviewStep data={data} />} />
        </Routes>
      </div>

      {/* Navigation Buttons */}
      <div className="mt-6 flex justify-between">
        <button
          onClick={prevStep}
          disabled={currentStep === 0}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <ChevronLeft className="h-4 w-4" /> Previous
        </button>
        
        {currentStep < STEPS.length - 1 ? (
          <button
            onClick={nextStep}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
          >
            Next <ChevronRight className="h-4 w-4" />
          </button>
        ) : (
          <button
            onClick={() => {/* Generate config */}}
            className="flex items-center gap-2 px-6 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700"
          >
            Generate Configuration
          </button>
        )}
      </div>
    </div>
  )
}
