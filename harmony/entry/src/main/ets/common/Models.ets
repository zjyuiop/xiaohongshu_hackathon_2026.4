export type ArenaMode = 'chat' | 'debate'
export type ReasoningEffort = 'low' | 'medium' | 'high' | 'xhigh'

// 人物类别 - 与 API 文档保持一致
export type PersonaCategory = 'self' | 'celebrity' | 'history' | 'fictional'

export interface PresetProfile {
  id: string
  displayName: string
  subtitle: string
  category: PersonaCategory
  coverSeed: string
  biography: string
  highlights: string[]
  suggestedTopics: string[]
}

export interface SourceEvidence {
  quote: string
  sourceLabel: string
}

// 时间线阶段类型
export type TimelineStageType = 'early' | 'turning-point' | 'stable' | 'crisis' | 'rebuild' | 'peak'

export interface TimelineNode {
  nodeId: string
  timeLabel: string
  ageLabel?: string
  stageLabel: string
  stageType: TimelineStageType
  keyEvent: string
  summary: string
  traits: string[]
  values: string[]
  tensions: string[]
  sourceEvidence: SourceEvidence[]
}

export interface PersonaSpec {
  agentId: string
  displayName: string
  personId: string
  avatarSeed: string
  timeLabel: string
  stageLabel: string
  keyEvent: string
  knownFacts: string[]
  sourceEvidence: SourceEvidence[]
  traits: string[]
  values: string[]
  goal: string
  fear: string
  voiceStyle: string
  knowledgeBoundary: string
  forbiddenFutureKnowledge: boolean
  stanceSeed: string
}

// Arena 消息立场
export type ArenaStance = 'support' | 'oppose' | 'reflective' | 'neutral'

// Arena 阶段类型
export type ArenaPhase = 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing' | 'manual'

export interface ArenaMessage {
  id: string
  kind?: 'agent' | 'user'
  agentId: string
  displayName: string
  stageLabel: string
  content: string
  stance: ArenaStance
  round?: number
  phase?: ArenaPhase
  replyToAgentId?: string
  replyToDisplayName?: string
  timestamp?: string
}

// 辩论评分卡
export interface DebateJudgeScorecard {
  agentId: string
  displayName: string
  argumentScore: number
  evidenceScore: number
  responsivenessScore: number
  comments: string
}

// 辩论裁决
export interface DebateVerdict {
  winnerAgentId?: string
  winnerDisplayName?: string
  rationale: string
  scorecards: DebateJudgeScorecard[]
}

export interface ArenaSummary {
  title: string
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
  moderatorNote?: string
  debateVerdict?: DebateVerdict
}

export interface ArenaRun {
  runId: string
  sessionId?: string
  continuedFromRunId?: string
  status?: 'completed' | 'interrupted'
  mode: ArenaMode
  topic: string
  participants: PersonaSpec[]
  messages: ArenaMessage[]
  summary: ArenaSummary
  config?: ArenaRunConfig
  createdAt?: string
}

export interface ArenaRunConfig {
  roundCount: number
  maxMessageChars: number
  reasoningEffort: ReasoningEffort
}

export interface SourceDocumentSummary {
  id: string
  title: string
  author?: string | null
  filePath: string
  importedAt: string
  sectionCount: number
}

export interface ProfileBundle {
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
  sourceDocument?: SourceDocumentSummary | null
}

export type ProfileImportType = 'manual' | 'wechat' | 'chat'

export interface ProfileImportSummary {
  importType: ProfileImportType
  sourceLabel: string
  title: string
  originalFileName: string
  mimeType: string
  extension: string
  charCount?: number
  messageCount?: number
}

export interface ProfileImportResponse {
  bundle: ProfileBundle
  import: ProfileImportSummary
}

export interface ProfileImportUploadRequest {
  importType: ProfileImportType
  fileName: string
  mimeType?: string
  title?: string
  displayNameHint?: string
  profileId?: string
  filePath?: string
  fileData?: string | ArrayBuffer
}

export interface SelectedAgentsBundle {
  profile: PresetProfile
  selectedAgents: PersonaSpec[]
}

export interface ParseTimelineResponse {
  personId: string
  displayName: string
  nodes: TimelineNode[]
}

export interface PresetsResponse {
  presets: PresetProfile[]
}

export interface ParseTimelineRequest {
  displayName: string
  biography: string
  profileId?: string
}

export interface BuildAgentsRequest {
  personId: string
  displayName: string
  biography?: string
  nodes: TimelineNode[]
}

export interface BuildAgentsResponse {
  agents: PersonaSpec[]
}

export interface MergeAgentsRequest {
  primary: PersonaSpec
  secondary: PersonaSpec
  displayName?: string
  mergePrompt?: string
}

export interface MergeAgentsExecution {
  requestedModel: string
  requestedEffort: ReasoningEffort
  effectiveModel: string
  effectiveEffort: 'low' | 'medium' | 'high' | 'max'
  fallbackUsed: boolean
  sessionId?: string
  durationMs: number
}

export interface MergeAgentsResponse {
  agent: PersonaSpec
  execution?: MergeAgentsExecution
}

export interface ArenaRunRequest {
  topic: string
  mode: ArenaMode
  selectedAgentIds: string[]
  agents: PersonaSpec[]
  reasoningEffort?: ReasoningEffort
  roundCount?: number
  maxMessageChars?: number
  guidance?: string
  continueFromRunId?: string
  sessionId?: string
}

export interface ArenaRunResponseEnvelope {
  result: ArenaRun
  links?: ArenaOutputLinks
}

export interface ArenaRunResponse extends ArenaRunResponseEnvelope {}

export interface ArenaRunHistoryItem {
  runId: string
  sessionId?: string
  continuedFromRunId?: string
  status?: 'completed' | 'interrupted'
  mode: ArenaMode
  topic: string
  title?: string
  consensus?: string
  participantNames: string[]
  participantStages?: string[]
  participantCount?: number
  messageCount?: number
  summaryTitle?: string
  consensusPreview?: string
  latestGuidance?: string
  createdAt?: string
}

export interface ArenaHistoryResponse {
  runs: ArenaRunHistoryItem[]
}

export interface ArenaRunDetailResponse {
  result: ArenaRun
  links?: ArenaOutputLinks
}

export interface ArenaSessionInterruptResponse {
  ok: boolean
  sessionId: string
}

// Arena 输出分享链接
export interface ArenaOutputLinks {
  runId: string
  shareApiPath: string
  shareApiUrl?: string
  suggestedSharePath: string
  suggestedShareUrl?: string
}

// Arena 海报资产
export interface ArenaPosterAsset {
  runId: string
  title: string
  summary: string
  stylePreset: 'poster' | 'editorial' | 'cinematic'
  aspectRatio: '16:9' | '2.35:1' | '4:3' | '3:2' | '1:1' | '3:4'
  outputDir: string
  imagePath: string
  imageUrl?: string
  promptPath?: string
  promptUrl?: string
  sourcePath?: string
  sourceUrl?: string
  generatedAt: string
}

export interface ArenaPosterRequest {
  runId?: string
  run?: ArenaRun
  stylePreset?: 'poster' | 'editorial' | 'cinematic'
  aspectRatio?: '16:9' | '2.35:1' | '4:3' | '3:2' | '1:1' | '3:4'
  language?: string
}

export interface ArenaPosterResponse {
  runId: string
  links: ArenaOutputLinks
  poster: ArenaPosterAsset
}

// 健康检查响应
export interface RuntimeInfo {
  mode: string
  claudeBinary?: string
  requestedModel?: string
  requestedEffort?: string
  fallbackModel?: string
  fallbackEffort?: string
  unsupportedModels?: string[]
}

export interface ImportState {
  running: boolean
  lastImportedProfileIds: string[]
  lastRunAt?: string
  lastError?: string
  documents?: number
  defaultProfiles?: number
  arenaRuns?: number
  libraryDir?: string
}

export interface HealthCheckResponse {
  ok: boolean
  error?: string
  runtime: RuntimeInfo
  import: ImportState
  timestamp: string
}

export interface ImportStatusState {
  running: boolean
  lastImportedProfileIds: string[]
  lastRunAt?: string
  lastError?: string
}

export interface ImportStatusOverview {
  documents: number
  defaultProfiles: number
  arenaRuns: number
  libraryDir: string
  lastImportedProfileIds: string[]
}

export interface ImportStatusResponse {
  state: ImportStatusState
  overview: ImportStatusOverview
}

// SSE 流式事件类型（完整版，对应 API 文档 5.7）
export type ArenaStreamEventType =
  | 'run_started'
  | 'phase_started'
  | 'speaker_started'
  | 'speaker_delta'
  | 'speaker_completed'
  | 'message'
  | 'phase_completed'
  | 'summary_started'
  | 'summary_delta'
  | 'summary'
  | 'done'
  | 'error'

// 计划的轮次信息
export interface PlannedRound {
  round: number
  phase: ArenaPhase
}

// 流式事件中的发言人信息
export interface StreamParticipant {
  agentId: string
  displayName: string
  stageLabel: string
}

// 流式事件中的回复目标
export interface StreamReplyTarget {
  agentId: string
  displayName: string
}

// 流式事件结构（完整版，兼容所有事件类型）
export interface ArenaStreamEvent {
  type: ArenaStreamEventType
  runId: string
  mode: ArenaMode
  topic: string
  sequence: number
  timestamp: string

  // run_started 事件字段
  reasoningEffort?: ReasoningEffort
  sessionId?: string
  continuedFromRunId?: string
  plannedRounds?: PlannedRound[]
  participants?: PersonaSpec[]

  // speaker_started / message 事件字段
  round?: number
  phase?: ArenaPhase
  messageId?: string
  agentId?: string
  displayName?: string
  stageLabel?: string
  participant?: StreamParticipant
  replyTarget?: StreamReplyTarget

  // speaker_delta / summary_delta 事件字段
  channel?: 'text' | 'thinking'
  delta?: string
  accumulatedText?: string

  // message 事件字段
  message?: ArenaMessage
  summary?: ArenaSummary

  // done 事件字段
  result?: ArenaRun
  links?: ArenaOutputLinks

  // error 事件字段
  error?: string
}

/** 融合台确定后传给智问页的人格摘要 */
export interface WorkbenchPickBrief {
  profileName: string
  stageLabel: string
  agentId: string
  displayName: string
}

export interface RouteParams {
  profileId?: string
  profileIds?: string
  selectedAgentIds?: string
  mergedAgentsJson?: string
  topic?: string
  /** 会议对话轮数（如 5–25），由参会页传入 */
  roundCount?: number
  arenaRunId?: string
  /** encodeURIComponent(JSON.stringify(WorkbenchPickBrief[]))，智问页展示用人格标签 */
  workbenchJson?: string
  /** encodeURIComponent(辩题正文)，由智问页等传入 */
  debateTopic?: string
  returnToMeeting?: string
}

export const ARENA_USER_TOPIC_AGENT_ID: string = 'user-prompt'

export const EMPTY_PROFILE: PresetProfile = {
  id: '',
  displayName: '',
  subtitle: '',
  category: 'self',
  coverSeed: '',
  biography: '',
  highlights: [],
  suggestedTopics: []
}

// 搜索分类枚举
export type SearchCategory =
  | 'all'           // 全部
  | 'business'      // 商业
  | 'finance'       // 金融/炒股
  | 'tech'          // 科技
  | 'politics'      // 政治
  | 'culture'       // 文化
  | 'sports'        // 体育
  | 'entertainment' // 娱乐
  | 'education'     // 教育
  | 'philosophy'    // 哲学

// 分类信息接口
export interface CategoryInfo {
  id: SearchCategory
  name: string
  icon: string
  description: string
}

// 搜索结果人物卡片接口
export interface PersonaSearchResult {
  id: string
  displayName: string
  subtitle: string
  category: SearchCategory
  coverSeed: string
  matchReason: string[]
  hotLevel: number
  tags: string[]
}

// 搜索历史记录
export interface SearchHistoryItem {
  id: string
  keyword: string
  timestamp: number
  resultCount: number
}

// ============================================
// 纪要相关模型 - Summary Models
// ============================================

// 导出资产类型
export type ExportAssetType = 'image' | 'video' | 'text'

// 导出资产
export interface ExportAsset {
  type: ExportAssetType
  path: string
  createdAt: string
  format: string
  size?: number
}

// 卡片模板类型
export type CardTemplateType = 'classic' | 'quote' | 'timeline'

// 导出格式类型
export type ExportFormatType = 'image' | 'video' | 'text'

// 导出图片尺寸
export type ImageSizeType = '1x1' | '16x9' | '9x16'

// 纪要标签
export interface SummaryTag {
  id: string
  name: string
  color: string
}

// 会议参与者信息
export interface SummaryParticipant {
  agentId: string
  displayName: string
  stageLabel: string
  avatarSeed: string
  accentColor: string
}

// 完整纪要数据
export interface SummaryRecord {
  id: string
  title: string
  topic: string
  createdAt: string
  updatedAt: string
  duration: number // 秒
  messageCount: number
  
  // 核心内容
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
  moderatorNote?: string
  
  // 参与者信息
  participants: SummaryParticipant[]
  
  // 亮点金句
  highlights: string[]
  
  // 元数据
  tags: string[]
  isFavorite: boolean
  viewCount: number
  
  // 导出的资产
  exportedAssets: ExportAsset[]
  
  // 缩略图路径
  thumbnailPath?: string
  
  // 引用消息ID列表（用于回放）
  messageIds: string[]
  
  // 原始ArenaRun ID
  arenaRunId?: string
  profileId?: string
}

// 纪要列表项（用于列表展示，字段比SummaryRecord少）
export interface SummaryListItem {
  id: string
  title: string
  topic: string
  createdAt: string
  timeAgo: string
  participantNames: string[]
  participantAvatars: string[]
  avatarColors: string[]
  accentColor: string
  consensusPreview: string
  highlightCount: number
  isFavorite: boolean
  messageCount: number
  duration: number
}

// 纪要卡片模板属性
export interface SummaryCardTemplateProps {
  // 基本信息
  title: string
  topic: string
  createdAt: string
  
  // 共识
  consensus: string
  
  // 分歧
  disagreements: SummaryParticipantDisagreement[]
  
  // 行动建议
  actionableAdvice: string[]
  
  // 金句
  narrativeHook: string
  narrativeSpeaker?: string
  
  // 参与者
  participants: SummaryParticipant[]
  
  // 亮点
  highlights: string[]
  
  // 模板类型
  templateType: CardTemplateType
  
  // 回调
  onShare?: () => void
  onFavorite?: () => void
}

// 参与者观点（用于展示分歧）
export interface SummaryParticipantDisagreement {
  participantName: string
  stageLabel: string
  view: string
  accentColor: string
}

// 导出选项
export interface ExportOptions {
  format: ExportFormatType
  imageSize?: ImageSizeType
  includeTimestamp?: boolean
  includeLogo?: boolean
  quality?: 'low' | 'medium' | 'high'
}

// 分享数据
export interface ShareData {
  title: string
  description: string
  thumbnailPath?: string
  content: string
  targetUrl?: string
  tags: string[]
}

// 纪要列表筛选
export interface SummaryFilter {
  category?: 'all' | 'favorite' | 'tag'
  tag?: string
  keyword?: string
  sortBy?: 'createdAt' | 'updatedAt' | 'viewCount'
  sortOrder?: 'asc' | 'desc'
}

// 纪要列表响应
export interface SummaryListResponse {
  total: number
  items: SummaryListItem[]
  hasMore: boolean
}

// API请求：创建纪要
export interface CreateSummaryRequest {
  arenaRunId: string
  profileId: string
  topic: string
  summary: ArenaSummary
  participants: PersonaSpec[]
  messageIds: string[]
  duration: number
}

// API请求：更新纪要
export interface UpdateSummaryRequest {
  title?: string
  tags?: string[]
  isFavorite?: boolean
  highlights?: string[]
}

// API响应：纪要详情
export interface SummaryDetailResponse {
  record: SummaryRecord
}

// 碰一碰分享数据
export interface HapShareData {
  summaryId: string
  title: string
  topic: string
  highlight: string
  avatarSeeds: string[]
}
