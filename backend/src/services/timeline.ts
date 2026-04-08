import type { BackendRepository } from '../repository.js';
import type { GeneratedProfileDraft, ParseTimelineRequest, ParseTimelineResponse, TimelineNode, TimelineStageType } from '../domain.js';
import { getRuntime } from './runtime.js';

const stageTemplates: Array<{ stageLabel: string; stageType: TimelineStageType }> = [
  { stageLabel: '起点探索期', stageType: 'early' },
  { stageLabel: '第一次转向期', stageType: 'turning-point' },
  { stageLabel: '持续拉扯期', stageType: 'stable' },
  { stageLabel: '关键受挫期', stageType: 'crisis' },
  { stageLabel: '重建成型期', stageType: 'rebuild' },
  { stageLabel: '成熟表达期', stageType: 'peak' },
];

function slugify(input: string): string {
  const normalized = input
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);

  return normalized || `profile-${Date.now()}`;
}

function inferTraits(text: string): string[] {
  const traits = new Set<string>();
  if (/[创办建立创业统一推进]/.test(text)) traits.add('进取');
  if (/[离开失败分手受挫失去]/.test(text)) traits.add('受伤');
  if (/[重建重新回归反思整理]/.test(text)) traits.add('反思');
  if (/[设计审美理想愿景]/.test(text)) traits.add('理想主义');
  if (/[权力掌控秩序纪律]/.test(text)) traits.add('控制欲强');
  if (/[工作压力疲惫成本]/.test(text)) traits.add('消耗感强');
  if (traits.size === 0) traits.add('正在成型');
  return Array.from(traits).slice(0, 3);
}

function inferValues(text: string): string[] {
  const values = new Set<string>();
  if (/[设计审美书法产品]/.test(text)) values.add('审美');
  if (/[统一秩序制度纪律]/.test(text)) values.add('秩序');
  if (/[稳定安全感边界]/.test(text)) values.add('稳定');
  if (/[创造改变世界影响力]/.test(text)) values.add('影响力');
  if (/[关系被爱尊重]/.test(text)) values.add('关系质量');
  if (values.size === 0) values.add('成长');
  return Array.from(values).slice(0, 3);
}

function inferTensions(text: string): string[] {
  const tensions = new Set<string>();
  if (/[创办推进统一]/.test(text)) tensions.add('速度与稳定冲突');
  if (/[离开失败分手]/.test(text)) tensions.add('害怕再次失去');
  if (/[边界重建]/.test(text)) tensions.add('想自保又怕错失机会');
  if (/[权力秩序]/.test(text)) tensions.add('高控制会压缩弹性');
  if (tensions.size === 0) tensions.add('目标在变，身份也在变');
  return Array.from(tensions).slice(0, 2);
}

function heuristicDraft(displayName: string, biography: string, profileId: string): GeneratedProfileDraft {
  const sentences = biography
    .split(/[。！？!?；;]/)
    .map((sentence) => sentence.trim())
    .filter((sentence) => sentence.length > 8)
    .slice(0, 6);

  const fallbackSentences =
    sentences.length >= 3
      ? sentences
      : [biography, `${displayName}开始经历第一次明显转折`, `${displayName}开始重新理解自己`];

  const nodes: TimelineNode[] = fallbackSentences.slice(0, 5).map((sentence, index) => {
    const template = stageTemplates[index] ?? stageTemplates[stageTemplates.length - 1];
    return {
      nodeId: `${profileId}-${index + 1}`,
      timeLabel: `阶段 ${index + 1}`,
      stageLabel: template.stageLabel,
      stageType: template.stageType,
      keyEvent: sentence.slice(0, 28),
      summary: sentence,
      traits: inferTraits(sentence),
      values: inferValues(sentence),
      tensions: inferTensions(sentence),
      sourceEvidence: [{ quote: sentence.slice(0, 80), sourceLabel: '用户输入' }],
    };
  });

  return {
    displayName,
    subtitle: '从原始叙述中提炼的人生节点',
    category: 'self',
    biography: biography.slice(0, 260),
    highlights: nodes.map((node) => node.keyEvent).slice(0, 4),
    suggestedTopics: [
      `如果你是 ${displayName}，当前最关键的选择是什么？`,
      `${displayName} 该如何理解自己最在意的代价？`,
      `${displayName} 在这个阶段最该避免什么？`,
    ],
    nodes,
  };
}

export async function parseTimeline(
  repository: BackendRepository,
  input: ParseTimelineRequest,
): Promise<ParseTimelineResponse> {
  if (input.profileId) {
    const existing = await repository.getProfileBundle(input.profileId);
    if (existing) {
      return {
        personId: existing.profile.id,
        displayName: existing.profile.displayName,
        nodes: existing.nodes,
      };
    }
  }

  const profileId = input.profileId ?? slugify(input.displayName);
  let draft: GeneratedProfileDraft;

  try {
    const generated = await getRuntime().generateTimelineFromText({
      displayNameHint: input.displayName,
      biographyOrDigest: input.biography,
      sourceLabel: '人物背景材料',
    });

    draft = {
      ...generated.draft,
      displayName: input.displayName || generated.draft.displayName,
      nodes: generated.draft.nodes.map((node, index) => ({
        ...node,
        nodeId: `${profileId}-${index + 1}`,
      })),
    };
  } catch (error) {
    console.warn('timeline generation fallback:', error);
    draft = heuristicDraft(input.displayName, input.biography, profileId);
  }

  await repository.upsertProfileBundle({
    id: profileId,
    displayName: draft.displayName,
    subtitle: draft.subtitle,
    category: draft.category,
    coverSeed: slugify(draft.displayName),
    biography: draft.biography,
    highlights: draft.highlights,
    suggestedTopics: draft.suggestedTopics,
    origin: 'manual',
    isDefault: false,
    rawInput: input.biography,
    nodes: draft.nodes,
  });

  return {
    personId: profileId,
    displayName: draft.displayName,
    nodes: draft.nodes,
  };
}
