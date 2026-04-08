import type { BackendRepository } from '../repository.js';
import type {
  ArenaMessage,
  ArenaOutputLinks,
  ArenaPhase,
  ArenaRun,
  ArenaRunObserver,
  ArenaRunRequest,
  ArenaRunResponse,
  ArenaStreamEvent,
  ClaudeExecutionInfo,
  PersonaSpec,
  ReasoningEffort,
} from '../domain.js';
import { getConfig } from '../config.js';
import { getRuntime } from './runtime.js';

const appConfig = getConfig();

class ArenaInterruptedError extends Error {
  constructor(message = '讨论已被中断') {
    super(message);
    this.name = 'ArenaInterruptedError';
  }
}

function messageId(runId: string, index: number): string {
  return `${runId}-msg-${index + 1}`;
}

function buildArenaLinks(runId: string): ArenaOutputLinks {
  return {
    runId,
    shareApiPath: `/api/arena/runs/${encodeURIComponent(runId)}`,
    suggestedSharePath: `/share/${encodeURIComponent(runId)}`,
  };
}

function heuristicMessage(
  persona: PersonaSpec,
  topic: string,
  phase: ArenaPhase,
  designatedTarget?: PersonaSpec,
): Pick<ArenaMessage, 'content' | 'stance'> {
  let stance: ArenaMessage['stance'] = 'neutral';
  if (persona.stanceSeed.includes('冒险') || persona.stanceSeed.includes('推进')) stance = 'support';
  if (persona.stanceSeed.includes('保守')) stance = 'oppose';
  if (persona.stanceSeed.includes('平衡') || persona.stanceSeed.includes('长期')) stance = 'reflective';

  if (phase === 'rebuttal' && designatedTarget) {
    return {
      content: `我不同意 ${designatedTarget.displayName} 的判断。围绕“${topic}”，你强调的是一时推进，但站在 ${persona.timeLabel} 的我更在意 ${persona.values.join('、')}，因为我最怕的是 ${persona.fear}。`,
      stance,
    };
  }

  if (phase === 'closing' || phase === 'synthesis') {
    return {
      content: `如果最后只能留下一句判断，围绕“${topic}”，我会坚持 ${persona.stanceSeed}。真正需要守住的是 ${persona.goal}，而不是被短期情绪推着走。`,
      stance,
    };
  }

  if (phase === 'reflection' && designatedTarget) {
    return {
      content: `我能理解 ${designatedTarget.displayName} 为什么会这样说，但站在 ${persona.timeLabel} 的我会补一句：别只看眼前势头，还得看 ${persona.values.join('、')} 是否撑得住这次选择。`,
      stance: 'reflective',
    };
  }

  return {
    content: `如果问题是“${topic}”，站在 ${persona.timeLabel} 的我会先看 ${persona.values.join('、')}。我最在意的是 ${persona.goal}，所以直觉会偏向 ${persona.stanceSeed}。`,
    stance,
  };
}

function heuristicChatSummary(topic: string, participants: PersonaSpec[], messages: ArenaMessage[]) {
  return {
    title: '阶段人格会议纪要',
    consensus: `围绕“${topic}”，这些阶段人格都不再把答案看成单一的是或否，而是更关注代价、边界和时机。`,
    disagreements: participants.map((agent) => `${agent.stageLabel} 更看重 ${agent.values.join('、')}`),
    actionableAdvice: [
      '先写清你当前最不能失去的东西，再决定是否行动。',
      '把冲动和恐惧拆开处理，不要让同一种情绪同时做判断和执行。',
      '如果要改变，优先做低后悔成本的那一步。',
    ],
    narrativeHook: messages[0]?.content ?? '不同阶段的自己在同一个问题上给出了明显不同的判断。',
    moderatorNote: '真正成熟的答案，不是立刻统一，而是先看清每个阶段为什么会这样说。',
  };
}

function heuristicDebateSummary(topic: string, participants: PersonaSpec[], messages: ArenaMessage[]) {
  const winner = participants[0];

  return {
    title: '阶段人格辩论结果',
    consensus: `围绕“${topic}”，大家都承认决策不能只看冲动，必须同时考虑代价、组织承受力和长期后果。`,
    disagreements: participants.map((agent) => `${agent.stageLabel} 对风险与机会的权重不同`),
    actionableAdvice: [
      '先验证团队和节奏能否承载目标，再决定推进速度。',
      '把“想证明自己”和“真正值得做”拆开判断。',
      '把第二次出手建立在第一次失败的复盘之上，而不是建立在不甘心之上。',
    ],
    narrativeHook: messages[0]?.content ?? '几个阶段的自己围绕同一个问题展开了真正的互相质问。',
    debateVerdict: {
      winnerAgentId: winner?.agentId,
      winnerDisplayName: winner?.displayName,
      rationale: '在 fallback 模式下，系统默认把论点最先完整展开的一方视作暂时领先，但这不是严格裁判结果。',
      scorecards: participants.map((participant, index) => ({
        agentId: participant.agentId,
        displayName: participant.displayName,
        argumentScore: Math.max(6, 8 - index),
        evidenceScore: Math.max(6, 8 - index),
        responsivenessScore: Math.max(6, 8 - index),
        comments: `${participant.stageLabel} 的立场清晰，但 fallback 模式无法给出更精细的评分。`,
      })),
    },
  };
}

function buildInterruptedSummary(
  mode: ArenaRunRequest['mode'],
  topic: string,
  participants: PersonaSpec[],
  messages: ArenaMessage[],
): ArenaRun['summary'] {
  const consensusPrefix =
    messages.length > 0 ? '讨论被用户中途打断，以下是截至当前节点的阶段性结论。' : '讨论在正式展开前被中断，尚未形成充分结论。';

  if (mode === 'debate') {
    const base = normalizeDebateSummary(heuristicDebateSummary(topic, participants, messages), participants);
    const verdict = base.debateVerdict ?? {
      winnerAgentId: participants[0]?.agentId,
      winnerDisplayName: participants[0]?.displayName,
      rationale: '讨论在形成完整裁决前已被中断。',
      scorecards: participants.map((participant) => ({
        agentId: participant.agentId,
        displayName: participant.displayName,
        argumentScore: 6,
        evidenceScore: 6,
        responsivenessScore: 6,
        comments: '讨论被提前中断，当前仅保留阶段性评分。',
      })),
    };
    return {
      ...base,
      title: `${base.title}（中途打断）`,
      consensus: `${consensusPrefix}${base.consensus}`,
      debateVerdict: {
        ...verdict,
        rationale: `本场辩论尚未完整结束，当前结论仅基于已生成的部分交锋内容。${verdict.rationale}`,
      },
    };
  }

  const base = heuristicChatSummary(topic, participants, messages);
  return {
    ...base,
    title: `${base.title}（中途打断）`,
    consensus: `${consensusPrefix}${base.consensus}`,
    moderatorNote: '用户在讨论过程中插入了新的引导，建议基于当前记录继续追问。',
  };
}

function isAbortLikeError(error: unknown): boolean {
  if (error instanceof ArenaInterruptedError) {
    return true;
  }

  const message = error instanceof Error ? error.message : String(error);
  return /abort|aborted|cancelled|canceled|interrupted/i.test(message);
}

function throwIfAborted(signal?: AbortSignal): void {
  if (!signal?.aborted) {
    return;
  }

  const reason =
    typeof signal.reason === 'string'
      ? signal.reason
      : signal.reason instanceof Error
        ? signal.reason.message
        : '讨论已被中断';
  throw new ArenaInterruptedError(reason);
}

function resolveParticipantReference(
  participants: PersonaSpec[],
  agentId?: string,
  displayName?: string,
): PersonaSpec | undefined {
  const normalizeReference = (value: string) =>
    value
      .toLowerCase()
      .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '')
      .trim();

  if (agentId) {
    const exactById = participants.find((participant) => participant.agentId === agentId);
    if (exactById) {
      return exactById;
    }
  }

  if (displayName) {
    const exactByDisplayName = participants.find((participant) => participant.displayName === displayName);
    if (exactByDisplayName) {
      return exactByDisplayName;
    }

    const normalizedDisplayName = normalizeReference(displayName);
    const byNormalizedDisplayName = participants.find((participant) => {
      const normalizedParticipantDisplayName = normalizeReference(participant.displayName);
      const normalizedStageLabel = normalizeReference(participant.stageLabel);
      return (
        normalizedParticipantDisplayName === normalizedDisplayName ||
        normalizedParticipantDisplayName.includes(normalizedDisplayName) ||
        normalizedDisplayName.includes(normalizedParticipantDisplayName) ||
        normalizedStageLabel === normalizedDisplayName ||
        normalizedDisplayName.includes(normalizedStageLabel)
      );
    });
    if (byNormalizedDisplayName) {
      return byNormalizedDisplayName;
    }

    const byStageLabel = participants.find(
      (participant) =>
        displayName.includes(participant.stageLabel) || participant.displayName.includes(displayName),
    );
    if (byStageLabel) {
      return byStageLabel;
    }
  }

  if (agentId) {
    const normalizedAgentId = normalizeReference(agentId);
    const byNormalizedId = participants.find((participant) => {
      const normalizedParticipantId = normalizeReference(participant.agentId);
      const normalizedStageLabel = normalizeReference(participant.stageLabel);
      return (
        normalizedParticipantId === normalizedAgentId ||
        normalizedParticipantId.includes(normalizedAgentId) ||
        normalizedAgentId.includes(normalizedParticipantId) ||
        normalizedAgentId.includes(normalizedStageLabel)
      );
    });
    if (byNormalizedId) {
      return byNormalizedId;
    }

    return participants.find(
      (participant) =>
        agentId.includes(participant.stageLabel) ||
        participant.agentId.includes(agentId) ||
        agentId.includes(participant.agentId),
    );
  }

  return undefined;
}

function normalizeDebateSummary(summary: ArenaRun['summary'], participants: PersonaSpec[]) {
  if (!summary.debateVerdict) {
    return summary;
  }

  const scorecards = summary.debateVerdict.scorecards.map((scorecard) => {
    const participant = resolveParticipantReference(participants, scorecard.agentId, scorecard.displayName);
    if (!participant) {
      return scorecard;
    }

    return {
      ...scorecard,
      agentId: participant.agentId,
      displayName: participant.displayName,
    };
  });

  const winner = resolveParticipantReference(
    participants,
    summary.debateVerdict.winnerAgentId,
    summary.debateVerdict.winnerDisplayName,
  );

  return {
    ...summary,
    debateVerdict: {
      ...summary.debateVerdict,
      winnerAgentId: winner?.agentId ?? summary.debateVerdict.winnerAgentId,
      winnerDisplayName: winner?.displayName ?? summary.debateVerdict.winnerDisplayName,
      scorecards,
    },
  };
}

function getRingTarget(participants: PersonaSpec[], index: number, direction: 'next' | 'previous'): PersonaSpec | undefined {
  if (participants.length <= 1) {
    return undefined;
  }

  if (direction === 'next') {
    return participants[(index + 1) % participants.length];
  }

  return participants[(index + participants.length - 1) % participants.length];
}

function rotateParticipants(participants: PersonaSpec[], offset: number): PersonaSpec[] {
  if (participants.length <= 1) {
    return participants;
  }

  const normalizedOffset = ((offset % participants.length) + participants.length) % participants.length;
  return participants.slice(normalizedOffset).concat(participants.slice(0, normalizedOffset));
}

function collectOwnMessages(messages: ArenaMessage[], agentId: string): ArenaMessage[] {
  return messages.filter((message) => message.agentId === agentId);
}

async function executeRound(input: {
  runId: string;
  topic: string;
  mode: ArenaRunRequest['mode'];
  phase: ArenaPhase;
  round: number;
  participants: PersonaSpec[];
  transcript: ArenaMessage[];
  maxMessageChars: number;
  reasoningEffort?: ReasoningEffort;
  signal?: AbortSignal;
  targetResolver?: (participants: PersonaSpec[], index: number) => PersonaSpec | undefined;
  onSpeakerStarted?: (event: {
    round: number;
    phase: ArenaPhase;
    messageId: string;
    participant: PersonaSpec;
    designatedTarget?: PersonaSpec;
  }) => void | Promise<void>;
  onSpeakerDelta?: (event: {
    round: number;
    phase: ArenaPhase;
    messageId: string;
    participant: PersonaSpec;
    channel: 'text' | 'thinking';
    delta: string;
    accumulatedText: string;
  }) => void | Promise<void>;
  onMessage?: (message: ArenaMessage) => void | Promise<void>;
  onSpeakerCompleted?: (event: {
    round: number;
    phase: ArenaPhase;
    messageId: string;
    participant: PersonaSpec;
    execution?: ClaudeExecutionInfo;
    usedFallback: boolean;
    durationMs: number;
  }) => void | Promise<void>;
}) {
  const executions: ClaudeExecutionInfo[] = [];
  const roundMessages: ArenaMessage[] = [];
  let rollingTranscript = [...input.transcript];

  for (const [index, persona] of input.participants.entries()) {
    throwIfAborted(input.signal);

    const designatedTarget = input.targetResolver?.(input.participants, index);
    const ownPreviousMessages = collectOwnMessages(rollingTranscript, persona.agentId).slice(-3);
    const currentStance = ownPreviousMessages.at(-1)?.stance;
    const visibleTranscript = (() => {
      const recentUserGuidance = rollingTranscript.filter((message) => message.kind === 'user').slice(-2);
      const recentConversation = rollingTranscript.filter((message) => message.kind !== 'user').slice(-8);
      const selected = new Set([...recentUserGuidance, ...recentConversation]);
      return rollingTranscript.filter((message) => selected.has(message));
    })();
    const currentMessageId = messageId(input.runId, rollingTranscript.length);
    const startedAt = Date.now();
    let partialText = '';

    await input.onSpeakerStarted?.({
      round: input.round,
      phase: input.phase,
      messageId: currentMessageId,
      participant: persona,
      designatedTarget,
    });

    try {
      const generated = await getRuntime().generatePersonaMessage({
        persona,
        topic: input.topic,
        mode: input.mode,
        round: input.round,
        phase: input.phase,
        maxMessageChars: input.maxMessageChars,
        participants: input.participants,
        designatedTarget,
        ownPreviousMessages,
        currentStance,
        previousMessages: visibleTranscript,
        reasoningEffort: input.reasoningEffort,
        signal: input.signal,
        streamObserver: {
          onSpeakerDelta: async (event) => {
            if (event.channel === 'text') {
              partialText = event.accumulatedText;
            }

            await input.onSpeakerDelta?.({
              round: input.round,
              phase: input.phase,
              messageId: currentMessageId,
              participant: persona,
              channel: event.channel,
              delta: event.delta,
              accumulatedText: event.accumulatedText,
            });
          },
        },
      });

      const message: ArenaMessage = {
        id: currentMessageId,
        kind: 'agent',
        agentId: persona.agentId,
        displayName: persona.displayName,
        stageLabel: persona.stageLabel,
        content: generated.message.content,
        stance: generated.message.stance,
        round: input.round,
        phase: input.phase,
        replyToAgentId: designatedTarget?.agentId,
        replyToDisplayName: designatedTarget?.displayName,
      };

      executions.push(generated.execution);
      roundMessages.push(message);
      rollingTranscript = [...rollingTranscript, message];
      await input.onMessage?.(message);
      await input.onSpeakerCompleted?.({
        round: input.round,
        phase: input.phase,
        messageId: message.id,
        participant: persona,
        execution: generated.execution,
        usedFallback: false,
        durationMs: Date.now() - startedAt,
      });
    } catch (error) {
      if (isAbortLikeError(error) || input.signal?.aborted) {
        const interruptedContent = partialText.trim();
        if (interruptedContent) {
          const partialMessage: ArenaMessage = {
            id: currentMessageId,
            kind: 'agent',
            agentId: persona.agentId,
            displayName: persona.displayName,
            stageLabel: persona.stageLabel,
            content: interruptedContent,
            stance: currentStance ?? 'reflective',
            round: input.round,
            phase: input.phase,
            replyToAgentId: designatedTarget?.agentId,
            replyToDisplayName: designatedTarget?.displayName,
          };

          roundMessages.push(partialMessage);
          rollingTranscript = [...rollingTranscript, partialMessage];
          await input.onMessage?.(partialMessage);
          await input.onSpeakerCompleted?.({
            round: input.round,
            phase: input.phase,
            messageId: partialMessage.id,
            participant: persona,
            execution: undefined,
            usedFallback: true,
            durationMs: Date.now() - startedAt,
          });
        }

        throw error instanceof ArenaInterruptedError ? error : new ArenaInterruptedError();
      }

      console.warn(`arena ${input.phase} fallback:`, error);
      const fallbackMessage = heuristicMessage(persona, input.topic, input.phase, designatedTarget);
      const message: ArenaMessage = {
        id: currentMessageId,
        kind: 'agent',
        agentId: persona.agentId,
        displayName: persona.displayName,
        stageLabel: persona.stageLabel,
        content: fallbackMessage.content,
        stance: fallbackMessage.stance,
        round: input.round,
        phase: input.phase,
        replyToAgentId: designatedTarget?.agentId,
        replyToDisplayName: designatedTarget?.displayName,
      };

      roundMessages.push(message);
      rollingTranscript = [...rollingTranscript, message];
      await input.onMessage?.(message);
      await input.onSpeakerCompleted?.({
        round: input.round,
        phase: input.phase,
        messageId: message.id,
        participant: persona,
        execution: undefined,
        usedFallback: true,
        durationMs: Date.now() - startedAt,
      });
    }
  }

  return {
    messages: roundMessages,
    executions,
  };
}

function getRoundPlans(mode: ArenaRunRequest['mode'], roundCount: number) {
  const plans: Array<{
    round: number;
    phase: ArenaPhase;
    targetResolver?: (participants: PersonaSpec[], index: number) => PersonaSpec | undefined;
  }> = [];

  for (let round = 1; round <= roundCount; round += 1) {
    if (round === 1) {
      plans.push({ round, phase: 'opening' });
      continue;
    }

    if (round === roundCount) {
      plans.push({
        round,
        phase: mode === 'debate' ? 'closing' : 'synthesis',
        targetResolver: (items, index) => getRingTarget(items, index, 'previous'),
      });
      continue;
    }

    plans.push({
      round,
      phase: mode === 'debate' ? 'rebuttal' : 'reflection',
      targetResolver: (items, index) => getRingTarget(items, index, round % 2 === 0 ? 'next' : 'previous'),
    });
  }

  return plans;
}

export async function runArena(
  repository: BackendRepository,
  input: ArenaRunRequest,
  options?: ArenaRunObserver & { signal?: AbortSignal },
): Promise<ArenaRunResponse> {
  const participants = input.selectedAgentIds
    .map((agentId) => input.agents.find((agent) => agent.agentId === agentId))
    .filter((agent): agent is PersonaSpec => Boolean(agent))
    .slice(0, 3);

  if (participants.length < 2) {
    throw new Error('至少需要 2 个 agent 才能开始讨论');
  }

  const previousRun = input.continueFromRunId ? await repository.getArenaRun(input.continueFromRunId) : null;
  if (input.continueFromRunId && !previousRun) {
    throw new Error(`未找到要继续的讨论记录: ${input.continueFromRunId}`);
  }

  const runId = `run-${Date.now()}`;
  const links = buildArenaLinks(runId);
  const executions: ClaudeExecutionInfo[] = [];
  const roundCount = input.roundCount ?? 3;
  const maxMessageChars = input.maxMessageChars ?? 180;
  const sessionId = input.sessionId ?? previousRun?.sessionId ?? runId;
  let transcript: ArenaMessage[] = previousRun?.messages ? [...previousRun.messages] : [];
  const roundPlans = getRoundPlans(input.mode, roundCount);
  let sequence = 0;
  const requestedReasoningEffort = input.reasoningEffort ?? getRuntime().getStatus().requestedEffort;
  const guidance = input.guidance?.trim();
  const timeoutController = new AbortController();
  const signal = timeoutController.signal;
  const timeout = setTimeout(() => {
    timeoutController.abort(new ArenaInterruptedError(`讨论执行超时（${appConfig.arenaRunTimeoutMs}ms）`));
  }, appConfig.arenaRunTimeoutMs);
  const forwardAbort = () => {
    timeoutController.abort(options?.signal?.reason ?? new ArenaInterruptedError());
  };
  if (options?.signal?.aborted) {
    forwardAbort();
  } else {
    options?.signal?.addEventListener('abort', forwardAbort, { once: true });
  }
  const config = {
    roundCount,
    maxMessageChars,
    reasoningEffort: requestedReasoningEffort,
  } as const;

  const emit = async (event: { type: ArenaStreamEvent['type']; [key: string]: unknown }) => {
    if (!options?.onEvent) {
      return;
    }

    sequence += 1;
    await options.onEvent({
      ...event,
      runId,
      mode: input.mode,
      topic: input.topic,
      sequence,
      timestamp: new Date().toISOString(),
    } as ArenaStreamEvent);
  };

  try {
    throwIfAborted(signal);

    await emit({
      type: 'run_started',
      reasoningEffort: requestedReasoningEffort,
      config,
      sessionId,
      continuedFromRunId: previousRun?.runId,
      participants,
      plannedRounds: roundPlans.map((item) => ({ round: item.round, phase: item.phase })),
    });

    if (guidance) {
      const guidanceMessage: ArenaMessage = {
        id: `${runId}-user-1`,
        kind: 'user',
        agentId: 'user',
        displayName: '你',
        stageLabel: '实时引导',
        content: guidance,
        stance: 'neutral',
      };
      transcript = [...transcript, guidanceMessage];
      await emit({
        type: 'message',
        round: 0,
        phase: 'opening',
        message: guidanceMessage,
      });
    }

    for (const roundPlan of roundPlans) {
      throwIfAborted(signal);

      const orderedParticipants = rotateParticipants(participants, Math.max(0, roundPlan.round - 1));
      await emit({
        type: 'phase_started',
        round: roundPlan.round,
        phase: roundPlan.phase,
        participants: orderedParticipants.map((participant) => ({
          agentId: participant.agentId,
          displayName: participant.displayName,
        })),
      });

      const executed = await executeRound({
        runId,
        topic: input.topic,
        mode: input.mode,
        phase: roundPlan.phase,
        round: roundPlan.round,
        participants: orderedParticipants,
        transcript,
        maxMessageChars,
        reasoningEffort: requestedReasoningEffort,
        signal,
        targetResolver: roundPlan.targetResolver,
        onSpeakerStarted: async ({ messageId, participant, designatedTarget }) => {
          await emit({
            type: 'speaker_started',
            round: roundPlan.round,
            phase: roundPlan.phase,
            messageId,
            participant: {
              agentId: participant.agentId,
              displayName: participant.displayName,
              stageLabel: participant.stageLabel,
            },
            replyTarget: designatedTarget
              ? {
                  agentId: designatedTarget.agentId,
                  displayName: designatedTarget.displayName,
                }
              : undefined,
          });
        },
        onSpeakerDelta: async ({ messageId, participant, channel, delta, accumulatedText }) => {
          await emit({
            type: 'speaker_delta',
            round: roundPlan.round,
            phase: roundPlan.phase,
            messageId,
            agentId: participant.agentId,
            displayName: participant.displayName,
            channel,
            delta,
            accumulatedText,
          });
        },
        onMessage: async (message) => {
          await emit({
            type: 'message',
            round: roundPlan.round,
            phase: roundPlan.phase,
            message,
          });
        },
        onSpeakerCompleted: async ({ messageId, participant, execution, usedFallback, durationMs }) => {
          await emit({
            type: 'speaker_completed',
            round: roundPlan.round,
            phase: roundPlan.phase,
            messageId,
            agentId: participant.agentId,
            displayName: participant.displayName,
            usedFallback,
            durationMs,
            execution,
          });
        },
      });

      transcript = [...transcript, ...executed.messages];
      executions.push(...executed.executions);

      await emit({
        type: 'phase_completed',
        round: roundPlan.round,
        phase: roundPlan.phase,
        messageIds: executed.messages.map((message) => message.id),
      });
    }

    const messages = transcript;
    throwIfAborted(signal);

    await emit({
      type: 'summary_started',
    });

    let summary;
    if (input.mode === 'debate') {
      try {
        const generated = await getRuntime().generateDebateJudgement({
          topic: input.topic,
          participants,
          messages,
          reasoningEffort: requestedReasoningEffort,
          signal,
          streamObserver: {
            onSummaryDelta: async ({ channel, delta, accumulatedText }) => {
              await emit({
                type: 'summary_delta',
                channel,
                delta,
                accumulatedText,
              });
            },
          },
        });
        summary = normalizeDebateSummary(generated.summary, participants);
        executions.push(generated.execution);
      } catch (error) {
        if (isAbortLikeError(error) || signal?.aborted) {
          throw error;
        }
        console.warn('debate judge fallback:', error);
        summary = normalizeDebateSummary(heuristicDebateSummary(input.topic, participants, messages), participants);
      }
    } else {
      try {
        const generated = await getRuntime().generateChatSummary({
          topic: input.topic,
          participants,
          messages,
          reasoningEffort: requestedReasoningEffort,
          signal,
          streamObserver: {
            onSummaryDelta: async ({ channel, delta, accumulatedText }) => {
              await emit({
                type: 'summary_delta',
                channel,
                delta,
                accumulatedText,
              });
            },
          },
        });
        summary = generated.summary;
        executions.push(generated.execution);
      } catch (error) {
        if (isAbortLikeError(error) || signal?.aborted) {
          throw error;
        }
        console.warn('chat moderator fallback:', error);
        summary = heuristicChatSummary(input.topic, participants, messages);
      }
    }

    await emit({
      type: 'summary',
      summary,
    });

    const result: ArenaRun = {
      runId,
      sessionId,
      continuedFromRunId: previousRun?.runId,
      status: 'completed',
      mode: input.mode,
      topic: input.topic,
      participants,
      messages,
      summary,
      config,
      createdAt: new Date().toISOString(),
    };

    await repository.saveArenaRun(result, executions);
    await emit({
      type: 'done',
      result,
      links,
    });

    return { result, links };
  } catch (error) {
    if (isAbortLikeError(error) || signal?.aborted) {
      const summary = buildInterruptedSummary(input.mode, input.topic, participants, transcript);
      const result: ArenaRun = {
        runId,
        sessionId,
        continuedFromRunId: previousRun?.runId,
        status: 'interrupted',
        mode: input.mode,
        topic: input.topic,
        participants,
        messages: transcript,
        summary,
        config,
        createdAt: new Date().toISOString(),
      };

      await emit({
        type: 'summary',
        summary,
      });
      await repository.saveArenaRun(result, executions);
      await emit({
        type: 'done',
        result,
        links,
      });

      return { result, links };
    }

    await emit({
      type: 'error',
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  } finally {
    clearTimeout(timeout);
    options?.signal?.removeEventListener('abort', forwardAbort);
  }
}
