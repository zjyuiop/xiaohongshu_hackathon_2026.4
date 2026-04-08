export type ArenaMode = 'chat' | 'debate'

export interface PresetProfile {
  id: string
  displayName: string
  subtitle: string
  category: string
  coverSeed: string
  biography: string
  highlights: string[]
  suggestedTopics: string[]
}

export interface SourceEvidence {
  quote: string
  sourceLabel: string
}

export interface TimelineNode {
  nodeId: string
  timeLabel: string
  ageLabel?: string
  stageLabel: string
  stageType: string
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

export interface ArenaMessage {
  id: string
  agentId: string
  displayName: string
  stageLabel: string
  content: string
  stance: string
}

export interface ArenaSummary {
  title: string
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
}

export interface ArenaRun {
  runId: string
  mode: ArenaMode
  topic: string
  participants: PersonaSpec[]
  messages: ArenaMessage[]
  summary: ArenaSummary
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
}

export interface BuildAgentsRequest {
  personId: string
  displayName: string
  biography: string
  nodes: TimelineNode[]
}

export interface BuildAgentsResponse {
  agents: PersonaSpec[]
}

export interface ArenaRunRequest {
  topic: string
  mode: ArenaMode
  selectedAgentIds: string[]
  agents: PersonaSpec[]
}

export interface ArenaRunResponse {
  result: ArenaRun
}

export interface RouteParams {
  profileId?: string
  selectedAgentIds?: string
}

export const EMPTY_PROFILE: PresetProfile = {
  id: '',
  displayName: '',
  subtitle: '',
  category: '',
  coverSeed: '',
  biography: '',
  highlights: [],
  suggestedTopics: []
}
