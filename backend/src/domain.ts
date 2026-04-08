export type TimelineStageType = 'early' | 'turning-point' | 'stable' | 'crisis' | 'rebuild' | 'peak';
export type ArenaMode = 'chat' | 'debate';
export type ArenaPhase = 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing';
export type ProfileCategory = 'self' | 'celebrity' | 'history' | 'fictional';
export type AgentRuntimeMode = 'claude-code-sdk';
export type ReasoningEffort = 'low' | 'medium' | 'high' | 'xhigh';
export type ClaudeCliEffort = 'low' | 'medium' | 'high' | 'max';

export interface SourceEvidence {
  quote: string;
  sourceLabel: string;
}

export interface TimelineNode {
  nodeId: string;
  timeLabel: string;
  ageLabel?: string;
  stageLabel: string;
  stageType: TimelineStageType;
  keyEvent: string;
  summary: string;
  traits: string[];
  values: string[];
  tensions: string[];
  sourceEvidence: SourceEvidence[];
}

export interface PersonaSpec {
  agentId: string;
  displayName: string;
  personId: string;
  avatarSeed: string;
  timeLabel: string;
  stageLabel: string;
  keyEvent: string;
  knownFacts: string[];
  sourceEvidence: SourceEvidence[];
  traits: string[];
  values: string[];
  goal: string;
  fear: string;
  voiceStyle: string;
  knowledgeBoundary: string;
  forbiddenFutureKnowledge: boolean;
  stanceSeed: string;
}

export interface PresetProfile {
  id: string;
  displayName: string;
  subtitle: string;
  category: ProfileCategory;
  coverSeed: string;
  biography: string;
  highlights: string[];
  suggestedTopics: string[];
}

export interface ArenaMessage {
  id: string;
  agentId: string;
  displayName: string;
  stageLabel: string;
  content: string;
  stance: 'support' | 'oppose' | 'reflective' | 'neutral';
  round?: number;
  phase?: ArenaPhase;
  replyToAgentId?: string;
  replyToDisplayName?: string;
}

export interface DebateJudgeScorecard {
  agentId: string;
  displayName: string;
  argumentScore: number;
  evidenceScore: number;
  responsivenessScore: number;
  comments: string;
}

export interface DebateVerdict {
  winnerAgentId?: string;
  winnerDisplayName?: string;
  rationale: string;
  scorecards: DebateJudgeScorecard[];
}

export interface ArenaSummary {
  title: string;
  consensus: string;
  disagreements: string[];
  actionableAdvice: string[];
  narrativeHook: string;
  moderatorNote?: string;
  debateVerdict?: DebateVerdict;
}

export interface ArenaRun {
  runId: string;
  mode: ArenaMode;
  topic: string;
  participants: PersonaSpec[];
  messages: ArenaMessage[];
  summary: ArenaSummary;
}

export interface ParseTimelineRequest {
  profileId?: string;
  displayName: string;
  biography: string;
}

export interface ParseTimelineResponse {
  personId: string;
  displayName: string;
  nodes: TimelineNode[];
}

export interface BuildAgentsRequest {
  personId: string;
  displayName: string;
  biography?: string;
  nodes: TimelineNode[];
}

export interface BuildAgentsResponse {
  agents: PersonaSpec[];
}

export interface ArenaRunRequest {
  topic: string;
  mode: ArenaMode;
  selectedAgentIds: string[];
  agents: PersonaSpec[];
}

export interface ArenaRunResponse {
  result: ArenaRun;
}

export interface SourceSection {
  ordinal: number;
  title: string;
  href?: string;
  rawText: string;
  excerpt: string;
}

export interface ParsedEpubDocument {
  title: string;
  author: string;
  sourceType: 'epub';
  metadata: Record<string, unknown>;
  sections: SourceSection[];
}

export interface GeneratedProfileDraft {
  displayName: string;
  subtitle: string;
  category: ProfileCategory;
  biography: string;
  highlights: string[];
  suggestedTopics: string[];
  nodes: TimelineNode[];
}

export interface PersonaBlueprint {
  nodeId: string;
  knownFacts: string[];
  goal: string;
  fear: string;
  voiceStyle: string;
  knowledgeBoundary: string;
  stanceSeed: string;
}

export interface ClaudeExecutionInfo {
  requestedModel: string;
  requestedEffort: ReasoningEffort;
  effectiveModel: string;
  effectiveEffort: ClaudeCliEffort;
  fallbackUsed: boolean;
  sessionId?: string;
  durationMs: number;
}

export interface RuntimeStatus {
  mode: AgentRuntimeMode;
  claudeBinary: string;
  requestedModel: string;
  requestedEffort: ReasoningEffort;
  fallbackModel: string;
  fallbackEffort: ClaudeCliEffort;
  unsupportedModels: string[];
}

export interface SourceDocumentSummary {
  id: string;
  title: string;
  author?: string | null;
  filePath: string;
  importedAt: string;
  sectionCount: number;
}

export interface ProfileBundle {
  profile: PresetProfile;
  nodes: TimelineNode[];
  agents: PersonaSpec[];
  sourceDocument?: SourceDocumentSummary | null;
}

export interface ImportState {
  running: boolean;
  lastRunAt?: string;
  lastError?: string;
  lastImportedProfileIds: string[];
}

export interface ImportOverview {
  documents: number;
  defaultProfiles: number;
  arenaRuns: number;
  libraryDir: string;
  lastImportedProfileIds: string[];
}
