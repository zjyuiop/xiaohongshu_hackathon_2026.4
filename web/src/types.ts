export type TimelineStageType = 'early' | 'turning-point' | 'stable' | 'crisis' | 'rebuild' | 'peak'
export type ArenaMode = 'chat' | 'debate'
export type ArenaPhase = 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
export type ReasoningEffort = 'low' | 'medium' | 'high' | 'xhigh'
export type PosterStylePreset = 'poster' | 'editorial' | 'cinematic'
export type PosterAspectRatio = '16:9' | '2.35:1' | '4:3' | '3:2' | '1:1' | '3:4'
export type ArenaRunStatus = 'completed' | 'interrupted'

export interface SourceEvidence {
  quote: string
  sourceLabel: string
}

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

export interface PresetProfile {
  id: string
  displayName: string
  subtitle: string
  category: 'self' | 'celebrity' | 'history' | 'fictional'
  coverSeed: string
  biography: string
  highlights: string[]
  suggestedTopics: string[]
}

export interface ArenaMessage {
  id: string
  kind?: 'agent' | 'user'
  agentId: string
  displayName: string
  stageLabel: string
  content: string
  stance: 'support' | 'oppose' | 'reflective' | 'neutral'
  round?: number
  phase?: ArenaPhase
  replyToAgentId?: string
  replyToDisplayName?: string
}

export interface DebateJudgeScorecard {
  agentId: string
  displayName: string
  argumentScore: number
  evidenceScore: number
  responsivenessScore: number
  comments: string
}

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
  status?: ArenaRunStatus
  mode: ArenaMode
  topic: string
  participants: PersonaSpec[]
  messages: ArenaMessage[]
  summary: ArenaSummary
  config?: {
    roundCount: number
    maxMessageChars: number
    reasoningEffort: ReasoningEffort
  }
  createdAt?: string
}

export interface ArenaOutputLinks {
  runId: string
  shareApiPath: string
  shareApiUrl?: string
  suggestedSharePath: string
  suggestedShareUrl?: string
}

export interface ArenaRunResponseEnvelope {
  result: ArenaRun
  links?: ArenaOutputLinks
}

export interface MergeAgentsRequestPayload {
  primary: PersonaSpec
  secondary: PersonaSpec
  displayName?: string
  mergePrompt?: string
}

export interface MergeAgentsResponse {
  agent: PersonaSpec
  execution?: {
    requestedModel: string
    requestedEffort: ReasoningEffort
    effectiveModel: string
    effectiveEffort: 'low' | 'medium' | 'high' | 'max'
    fallbackUsed: boolean
    sessionId?: string
    durationMs: number
  }
}

export interface ArenaRunRequestPayload {
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

export interface ArenaRunHistoryItem {
  runId: string
  sessionId: string
  status: ArenaRunStatus
  topic: string
  mode: ArenaMode
  title: string
  consensus: string
  participantNames: string[]
  messageCount: number
  createdAt: string
  continuedFromRunId?: string
  latestGuidance?: string
}

export interface ArenaPosterAsset {
  runId: string
  title: string
  summary: string
  stylePreset: PosterStylePreset
  aspectRatio: PosterAspectRatio
  outputDir: string
  imagePath: string
  imageUrl?: string
  promptPath?: string
  promptUrl?: string
  sourcePath?: string
  sourceUrl?: string
  generatedAt: string
}

export interface ArenaPosterResponse {
  runId: string
  links: ArenaOutputLinks
  poster: ArenaPosterAsset
}

interface ArenaStreamEventBase {
  type: string
  runId: string
  mode: ArenaMode
  topic: string
  sequence: number
  timestamp: string
}

export interface ArenaRunStartedEvent extends ArenaStreamEventBase {
  type: 'run_started'
  reasoningEffort: ReasoningEffort
  config?: {
    roundCount: number
    maxMessageChars: number
    reasoningEffort: ReasoningEffort
  }
  sessionId?: string
  continuedFromRunId?: string
  participants: PersonaSpec[]
  plannedRounds: Array<{
    round: number
    phase: ArenaPhase
  }>
}

export interface ArenaPhaseStartedEvent extends ArenaStreamEventBase {
  type: 'phase_started'
  round: number
  phase: ArenaPhase
  participants: Array<{
    agentId: string
    displayName: string
  }>
}

export interface ArenaSpeakerStartedEvent extends ArenaStreamEventBase {
  type: 'speaker_started'
  round: number
  phase: ArenaPhase
  messageId: string
  participant: {
    agentId: string
    displayName: string
    stageLabel: string
  }
  replyTarget?: {
    agentId: string
    displayName: string
  }
}

export interface ArenaSpeakerDeltaEvent extends ArenaStreamEventBase {
  type: 'speaker_delta'
  round: number
  phase: ArenaPhase
  messageId: string
  agentId: string
  displayName: string
  channel: 'text' | 'thinking'
  delta: string
  accumulatedText: string
}

export interface ArenaSpeakerCompletedEvent extends ArenaStreamEventBase {
  type: 'speaker_completed'
  round: number
  phase: ArenaPhase
  messageId: string
  agentId: string
  displayName: string
  usedFallback: boolean
  durationMs?: number
}

export interface ArenaMessageEvent extends ArenaStreamEventBase {
  type: 'message'
  round: number
  phase: ArenaPhase
  message: ArenaMessage
}

export interface ArenaPhaseCompletedEvent extends ArenaStreamEventBase {
  type: 'phase_completed'
  round: number
  phase: ArenaPhase
  messageIds: string[]
}

export interface ArenaSummaryStartedEvent extends ArenaStreamEventBase {
  type: 'summary_started'
}

export interface ArenaSummaryDeltaEvent extends ArenaStreamEventBase {
  type: 'summary_delta'
  channel: 'text' | 'thinking'
  delta: string
  accumulatedText: string
}

export interface ArenaSummaryEvent extends ArenaStreamEventBase {
  type: 'summary'
  summary: ArenaSummary
}

export interface ArenaDoneEvent extends ArenaStreamEventBase {
  type: 'done'
  result: ArenaRun
  links?: ArenaOutputLinks
}

export interface ArenaErrorEvent extends ArenaStreamEventBase {
  type: 'error'
  error: string
  round?: number
  phase?: ArenaPhase
}

export type ArenaStreamEvent =
  | ArenaRunStartedEvent
  | ArenaPhaseStartedEvent
  | ArenaSpeakerStartedEvent
  | ArenaSpeakerDeltaEvent
  | ArenaSpeakerCompletedEvent
  | ArenaMessageEvent
  | ArenaPhaseCompletedEvent
  | ArenaSummaryStartedEvent
  | ArenaSummaryDeltaEvent
  | ArenaSummaryEvent
  | ArenaDoneEvent
  | ArenaErrorEvent
