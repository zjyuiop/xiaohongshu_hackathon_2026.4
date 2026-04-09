import { query, type SDKMessage, type SDKResultMessage } from '@anthropic-ai/claude-agent-sdk';

import { getConfig, mapEffortToClaude } from '../config.js';
import type {
  ArenaMessage,
  ArenaMode,
  ArenaPhase,
  ArenaRun,
  ArenaSummary,
  ArenaRuntimeStreamObserver,
  ClaudeCliEffort,
  ClaudeExecutionInfo,
  GeneratedProfileDraft,
  MergeAgentsRequest,
  MergedPersonaDraft,
  PersonaBlueprint,
  PersonaSpec,
  PosterAspectRatio,
  PosterStylePreset,
  ReasoningEffort,
  RuntimeStatus,
  TimelineNode,
  TimelinePresentationRefinement,
} from '../domain.js';
import {
  buildArenaPosterTaskPrompt,
  buildArenaTurnTaskPrompt,
  buildChatSummaryTaskPrompt,
  buildDebateJudgementTaskPrompt,
  buildPersonaMergeTaskPrompt,
  buildPersonaAgentPrompt,
  buildPersonaTaskPrompt,
  buildTimelinePresentationTaskPrompt,
  buildTimelineTaskPrompt,
  chatModeratorAgentPrompt,
  debateJudgeAgentPrompt,
  personaFusionAgentPrompt,
  personaSmithAgentPrompt,
  posterArtDirectorAgentPrompt,
  timelineArchivistAgentPrompt,
  timelineDisplayEditorAgentPrompt,
} from '../prompts.js';
import {
  generatedArenaMessageJsonSchema,
  generatedArenaMessageSchema,
  generatedArenaPosterJsonSchema,
  generatedArenaPosterSchema,
  generatedChatSummaryJsonSchema,
  generatedChatSummarySchema,
  generatedDebateJudgeJsonSchema,
  generatedDebateJudgeSchema,
  generatedMergedPersonaJsonSchema,
  generatedMergedPersonaSchema,
  generatedPersonaBlueprintsJsonSchema,
  generatedPersonaBlueprintsSchema,
  generatedProfileJsonSchema,
  generatedProfileSchema,
  generatedTimelinePresentationJsonSchema,
  generatedTimelinePresentationSchema,
} from '../schemas.js';

interface StructuredCallOptions<T> {
  agentName: string;
  agentDescription: string;
  agentPrompt: string;
  taskPrompt: string;
  schema: Record<string, unknown>;
  parse: (value: unknown) => T;
  timeoutMs?: number;
  reasoningEffort?: ReasoningEffort;
  cwd?: string;
  settingSources?: Array<'user' | 'project' | 'local'>;
  tools?: string[] | { type: 'preset'; preset: 'claude_code' };
  allowedTools?: string[];
  permissionMode?: 'default' | 'acceptEdits' | 'plan' | 'dontAsk';
  onStreamMessage?: (message: SDKMessage) => void | Promise<void>;
  signal?: AbortSignal;
}

interface GeneratedArenaPosterPaths {
  outputDir: string;
  imagePath: string;
  promptPath?: string;
  sourcePath?: string;
  title: string;
  summary: string;
}

function normalizeClaudeResultText(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) {
    return trimmed;
  }

  const fenced = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  return fenced?.[1]?.trim() ?? trimmed;
}

function parseStructuredFallback(text: string): unknown {
  const normalized = normalizeClaudeResultText(text);
  if (!normalized) {
    throw new Error('Claude Agent SDK 未返回 structured_output');
  }

  return JSON.parse(normalized);
}

function hasUnsupportedModelMessage(message: string): boolean {
  return /issue with the selected model|may not exist|may not have access/i.test(message);
}

function isTimeoutMessage(message: string): boolean {
  return /超时|timeout|timed out/i.test(message);
}

function shouldUseSiliconFlowForModel(model: string): boolean {
  return /(gpt-5\.4|codex)/i.test(model);
}

function toError(value: unknown): Error {
  return value instanceof Error ? value : new Error(String(value));
}

function pickEffectiveModel(result: SDKResultMessage, fallback: string): string {
  const keys = Object.keys(result.modelUsage ?? {});
  return keys[0] ?? fallback;
}

function buildQueryErrorMessage(result: SDKResultMessage | undefined, caughtError?: Error): string {
  const parts: string[] = [];

  if (result?.type === 'result') {
    if (result.subtype === 'success') {
      if (result.result) {
        parts.push(result.result);
      }
    } else if (result.errors.length > 0) {
      parts.push(result.errors.join('; '));
    }
  }

  if (caughtError?.message) {
    parts.push(caughtError.message);
  }

  return parts.filter(Boolean).join('\n').trim();
}

function readPartialDelta(message: SDKMessage): { channel: 'text' | 'thinking'; delta: string } | null {
  if (message.type !== 'stream_event') {
    return null;
  }

  if (message.event.type !== 'content_block_delta') {
    return null;
  }

  if (message.event.delta.type === 'text_delta') {
    return {
      channel: 'text',
      delta: message.event.delta.text,
    };
  }

  if (message.event.delta.type === 'thinking_delta') {
    return {
      channel: 'thinking',
      delta: message.event.delta.thinking,
    };
  }

  return null;
}

interface SiliconFlowChatCompletionPayload {
  choices?: Array<{
    message?: {
      content?: string;
    };
  }>;
}

export class ClaudeCodeRuntime {
  private readonly config = getConfig();
  private readonly unsupportedModels = new Set<string>();

  getStatus(): RuntimeStatus {
    return {
      mode: 'claude-agent-sdk',
      claudeBinary: this.config.claudeBinary,
      ccsProfile: this.config.ccsProfile,
      requestedModel: this.config.targetModel,
      requestedEffort: this.config.reasoningEffort,
      fallbackModel: this.config.fallbackModel,
      fallbackEffort: this.config.fallbackEffort,
      unsupportedModels: Array.from(this.unsupportedModels),
      siliconFlowEnabled: Boolean(this.config.siliconFlowApiKey),
      siliconFlowFallbackModels: this.config.siliconFlowFallbackModels,
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

  async refineTimelinePresentation(input: {
    displayName: string;
    sourceLabel: string;
    subtitle: string;
    nodes: TimelineNode[];
  }): Promise<{ refinement: TimelinePresentationRefinement; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'timeline_display_editor',
      agentDescription: 'Polishes timeline node titles and summaries for UI display.',
      agentPrompt: timelineDisplayEditorAgentPrompt,
      taskPrompt: buildTimelinePresentationTaskPrompt(input),
      schema: generatedTimelinePresentationJsonSchema,
      parse: (value) => generatedTimelinePresentationSchema.parse(value),
      timeoutMs: 180000,
    }).then(({ value, execution }) => ({ refinement: value, execution }));
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

  async generateMergedPersona(input: MergeAgentsRequest): Promise<{ draft: MergedPersonaDraft; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'persona_fusion_architect',
      agentDescription: 'Fuses two existing personas into a new synthesized discussion persona.',
      agentPrompt: personaFusionAgentPrompt,
      taskPrompt: buildPersonaMergeTaskPrompt(input),
      schema: generatedMergedPersonaJsonSchema,
      parse: (value) => generatedMergedPersonaSchema.parse(value),
      timeoutMs: 45000,
    }).then(({ value, execution }) => ({ draft: value, execution }));
  }

  async generatePersonaMessage(input: {
    persona: PersonaSpec;
    topic: string;
    mode: ArenaMode;
    round: number;
    phase: ArenaPhase;
    maxMessageChars: number;
    participants: PersonaSpec[];
    designatedTarget?: PersonaSpec;
    ownPreviousMessages: ArenaMessage[];
    currentStance?: ArenaMessage['stance'];
    previousMessages: ArenaMessage[];
    reasoningEffort?: ReasoningEffort;
    streamObserver?: ArenaRuntimeStreamObserver;
    signal?: AbortSignal;
  }): Promise<{ message: Pick<ArenaMessage, 'content' | 'stance'>; execution: ClaudeExecutionInfo }> {
    const agentName = input.persona.agentId.replace(/[^a-zA-Z0-9_-]+/g, '_').slice(0, 60) || 'stage_speaker';
    const deltas = {
      text: '',
      thinking: '',
    };

    return this.runStructured({
      agentName,
      agentDescription: `${input.persona.displayName} speaking from a fixed historical stage.`,
      agentPrompt: buildPersonaAgentPrompt(input.persona),
      taskPrompt: buildArenaTurnTaskPrompt({
        mode: input.mode,
        topic: input.topic,
        round: input.round,
        phase: input.phase,
        maxMessageChars: input.maxMessageChars,
        persona: input.persona,
        participants: input.participants,
        designatedTarget: input.designatedTarget,
        ownPreviousMessages: input.ownPreviousMessages,
        currentStance: input.currentStance,
        previousMessages: input.previousMessages,
      }),
      schema: generatedArenaMessageJsonSchema,
      parse: (value) => generatedArenaMessageSchema.parse(value),
      timeoutMs: this.config.arenaSpeakerTimeoutMs,
      reasoningEffort: input.reasoningEffort,
      signal: input.signal,
      onStreamMessage: async (message) => {
        const partial = readPartialDelta(message);
        if (!partial) {
          return;
        }

        deltas[partial.channel] += partial.delta;
        await input.streamObserver?.onSpeakerDelta?.({
          channel: partial.channel,
          delta: partial.delta,
          accumulatedText: deltas[partial.channel],
        });
      },
    }).then(({ value, execution }) => ({ message: value, execution }));
  }

  async generateChatSummary(input: {
    topic: string;
    participants: PersonaSpec[];
    messages: ArenaMessage[];
    reasoningEffort?: ReasoningEffort;
    streamObserver?: ArenaRuntimeStreamObserver;
    signal?: AbortSignal;
  }): Promise<{ summary: ArenaSummary; execution: ClaudeExecutionInfo }> {
    const deltas = {
      text: '',
      thinking: '',
    };

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
      timeoutMs: this.config.arenaSummaryTimeoutMs,
      reasoningEffort: input.reasoningEffort,
      signal: input.signal,
      onStreamMessage: async (message) => {
        const partial = readPartialDelta(message);
        if (!partial) {
          return;
        }

        deltas[partial.channel] += partial.delta;
        await input.streamObserver?.onSummaryDelta?.({
          channel: partial.channel,
          delta: partial.delta,
          accumulatedText: deltas[partial.channel],
        });
      },
    }).then(({ value, execution }) => ({ summary: value, execution }));
  }

  async generateDebateJudgement(input: {
    topic: string;
    participants: PersonaSpec[];
    messages: ArenaMessage[];
    reasoningEffort?: ReasoningEffort;
    streamObserver?: ArenaRuntimeStreamObserver;
    signal?: AbortSignal;
  }): Promise<{ summary: ArenaSummary; execution: ClaudeExecutionInfo }> {
    const deltas = {
      text: '',
      thinking: '',
    };

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
      timeoutMs: this.config.arenaSummaryTimeoutMs,
      reasoningEffort: input.reasoningEffort,
      signal: input.signal,
      onStreamMessage: async (message) => {
        const partial = readPartialDelta(message);
        if (!partial) {
          return;
        }

        deltas[partial.channel] += partial.delta;
        await input.streamObserver?.onSummaryDelta?.({
          channel: partial.channel,
          delta: partial.delta,
          accumulatedText: deltas[partial.channel],
        });
      },
    }).then(({ value, execution }) => ({ summary: value, execution }));
  }

  async generateArenaPoster(input: {
    run: ArenaRun;
    sourceFilePath: string;
    workingDirectory: string;
    stylePreset: PosterStylePreset;
    aspectRatio: PosterAspectRatio;
    language: string;
    htmlOutputPath?: string;
    imageOutputPath?: string;
  }): Promise<{ poster: GeneratedArenaPosterPaths; execution: ClaudeExecutionInfo }> {
    return this.runStructured({
      agentName: 'arena_poster_director',
      agentDescription: 'Creates a shareable arena poster using Claude Code skills.',
      agentPrompt: posterArtDirectorAgentPrompt,
      taskPrompt: buildArenaPosterTaskPrompt({
        run: input.run,
        sourceFilePath: input.sourceFilePath,
        stylePreset: input.stylePreset,
        aspectRatio: input.aspectRatio,
        language: input.language,
        htmlOutputPath: input.htmlOutputPath,
        imageOutputPath: input.imageOutputPath,
      }),
      schema: generatedArenaPosterJsonSchema,
      parse: (value) => generatedArenaPosterSchema.parse(value),
      timeoutMs: 45000,
      cwd: input.workingDirectory,
      settingSources: ['project'],
      tools: { type: 'preset', preset: 'claude_code' },
      allowedTools: ['Skill', 'Read', 'Write', 'Edit', 'MultiEdit', 'Glob', 'LS', 'Bash'],
      permissionMode: 'dontAsk',
    }).then(({ value, execution }) => ({ poster: value, execution }));
  }

  private async runStructured<T>(options: StructuredCallOptions<T>): Promise<{ value: T; execution: ClaudeExecutionInfo }> {
    const requestedEffort = options.reasoningEffort ?? this.config.reasoningEffort;
    const primaryEffort = mapEffortToClaude(requestedEffort);
    const attempts = this.unsupportedModels.has(this.config.targetModel)
      ? [{ model: this.config.fallbackModel, effort: this.config.fallbackEffort, fallbackUsed: true }]
      : [
          { model: this.config.targetModel, effort: primaryEffort, fallbackUsed: false },
          { model: this.config.fallbackModel, effort: this.config.fallbackEffort, fallbackUsed: true },
        ];

    let lastError: Error | null = null;

    for (const attempt of attempts) {
      try {
        return await this.executeAttempt(options, attempt.model, attempt.effort, attempt.fallbackUsed);
      } catch (error) {
        lastError = toError(error);

        if (
          attempt.model === this.config.targetModel &&
          shouldUseSiliconFlowForModel(this.config.targetModel) &&
          isTimeoutMessage(lastError.message)
        ) {
          try {
            return await this.executeSiliconFlowFallback(options, requestedEffort);
          } catch (siliconFlowError) {
            lastError = toError(siliconFlowError);
          }
        }

        if (!this.unsupportedModels.has(this.config.targetModel) && attempt.model === this.config.targetModel && hasUnsupportedModelMessage(lastError.message)) {
          this.unsupportedModels.add(this.config.targetModel);
          continue;
        }

        if (attempt.model === this.config.fallbackModel) {
          break;
        }
      }
    }

    throw lastError ?? new Error('Claude Agent SDK 调用失败');
  }

  private async executeSiliconFlowFallback<T>(
    options: StructuredCallOptions<T>,
    requestedEffort: ReasoningEffort,
  ): Promise<{ value: T; execution: ClaudeExecutionInfo }> {
    if (!this.config.siliconFlowApiKey) {
      throw new Error('SiliconFlow fallback 未配置 API key');
    }

    const systemPrompt = `${options.agentPrompt}\n\nAgent ID: ${options.agentName}\nRole: ${options.agentDescription}`;
    const userPrompt = [
      options.taskPrompt,
      '',
      '硬性要求：',
      '1. 最终只输出一个 JSON 对象。',
      '2. 不要输出 markdown 代码块。',
      '3. 不要输出解释、前言、后记。',
      '4. JSON 必须严格符合给定 schema 的字段约束。',
    ].join('\n');

    let lastError: Error | null = null;

    for (const model of this.config.siliconFlowFallbackModels) {
      const startedAt = Date.now();
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), this.config.siliconFlowRequestTimeoutMs);
      const abortFromSignal = () => {
        controller.abort(options.signal?.reason);
      };

      try {
        if (options.signal?.aborted) {
          controller.abort(options.signal.reason);
        } else {
          options.signal?.addEventListener('abort', abortFromSignal, { once: true });
        }

        const response = await fetch(`${this.config.siliconFlowBaseUrl}/chat/completions`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${this.config.siliconFlowApiKey}`,
          },
          body: JSON.stringify({
            model,
            temperature: 0.2,
            response_format: { type: 'json_object' },
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: userPrompt },
            ],
          }),
          signal: controller.signal,
        });

        if (!response.ok) {
          const rawBody = (await response.text()).trim();
          throw new Error(
            `SiliconFlow 请求失败 (${model}): ${response.status}${rawBody ? ` - ${rawBody.slice(0, 240)}` : ''}`,
          );
        }

        const payload = (await response.json()) as SiliconFlowChatCompletionPayload;
        const content = payload.choices?.[0]?.message?.content?.trim();
        if (!content) {
          throw new Error(`SiliconFlow 未返回内容 (${model})`);
        }

        const rawValue = parseStructuredFallback(content);
        const value = options.parse(rawValue);

        return {
          value,
          execution: {
            requestedModel: this.config.targetModel,
            requestedEffort,
            effectiveModel: model,
            effectiveEffort: mapEffortToClaude(requestedEffort),
            fallbackUsed: true,
            durationMs: Date.now() - startedAt,
          },
        };
      } catch (error) {
        if (error instanceof Error && error.name === 'AbortError') {
          lastError = new Error(`SiliconFlow 超时 (${model}, ${this.config.siliconFlowRequestTimeoutMs}ms)`);
        } else {
          lastError = toError(error);
        }
      } finally {
        clearTimeout(timeout);
        options.signal?.removeEventListener('abort', abortFromSignal);
      }
    }

    throw lastError ?? new Error('SiliconFlow fallback 调用失败');
  }

  private async executeAttempt<T>(
    options: StructuredCallOptions<T>,
    model: string,
    effort: ClaudeCliEffort,
    fallbackUsed: boolean,
  ): Promise<{ value: T; execution: ClaudeExecutionInfo }> {
    const abortController = new AbortController();
    let timedOut = false;
    const abortFromSignal = () => {
      abortController.abort(options.signal?.reason);
    };

    const timer = setTimeout(() => {
      timedOut = true;
      abortController.abort();
    }, options.timeoutMs ?? 120000);

    let resultMessage: SDKResultMessage | undefined;
    let caughtError: Error | undefined;

    try {
      if (options.signal?.aborted) {
        abortFromSignal();
      } else {
        options.signal?.addEventListener('abort', abortFromSignal, { once: true });
      }

      for await (const message of query({
        prompt: options.taskPrompt,
        options: {
          abortController,
          cwd: options.cwd ?? this.config.backendRoot,
          pathToClaudeCodeExecutable: this.config.claudeBinary,
          permissionMode: options.permissionMode ?? 'plan',
          model,
          effort,
          tools: options.tools,
          allowedTools: options.allowedTools,
          settingSources: options.settingSources,
          outputFormat: {
            type: 'json_schema',
            schema: options.schema,
          },
          systemPrompt: `${options.agentPrompt}\n\nAgent ID: ${options.agentName}\nRole: ${options.agentDescription}`,
        },
      })) {
        if (options.onStreamMessage) {
          await options.onStreamMessage(message);
        }

        if (message.type === 'result') {
          resultMessage = message;
        }
      }
    } catch (error) {
      caughtError = toError(error);
    } finally {
      clearTimeout(timer);
      options.signal?.removeEventListener('abort', abortFromSignal);
    }

    if (timedOut) {
      throw new Error(`Claude Agent SDK 超时 (${options.timeoutMs ?? 120000}ms)`);
    }

    if (!resultMessage) {
      throw caughtError ?? new Error('Claude Agent SDK 未返回 result 消息');
    }

    if (resultMessage.subtype !== 'success' || resultMessage.is_error) {
      const message = buildQueryErrorMessage(resultMessage, caughtError);
      throw new Error(message || 'Claude Agent SDK 返回错误');
    }

    const rawValue = resultMessage.structured_output ?? parseStructuredFallback(resultMessage.result);
    const value = options.parse(rawValue);

    return {
      value,
      execution: {
        requestedModel: this.config.targetModel,
        requestedEffort: options.reasoningEffort ?? this.config.reasoningEffort,
        effectiveModel: pickEffectiveModel(resultMessage, model),
        effectiveEffort: effort,
        fallbackUsed,
        sessionId: resultMessage.session_id,
        durationMs: Number(resultMessage.duration_ms ?? 0),
      },
    };
  }
}

const runtime = new ClaudeCodeRuntime();

export function getRuntime(): ClaudeCodeRuntime {
  return runtime;
}

export function describeRuntime(): RuntimeStatus {
  return runtime.getStatus();
}
