import { http } from '@kit.NetworkKit'
import {
  ArenaMode,
  ArenaRun,
  ArenaRunRequest,
  ArenaRunResponse,
  BuildAgentsRequest,
  BuildAgentsResponse,
  ParseTimelineRequest,
  ParseTimelineResponse,
  PersonaSpec,
  PresetProfile,
  PresetsResponse,
  ProfileBundle,
  SelectedAgentsBundle,
  TimelineNode
} from '../common/Models'
import {
  buildAgents,
  buildArenaRun,
  getPresetProfiles,
  getProfileById,
  getTimelineByProfileId
} from '../data/MockData'

const API_BASE_URLS: string[] = [
  'http://192.168.51.148:3030',
  'http://10.0.2.2:3030',
  'http://127.0.0.1:3030',
  'http://localhost:3030'
]

const PROFILE_TIMEOUT_MS: number = 45_000
const GENERATION_TIMEOUT_MS: number = 180_000

let activeBaseUrl: string = API_BASE_URLS[0]
let lastConnectionLabel: string = 'LIVE · 192.168.51.148:3030'

function orderedBaseUrls(): string[] {
  let result: string[] = [activeBaseUrl]
  API_BASE_URLS.forEach((url: string) => {
    if (url !== activeBaseUrl) {
      result.push(url)
    }
  })
  return result
}

function rememberBaseUrl(baseUrl: string): void {
  activeBaseUrl = baseUrl
  lastConnectionLabel = `LIVE · ${baseUrl.replace('http://', '')}`
}

function markMock(): void {
  lastConnectionLabel = 'MOCK FALLBACK'
}

function normalizePayload(result: Object | string): string {
  if (typeof result === 'string') {
    return result
  }
  return JSON.stringify(result)
}

function parseJson<T>(result: Object | string): T {
  return JSON.parse(normalizePayload(result)) as T
}

function parseErrorMessage(result: Object | string, statusCode: number): string {
  try {
    const payload = parseJson<Record<string, Object | string>>(result)
    const errorValue = payload.error

    if (typeof errorValue === 'string') {
      return errorValue
    }

    if (errorValue) {
      const flatError = errorValue as Record<string, Object>
      const fieldErrors = flatError.fieldErrors as Record<string, string[]> | undefined
      if (fieldErrors) {
        let messages: string[] = []
        Object.keys(fieldErrors).forEach((key: string) => {
          const values = fieldErrors[key]
          if (values && values.length > 0) {
            messages.push(`${key}: ${values[0]}`)
          }
        })
        if (messages.length > 0) {
          return messages.join('；')
        }
      }
    }
  } catch (_error) {
  }

  return `请求失败 ${statusCode}`
}

function formatThrownError(error: Object): string {
  if (typeof error === 'string') {
    return error
  }

  const maybeMessage = error as Record<string, string>
  if (maybeMessage.message) {
    return maybeMessage.message
  }

  return JSON.stringify(error)
}

function buildMockBundle(profileId: string): ProfileBundle | null {
  const profile = getProfileById(profileId)
  if (!profile.id.length) {
    return null
  }

  const nodes = getTimelineByProfileId(profileId)
  return {
    profile,
    nodes,
    agents: buildAgents(profile.id, profile.displayName, nodes)
  }
}

function buildCustomProfile(profileId: string, displayName: string, biography: string, nodes: TimelineNode[]): PresetProfile {
  return {
    id: profileId,
    displayName,
    subtitle: '自定义导入角色',
    category: 'self',
    coverSeed: profileId,
    biography,
    highlights: nodes.slice(0, 4).map((node: TimelineNode) => node.stageLabel),
    suggestedTopics: [
      '现在最该坚持的到底是什么？',
      '应该继续投入还是及时止损？',
      '边界、野心和现实怎么重新排序？'
    ]
  }
}

function buildParseTimelineRequest(displayName: string, biography: string): ParseTimelineRequest {
  return {
    displayName,
    biography
  }
}

function buildAgentsRequest(parsed: ParseTimelineResponse, biography: string): BuildAgentsRequest {
  return {
    personId: parsed.personId,
    displayName: parsed.displayName,
    biography,
    nodes: parsed.nodes
  }
}

function buildArenaRunRequest(topic: string, mode: ArenaMode, selectedAgents: PersonaSpec[]): ArenaRunRequest {
  return {
    topic,
    mode,
    selectedAgentIds: selectedAgents.map((agent: PersonaSpec) => agent.agentId),
    agents: selectedAgents
  }
}

async function requestJson<T>(path: string, method: http.RequestMethod, body?: Object, timeoutMs: number = PROFILE_TIMEOUT_MS): Promise<T> {
  let lastError: string = `请求 ${path} 失败`

  for (let baseUrl of orderedBaseUrls()) {
    const client = http.createHttp()

    try {
      let response = await client.request(`${baseUrl}${path}`, {
        method,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: body ? JSON.stringify(body) : '',
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs
      })

      if (response.responseCode >= 200 && response.responseCode < 300) {
        rememberBaseUrl(baseUrl)
        return parseJson<T>(response.result)
      }

      lastError = parseErrorMessage(response.result, response.responseCode)
    } catch (error) {
      lastError = formatThrownError(error as Object)
    } finally {
      client.destroy()
    }
  }

  throw new Error(lastError)
}

export class PersonaApi {
  static getConnectionLabel(): string {
    return lastConnectionLabel
  }

  static async getPresets(): Promise<PresetProfile[]> {
    try {
      const result = await requestJson<PresetsResponse>('/api/presets', http.RequestMethod.GET)
      return result.presets
    } catch (_error) {
      markMock()
      return Promise.resolve(getPresetProfiles())
    }
  }

  static async getProfileBundle(profileId: string): Promise<ProfileBundle> {
    try {
      return await requestJson<ProfileBundle>(`/api/profiles/${encodeURIComponent(profileId)}`, http.RequestMethod.GET)
    } catch (error) {
      const mockBundle = buildMockBundle(profileId)
      if (mockBundle) {
        markMock()
        return Promise.resolve(mockBundle)
      }
      throw new Error(formatThrownError(error as Object))
    }
  }

  static async getSelectedAgents(profileId: string, selectedAgentIds: string[]): Promise<SelectedAgentsBundle> {
    const bundle = await PersonaApi.getProfileBundle(profileId)
    const selectedAgents = bundle.agents.filter((agent: PersonaSpec) => selectedAgentIds.includes(agent.agentId))
    let selectedBundle: SelectedAgentsBundle = { profile: bundle.profile, selectedAgents }
    return Promise.resolve(selectedBundle)
  }

  static async importCustomProfile(displayName: string, biography: string): Promise<ProfileBundle> {
    const parseRequest: ParseTimelineRequest = buildParseTimelineRequest(displayName, biography)
    const parsed = await requestJson<ParseTimelineResponse>('/api/timeline/parse', http.RequestMethod.POST, parseRequest, GENERATION_TIMEOUT_MS)

    const agentsRequest: BuildAgentsRequest = buildAgentsRequest(parsed, biography)
    const built = await requestJson<BuildAgentsResponse>('/api/agents/build', http.RequestMethod.POST, agentsRequest, GENERATION_TIMEOUT_MS)

    try {
      const storedBundle = await requestJson<ProfileBundle>(`/api/profiles/${encodeURIComponent(parsed.personId)}`, http.RequestMethod.GET)
      if (storedBundle.agents.length === 0) {
        storedBundle.agents = built.agents
      }
      return storedBundle
    } catch (_error) {
      const fallbackBundle: ProfileBundle = {
        profile: buildCustomProfile(parsed.personId, parsed.displayName, biography, parsed.nodes),
        nodes: parsed.nodes,
        agents: built.agents
      }
      return Promise.resolve(fallbackBundle)
    }
  }

  static async runArena(topic: string, selectedAgents: PersonaSpec[], mode: ArenaMode = 'chat'): Promise<ArenaRun> {
    try {
      const arenaRequest: ArenaRunRequest = buildArenaRunRequest(topic, mode, selectedAgents)
      const result = await requestJson<ArenaRunResponse>('/api/arena/run', http.RequestMethod.POST, arenaRequest, GENERATION_TIMEOUT_MS)
      return result.result
    } catch (_error) {
      markMock()
      return Promise.resolve(buildArenaRun(topic, selectedAgents, mode))
    }
  }
}
