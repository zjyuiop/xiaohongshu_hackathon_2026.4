import type { BackendRepository } from '../repository.js';
import type { ArenaMessage, ArenaPhase, ArenaRun, ArenaRunRequest, ArenaRunResponse, ClaudeExecutionInfo, PersonaSpec } from '../domain.js';
import { getRuntime } from './runtime.js';

function messageId(runId: string, index: number): string {
  return `${runId}-msg-${index + 1}`;
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

function getRingTarget(participants: PersonaSpec[], index: number, direction: 'next' | 'previous'): PersonaSpec | undefined {
  if (participants.length <= 1) {
    return undefined;
  }

  if (direction === 'next') {
    return participants[(index + 1) % participants.length];
  }

  return participants[(index + participants.length - 1) % participants.length];
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
  targetResolver?: (participants: PersonaSpec[], index: number) => PersonaSpec | undefined;
}) {
  const executions: ClaudeExecutionInfo[] = [];

  const calls = await Promise.all(
    input.participants.map(async (persona, index) => {
      const designatedTarget = input.targetResolver?.(input.participants, index);
      const ownPreviousMessages = collectOwnMessages(input.transcript, persona.agentId);
      const currentStance = ownPreviousMessages.at(-1)?.stance;

      try {
        return await getRuntime().generatePersonaMessage({
          persona,
          topic: input.topic,
          mode: input.mode,
          round: input.round,
          phase: input.phase,
          participants: input.participants,
          designatedTarget,
          ownPreviousMessages,
          currentStance,
          previousMessages: input.transcript,
        });
      } catch (error) {
        console.warn(`arena ${input.phase} fallback:`, error);
        return {
          message: heuristicMessage(persona, input.topic, input.phase, designatedTarget),
          execution: undefined,
        };
      }
    }),
  );

  const roundMessages: ArenaMessage[] = calls.map((result, index) => {
    if (result.execution) {
      executions.push(result.execution);
    }

    const persona = input.participants[index];
    const designatedTarget = input.targetResolver?.(input.participants, index);

    return {
      id: messageId(input.runId, input.transcript.length + index),
      agentId: persona.agentId,
      displayName: persona.displayName,
      stageLabel: persona.stageLabel,
      content: result.message.content,
      stance: result.message.stance,
      round: input.round,
      phase: input.phase,
      replyToAgentId: designatedTarget?.agentId,
      replyToDisplayName: designatedTarget?.displayName,
    };
  });

  return {
    messages: roundMessages,
    executions,
  };
}

export async function runArena(
  repository: BackendRepository,
  input: ArenaRunRequest,
): Promise<ArenaRunResponse> {
  const participants = input.selectedAgentIds
    .map((agentId) => input.agents.find((agent) => agent.agentId === agentId))
    .filter((agent): agent is PersonaSpec => Boolean(agent))
    .slice(0, 3);

  if (participants.length < 2) {
    throw new Error('至少需要 2 个 agent 才能开始讨论');
  }

  const runId = `run-${Date.now()}`;
  const executions: ClaudeExecutionInfo[] = [];
  let transcript: ArenaMessage[] = [];

  const roundPlans =
    input.mode === 'debate'
      ? [
          { round: 1, phase: 'opening' as ArenaPhase },
          { round: 2, phase: 'rebuttal' as ArenaPhase, targetResolver: (items: PersonaSpec[], index: number) => getRingTarget(items, index, 'next') },
          { round: 3, phase: 'closing' as ArenaPhase, targetResolver: (items: PersonaSpec[], index: number) => getRingTarget(items, index, 'previous') },
        ]
      : [
          { round: 1, phase: 'opening' as ArenaPhase },
          { round: 2, phase: 'reflection' as ArenaPhase, targetResolver: (items: PersonaSpec[], index: number) => getRingTarget(items, index, 'previous') },
          { round: 3, phase: 'synthesis' as ArenaPhase, targetResolver: (items: PersonaSpec[], index: number) => getRingTarget(items, index, 'next') },
        ];

  for (const roundPlan of roundPlans) {
    const executed = await executeRound({
      runId,
      topic: input.topic,
      mode: input.mode,
      phase: roundPlan.phase,
      round: roundPlan.round,
      participants,
      transcript,
      targetResolver: roundPlan.targetResolver,
    });

    transcript = [...transcript, ...executed.messages];
    executions.push(...executed.executions);
  }

  const messages = transcript;

  let summary;
  if (input.mode === 'debate') {
    try {
      const generated = await getRuntime().generateDebateJudgement({
        topic: input.topic,
        participants,
        messages,
      });
      summary = generated.summary;
      executions.push(generated.execution);
    } catch (error) {
      console.warn('debate judge fallback:', error);
      summary = heuristicDebateSummary(input.topic, participants, messages);
    }
  } else {
    try {
      const generated = await getRuntime().generateChatSummary({
        topic: input.topic,
        participants,
        messages,
      });
      summary = generated.summary;
      executions.push(generated.execution);
    } catch (error) {
      console.warn('chat moderator fallback:', error);
      summary = heuristicChatSummary(input.topic, participants, messages);
    }
  }

  const result: ArenaRun = {
    runId,
    mode: input.mode,
    topic: input.topic,
    participants,
    messages,
    summary,
  };

  await repository.saveArenaRun(result, executions);
  return { result };
}
