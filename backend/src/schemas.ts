import { z } from 'zod';

export const sourceEvidenceSchema = z.object({
  quote: z.string().min(1),
  sourceLabel: z.string().min(1),
});

export const timelineNodeSchema = z.object({
  nodeId: z.string().min(1),
  timeLabel: z.string().min(1),
  ageLabel: z.string().min(1).optional(),
  stageLabel: z.string().min(1),
  stageType: z.enum(['early', 'turning-point', 'stable', 'crisis', 'rebuild', 'peak']),
  keyEvent: z.string().min(1),
  summary: z.string().min(1),
  traits: z.array(z.string().min(1)).min(1).max(5),
  values: z.array(z.string().min(1)).min(1).max(5),
  tensions: z.array(z.string().min(1)).min(1).max(4),
  sourceEvidence: z.array(sourceEvidenceSchema).min(1).max(4),
});

export const personaSpecSchema = z.object({
  agentId: z.string().min(1),
  displayName: z.string().min(1),
  personId: z.string().min(1),
  avatarSeed: z.string().min(1),
  timeLabel: z.string().min(1),
  stageLabel: z.string().min(1),
  keyEvent: z.string().min(1),
  knownFacts: z.array(z.string().min(1)).min(1),
  sourceEvidence: z.array(sourceEvidenceSchema).min(1),
  traits: z.array(z.string().min(1)).min(1),
  values: z.array(z.string().min(1)).min(1),
  goal: z.string().min(1),
  fear: z.string().min(1),
  voiceStyle: z.string().min(1),
  knowledgeBoundary: z.string().min(1),
  forbiddenFutureKnowledge: z.boolean(),
  stanceSeed: z.string().min(1),
});

export const parseTimelineRequestSchema = z.object({
  profileId: z.string().min(1).optional(),
  displayName: z.string().min(1),
  biography: z.string().min(10),
});

export const buildAgentsRequestSchema = z.object({
  personId: z.string().min(1),
  displayName: z.string().min(1),
  biography: z.string().min(10).optional(),
  nodes: z.array(timelineNodeSchema).min(1),
});

export const arenaRunRequestSchema = z.object({
  topic: z.string().min(1),
  mode: z.enum(['chat', 'debate']),
  selectedAgentIds: z.array(z.string().min(1)).min(2).max(3),
  agents: z.array(personaSpecSchema).min(2),
});

export const generatedProfileSchema = z.object({
  displayName: z.string().min(1),
  subtitle: z.string().min(1),
  category: z.enum(['self', 'celebrity', 'history', 'fictional']),
  biography: z.string().min(20),
  highlights: z.array(z.string().min(1)).min(3).max(6),
  suggestedTopics: z.array(z.string().min(1)).min(3).max(6),
  nodes: z.array(timelineNodeSchema).min(3).max(6),
});

export const personaBlueprintSchema = z.object({
  nodeId: z.string().min(1),
  knownFacts: z.array(z.string().min(1)).min(2).max(5),
  goal: z.string().min(1),
  fear: z.string().min(1),
  voiceStyle: z.string().min(1),
  knowledgeBoundary: z.string().min(1),
  stanceSeed: z.string().min(1),
});

export const generatedPersonaBlueprintsSchema = z.object({
  agents: z.array(personaBlueprintSchema).min(1),
});

export const generatedArenaMessageSchema = z.object({
  content: z.string().min(20),
  stance: z.enum(['support', 'oppose', 'reflective', 'neutral']),
});

export const generatedArenaSummarySchema = z.object({
  title: z.string().min(1),
  consensus: z.string().min(10),
  disagreements: z.array(z.string().min(1)).min(1),
  actionableAdvice: z.array(z.string().min(1)).min(1).max(5),
  narrativeHook: z.string().min(10),
});

export const generatedChatSummarySchema = generatedArenaSummarySchema.extend({
  moderatorNote: z.string().min(10).optional(),
});

export const generatedDebateJudgeSchema = generatedArenaSummarySchema.extend({
  debateVerdict: z.object({
    winnerAgentId: z.string().min(1).optional(),
    winnerDisplayName: z.string().min(1).optional(),
    rationale: z.string().min(10),
    scorecards: z
      .array(
        z.object({
          agentId: z.string().min(1),
          displayName: z.string().min(1),
          argumentScore: z.number().min(1).max(10),
          evidenceScore: z.number().min(1).max(10),
          responsivenessScore: z.number().min(1).max(10),
          comments: z.string().min(10),
        }),
      )
      .min(2)
      .max(3),
  }),
});

const sourceEvidenceJsonSchema = {
  type: 'object',
  properties: {
    quote: { type: 'string' },
    sourceLabel: { type: 'string' },
  },
  required: ['quote', 'sourceLabel'],
  additionalProperties: false,
} as const;

const timelineNodeJsonSchema = {
  type: 'object',
  properties: {
    nodeId: { type: 'string' },
    timeLabel: { type: 'string' },
    ageLabel: { type: ['string', 'null'] },
    stageLabel: { type: 'string' },
    stageType: {
      type: 'string',
      enum: ['early', 'turning-point', 'stable', 'crisis', 'rebuild', 'peak'],
    },
    keyEvent: { type: 'string' },
    summary: { type: 'string' },
    traits: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 5 },
    values: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 5 },
    tensions: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 4 },
    sourceEvidence: { type: 'array', items: sourceEvidenceJsonSchema, minItems: 1, maxItems: 4 },
  },
  required: ['nodeId', 'timeLabel', 'stageLabel', 'stageType', 'keyEvent', 'summary', 'traits', 'values', 'tensions', 'sourceEvidence'],
  additionalProperties: false,
} as const;

export const generatedProfileJsonSchema = {
  type: 'object',
  properties: {
    displayName: { type: 'string' },
    subtitle: { type: 'string' },
    category: { type: 'string', enum: ['self', 'celebrity', 'history', 'fictional'] },
    biography: { type: 'string' },
    highlights: { type: 'array', items: { type: 'string' }, minItems: 3, maxItems: 6 },
    suggestedTopics: { type: 'array', items: { type: 'string' }, minItems: 3, maxItems: 6 },
    nodes: { type: 'array', items: timelineNodeJsonSchema, minItems: 3, maxItems: 6 },
  },
  required: ['displayName', 'subtitle', 'category', 'biography', 'highlights', 'suggestedTopics', 'nodes'],
  additionalProperties: false,
} as const;

export const generatedPersonaBlueprintsJsonSchema = {
  type: 'object',
  properties: {
    agents: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          nodeId: { type: 'string' },
          knownFacts: { type: 'array', items: { type: 'string' }, minItems: 2, maxItems: 5 },
          goal: { type: 'string' },
          fear: { type: 'string' },
          voiceStyle: { type: 'string' },
          knowledgeBoundary: { type: 'string' },
          stanceSeed: { type: 'string' },
        },
        required: ['nodeId', 'knownFacts', 'goal', 'fear', 'voiceStyle', 'knowledgeBoundary', 'stanceSeed'],
        additionalProperties: false,
      },
      minItems: 1,
    },
  },
  required: ['agents'],
  additionalProperties: false,
} as const;

export const generatedArenaMessageJsonSchema = {
  type: 'object',
  properties: {
    content: { type: 'string' },
    stance: {
      type: 'string',
      enum: ['support', 'oppose', 'reflective', 'neutral'],
    },
  },
  required: ['content', 'stance'],
  additionalProperties: false,
} as const;

export const generatedArenaSummaryJsonSchema = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    consensus: { type: 'string' },
    disagreements: { type: 'array', items: { type: 'string' }, minItems: 1 },
    actionableAdvice: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 5 },
    narrativeHook: { type: 'string' },
  },
  required: ['title', 'consensus', 'disagreements', 'actionableAdvice', 'narrativeHook'],
  additionalProperties: false,
} as const;

export const generatedChatSummaryJsonSchema = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    consensus: { type: 'string' },
    disagreements: { type: 'array', items: { type: 'string' }, minItems: 1 },
    actionableAdvice: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 5 },
    narrativeHook: { type: 'string' },
    moderatorNote: { type: 'string' },
  },
  required: ['title', 'consensus', 'disagreements', 'actionableAdvice', 'narrativeHook'],
  additionalProperties: false,
} as const;

export const generatedDebateJudgeJsonSchema = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    consensus: { type: 'string' },
    disagreements: { type: 'array', items: { type: 'string' }, minItems: 1 },
    actionableAdvice: { type: 'array', items: { type: 'string' }, minItems: 1, maxItems: 5 },
    narrativeHook: { type: 'string' },
    debateVerdict: {
      type: 'object',
      properties: {
        winnerAgentId: { type: 'string' },
        winnerDisplayName: { type: 'string' },
        rationale: { type: 'string' },
        scorecards: {
          type: 'array',
          minItems: 2,
          maxItems: 3,
          items: {
            type: 'object',
            properties: {
              agentId: { type: 'string' },
              displayName: { type: 'string' },
              argumentScore: { type: 'number' },
              evidenceScore: { type: 'number' },
              responsivenessScore: { type: 'number' },
              comments: { type: 'string' },
            },
            required: ['agentId', 'displayName', 'argumentScore', 'evidenceScore', 'responsivenessScore', 'comments'],
            additionalProperties: false,
          },
        },
      },
      required: ['rationale', 'scorecards'],
      additionalProperties: false,
    },
  },
  required: ['title', 'consensus', 'disagreements', 'actionableAdvice', 'narrativeHook', 'debateVerdict'],
  additionalProperties: false,
} as const;
