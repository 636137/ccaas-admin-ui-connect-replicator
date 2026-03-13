import express from 'express'
import cors from 'cors'
import { configRoutes } from './routes/config.js'
import { deployRoutes } from './routes/deploy.js'
import packageRoutes from './routes/package.js'
import prerequisitesRoutes from './routes/prerequisites.js'
import connectRoutes from './routes/connect.js'

const app = express()
const PORT = process.env.PORT || 3001

app.use(cors())
app.use(express.json())

// Health check
app.get('/api/health', (_, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// Routes
app.use('/api/config', configRoutes)
app.use('/api/deploy', deployRoutes)
app.use('/api/package', packageRoutes)
app.use('/api/prerequisites', prerequisitesRoutes)
app.use('/api/connect', connectRoutes)

app.listen(PORT, () => {
  console.log(`API server running on http://localhost:${PORT}`)
})
