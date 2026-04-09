import type { BackendRepository } from '../repository.js';
import type {
  BuildAgentsRequest,
  BuildAgentsResponse,
  MergeAgentsRequest,
  MergeAgentsResponse,
  MergedPersonaDraft,
  PersonaBlueprint,
  PersonaSpec,
  SourceEvidence,
  TimelineNode,
} from '../domain.js';
import { getRuntime } from './runtime.js';

function defaultGoal(node: TimelineNode): string {
  if (node.stageType === 'early') return '证明自己有资格被看见';
  if (node.stageType === 'turning-point') return '抓住转折并把势能放大';
  if (node.stageType === 'crisis') return '避免再次受伤，同时守住体面';
  if (node.stageType === 'rebuild') return '重新建立更稳定的选择方式';
  if (node.stageType === 'peak') return '把经验沉淀成更有掌控感的判断';
  return '把眼前的局面撑住';
}

function defaultFear(node: TimelineNode): string {
  if (node.stageType === 'early') return '害怕还没开始就被现实定义';
  if (node.stageType === 'turning-point') return '害怕错过机会后再也追不上';
  if (node.stageType === 'crisis') return '害怕投入再次变成损耗';
  if (node.stageType === 'rebuild') return '害怕退回旧模式';
  if (node.stageType === 'peak') return '害怕因为自负而忽略风险';
  return '害怕选择被动发生';
}

function defaultVoiceStyle(node: TimelineNode): string {
  if (node.stageType === 'early') return '语气直接、带一点冲劲';
  if (node.stageType === 'turning-point') return '表达强势，偏行动导向';
  if (node.stageType === 'crisis') return '更谨慎，也更容易显露情绪';
  if (node.stageType === 'rebuild') return '说话更慢，更强调边界';
  if (node.stageType === 'peak') return '表达简洁，结论性强';
  return '语气克制，偏观察型';
}

function defaultStanceSeed(node: TimelineNode): string {
  if (node.stageType === 'early') return '倾向冒险，认为先行动再修正';
  if (node.stageType === 'turning-point') return '倾向强推进，认为窗口期最重要';
  if (node.stageType === 'crisis') return '倾向保守，先降低损失';
  if (node.stageType === 'rebuild') return '倾向平衡，强调边界与节奏';
  if (node.stageType === 'peak') return '倾向聚焦，强调长期判断';
  return '倾向先观察再判断';
}

function mergeBlueprint(personId: string, displayName: string, node: TimelineNode, blueprint?: PersonaBlueprint): PersonaSpec {
  return {
    agentId: `${node.nodeId}-agent`,
    displayName: `${displayName} · ${node.stageLabel}`,
    personId,
    avatarSeed: `${personId}-${node.stageType}`,
    timeLabel: node.timeLabel,
    stageLabel: node.stageLabel,
    keyEvent: node.keyEvent,
    knownFacts: blueprint?.knownFacts?.length ? blueprint.knownFacts : [node.summary, ...node.tensions].slice(0, 4),
    sourceEvidence: node.sourceEvidence,
    traits: node.traits,
    values: node.values,
    goal: blueprint?.goal ?? defaultGoal(node),
    fear: blueprint?.fear ?? defaultFear(node),
    voiceStyle: blueprint?.voiceStyle ?? defaultVoiceStyle(node),
    knowledgeBoundary: blueprint?.knowledgeBoundary ?? `只能知道 ${node.timeLabel} 及之前已经发生的事实，不知道后续结局。`,
    forbiddenFutureKnowledge: true,
    stanceSeed: blueprint?.stanceSeed ?? defaultStanceSeed(node),
  };
}

function slugify(value: string): string {
  const normalized = value
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return normalized || 'fusion';
}

function uniqueStrings(values: string[], maxItems: number): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const rawValue of values) {
    const value = rawValue.trim();
    if (!value) {
      continue;
    }

    const key = value.toLowerCase();
    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    result.push(value);

    if (result.length >= maxItems) {
      break;
    }
  }

  return result;
}

function uniqueEvidence(items: SourceEvidence[], maxItems: number): SourceEvidence[] {
  const seen = new Set<string>();
  const result: SourceEvidence[] = [];

  for (const item of items) {
    const quote = item.quote.trim();
    const sourceLabel = item.sourceLabel.trim();
    if (!quote || !sourceLabel) {
      continue;
    }

    const key = `${sourceLabel.toLowerCase()}::${quote.toLowerCase()}`;
    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    result.push({ quote, sourceLabel });

    if (result.length >= maxItems) {
      break;
    }
  }

  return result;
}

function buildMergedKnowledgeBoundary(primary: PersonaSpec, secondary: PersonaSpec): string {
  return `只能基于 ${primary.displayName} 在 ${primary.timeLabel} 之前、以及 ${secondary.displayName} 在 ${secondary.timeLabel} 之前已经发生的事实发言，不能补充任一人格尚未经历的后续信息。`;
}

function buildMergedDraftFallback(input: MergeAgentsRequest): MergedPersonaDraft {
  const name =
    input.displayName?.trim() ||
    uniqueStrings(
      [
        input.primary.displayName.replace(/\s*·\s*.+$/, ''),
        input.secondary.displayName.replace(/\s*·\s*.+$/, ''),
      ],
      2,
    ).join(' × ');

  return {
    displayName: name || '融合人格',
    avatarSeed: slugify(`${input.primary.avatarSeed}-${input.secondary.avatarSeed}`),
    timeLabel: uniqueStrings([input.primary.timeLabel, input.secondary.timeLabel], 2).join(' / '),
    stageLabel: uniqueStrings([input.primary.stageLabel, input.secondary.stageLabel], 2).join(' × '),
    keyEvent: uniqueStrings([input.primary.keyEvent, input.secondary.keyEvent], 2).join('；'),
    knownFacts: uniqueStrings([...input.primary.knownFacts, ...input.secondary.knownFacts], 6),
    sourceEvidence: uniqueEvidence([...input.primary.sourceEvidence, ...input.secondary.sourceEvidence], 6),
    traits: uniqueStrings([...input.primary.traits, ...input.secondary.traits], 6),
    values: uniqueStrings([...input.primary.values, ...input.secondary.values], 6),
    goal: `既要 ${input.primary.goal}，也要 ${input.secondary.goal}`.slice(0, 120),
    fear: `既担心 ${input.primary.fear}，也担心 ${input.secondary.fear}`.slice(0, 120),
    voiceStyle: `融合 ${input.primary.voiceStyle} 与 ${input.secondary.voiceStyle}`.slice(0, 80),
    knowledgeBoundary: buildMergedKnowledgeBoundary(input.primary, input.secondary),
    forbiddenFutureKnowledge: input.primary.forbiddenFutureKnowledge || input.secondary.forbiddenFutureKnowledge,
    stanceSeed: uniqueStrings([input.primary.stanceSeed, input.secondary.stanceSeed], 2).join('；'),
  };
}

function normalizeMergedPersona(input: MergeAgentsRequest, draft: MergedPersonaDraft): PersonaSpec {
  const mergedPersonIdBase = slugify(`${input.primary.personId}-${input.secondary.personId}`);
  const mergedPersonId = `fusion-${mergedPersonIdBase}`.slice(0, 80);
  const nonce = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  const displayName = input.displayName?.trim() || draft.displayName.trim() || '融合人格';
  const fallbackDraft = buildMergedDraftFallback(input);

  return {
    agentId: `fusion-${slugify(displayName)}-${nonce}`.slice(0, 96),
    displayName,
    personId: mergedPersonId,
    avatarSeed: draft.avatarSeed?.trim() || fallbackDraft.avatarSeed,
    timeLabel: draft.timeLabel?.trim() || fallbackDraft.timeLabel,
    stageLabel: draft.stageLabel?.trim() || fallbackDraft.stageLabel,
    keyEvent: draft.keyEvent?.trim() || fallbackDraft.keyEvent,
    knownFacts: uniqueStrings(draft.knownFacts?.length ? draft.knownFacts : fallbackDraft.knownFacts, 6),
    sourceEvidence: uniqueEvidence(draft.sourceEvidence?.length ? draft.sourceEvidence : fallbackDraft.sourceEvidence, 6),
    traits: uniqueStrings(draft.traits?.length ? draft.traits : fallbackDraft.traits, 6),
    values: uniqueStrings(draft.values?.length ? draft.values : fallbackDraft.values, 6),
    goal: draft.goal?.trim() || fallbackDraft.goal,
    fear: draft.fear?.trim() || fallbackDraft.fear,
    voiceStyle: draft.voiceStyle?.trim() || fallbackDraft.voiceStyle,
    knowledgeBoundary: draft.knowledgeBoundary?.trim() || fallbackDraft.knowledgeBoundary,
    forbiddenFutureKnowledge: Boolean(
      draft.forbiddenFutureKnowledge ||
        input.primary.forbiddenFutureKnowledge ||
        input.secondary.forbiddenFutureKnowledge,
    ),
    stanceSeed: draft.stanceSeed?.trim() || fallbackDraft.stanceSeed,
  };
}

export async function buildAgents(
  repository: BackendRepository,
  input: BuildAgentsRequest,
): Promise<BuildAgentsResponse> {
  const existingAgents = await repository.getPersonasForProfile(input.personId);
  if (existingAgents.length === input.nodes.length && existingAgents.every((agent) => input.nodes.some((node) => `${node.nodeId}-agent` === agent.agentId))) {
    return { agents: existingAgents };
  }

  let execution;
  let blueprints: PersonaBlueprint[] = [];

  try {
    const generated = await getRuntime().generatePersonaBlueprints({
      personId: input.personId,
      displayName: input.displayName,
      biography: input.biography ?? input.nodes.map((node) => node.summary).join('\n'),
      nodes: input.nodes,
    });
    blueprints = generated.blueprints;
    execution = generated.execution;
  } catch (error) {
    console.warn('persona generation fallback:', error);
  }

  const blueprintMap = new Map(blueprints.map((item) => [item.nodeId, item]));
  const agents = input.nodes.map((node) => mergeBlueprint(input.personId, input.displayName, node, blueprintMap.get(node.nodeId)));

  await repository.savePersonas(input.personId, agents, execution);
  return { agents };
}

export async function mergeAgents(input: MergeAgentsRequest): Promise<MergeAgentsResponse> {
  let execution;
  let draft = buildMergedDraftFallback(input);

  try {
    const generated = await getRuntime().generateMergedPersona(input);
    draft = generated.draft;
    execution = generated.execution;
  } catch (error) {
    console.warn('persona merge fallback:', error);
  }

  return {
    agent: normalizeMergedPersona(input, draft),
    execution,
  };
}
