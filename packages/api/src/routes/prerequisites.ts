import { Router, Request, Response } from 'express'
import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)
const router = Router()

interface PrerequisiteCheck {
  terraform: {
    installed: boolean
    version?: string
  }
  awsCli: {
    installed: boolean
    version?: string
  }
}

/**
 * Check system prerequisites (Terraform, AWS CLI)
 */
router.get('/check', async (req: Request, res: Response) => {
  const result: PrerequisiteCheck = {
    terraform: {
      installed: false
    },
    awsCli: {
      installed: false
    }
  }

  try {
    // Check Terraform
    try {
      const { stdout } = await execAsync('terraform --version')
      const versionMatch = stdout.match(/Terraform v?(\d+\.\d+\.\d+)/)
      result.terraform.installed = true
      result.terraform.version = versionMatch ? versionMatch[1] : 'unknown'
    } catch {
      result.terraform.installed = false
    }

    // Check AWS CLI
    try {
      const { stdout } = await execAsync('aws --version')
      const versionMatch = stdout.match(/aws-cli\/(\d+\.\d+\.\d+)/)
      result.awsCli.installed = true
      result.awsCli.version = versionMatch ? versionMatch[1] : 'unknown'
    } catch {
      result.awsCli.installed = false
    }

    res.json(result)
  } catch (error) {
    console.error('Error checking prerequisites:', error)
    res.status(500).json({
      error: 'Check failed',
      message: error instanceof Error ? error.message : 'Unknown error'
    })
  }
})

export default router
