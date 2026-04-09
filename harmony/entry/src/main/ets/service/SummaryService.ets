import { http } from '@kit.NetworkKit'
import { common } from '@kit.AbilityKit'
import dataPreferences from '@ohos.data.preferences'
import {
  SummaryRecord,
  SummaryListItem,
  SummaryListResponse,
  SummaryDetailResponse,
  SummaryFilter,
  CreateSummaryRequest,
  UpdateSummaryRequest,
  ShareData,
  HapShareData,
  SummaryParticipant,
  ArenaRun
} from '../common/Models'

const SUMMARY_API_BASE_URL = 'https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com'

let summaryPrefs: dataPreferences.Preferences | null = null

const STORAGE_KEY_SUMMARY_LIST = 'summary_list'
const STORAGE_KEY_SUMMARY_DETAIL_PREFIX = 'summary_detail_'

const PARTICIPANT_COLORS: string[] = [
  '#FEE2E2', '#DBEAFE', '#D1FAE5', '#FEF3C7', '#E9D5FF',
  '#FECACA', '#BFDBFE', '#A7F3D0', '#FDE68A', '#DDD6FE'
]

const AVATAR_TEXT_COLORS: string[] = [
  '#DC2626', '#2563EB', '#059669', '#D97706', '#7C3AED',
  '#EF4444', '#3B82F6', '#10B981', '#F59E0B', '#8B5CF6'
]

function formatTimeAgo(dateStr: string): string {
  const date = new Date(dateStr)
  if (Number.isNaN(date.getTime())) {
    return '刚刚'
  }

  const now = new Date()
  const diffMs = Math.max(0, now.getTime() - date.getTime())
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

  if (diffDays <= 0) {
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
    if (diffHours <= 0) {
      const diffMins = Math.floor(diffMs / (1000 * 60))
      return diffMins <= 1 ? '刚刚' : `${diffMins} 分钟前`
    }
    return diffHours === 1 ? '1 小时前' : `${diffHours} 小时前`
  }

  if (diffDays === 1) {
    return '昨天'
  }
  if (diffDays < 7) {
    return `${diffDays} 天前`
  }
  if (diffDays < 30) {
    return `${Math.floor(diffDays / 7)} 周前`
  }
  return `${Math.floor(diffDays / 30)} 个月前`
}

function generateId(): string {
  return `summary_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}

function getParticipantColor(index: number): string {
  return PARTICIPANT_COLORS[index % PARTICIPANT_COLORS.length]
}

function getAvatarTextColor(index: number): string {
  return AVATAR_TEXT_COLORS[index % AVATAR_TEXT_COLORS.length]
}

interface ErrorPayload {
  error?: string
  fieldErrors?: Record<string, string[]>
}

function parseErrorMessage(result: Object | string, statusCode: number): string {
  try {
    const payloadStr = typeof result === 'string' ? result : JSON.stringify(result)
    const payload: ErrorPayload = JSON.parse(payloadStr)
    if (payload.error && typeof payload.error === 'string') {
      return payload.error
    }
    if (payload.fieldErrors) {
      const keys = Object.keys(payload.fieldErrors)
      if (keys.length > 0 && payload.fieldErrors[keys[0]] && payload.fieldErrors[keys[0]].length > 0) {
        return `${keys[0]}: ${payload.fieldErrors[keys[0]][0]}`
      }
    }
  } catch (_error) {
  }
  return `请求失败 ${statusCode}`
}

interface ErrorWithMessage {
  message?: string
}

function formatThrownError(error: Object): string {
  if (typeof error === 'string') {
    return error
  }
  const err = error as ErrorWithMessage
  if (err.message) {
    return err.message
  }
  return JSON.stringify(error)
}

function createEmptySummaryRecord(): SummaryRecord {
  return {
    id: '',
    title: '',
    topic: '',
    createdAt: '',
    updatedAt: '',
    duration: 0,
    messageCount: 0,
    consensus: '',
    disagreements: [],
    actionableAdvice: [],
    narrativeHook: '',
    participants: [],
    highlights: [],
    tags: [],
    isFavorite: false,
    viewCount: 0,
    exportedAssets: [],
    messageIds: []
  }
}

function convertArenaRunToSummaryRecord(arenaRun: ArenaRun, profileId: string | undefined): SummaryRecord {
  const result = createEmptySummaryRecord()
  result.id = generateId()
  result.title = arenaRun.summary.title || '阶段人格会议纪要'
  result.topic = arenaRun.topic
  result.createdAt = new Date().toISOString()
  result.updatedAt = result.createdAt
  result.messageCount = arenaRun.messages.length
  result.consensus = arenaRun.summary.consensus
  result.disagreements = arenaRun.summary.disagreements
  result.actionableAdvice = arenaRun.summary.actionableAdvice
  result.narrativeHook = arenaRun.summary.narrativeHook
  result.moderatorNote = arenaRun.summary.moderatorNote
  result.arenaRunId = arenaRun.runId
  result.profileId = profileId

  result.participants = arenaRun.participants.map((agent, index): SummaryParticipant => {
    return {
      agentId: agent.agentId,
      displayName: agent.displayName,
      stageLabel: agent.stageLabel,
      avatarSeed: agent.avatarSeed,
      accentColor: getParticipantColor(index)
    }
  })

  const contentList: string[] = []
  for (let i = Math.max(0, arenaRun.messages.length - 4); i < arenaRun.messages.length; i++) {
    const content = arenaRun.messages[i].content
    if (content.length > 10 && content.length < 100) {
      contentList.push(content)
    }
  }
  result.highlights = contentList.slice(0, 3)
  return result
}

function convertToListItem(record: SummaryRecord): SummaryListItem {
  const participantNames = record.participants.map((participant: SummaryParticipant) => participant.displayName)
  const participantAvatars = record.participants.map((participant: SummaryParticipant) => {
    return participant.displayName.length > 0 ? participant.displayName.charAt(0) : '?'
  })
  const avatarColors = record.participants.map((_participant: SummaryParticipant, index: number) => getParticipantColor(index))
  const previewConsensus = record.consensus.length > 50 ? `${record.consensus.substring(0, 50)}...` : record.consensus

  return {
    id: record.id,
    title: record.title,
    topic: record.topic,
    createdAt: record.createdAt,
    timeAgo: formatTimeAgo(record.createdAt),
    participantNames: participantNames,
    participantAvatars: participantAvatars,
    avatarColors: avatarColors,
    accentColor: record.participants.length > 0 ? record.participants[0].accentColor : '#4ECDC4',
    consensusPreview: previewConsensus,
    highlightCount: record.highlights.length,
    isFavorite: record.isFavorite,
    messageCount: record.messageCount,
    duration: record.duration
  }
}

async function requestJson<T>(path: string, method: http.RequestMethod, body: Object | undefined, timeoutMs: number): Promise<T> {
  const client = http.createHttp()
  try {
    const response = await client.request(`${SUMMARY_API_BASE_URL}${path}`, {
      method: method,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: body ? JSON.stringify(body) : '',
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    })

    if (response.responseCode >= 200 && response.responseCode < 300) {
      const resultStr = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      return JSON.parse(resultStr) as T
    }

    const errMsg = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
    throw new Error(parseErrorMessage(errMsg, response.responseCode))
  } catch (error) {
    throw new Error(formatThrownError(error))
  } finally {
    client.destroy()
  }
}

function matchesSummaryFilter(record: SummaryRecord, filter: SummaryFilter | undefined): boolean {
  if (!filter) {
    return true
  }

  if (filter.keyword && filter.keyword.trim().length > 0) {
    const keyword = filter.keyword.trim().toLowerCase()
    const haystack = `${record.title} ${record.topic} ${record.consensus} ${record.tags.join(' ')}`.toLowerCase()
    if (!haystack.includes(keyword)) {
      return false
    }
  }

  if (filter.category === 'favorite') {
    return record.isFavorite === true
  }

  if (filter.category === 'tag' && filter.tag && filter.tag.length > 0) {
    return record.tags.some((tag: string) => tag.includes(filter.tag!))
  }

  return true
}

export class SummaryService {
  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      summaryPrefs = await dataPreferences.getPreferences(context, 'time_persona_summary_store')
    } catch (error) {
      console.error('[SummaryService] init failed:', error)
    }
  }

  private static async loadAllRecordsFromStorage(): Promise<SummaryRecord[]> {
    if (!summaryPrefs) {
      return []
    }
    try {
      const raw = await summaryPrefs.get(STORAGE_KEY_SUMMARY_LIST, '[]')
      const str = typeof raw === 'string' ? raw : JSON.stringify(raw)
      const parsed = JSON.parse(str) as SummaryRecord[]
      return Array.isArray(parsed) ? parsed : []
    } catch (error) {
      console.error('[SummaryService] loadAllRecordsFromStorage failed:', error)
      return []
    }
  }

  private static async saveAllRecordsToStorage(records: SummaryRecord[]): Promise<void> {
    if (!summaryPrefs) {
      return
    }
    try {
      await summaryPrefs.put(STORAGE_KEY_SUMMARY_LIST, JSON.stringify(records))
      await summaryPrefs.flush()
    } catch (error) {
      console.error('[SummaryService] saveAllRecordsToStorage failed:', error)
    }
  }

  private static async upsertLocalRecord(record: SummaryRecord): Promise<void> {
    const records = await SummaryService.loadAllRecordsFromStorage()
    const index = records.findIndex((item: SummaryRecord) => item.id === record.id)
    if (index >= 0) {
      records[index] = record
    } else {
      records.unshift(record)
    }
    await SummaryService.saveAllRecordsToStorage(records)
  }

  private static async loadRecordById(summaryId: string): Promise<SummaryRecord | null> {
    const records = await SummaryService.loadAllRecordsFromStorage()
    const found = records.find((record: SummaryRecord) => record.id === summaryId)
    return found ? found : null
  }

  private static async removeLocalRecord(summaryId: string): Promise<boolean> {
    const records = await SummaryService.loadAllRecordsFromStorage()
    const next = records.filter((record: SummaryRecord) => record.id !== summaryId)
    if (next.length === records.length) {
      return false
    }
    await SummaryService.saveAllRecordsToStorage(next)
    return true
  }

  private static async buildLocalListResponse(filter: SummaryFilter | undefined): Promise<SummaryListResponse> {
    let records = await SummaryService.loadAllRecordsFromStorage()
    records = records.filter((record: SummaryRecord) => matchesSummaryFilter(record, filter))
    records.sort((a: SummaryRecord, b: SummaryRecord) => {
      const sortBy = filter?.sortBy || 'createdAt'
      const sortOrder = filter?.sortOrder || 'desc'
      const sign = sortOrder === 'asc' ? 1 : -1

      if (sortBy === 'viewCount') {
        return (a.viewCount - b.viewCount) * sign
      }
      const left = sortBy === 'updatedAt' ? a.updatedAt : a.createdAt
      const right = sortBy === 'updatedAt' ? b.updatedAt : b.createdAt
      return (new Date(left).getTime() - new Date(right).getTime()) * sign
    })

    return {
      total: records.length,
      items: records.map((record: SummaryRecord) => convertToListItem(record)),
      hasMore: false
    }
  }

  static async getSummaryList(filter: SummaryFilter | undefined): Promise<SummaryListResponse> {
    let remote: SummaryListResponse | null = null
    try {
      const parts: string[] = []
      if (filter?.category) parts.push(`category=${encodeURIComponent(filter.category)}`)
      if (filter?.tag) parts.push(`tag=${encodeURIComponent(filter.tag)}`)
      if (filter?.keyword) parts.push(`keyword=${encodeURIComponent(filter.keyword)}`)
      if (filter?.sortBy) parts.push(`sortBy=${encodeURIComponent(filter.sortBy)}`)
      if (filter?.sortOrder) parts.push(`sortOrder=${encodeURIComponent(filter.sortOrder)}`)
      const queryString = parts.length > 0 ? `?${parts.join('&')}` : ''
      remote = await requestJson<SummaryListResponse>(`/api/summaries${queryString}`, http.RequestMethod.GET, undefined, 20000)
    } catch (error) {
      console.info('[SummaryService] remote summaries list unavailable, using local:', error)
    }

    const local = await SummaryService.buildLocalListResponse(filter)
    return remote && remote.items.length > 0 ? remote : local
  }

  static async getSummaryDetail(summaryId: string): Promise<SummaryRecord | null> {
    try {
      const response = await requestJson<SummaryDetailResponse>(
        `/api/summaries/${encodeURIComponent(summaryId)}`,
        http.RequestMethod.GET,
        undefined,
        20000
      )
      return response.record
    } catch (error) {
      console.info('[SummaryService] remote detail unavailable, trying local:', error)
      return await SummaryService.loadRecordById(summaryId)
    }
  }

  static async createSummary(arenaRun: ArenaRun, profileId: string | undefined): Promise<SummaryRecord> {
    const summaryRecord = convertArenaRunToSummaryRecord(arenaRun, profileId)

    try {
      const request: CreateSummaryRequest = {
        arenaRunId: arenaRun.runId,
        profileId: profileId || '',
        topic: arenaRun.topic,
        summary: arenaRun.summary,
        participants: arenaRun.participants,
        messageIds: arenaRun.messages.map((message) => message.id),
        duration: 0
      }

      const response = await requestJson<SummaryDetailResponse>(
        '/api/summaries',
        http.RequestMethod.POST,
        request,
        30000
      )
      await SummaryService.upsertLocalRecord(response.record)
      return response.record
    } catch (error) {
      console.info('[SummaryService] createSummary remote unavailable, persisting locally:', error)
      await SummaryService.upsertLocalRecord(summaryRecord)
      return summaryRecord
    }
  }

  static async updateSummary(summaryId: string, updates: UpdateSummaryRequest): Promise<boolean> {
    let remoteOk = false
    try {
      await requestJson<Object>(
        `/api/summaries/${encodeURIComponent(summaryId)}`,
        http.RequestMethod.PUT,
        updates,
        20000
      )
      remoteOk = true
    } catch (error) {
      console.info('[SummaryService] updateSummary remote failed, updating local:', error)
    }

    const local = await SummaryService.loadRecordById(summaryId)
    if (!local) {
      return remoteOk
    }

    if (updates.isFavorite !== undefined) {
      local.isFavorite = updates.isFavorite
    }
    if (updates.title !== undefined) {
      local.title = updates.title
    }
    if (updates.tags !== undefined) {
      local.tags = updates.tags
    }
    if (updates.highlights !== undefined) {
      local.highlights = updates.highlights
    }
    local.updatedAt = new Date().toISOString()
    await SummaryService.upsertLocalRecord(local)
    return true
  }

  static async deleteSummary(summaryId: string): Promise<boolean> {
    let remoteOk = false
    try {
      await requestJson<Object>(
        `/api/summaries/${encodeURIComponent(summaryId)}`,
        http.RequestMethod.DELETE,
        undefined,
        20000
      )
      remoteOk = true
    } catch (error) {
      console.info('[SummaryService] deleteSummary remote failed:', error)
    }
    const removed = await SummaryService.removeLocalRecord(summaryId)
    return remoteOk || removed
  }

  static async toggleFavorite(summaryId: string, isFavorite: boolean): Promise<boolean> {
    return SummaryService.updateSummary(summaryId, { isFavorite: isFavorite })
  }

  static async getLocalSummaryListAsync(): Promise<SummaryListItem[]> {
    const response = await SummaryService.buildLocalListResponse(undefined)
    return response.items
  }

  static async getLocalSummaryDetailAsync(summaryId: string): Promise<SummaryRecord | null> {
    return SummaryService.loadRecordById(summaryId)
  }

  static generateShareData(record: SummaryRecord): ShareData {
    const tags = record.tags.length > 0 ? record.tags : ['阶段人格会议', '会议纪要']
    return {
      title: record.title,
      description: record.consensus.length > 0 ? record.consensus : record.topic,
      thumbnailPath: record.thumbnailPath,
      content: SummaryService.generateShareText(record),
      tags: tags
    }
  }

  static generateShareText(record: SummaryRecord): string {
    const lines: string[] = [
      `《${record.title}》`,
      `主题：${record.topic}`,
      `时间：${SummaryService.formatDateTime(record.createdAt)}`,
      `时长：${SummaryService.formatDuration(record.duration)}`,
      ''
    ]

    if (record.consensus.length > 0) {
      lines.push('核心共识')
      lines.push(record.consensus)
      lines.push('')
    }

    if (record.highlights.length > 0) {
      lines.push('亮点摘录')
      record.highlights.slice(0, 3).forEach((highlight: string) => {
        lines.push(`- ${highlight}`)
      })
      lines.push('')
    }

    if (record.actionableAdvice.length > 0) {
      lines.push('行动建议')
      for (let i = 0; i < record.actionableAdvice.length; i++) {
        lines.push(`${i + 1}. ${record.actionableAdvice[i]}`)
      }
      lines.push('')
    }

    if (record.disagreements.length > 0) {
      lines.push('仍待讨论')
      for (let i = 0; i < record.disagreements.length; i++) {
        lines.push(`${i + 1}. ${record.disagreements[i]}`)
      }
      lines.push('')
    }

    if (record.narrativeHook && record.narrativeHook.length > 0) {
      lines.push('一句总结')
      lines.push(record.narrativeHook)
      lines.push('')
    }

    const names = record.participants
      .map((participant: SummaryParticipant) => participant.displayName)
      .filter((name: string) => name.length > 0)

    if (names.length > 0) {
      lines.push(`参与角色：${names.join(' / ')}`)
      lines.push('')
    }

    lines.push('由阶段人格会议生成')
    return lines.join('\n').trim()
  }

  static generateHapShareData(record: SummaryRecord): HapShareData {
    return {
      summaryId: record.id,
      title: record.title,
      topic: record.topic,
      highlight: record.highlights.length > 0
        ? record.highlights[0]
        : (record.narrativeHook ? record.narrativeHook : record.consensus),
      avatarSeeds: record.participants.map((participant: SummaryParticipant) => participant.avatarSeed)
    }
  }

  static formatDuration(seconds: number): string {
    if (seconds <= 0) {
      return '未记录时长'
    }
    if (seconds < 60) {
      return `${seconds} 秒`
    }

    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = seconds % 60
    if (minutes < 60) {
      return remainingSeconds > 0 ? `${minutes} 分 ${remainingSeconds} 秒` : `${minutes} 分钟`
    }

    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60
    return remainingMinutes > 0 ? `${hours} 小时 ${remainingMinutes} 分钟` : `${hours} 小时`
  }

  static formatDate(dateStr: string): string {
    const date = new Date(dateStr)
    const year = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${year}年${month}月${day}日`
  }

  static formatDateTime(dateStr: string): string {
    const date = new Date(dateStr)
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}`
  }
}

export {
  STORAGE_KEY_SUMMARY_LIST,
  STORAGE_KEY_SUMMARY_DETAIL_PREFIX,
  formatTimeAgo,
  generateId,
  getParticipantColor,
  getAvatarTextColor,
  convertArenaRunToSummaryRecord,
  convertToListItem
}
