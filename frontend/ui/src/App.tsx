import { Routes, Route } from 'react-router-dom'
import { Layout } from './components/Layout'
import { Dashboard } from './pages/Dashboard'
import { ConfigWizard } from './pages/ConfigWizard'
import { ModelsPage } from './pages/ModelsPage'
import { DeploymentsPage } from './pages/DeploymentsPage'
import { ConnectReplicatorPage } from './pages/ConnectReplicatorPage'

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/wizard/*" element={<ConfigWizard />} />
        <Route path="/models" element={<ModelsPage />} />
        <Route path="/deployments" element={<DeploymentsPage />} />
        <Route path="/connect" element={<ConnectReplicatorPage />} />
      </Routes>
    </Layout>
  )
}

export default App
