import { Router, Request, Response } from 'express'
import { z } from 'zod'
import {
  ConnectClient,
  DescribeInstanceCommand,
  ListInstancesCommand,
  ListTrafficDistributionGroupsCommand,
  ReplicateInstanceCommand,
} from '@aws-sdk/client-connect'
import { ALL_REGIONS, GLOBAL_RESILIENCY_REGION_TARGETS } from '../services/connectRegions.js'
import { mkdir, writeFile } from 'fs/promises'
import path from 'path'

const router = Router()

const snapshotDir = () => path.resolve(process.cwd(), 'snapshots')

function connectClient(region: string) {
  return new ConnectClient({ region })
}

function instanceIdFromArnOrId(instanceIdOrArn: string): string {
  // Accept raw UUID, or an ARN ending with instance/<uuid>
  const m = instanceIdOrArn.match(/instance\/(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})$/)
  return m ? m[1] : instanceIdOrArn
}

router.get('/regions', (_req: Request, res: Response) => {
  res.json({
    regions: ALL_REGIONS,
    globalResiliencyTargets: GLOBAL_RESILIENCY_REGION_TARGETS,
  })
})

router.get('/instances', async (req: Request, res: Response) => {
  try {
    const region = z.string().min(1).parse(req.query.region)

    const client = connectClient(region)
    const instances: any[] = []
    let nextToken: string | undefined = undefined

    do {
      const out = await client.send(
        new ListInstancesCommand({
          MaxResults: 10,
          NextToken: nextToken,
        })
      )
      instances.push(...(out.InstanceSummaryList || []))
      nextToken = out.NextToken
    } while (nextToken)

    res.json({ region, instances })
  } catch (error) {
    console.error('Error listing Connect instances:', error)
    res.status(500).json({
      error: 'ListInstances failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

router.get('/instance', async (req: Request, res: Response) => {
  try {
    const region = z.string().min(1).parse(req.query.region)
    const instanceId = z.string().min(1).parse(req.query.instanceId)

    const client = connectClient(region)
    const out = await client.send(
      new DescribeInstanceCommand({ InstanceId: instanceIdFromArnOrId(instanceId) })
    )

    res.json({ region, instance: out.Instance })
  } catch (error) {
    console.error('Error describing Connect instance:', error)
    res.status(500).json({
      error: 'DescribeInstance failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

router.get('/replication-status', async (req: Request, res: Response) => {
  try {
    const region = z.string().min(1).parse(req.query.region)
    const instanceId = z.string().min(1).parse(req.query.instanceId)

    const client = connectClient(region)
    const out = await client.send(
      new DescribeInstanceCommand({ InstanceId: instanceIdFromArnOrId(instanceId) })
    )

    res.json({ region, status: out.Instance?.InstanceStatus, instance: out.Instance })
  } catch (error) {
    console.error('Error checking replication status:', error)
    res.status(500).json({
      error: 'Replication status failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

router.post('/replicate', async (req: Request, res: Response) => {
  try {
    const schema = z.object({
      sourceRegion: z.string().min(1),
      targetRegion: z.string().min(1),
      instanceId: z.string().min(1),
      replicaAlias: z.string().min(1).max(45),
      clientToken: z.string().min(1).max(500).optional(),
    })

    const body = schema.parse(req.body)

    const allowedTargets = GLOBAL_RESILIENCY_REGION_TARGETS[body.sourceRegion] || []
    const isAllowedPair = allowedTargets.includes(body.targetRegion)

    const client = connectClient(body.sourceRegion)
    const out = await client.send(
      new ReplicateInstanceCommand({
        InstanceId: instanceIdFromArnOrId(body.instanceId),
        ReplicaRegion: body.targetRegion,
        ReplicaAlias: body.replicaAlias,
        ClientToken: body.clientToken,
      })
    )

    res.json({
      request: { ...body, instanceId: instanceIdFromArnOrId(body.instanceId) },
      result: { id: out.Id, arn: out.Arn },
      warnings: isAllowedPair
        ? []
        : [
            'Selected region pairing is not in the documented Global Resiliency pair list; ReplicateInstance may fail unless AWS has expanded support.',
          ],
    })
  } catch (error) {
    console.error('Error replicating instance:', error)
    res.status(500).json({
      error: 'ReplicateInstance failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

router.post('/snapshot', async (req: Request, res: Response) => {
  try {
    const schema = z.object({
      region: z.string().min(1),
      instanceId: z.string().min(1),
    })

    const body = schema.parse(req.body)
    const region = body.region
    const instanceId = instanceIdFromArnOrId(body.instanceId)

    const client = connectClient(region)
    const [instanceOut, tdgOut] = await Promise.all([
      client.send(new DescribeInstanceCommand({ InstanceId: instanceId })),
      client.send(new ListTrafficDistributionGroupsCommand({ InstanceId: instanceId, MaxResults: 10 })),
    ])

    const snapshot = {
      kind: 'connect-instance-snapshot',
      createdAt: new Date().toISOString(),
      region,
      instance: instanceOut.Instance,
      trafficDistributionGroups: tdgOut.TrafficDistributionGroupSummaryList || [],
    }

    const dir = snapshotDir()
    await mkdir(dir, { recursive: true })

    const safeTs = snapshot.createdAt.replace(/[:.]/g, '-')
    const fileName = `connect_${instanceId}_${region}_${safeTs}.json`
    const filePath = path.join(dir, fileName)

    await writeFile(filePath, JSON.stringify(snapshot, null, 2), 'utf-8')

    res.json({
      snapshotId: fileName,
      fileName,
      snapshot,
    })
  } catch (error) {
    console.error('Error snapshotting instance:', error)
    res.status(500).json({
      error: 'Snapshot failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

export default router
