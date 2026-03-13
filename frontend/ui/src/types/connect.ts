export type AwsRegion = {
  code: string
  name: string
  partition?: 'aws' | 'aws-us-gov'
}

export type ConnectInstanceSummary = {
  Id?: string
  Arn?: string
  IdentityManagementType?: string
  InstanceAlias?: string
  CreatedTime?: string
  ServiceRole?: string
  InstanceStatus?: string
  InboundCallsEnabled?: boolean
  OutboundCallsEnabled?: boolean
}

export type RegionsResponse = {
  regions: AwsRegion[]
  globalResiliencyTargets: Record<string, string[]>
}

export type ListInstancesResponse = {
  region: string
  instances: ConnectInstanceSummary[]
}

export type DescribeInstanceResponse = {
  region: string
  instance: ConnectInstanceSummary | null
}

export type SnapshotResponse = {
  snapshotId: string
  fileName: string
  snapshot: unknown
}

export type ReplicateResponse = {
  request: {
    sourceRegion: string
    targetRegion: string
    instanceId: string
    replicaAlias: string
    clientToken?: string
  }
  result: {
    id?: string
    arn?: string
  }
  warnings: string[]
}

export type ReplicationStatusResponse = {
  region: string
  status?: string
  instance?: ConnectInstanceSummary | null
}
