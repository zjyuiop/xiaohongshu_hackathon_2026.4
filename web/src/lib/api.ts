import {
  buildMockAgents,
  presets as mockPresets,
  timelineMap,
} from './mock'
import type {
  ArenaOutputLinks,
  ArenaPosterResponse,
  ArenaRun,
  ArenaRunHistoryItem,
  ArenaRunRequestPayload,
  ArenaRunResponseEnvelope,
  ArenaStreamEvent,
  PersonaSpec,
  PresetProfile,
  PosterAspectRatio,
  PosterStylePreset,
  TimelineNode,
} from '../types'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''

function parseApiError(payload: unknown, status: number): Error {
  if (payload && typeof payload === 'object' && 'error' in payload) {
    const errorValue = (payload as { error?: unknown }).error

    if (typeof errorValue === 'string') {
      return new Error(errorValue)
    }

    if (errorValue && typeof errorValue === 'object' && 'fieldErrors' in errorValue) {
      const fieldErrors = (errorValue as { fieldErrors?: Record<string, string[]> }).fieldErrors
      if (fieldErrors) {
        const first = Object.entries(fieldErrors).flatMap(([key, values]) => values.map((value) => `${key}: ${value}`))[0]
        if (first) {
          return new Error(first)
        }
      }
    }
  }

  return new Error(`请求失败: ${status}`)
}

async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, init)

  if (!response.ok) {
    let payload: unknown
    try {
      payload = await response.json()
    } catch {
      payload = null
    }
    throw parseApiError(payload, response.status)
  }

  return response.json() as Promise<T>
}

export async function loadPresets(): Promise<PresetProfile[]> {
  try {
    const result = await fetchJson<{ presets: PresetProfile[] }>('/api/presets')
    return result.presets
  } catch {
    return mockPresets
  }
}

/** Load a preset profile bundle in one shot (profile + nodes + agents) */
export async function loadProfile(profileId: string): Promise<{
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
}> {
  return fetchJson(`/api/profiles/${encodeURIComponent(profileId)}`)
}

export async function parseTimeline(input: {
  profileId?: string
  displayName: string
  biography: string
}): Promise<{ personId: string; displayName: string; nodes: TimelineNode[] }> {
  try {
    return await fetchJson('/api/timeline/parse', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(input),
    })
  } catch {
    const profileId = input.profileId ?? 'custom'
    return {
      personId: profileId,
      displayName: input.displayName,
      nodes: timelineMap[profileId] ?? timelineMap.graduate,
    }
  }
}

export async function buildAgents(input: {
  personId: string
  displayName: string
  biography?: string
  nodes: TimelineNode[]
}): Promise<PersonaSpec[]> {
  try {
    const result = await fetchJson<{ agents: PersonaSpec[] }>('/api/agents/build', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(input),
    })
    return result.agents
  } catch {
    return buildMockAgents(input.personId, input.displayName, input.nodes)
  }
}

export async function runArena(input: ArenaRunRequestPayload): Promise<ArenaRunResponseEnvelope> {
  return fetchJson<ArenaRunResponseEnvelope>('/api/arena/run', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(input),
  })
}

export async function runArenaStream(
  input: ArenaRunRequestPayload,
  options: {
    signal?: AbortSignal
    onEvent: (event: ArenaStreamEvent) => void
  },
): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/api/arena/stream`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    },
    body: JSON.stringify(input),
    signal: options.signal,
  })

  if (!response.ok) {
    let payload: unknown
    try {
      payload = await response.json()
    } catch {
      payload = null
    }
    throw parseApiError(payload, response.status)
  }

  if (!response.body) {
    throw new Error('流式响应体为空')
  }

  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  let terminalEventReceived = false

  const flushBlock = (block: string) => {
    const lines = block.split(/\r?\n/)
    let eventName = ''
    const dataLines: string[] = []

    for (const line of lines) {
      if (line.startsWith(':')) {
        continue
      }

      if (line.startsWith('event:')) {
        eventName = line.slice(6).trim()
        continue
      }

      if (line.startsWith('data:')) {
        dataLines.push(line.slice(5).trim())
      }
    }

    if (!eventName || dataLines.length === 0) {
      return
    }

    const parsed = JSON.parse(dataLines.join('\n')) as ArenaStreamEvent
    if (parsed.type === 'done' || parsed.type === 'error') {
      terminalEventReceived = true
    }
    options.onEvent(parsed)
  }

  while (true) {
    const { done, value } = await reader.read()
    if (done) {
      break
    }

    buffer += decoder.decode(value, { stream: true })

    while (true) {
      const separatorIndex = buffer.indexOf('\n\n')
      if (separatorIndex === -1) {
        break
      }

      const block = buffer.slice(0, separatorIndex)
      buffer = buffer.slice(separatorIndex + 2)
      flushBlock(block)
    }
  }

  buffer += decoder.decode()
  if (buffer.trim()) {
    flushBlock(buffer.trim())
  }

  if (!terminalEventReceived && !options.signal?.aborted) {
    throw new Error('讨论流提前结束，未收到 done/error 终止事件')
  }
}

export async function loadArenaRun(runId: string): Promise<ArenaRunResponseEnvelope> {
  return fetchJson<ArenaRunResponseEnvelope>(`/api/arena/runs/${encodeURIComponent(runId)}`)
}

export async function loadArenaHistory(limit = 20): Promise<ArenaRunHistoryItem[]> {
  const query = new URLSearchParams({ limit: String(limit) }).toString()
  const result = await fetchJson<{ runs: ArenaRunHistoryItem[] }>(`/api/arena/history?${query}`)
  return result.runs
}

export async function interruptArenaSession(sessionId: string): Promise<void> {
  await fetchJson<{ ok: boolean; sessionId: string }>(`/api/arena/sessions/${encodeURIComponent(sessionId)}/interrupt`, {
    method: 'POST',
  })
}

export async function generateArenaPoster(input: {
  runId?: string
  run?: ArenaRun
  stylePreset?: PosterStylePreset
  aspectRatio?: PosterAspectRatio
  language?: string
}): Promise<ArenaPosterResponse> {
  return fetchJson<ArenaPosterResponse>('/api/arena/poster', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(input),
  })
}

export function buildSuggestedShareUrl(links: ArenaOutputLinks | undefined, runId: string): string {
  if (links?.suggestedShareUrl) {
    return links.suggestedShareUrl
  }

  if (links?.suggestedSharePath) {
    return `${window.location.origin}${links.suggestedSharePath}`
  }

  return `${window.location.origin}/share/${encodeURIComponent(runId)}`
}
