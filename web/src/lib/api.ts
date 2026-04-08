import {
  buildMockAgents,
  buildMockArena,
  presets as mockPresets,
  timelineMap,
} from './mock'
import type {
  ArenaMode,
  ArenaRun,
  PersonaSpec,
  PresetProfile,
  TimelineNode,
} from '../types'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3030'

async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, init)

  if (!response.ok) {
    throw new Error(`请求失败: ${response.status}`)
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

export async function runArena(input: {
  topic: string
  mode: ArenaMode
  selectedAgentIds: string[]
  agents: PersonaSpec[]
}): Promise<ArenaRun> {
  try {
    const result = await fetchJson<{ result: ArenaRun }>('/api/arena/run', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(input),
    })
    return result.result
  } catch {
    return buildMockArena(input.topic, input.mode, input.selectedAgentIds, input.agents)
  }
}
