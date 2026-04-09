export type TimelineStageType = 'early' | 'turning-point' | 'stable' | 'crisis' | 'rebuild' | 'peak';
export type ArenaMode = 'chat' | 'debate';
export type ArenaPhase = 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing';
export type ProfileCategory = 'self' | 'celebrity' | 'history' | 'fictional';
export type AgentRuntimeMode = 'claude-agent-sdk';
export type ReasoningEffort = 'low' | 'medium' | 'high' | 'xhigh';
export type ArenaMessageKind = 'agent' | 'user';
export type ClaudeCliEffort = 'low' | 'medium' | 'high' | 'max';
export type PosterAspectRatio = '16:9' | '2.35:1' | '4:3' | '3:2' | '1:1' | '3:4';
export type PosterStylePreset = 'poster' | 'editorial' | 'cinematic';
export type ArenaRunStatus = 'completed' | 'interrupted';
export type ProfileImportType = 'manual' | 'wechat' | 'chat';

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
  kind?: ArenaMessageKind;
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

export interface ArenaRunConfig {
  roundCount: number;
  maxMessageChars: number;
  reasoningEffort: ReasoningEffort;
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
  sessionId?: string;
  continuedFromRunId?: string;
  status?: ArenaRunStatus;
  mode: ArenaMode;
  topic: string;
  participants: PersonaSpec[];
  messages: ArenaMessage[];
  summary: ArenaSummary;
  config?: ArenaRunConfig;
  createdAt?: string;
}

export interface ArenaOutputLinks {
  runId: string;
  shareApiPath: string;
  shareApiUrl?: string;
  suggestedSharePath: string;
  suggestedShareUrl?: string;
}

export interface ArenaPosterAsset {
  runId: string;
  title: string;
  summary: string;
  stylePreset: PosterStylePreset;
  aspectRatio: PosterAspectRatio;
  outputDir: string;
  imagePath: string;
  imageUrl?: string;
  promptPath?: string;
  promptUrl?: string;
  sourcePath?: string;
  sourceUrl?: string;
  generatedAt: string;
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

export interface ProfileImportRequest {
  importType: ProfileImportType;
  profileId?: string;
  displayNameHint?: string;
  title?: string;
}

export interface ProfileImportSourceSummary {
  importType: ProfileImportType;
  sourceLabel: string;
  title: string;
  originalFileName: string;
  mimeType: string;
  extension: string;
  charCount: number;
  messageCount?: number;
}

export interface ProfileImportResponse {
  bundle: ProfileBundle;
  import: ProfileImportSourceSummary;
}

export interface MergeAgentsRequest {
  primary: PersonaSpec;
  secondary: PersonaSpec;
  displayName?: string;
  mergePrompt?: string;
}

export interface MergedPersonaDraft {
  displayName: string;
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

export interface MergeAgentsResponse {
  agent: PersonaSpec;
  execution?: ClaudeExecutionInfo;
}

export interface ArenaPendingUserMessage {
  id?: string;
  content: string;
  createdAt?: string;
}

export interface ArenaRunRequest {
  topic: string;
  mode: ArenaMode;
  selectedAgentIds: string[];
  agents: PersonaSpec[];
  reasoningEffort?: ReasoningEffort;
  roundCount?: number;
  maxMessageChars?: number;
  guidance?: string;
  pendingUserMessages?: ArenaPendingUserMessage[];
  continueFromRunId?: string;
  sessionId?: string;
}

export interface ArenaRunResponse {
  result: ArenaRun;
  links?: ArenaOutputLinks;
}

export interface ArenaSessionMessageRequest {
  content: string;
  clientMessageId?: string;
  createdAt?: string;
}

export interface ArenaSessionMessageResponse {
  ok: true;
  sessionId: string;
  queuedMessages: number;
}

export interface ArenaPosterRequest {
  runId?: string;
  run?: ArenaRun;
  stylePreset?: PosterStylePreset;
  aspectRatio?: PosterAspectRatio;
  language?: string;
}

export interface ArenaPosterResponse {
  runId: string;
  links: ArenaOutputLinks;
  poster: ArenaPosterAsset;
}

export interface ArenaRunHistoryItem {
  runId: string;
  sessionId: string;
  status: ArenaRunStatus;
  topic: string;
  mode: ArenaMode;
  title: string;
  consensus: string;
  participantNames: string[];
  messageCount: number;
  createdAt: string;
  continuedFromRunId?: string;
  latestGuidance?: string;
}

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
  | 'error';

interface ArenaStreamEventBase {
  type: ArenaStreamEventType;
  runId: string;
  mode: ArenaMode;
  topic: string;
  sequence: number;
  timestamp: string;
}

export interface ArenaRunStartedEvent extends ArenaStreamEventBase {
  type: 'run_started';
  reasoningEffort: ReasoningEffort;
  config: ArenaRunConfig;
  sessionId: string;
  continuedFromRunId?: string;
  participants: PersonaSpec[];
  plannedRounds: Array<{
    round: number;
    phase: ArenaPhase;
  }>;
}

export interface ArenaPhaseStartedEvent extends ArenaStreamEventBase {
  type: 'phase_started';
  round: number;
  phase: ArenaPhase;
  participants: Array<{
    agentId: string;
    displayName: string;
  }>;
}

export interface ArenaMessageEvent extends ArenaStreamEventBase {
  type: 'message';
  round: number;
  phase: ArenaPhase;
  message: ArenaMessage;
}

export interface ArenaSpeakerStartedEvent extends ArenaStreamEventBase {
  type: 'speaker_started';
  round: number;
  phase: ArenaPhase;
  messageId: string;
  participant: {
    agentId: string;
    displayName: string;
    stageLabel: string;
  };
  replyTarget?: {
    agentId: string;
    displayName: string;
  };
}

export interface ArenaSpeakerDeltaEvent extends ArenaStreamEventBase {
  type: 'speaker_delta';
  round: number;
  phase: ArenaPhase;
  messageId: string;
  agentId: string;
  displayName: string;
  channel: 'text' | 'thinking';
  delta: string;
  accumulatedText: string;
}

export interface ArenaSpeakerCompletedEvent extends ArenaStreamEventBase {
  type: 'speaker_completed';
  round: number;
  phase: ArenaPhase;
  messageId: string;
  agentId: string;
  displayName: string;
  usedFallback: boolean;
  durationMs?: number;
  execution?: ClaudeExecutionInfo;
}

export interface ArenaPhaseCompletedEvent extends ArenaStreamEventBase {
  type: 'phase_completed';
  round: number;
  phase: ArenaPhase;
  messageIds: string[];
}

export interface ArenaSummaryStartedEvent extends ArenaStreamEventBase {
  type: 'summary_started';
}

export interface ArenaSummaryDeltaEvent extends ArenaStreamEventBase {
  type: 'summary_delta';
  channel: 'text' | 'thinking';
  delta: string;
  accumulatedText: string;
}

export interface ArenaSummaryEvent extends ArenaStreamEventBase {
  type: 'summary';
  summary: ArenaSummary;
}

export interface ArenaDoneEvent extends ArenaStreamEventBase {
  type: 'done';
  result: ArenaRun;
  links?: ArenaOutputLinks;
}

export interface ArenaErrorEvent extends ArenaStreamEventBase {
  type: 'error';
  error: string;
  round?: number;
  phase?: ArenaPhase;
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
  | ArenaErrorEvent;

export interface ArenaRunObserver {
  onEvent?: (event: ArenaStreamEvent) => void | Promise<void>;
}

export interface ArenaRuntimeStreamObserver {
  onSpeakerDelta?: (event: {
    channel: 'text' | 'thinking';
    delta: string;
    accumulatedText: string;
  }) => void | Promise<void>;
  onSummaryDelta?: (event: {
    channel: 'text' | 'thinking';
    delta: string;
    accumulatedText: string;
  }) => void | Promise<void>;
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

export interface TimelineNodePresentationRefinement {
  nodeId: string;
  stageLabel: string;
  keyEvent: string;
  summary: string;
}

export interface TimelinePresentationRefinement {
  subtitle: string;
  highlights: string[];
  nodes: TimelineNodePresentationRefinement[];
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
  ccsProfile?: string;
  requestedModel: string;
  requestedEffort: ReasoningEffort;
  fallbackModel: string;
  fallbackEffort: ClaudeCliEffort;
  unsupportedModels: string[];
  siliconFlowEnabled?: boolean;
  siliconFlowFallbackModels?: string[];
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
