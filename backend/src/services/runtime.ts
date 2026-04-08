import { spawn } from 'node:child_process';

import { getConfig, mapEffortToClaude } from '../config.js';
import {
  buildArenaTurnTaskPrompt,
  buildChatSummaryTaskPrompt,
  buildDebateJudgementTaskPrompt,
  buildPersonaAgentPrompt,
  buildPersonaTaskPrompt,
  buildTimelineTaskPrompt,
  chatModeratorAgentPrompt,
  debateJudgeAgentPrompt,
  personaSmithAgentPrompt,
  timelineArchivistAgentPrompt,
} from '../prompts.js';
import {
  generatedChatSummaryJsonSchema,
  generatedChatSummarySchema,
  generatedDebateJudgeJsonSchema,
  generatedDebateJudgeSchema,
  generatedArenaMessageJsonSchema,
  generatedArenaMessageSchema,
  generatedPersonaBlueprintsJsonSchema,
  generatedPersonaBlueprintsSchema,
  generatedProfileJsonSchema,
  generatedProfileSchema,
} from '../schemas.js';
import type {
  ArenaMessage,
  ArenaMode,
  ArenaPhase,
  ArenaSummary,
  ClaudeExecutionInfo,
  PersonaBlueprint,
  PersonaSpec,
  RuntimeStatus,
  TimelineNode,
  GeneratedProfileDraft,
} from '../domain.js';

interface StructuredCallOptions<T> {
  agentName: string;
  agentDescription: string;
  agentPrompt: string;
  taskPrompt: string;
  schema: Record<string, unknown>;
  parse: (value: unknown) => T;
  timeoutMs?: number;
}

interface ClaudePayload {
  is_error?: boolean;
  result?: string;
  structured_output?: unknown;
  modelUsage?: Record<string, unknown>;
  session_id?: string;
  duration_ms?: number;
}

function parseJsonResult(stdout: string): ClaudePayload {
  const trimmed = stdout.trim();
  if (!trimmed) {
    throw new Error('Claude Code 未返回输出');
  }

  try {
    return JSON.parse(trimmed) as ClaudePayload;
  } catch {
    const lines = trimmed.split('\n').reverse();
    for (const line of lines) {
      try {
        return JSON.parse(line) as ClaudePayload;
      } catch {
        continue;
      }
    }
  }

  throw new Error(`Claude Code 输出无法解析为 JSON: ${trimmed.slice(0, 300)}`);
}

function hasUnsupportedModelMessage(payload: ClaudePayload, stderr: string): boolean {
  const combined = [payload.result, stderr].filter(Boolean).join('\n');
  return /issue with the selected model|may not exist|may not have access/i.test(combined);
}

export class ClaudeCodeRuntime {
  private readonly config = getConfig();
  private readonly unsupportedModels = new Set<string>();

  getStatus(): RuntimeStatus {
    return {
      mode: 'claude-code-sdk',
      claudeBinary: this.config.claudeBinary,
      requestedModel: this.config.targetModel,
      requestedEffort: this.config.reasoningEffort,
      fallbackModel: this.config.fallbackModel,
      fallbackEffort: this.config.fallbackEffort,
      unsupportedModels: Array.from(this.unsupportedModels),
    };
  }

  async generateTimelineFromText(input: {
    displayNameHint?: string;
    biographyOrDigest: string;
    sourceLabel: string;
  }): Promise<{ draft: GeneratedProfileDraft; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'timeline_archivist',
      agentDescription: 'Extracts factual timeline nodes from biographies.',
      agentPrompt: timelineArchivistAgentPrompt,
      taskPrompt: buildTimelineTaskPrompt(input),
      schema: generatedProfileJsonSchema,
      parse: (value) => generatedProfileSchema.parse(value),
      timeoutMs: 180000,
    }).then(({ value, execution }) => ({ draft: value, execution }));
  }

  async generatePersonaBlueprints(input: {
    personId: string;
    displayName: string;
    biography: string;
    nodes: TimelineNode[];
  }): Promise<{ blueprints: PersonaBlueprint[]; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'persona_smith',
      agentDescription: 'Builds time-sliced persona blueprints from timeline nodes.',
      agentPrompt: personaSmithAgentPrompt,
      taskPrompt: buildPersonaTaskPrompt(input),
      schema: generatedPersonaBlueprintsJsonSchema,
      parse: (value) => generatedPersonaBlueprintsSchema.parse(value),
      timeoutMs: 180000,
    }).then(({ value, execution }) => ({ blueprints: value.agents, execution }));
  }

  async generatePersonaMessage(input: {
    persona: PersonaSpec;
    topic: string;
    mode: ArenaMode;
    round: number;
    phase: ArenaPhase;
    participants: PersonaSpec[];
    designatedTarget?: PersonaSpec;
    ownPreviousMessages: ArenaMessage[];
    currentStance?: ArenaMessage['stance'];
    previousMessages: ArenaMessage[];
  }): Promise<{ message: Pick<ArenaMessage, 'content' | 'stance'>; execution: ClaudeExecutionInfo }> {
    const agentName = input.persona.agentId.replace(/[^a-zA-Z0-9_-]+/g, '_').slice(0, 60) || 'stage_speaker';
    return this.runStructured({
      agentName,
      agentDescription: `${input.persona.displayName} speaking from a fixed historical stage.`,
      agentPrompt: buildPersonaAgentPrompt(input.persona),
      taskPrompt: buildArenaTurnTaskPrompt({
        mode: input.mode,
        topic: input.topic,
        round: input.round,
        phase: input.phase,
        persona: input.persona,
        participants: input.participants,
        designatedTarget: input.designatedTarget,
        ownPreviousMessages: input.ownPreviousMessages,
        currentStance: input.currentStance,
        previousMessages: input.previousMessages,
      }),
      schema: generatedArenaMessageJsonSchema,
      parse: (value) => generatedArenaMessageSchema.parse(value),
      timeoutMs: 120000,
    }).then(({ value, execution }) => ({ message: value, execution }));
  }

  async generateChatSummary(input: {
    topic: string;
    participants: PersonaSpec[];
    messages: ArenaMessage[];
  }): Promise<{ summary: ArenaSummary; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'chat_moderator',
      agentDescription: 'Moderates and summarizes reflective cross-time conversations.',
      agentPrompt: chatModeratorAgentPrompt,
      taskPrompt: buildChatSummaryTaskPrompt({
        topic: input.topic,
        participants: input.participants,
        messages: input.messages,
      }),
      schema: generatedChatSummaryJsonSchema,
      parse: (value) => generatedChatSummarySchema.parse(value),
      timeoutMs: 180000,
    }).then(({ value, execution }) => ({ summary: value, execution }));
  }

  async generateDebateJudgement(input: {
    topic: string;
    participants: PersonaSpec[];
    messages: ArenaMessage[];
  }): Promise<{ summary: ArenaSummary; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'debate_judge',
      agentDescription: 'Judges cross-time persona debates and emits a score-backed verdict.',
      agentPrompt: debateJudgeAgentPrompt,
      taskPrompt: buildDebateJudgementTaskPrompt({
        topic: input.topic,
        participants: input.participants,
        messages: input.messages,
      }),
      schema: generatedDebateJudgeJsonSchema,
      parse: (value) => generatedDebateJudgeSchema.parse(value),
      timeoutMs: 180000,
    }).then(({ value, execution }) => ({ summary: value, execution }));
  }

  private async runStructured<T>(options: StructuredCallOptions<T>): Promise<{ value: T; execution: ClaudeExecutionInfo }> {
    const primaryEffort = mapEffortToClaude(this.config.reasoningEffort);
    const attempts = this.unsupportedModels.has(this.config.targetModel)
      ? [{ model: this.config.fallbackModel, effort: this.config.fallbackEffort, fallbackUsed: true }]
      : [
          { model: this.config.targetModel, effort: primaryEffort, fallbackUsed: false },
          { model: this.config.fallbackModel, effort: this.config.fallbackEffort, fallbackUsed: true },
        ];

    let lastError: Error | null = null;

    for (const attempt of attempts) {
      try {
        const result = await this.executeAttempt(options, attempt.model, attempt.effort, attempt.fallbackUsed);
        return result;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        if (!this.unsupportedModels.has(this.config.targetModel) && attempt.model === this.config.targetModel && /selected model/i.test(lastError.message)) {
          this.unsupportedModels.add(this.config.targetModel);
          continue;
        }

        if (attempt.model === this.config.fallbackModel) {
          break;
        }
      }
    }

    throw lastError ?? new Error('Claude Code 调用失败');
  }

  private async executeAttempt<T>(
    options: StructuredCallOptions<T>,
    model: string,
    effort: RuntimeStatus['fallbackEffort'],
    fallbackUsed: boolean,
  ): Promise<{ value: T; execution: ClaudeExecutionInfo }> {
    const agents = {
      [options.agentName]: {
        description: options.agentDescription,
        prompt: options.agentPrompt,
      },
    };

    const args = [
      '-p',
      '--output-format',
      'json',
      '--no-session-persistence',
      '--disable-slash-commands',
      '--agent',
      options.agentName,
      '--agents',
      JSON.stringify(agents),
      '--json-schema',
      JSON.stringify(options.schema),
      '--model',
      model,
      '--effort',
      effort,
      options.taskPrompt,
    ];

    const { stdout, stderr } = await this.spawnClaude(args, options.timeoutMs ?? 120000);
    const payload = parseJsonResult(stdout);

    if (payload.is_error || !payload.structured_output) {
      if (hasUnsupportedModelMessage(payload, stderr)) {
        throw new Error(payload.result ?? 'selected model is unavailable');
      }

      throw new Error(payload.result ?? (stderr || 'Claude Code 返回错误'));
    }

    const effectiveModel = Object.keys(payload.modelUsage ?? {})[0] ?? model;
    const value = options.parse(payload.structured_output);

    return {
      value,
      execution: {
        requestedModel: this.config.targetModel,
        requestedEffort: this.config.reasoningEffort,
        effectiveModel,
        effectiveEffort: effort,
        fallbackUsed,
        sessionId: payload.session_id,
        durationMs: Number(payload.duration_ms ?? 0),
      },
    };
  }

  private async spawnClaude(args: string[], timeoutMs: number): Promise<{ stdout: string; stderr: string }> {
    return new Promise((resolve, reject) => {
      const child = spawn(this.config.claudeBinary, args, {
        cwd: this.config.backendRoot,
        env: process.env,
      });

      let stdout = '';
      let stderr = '';

      const timer = setTimeout(() => {
        child.kill('SIGKILL');
        reject(new Error(`Claude Code 超时 (${timeoutMs}ms)`));
      }, timeoutMs);

      child.stdout.on('data', (chunk) => {
        stdout += String(chunk);
      });

      child.stderr.on('data', (chunk) => {
        stderr += String(chunk);
      });

      child.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });

      child.on('close', () => {
        clearTimeout(timer);
        resolve({ stdout, stderr });
      });
    });
  }
}

const runtime = new ClaudeCodeRuntime();

export function getRuntime(): ClaudeCodeRuntime {
  return runtime;
}

export function describeRuntime(): RuntimeStatus {
  return runtime.getStatus();
}
