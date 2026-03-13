import { useEffect, useMemo, useRef, useState } from 'react'
import {
  ArrowRight,
  CheckCircle2,
  Copy,
  FileDown,
  Globe2,
  Loader2,
  ShieldCheck,
  AlertTriangle,
  XCircle,
} from 'lucide-react'
import { apiClient } from '../services/api'
import type {
  AwsRegion,
  ConnectInstanceSummary,
  DescribeInstanceResponse,
  RegionsResponse,
  ReplicateResponse,
  ReplicationStatusResponse,
  SnapshotResponse,
} from '../types/connect'

function toInstanceId(idOrArn?: string) {
  if (!idOrArn) return ''
  if (idOrArn.startsWith('arn:')) return idOrArn.split('/').pop() || idOrArn
  return idOrArn
}

function classNames(...xs: Array<string | false | undefined | null>) {
  return xs.filter(Boolean).join(' ')
}

function sanitizeAlias(input: string) {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, '-')
    .replace(/--+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 45)
}

function downloadJson(filename: string, data: unknown) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = window.URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  window.URL.revokeObjectURL(url)
}

export function ConnectReplicatorPage() {
  const [regions, setRegions] = useState<AwsRegion[]>([])
  const [globalTargets, setGlobalTargets] = useState<Record<string, string[]>>({})

  const [region, setRegion] = useState('us-east-1')
  const [instances, setInstances] = useState<ConnectInstanceSummary[]>([])
  const [instancesLoading, setInstancesLoading] = useState(false)

  const [selected, setSelected] = useState<ConnectInstanceSummary | null>(null)
  const [selectedDetails, setSelectedDetails] = useState<ConnectInstanceSummary | null>(null)
  const [detailsLoading, setDetailsLoading] = useState(false)

  const [targetRegion, setTargetRegion] = useState('us-west-2')
  const [replicaAlias, setReplicaAlias] = useState('')
  const [aliasTouched, setAliasTouched] = useState(false)

  const [confirmOpen, setConfirmOpen] = useState(false)
  const [actionLog, setActionLog] = useState<Array<{ ts: string; msg: string; tone?: 'ok' | 'warn' | 'err' }>>([])

  const [busy, setBusy] = useState<null | 'snapshot' | 'replicate' | 'polling'>(null)
  const pollingRef = useRef<number | null>(null)

  const allowedTargets = useMemo(() => globalTargets[region] || [], [globalTargets, region])
  const isAllowedPair = allowedTargets.includes(targetRegion)

  const preflight = useMemo(() => {
    const status = selectedDetails?.InstanceStatus
    const idm = selectedDetails?.IdentityManagementType
    return {
      active: status === 'ACTIVE',
      saml: idm === 'SAML',
      allowedPair: isAllowedPair,
    }
  }, [selectedDetails, isAllowedPair])

  useEffect(() => {
    let ignore = false
    ;(async () => {
      try {
        const data = (await apiClient.connectRegions()) as RegionsResponse
        if (ignore) return
        setRegions(data.regions)
        setGlobalTargets(data.globalResiliencyTargets)
      } catch (e) {
        setActionLog((x) => [
          { ts: new Date().toISOString(), msg: `Failed to load regions: ${e instanceof Error ? e.message : String(e)}`, tone: 'err' },
          ...x,
        ])
      }
    })()
    return () => {
      ignore = true
    }
  }, [])

  useEffect(() => {
    let ignore = false
    ;(async () => {
      setInstancesLoading(true)
      setSelected(null)
      setSelectedDetails(null)
      setReplicaAlias('')
      setAliasTouched(false)
      try {
        const data = await apiClient.connectListInstances(region)
        if (ignore) return
        setInstances(data.instances || [])
      } catch (e) {
        if (!ignore) {
          setActionLog((x) => [
            { ts: new Date().toISOString(), msg: `ListInstances failed in ${region}: ${e instanceof Error ? e.message : String(e)}`, tone: 'err' },
            ...x,
          ])
        }
      } finally {
        if (!ignore) setInstancesLoading(false)
      }
    })()
    return () => {
      ignore = true
    }
  }, [region])

  useEffect(() => {
    if (!selected) return

    let ignore = false
    ;(async () => {
      setDetailsLoading(true)
      try {
        const data = (await apiClient.connectDescribeInstance(region, toInstanceId(selected.Id || selected.Arn))) as DescribeInstanceResponse
        if (ignore) return
        setSelectedDetails(data.instance)
        setAliasTouched(false)

        const allowed = globalTargets[region] || []
        const suggestedTarget = allowed[0]
        if (suggestedTarget && !allowed.includes(targetRegion)) {
          setTargetRegion(suggestedTarget)
        }
      } catch (e) {
        if (!ignore) {
          setActionLog((x) => [
            { ts: new Date().toISOString(), msg: `DescribeInstance failed: ${e instanceof Error ? e.message : String(e)}`, tone: 'err' },
            ...x,
          ])
        }
      } finally {
        if (!ignore) setDetailsLoading(false)
      }
    })()

    return () => {
      ignore = true
    }
  }, [selected, region, globalTargets, targetRegion])

  useEffect(() => {
    if (!selected || aliasTouched) return

    const sourceAlias =
      selectedDetails?.InstanceAlias ||
      selected.InstanceAlias ||
      (toInstanceId(selected.Id || selected.Arn) || '').slice(0, 8)

    if (!sourceAlias) return

    setReplicaAlias(sanitizeAlias(`${sourceAlias}-replica-${targetRegion}`))
  }, [selected, selectedDetails, targetRegion, aliasTouched])

  useEffect(() => {
    return () => {
      if (pollingRef.current) window.clearInterval(pollingRef.current)
    }
  }, [])

  const themeRegionName = (code: string) => regions.find((r) => r.code === code)?.name || code

  async function snapshot() {
    if (!selected) return
    setBusy('snapshot')
    try {
      const data = (await apiClient.connectSnapshot(region, toInstanceId(selected.Id || selected.Arn))) as SnapshotResponse
      setActionLog((x) => [
        { ts: new Date().toISOString(), msg: `Snapshot created: ${data.fileName}`, tone: 'ok' },
        ...x,
      ])
      downloadJson(data.fileName, data.snapshot)
    } catch (e) {
      setActionLog((x) => [
        { ts: new Date().toISOString(), msg: `Snapshot failed: ${e instanceof Error ? e.message : String(e)}`, tone: 'err' },
        ...x,
      ])
    } finally {
      setBusy(null)
    }
  }

  async function startReplication() {
    if (!selected) return
    setBusy('replicate')

    try {
      const resp = (await apiClient.connectReplicate({
        sourceRegion: region,
        targetRegion,
        instanceId: toInstanceId(selected.Id || selected.Arn),
        replicaAlias,
      })) as ReplicateResponse

      setActionLog((x) => [
        { ts: new Date().toISOString(), msg: `ReplicateInstance started: ${resp.result.id || ''}`, tone: 'ok' },
        ...(resp.warnings || []).map((w) => ({ ts: new Date().toISOString(), msg: w, tone: 'warn' as const })),
        ...x,
      ])

      const instanceId = resp.result.id || toInstanceId(selected.Id || selected.Arn) || ''

      setBusy('polling')
      if (pollingRef.current) window.clearInterval(pollingRef.current)
      pollingRef.current = window.setInterval(async () => {
        try {
          const status = (await apiClient.connectReplicationStatus(targetRegion, instanceId)) as ReplicationStatusResponse
          if (status.status) {
            setActionLog((x) => [
              { ts: new Date().toISOString(), msg: `Replica status (${targetRegion}): ${status.status}`, tone: status.status === 'ACTIVE' ? 'ok' : 'warn' },
              ...x,
            ])
          }
          if (status.status === 'ACTIVE') {
            if (pollingRef.current) window.clearInterval(pollingRef.current)
            pollingRef.current = null
            setBusy(null)
          }
        } catch (e) {
          setActionLog((x) => [
            { ts: new Date().toISOString(), msg: `Polling error: ${e instanceof Error ? e.message : String(e)}`, tone: 'err' },
            ...x,
          ])
        }
      }, 5000)
    } catch (e) {
      setActionLog((x) => [
        { ts: new Date().toISOString(), msg: `Replication failed: ${e instanceof Error ? e.message : String(e)}`, tone: 'err' },
        ...x,
      ])
      setBusy(null)
    }
  }

  const headerKicker = useMemo(() => {
    const k = allowedTargets.length
      ? `Global Resiliency target for ${region}: ${allowedTargets.join(', ')}`
      : `Browse and replicate Connect instances across regions`
    return k
  }, [allowedTargets, region])

  return (
    <div className="connect-atlas">
      <div className="relative overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm">
        {/* Ambient mesh */}
        <div
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(900px 500px at 15% -10%, rgba(232,93,4,.18), transparent 60%),' +
              'radial-gradient(700px 420px at 80% 0%, rgba(8,145,178,.15), transparent 55%),' +
              'radial-gradient(800px 500px at 0% 90%, rgba(249,115,22,.10), transparent 55%),' +
              'radial-gradient(900px 560px at 95% 95%, rgba(34,197,94,.10), transparent 55%)',
          }}
        />
        <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(to_right,rgba(2,6,23,.06)_1px,transparent_1px),linear-gradient(to_bottom,rgba(2,6,23,.06)_1px,transparent_1px)] bg-[size:48px_48px] opacity-50" />
        <div className="pointer-events-none absolute -inset-x-10 top-0 h-[2px] bg-gradient-to-r from-transparent via-orange-500/40 to-transparent animate-scanline" />

        <div className="relative p-7">
          <div className="flex items-start justify-between gap-6">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold tracking-wide text-slate-100">
                <Globe2 className="h-3.5 w-3.5 text-cyan-300" />
                CONNECT ATLAS
              </div>
              <h1 className="mt-3 text-3xl font-semibold text-slate-950">
                Snapshot & Replicate Amazon Connect
              </h1>
              <p className="mt-2 max-w-3xl text-sm text-slate-600">{headerKicker}</p>
            </div>

            <div className="rounded-2xl border border-slate-200 bg-white/70 px-4 py-3 backdrop-blur">
              <div className="text-[11px] font-semibold uppercase tracking-wider text-slate-500">Operator status</div>
              <div className="mt-1 flex items-center gap-2">
                {busy ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin text-slate-700" />
                    <span className="text-sm font-medium text-slate-800">{busy}</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                    <span className="text-sm font-medium text-slate-800">ready</span>
                  </>
                )}
              </div>
            </div>
          </div>

          <div className="mt-7 grid gap-6 lg:grid-cols-12">
            {/* Left: Regions + Instances */}
            <div className="lg:col-span-7">
              <div className="rounded-2xl border border-slate-200 bg-white/70 backdrop-blur">
                <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Regions</div>
                    <div className="mt-1 text-sm font-medium text-slate-900">Pick a source region</div>
                  </div>
                  <div className="text-xs text-slate-500">{regions.length ? `${regions.length} listed` : 'loading…'}</div>
                </div>

                <div className="flex flex-wrap gap-2 p-5">
                  {regions.map((r) => {
                    const active = r.code === region
                    const isGR = Boolean(globalTargets[r.code]?.length)
                    return (
                      <button
                        key={r.code}
                        onClick={() => setRegion(r.code)}
                        className={classNames(
                          'group inline-flex items-center gap-2 rounded-full px-3 py-2 text-sm transition',
                          active
                            ? 'bg-slate-950 text-white shadow'
                            : 'bg-white text-slate-700 hover:bg-slate-50 border border-slate-200',
                        )}
                      >
                        <span className={classNames('h-2 w-2 rounded-full', isGR ? 'bg-emerald-400' : 'bg-slate-300')} />
                        <span className="font-medium">{r.code}</span>
                        <span className={classNames('text-xs', active ? 'text-slate-300' : 'text-slate-400')}>
                          {r.name}
                        </span>
                      </button>
                    )
                  })}
                </div>
              </div>

              <div className="mt-6 rounded-2xl border border-slate-200 bg-white/70 backdrop-blur">
                <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Instances</div>
                    <div className="mt-1 text-sm font-medium text-slate-900">{themeRegionName(region)}</div>
                  </div>
                  <div className="text-xs text-slate-500">
                    {instancesLoading ? 'scanning…' : `${instances.length} found`}
                  </div>
                </div>

                <div className="max-h-[440px] overflow-auto p-2">
                  {instances.map((inst) => {
                    const active = selected?.Id && inst.Id === selected.Id
                    return (
                      <button
                        key={inst.Id || inst.Arn}
                        onClick={() => setSelected(inst)}
                        className={classNames(
                          'w-full rounded-xl px-4 py-3 text-left transition',
                          active
                            ? 'bg-slate-950 text-white'
                            : 'bg-white hover:bg-slate-50 border border-slate-200',
                        )}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className={classNames('text-sm font-semibold', active ? 'text-white' : 'text-slate-900')}>
                              {inst.InstanceAlias || '(no alias)'}
                            </div>
                            <div className={classNames('mt-1 font-mono text-xs', active ? 'text-slate-300' : 'text-slate-500')}>
                              {inst.Id}
                            </div>
                          </div>
                          <div className="text-right">
                            <div
                              className={classNames(
                                'inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold',
                                inst.InstanceStatus === 'ACTIVE'
                                  ? active
                                    ? 'bg-emerald-400/20 text-emerald-200'
                                    : 'bg-emerald-50 text-emerald-700'
                                  : active
                                    ? 'bg-amber-300/15 text-amber-200'
                                    : 'bg-amber-50 text-amber-700',
                              )}
                            >
                              {inst.InstanceStatus || 'UNKNOWN'}
                            </div>
                            <div className={classNames('mt-2 text-xs', active ? 'text-slate-300' : 'text-slate-500')}>
                              {inst.IdentityManagementType || '—'}
                            </div>
                          </div>
                        </div>
                      </button>
                    )
                  })}

                  {!instancesLoading && instances.length === 0 && (
                    <div className="p-6 text-sm text-slate-600">
                      No instances found in this region (or AWS creds not configured for the API server).
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Right: Selected + Actions */}
            <div className="lg:col-span-5">
              <div className="rounded-2xl border border-slate-200 bg-white/70 backdrop-blur">
                <div className="border-b border-slate-200 px-5 py-4">
                  <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Selection</div>
                  <div className="mt-1 text-sm font-medium text-slate-900">
                    {selected ? selected.InstanceAlias || selected.Id : 'Choose an instance'}
                  </div>
                </div>

                <div className="p-5">
                  {selected ? (
                    <div className="space-y-4">
                      <div className="rounded-xl border border-slate-200 bg-white p-4">
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Source</div>
                            <div className="mt-1 text-sm font-semibold text-slate-900">{region}</div>
                            <div className="mt-1 text-xs text-slate-600">{themeRegionName(region)}</div>
                          </div>
                          <div className="text-right">
                            {detailsLoading ? (
                              <div className="inline-flex items-center gap-2 rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold text-white">
                                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                                preflight
                              </div>
                            ) : (
                              <div className="inline-flex items-center gap-2 rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold text-white">
                                <ShieldCheck className="h-3.5 w-3.5 text-emerald-300" />
                                checks
                              </div>
                            )}
                          </div>
                        </div>

                        <div className="mt-4 grid gap-2">
                          <CheckItem ok={preflight.active} label="Instance status ACTIVE" />
                          <CheckItem ok={preflight.saml} label="Identity type SAML (required)" />
                          <CheckItem ok={preflight.allowedPair} label="Region pairing supported" />
                        </div>
                      </div>

                      <div className="rounded-xl border border-slate-200 bg-white p-4">
                        <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Target region</div>
                        <div className="mt-2 grid gap-2">
                          <select
                            value={targetRegion}
                            onChange={(e) => setTargetRegion(e.target.value)}
                            className={classNames(
                              'w-full rounded-xl border px-4 py-2 text-sm font-medium outline-none transition',
                              isAllowedPair
                                ? 'border-slate-200 bg-white focus:border-orange-400 focus:ring-2 focus:ring-orange-200'
                                : 'border-amber-300 bg-amber-50 focus:border-amber-400 focus:ring-2 focus:ring-amber-200',
                            )}
                          >
                            {regions.map((r) => (
                              <option key={r.code} value={r.code}>
                                {r.code} — {r.name}
                              </option>
                            ))}
                          </select>
                          {!isAllowedPair && (
                            <div className="flex items-start gap-2 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900">
                              <AlertTriangle className="mt-0.5 h-4 w-4" />
                              <div>
                                This pairing isn’t in the documented Global Resiliency list for the source region.
                              </div>
                            </div>
                          )}
                        </div>

                        <div className="mt-4 text-xs font-semibold uppercase tracking-wider text-slate-500">Replica alias</div>
                        <input
                          value={replicaAlias}
                          onChange={(e) => {
                            setAliasTouched(true)
                            setReplicaAlias(sanitizeAlias(e.target.value))
                          }}
                          className="mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-medium outline-none focus:border-cyan-400 focus:ring-2 focus:ring-cyan-200"
                          placeholder="unique-alias"
                        />
                        <div className="mt-2 text-xs text-slate-500">
                          Must be unique and max 45 chars; we’ll auto-sanitize.
                        </div>
                      </div>

                      <div className="grid grid-cols-2 gap-3">
                        <button
                          onClick={snapshot}
                          disabled={!!busy}
                          className="group inline-flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-900 transition hover:bg-slate-50 disabled:opacity-50"
                        >
                          {busy === 'snapshot' ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <FileDown className="h-4 w-4 text-slate-700" />
                          )}
                          Snapshot
                        </button>

                        <button
                          onClick={() => setConfirmOpen(true)}
                          disabled={!!busy || !replicaAlias || !selectedDetails}
                          className="group inline-flex items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-900 disabled:opacity-50"
                        >
                          <Copy className="h-4 w-4 text-orange-300" />
                          Replicate
                          <ArrowRight className="h-4 w-4 opacity-70" />
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="rounded-xl border border-dashed border-slate-300 bg-white p-6 text-sm text-slate-600">
                      Select an instance on the left to enable snapshot + replication actions.
                    </div>
                  )}
                </div>
              </div>

              <div className="mt-6 rounded-2xl border border-slate-200 bg-white/70 backdrop-blur">
                <div className="border-b border-slate-200 px-5 py-4">
                  <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Activity</div>
                  <div className="mt-1 text-sm font-medium text-slate-900">Latest events</div>
                </div>
                <div className="max-h-[260px] overflow-auto p-4">
                  {actionLog.length === 0 ? (
                    <div className="text-sm text-slate-600">No activity yet.</div>
                  ) : (
                    <ul className="space-y-2">
                      {actionLog.slice(0, 25).map((e, idx) => (
                        <li key={idx} className="flex items-start gap-2">
                          <span
                            className={classNames(
                              'mt-1 h-2 w-2 rounded-full',
                              e.tone === 'ok'
                                ? 'bg-emerald-400'
                                : e.tone === 'warn'
                                  ? 'bg-amber-400'
                                  : 'bg-rose-400',
                            )}
                          />
                          <div>
                            <div className="text-xs font-mono text-slate-500">{new Date(e.ts).toLocaleTimeString()}</div>
                            <div className="text-sm text-slate-800">{e.msg}</div>
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <ConfirmModal
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        sourceRegion={region}
        targetRegion={targetRegion}
        instanceAlias={selectedDetails?.InstanceAlias || selected?.InstanceAlias || ''}
        instanceId={selectedDetails?.Id || selected?.Id || ''}
        replicaAlias={replicaAlias}
        preflight={preflight}
        onConfirm={async () => {
          setConfirmOpen(false)
          await startReplication()
        }}
      />
    </div>
  )
}

function CheckItem({ ok, label }: { ok: boolean; label: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-slate-200 bg-slate-50 px-3 py-2">
      <div className="text-sm font-medium text-slate-800">{label}</div>
      {ok ? (
        <CheckCircle2 className="h-4 w-4 text-emerald-600" />
      ) : (
        <XCircle className="h-4 w-4 text-rose-600" />
      )}
    </div>
  )
}

function ConfirmModal(props: {
  open: boolean
  onClose: () => void
  onConfirm: () => void
  sourceRegion: string
  targetRegion: string
  instanceAlias: string
  instanceId: string
  replicaAlias: string
  preflight: { active: boolean; saml: boolean; allowedPair: boolean }
}) {
  const { open, onClose, onConfirm, preflight } = props
  if (!open) return null

  const canProceed = preflight.active && preflight.saml && preflight.allowedPair

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-6">
      <div className="absolute inset-0 bg-slate-950/40 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-xl overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-2xl">
        <div className="p-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Confirm replication</div>
              <h2 className="mt-2 text-xl font-semibold text-slate-950">Last chance before the wire</h2>
              <p className="mt-1 text-sm text-slate-600">
                This triggers <span className="font-mono">ReplicateInstance</span> in the source region.
              </p>
            </div>
            <button
              onClick={onClose}
              className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
            >
              Close
            </button>
          </div>

          <div className="mt-5 grid gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4">
            <Row k="Source" v={`${props.sourceRegion}  →  ${props.targetRegion}`} />
            <Row k="Instance" v={props.instanceAlias || props.instanceId} />
            <Row k="Replica alias" v={props.replicaAlias} mono />
          </div>

          <div className="mt-5">
            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">Preflight</div>
            <div className="mt-2 grid gap-2">
              <CheckItem ok={preflight.active} label="Source instance ACTIVE" />
              <CheckItem ok={preflight.saml} label="SAML enabled" />
              <CheckItem ok={preflight.allowedPair} label="Region pairing supported" />
            </div>
            {!canProceed && (
              <div className="mt-3 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
                Fix the failed checks before proceeding.
              </div>
            )}
          </div>
        </div>

        <div className="flex items-center justify-between gap-3 border-t border-slate-200 bg-white p-5">
          <div className="text-xs text-slate-500">
            Tip: run a snapshot first so you can diff configs if ReplicateInstance hits conflicts.
          </div>
          <button
            onClick={onConfirm}
            disabled={!canProceed}
            className="inline-flex items-center gap-2 rounded-xl bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-slate-900 disabled:opacity-50"
          >
            <Copy className="h-4 w-4 text-orange-300" />
            Confirm & replicate
          </button>
        </div>
      </div>
    </div>
  )
}

function Row({ k, v, mono }: { k: string; v: string; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between gap-3">
      <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">{k}</div>
      <div className={classNames('text-sm font-semibold text-slate-900', mono && 'font-mono')}>{v}</div>
    </div>
  )
}
