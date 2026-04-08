export type TimelineStageType = 'early' | 'turning-point' | 'stable' | 'crisis' | 'rebuild' | 'peak';

export type ArenaMode = 'chat' | 'debate';

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
  category: 'self' | 'celebrity' | 'history' | 'fictional';
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
}

export interface ArenaSummary {
  title: string;
  consensus: string;
  disagreements: string[];
  actionableAdvice: string[];
  narrativeHook: string;
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
