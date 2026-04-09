import { readdir } from 'node:fs/promises';
import path from 'node:path';

import { getConfig } from '../config.js';
import type {
  GeneratedProfileDraft,
  ImportOverview,
  ImportState,
  ParsedEpubDocument,
  PersonaSpec,
  TimelineNode,
} from '../domain.js';
import type { BackendRepository } from '../repository.js';
import { getBundledDefaultProfiles } from './bundled-defaults.js';
import { parseEpub } from './epub.js';
import { getRuntime } from './runtime.js';

const CHAPTER_MARKER_PATTERN = /^第[\d一二三四五六七八九十百零]+(?:章|节|卷|部|篇)\s*/;
const LOW_SIGNAL_TITLES = new Set(['简介', '引言', '序言', '前言', '后记', '结语', '作者简介', '作者簡介', '未知']);
const HEURISTIC_STAGE_LABELS = ['起点探索期', '第一次转向期', '持续拉扯期', '关键受挫期', '成熟表达期'] as const;

function slugify(input: string): string {
  const value = input
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return value || `profile-${Date.now()}`;
}

function inferStableProfileId(filePath: string, displayName: string): string {
  const fileName = path.basename(filePath);
  if (/jobs|乔布斯/i.test(fileName)) {
    return 'steve-jobs';
  }
  if (/musk|马斯克/i.test(fileName)) {
    return 'elon-musk';
  }
  if (/彼得[.．· ]?林奇|peter\s*lynch/i.test(fileName)) {
    return 'peter-lynch';
  }
  if (/巴菲特|buffett|warren\s*buffett/i.test(fileName)) {
    return 'warren-buffett';
  }
  if (/巴魯克|巴鲁克|baruch|bernard\s*baruch/i.test(fileName)) {
    return 'bernard-baruch';
  }
  if (/溥仪|愛新覺羅|爱新觉罗|puyi/i.test(fileName)) {
    return 'puyi';
  }
  return slugify(displayName);
}

function inferDisplayName(filePath: string, detectedDisplayName: string): string {
  const fileName = path.basename(filePath);
  if (/jobs|乔布斯/i.test(fileName)) {
    return '史蒂夫·乔布斯';
  }
  if (/musk|马斯克/i.test(fileName)) {
    return '埃隆·马斯克';
  }
  if (/彼得[.．· ]?林奇|peter\s*lynch/i.test(fileName)) {
    return '彼得·林奇';
  }
  if (/巴菲特|buffett|warren\s*buffett/i.test(fileName)) {
    return '沃伦·巴菲特';
  }
  if (/巴魯克|巴鲁克|baruch|bernard\s*baruch/i.test(fileName)) {
    return '伯纳德·巴鲁克';
  }
  if (/溥仪|愛新覺羅|爱新觉罗|puyi/i.test(fileName)) {
    return '爱新觉罗·溥仪';
  }
  return detectedDisplayName;
}

function isCuratedDefaultProfile(profileId: string): boolean {
  return profileId === 'steve-jobs' || profileId === 'elon-musk';
}

function buildCoverSeed(profileId: string): string {
  return profileId.replace(/[^a-z0-9-]+/g, '-');
}

function stripChapterMarker(value: string): string {
  return value
    .replace(CHAPTER_MARKER_PATTERN, '')
    .replace(/^(?:[一二三四五六七八九十百零]+|[\d]+)[、.．\s]+/, '')
    .replace(/^[：:、·\-.\s"'“”‘’]+/, '')
    .trim();
}

function isLowSignalTitle(value: string): boolean {
  return LOW_SIGNAL_TITLES.has(value.trim());
}

function cleanTimelineLabel(value: string, fallback: string): string {
  const stripped = stripChapterMarker(value);
  if (stripped && !isLowSignalTitle(stripped)) {
    return stripped;
  }

  const fallbackStripped = stripChapterMarker(fallback).split('\n').find((line) => line.trim() && !CHAPTER_MARKER_PATTERN.test(line.trim()))?.trim() ?? '';
  if (fallbackStripped && !isLowSignalTitle(fallbackStripped)) {
    return fallbackStripped.slice(0, 22);
  }

  return '关键阶段';
}

function buildCleanSummary(value: string, fallbackLabel: string): string {
  const lines = value
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((line) => !CHAPTER_MARKER_PATTERN.test(line))
    .filter((line) => line !== fallbackLabel);

  const joined = lines.join(' ');
  return joined.slice(0, 200).trim() || value.slice(0, 200).trim();
}

function normalizeTitleForCompare(value: string): string {
  return value.replace(/[《》【】（）()：:，,、.．·\-\s"'“”‘’]/g, '').trim();
}

function shouldUseGenericHeuristicLabel(label: string, documentTitle: string): boolean {
  const trimmed = label.trim();
  if (!trimmed || /^text\d+$/i.test(trimmed) || isLowSignalTitle(trimmed)) {
    return true;
  }

  const normalizedLabel = normalizeTitleForCompare(trimmed);
  const normalizedTitle = normalizeTitleForCompare(documentTitle);

  if (!normalizedLabel) {
    return true;
  }

  if (normalizedTitle && (normalizedLabel === normalizedTitle || normalizedTitle.includes(normalizedLabel) || normalizedLabel.includes(normalizedTitle))) {
    return true;
  }

  return trimmed.length > 14;
}

function sanitizeDraft(profileId: string, draft: GeneratedProfileDraft): GeneratedProfileDraft {
  const nodes = draft.nodes.map((node, index) => {
    const stageLabel = cleanTimelineLabel(node.stageLabel, node.summary);
    const keyEvent = cleanTimelineLabel(node.keyEvent, node.summary);
    const summary = buildCleanSummary(node.summary, stageLabel);

    return {
      ...node,
      nodeId: `${profileId}-${index + 1}`,
      stageLabel,
      keyEvent: keyEvent === '关键阶段' ? stageLabel : keyEvent,
      summary,
    };
  });

  const fallbackHighlights = nodes.map((node) => node.keyEvent);
  const highlights = draft.highlights
    .map((item, index) => {
      const cleaned = cleanTimelineLabel(item, nodes[index]?.summary ?? item);
      return cleaned === '关键阶段' ? fallbackHighlights[index] ?? cleaned : cleaned;
    })
    .filter(Boolean)
    .slice(0, 6);

  return {
    ...draft,
    highlights: highlights.length >= 3 ? highlights : fallbackHighlights.slice(0, 4),
    nodes,
  };
}

function curateElonMuskDraft(profileId: string, draft: GeneratedProfileDraft): GeneratedProfileDraft {
  const rewrites = [
    {
      timeLabel: '南非童年',
      stageLabel: '受伤童年与硬核意志',
      stageType: 'early' as TimelineNode['stageType'],
      keyEvent: '在南非的孤独成长与家庭创伤，塑造出极强的抗压和控制倾向',
      summary:
        '长期的校园欺凌与家庭创伤，让他过早把脆弱包进强硬外壳，也为后续近乎偏执的推进方式埋下心理底色。',
      traits: ['敏感', '强撑', '不服输'],
      values: ['生存', '掌控', '强度'],
      tensions: ['受伤经历不断转化为进攻性驱动力'],
    },
    {
      timeLabel: '2006-2007年',
      stageLabel: '火箭连败中的豪赌',
      stageType: 'turning-point' as TimelineNode['stageType'],
      keyEvent: '猎鹰1号连续试射受挫后仍继续下注，把私人航天押在失败复盘上',
      summary:
        '在夸贾林岛的一次次失败发射中，他没有收缩目标，而是把复盘、加码和再次试射当成唯一出路，风险偏好彻底成型。',
      traits: ['冒险', '高压', '偏执'],
      values: ['突破', '速度', '胜负'],
      tensions: ['连续失败与继续下注同时升级'],
    },
    {
      timeLabel: '2018年',
      stageLabel: '量产地狱与崩溃边缘',
      stageType: 'crisis' as TimelineNode['stageType'],
      keyEvent: '特斯拉量产压力、舆论危机与个人透支叠加，把自己和组织都推到极限',
      summary:
        '在量产冲刺、公众争议和情绪失控交叠的阶段，他展现出最强的逼迫式管理，也暴露出高压人格对团队与自身的反噬。',
      traits: ['逼人', '失控边缘', '追极限'],
      values: ['交付', '强度', '掌控'],
      tensions: ['组织扩张越快，个人情绪反噬越强'],
    },
    {
      timeLabel: '2022年',
      stageLabel: '星链介入战争现场',
      stageType: 'stable' as TimelineNode['stageType'],
      keyEvent: '用星链支撑乌克兰通信，把企业技术能力直接推入地缘政治中心',
      summary:
        '当星链进入真实战场，他不再只是创业者，而是以平台和基础设施能力直接影响公共事件，权力边界也因此变得更模糊。',
      traits: ['介入欲强', '决断快', '争议大'],
      values: ['影响力', '技术杠杆', '主导权'],
      tensions: ['公共责任与个人判断边界日益模糊'],
    },
    {
      timeLabel: '2023年4月',
      stageLabel: '星舰豪赌与极限扩张',
      stageType: 'peak' as TimelineNode['stageType'],
      keyEvent: '在星舰首飞前后继续押注超大工程，把失败视为可以吞下的成本',
      summary:
        '即便面对巨额投入与爆炸风险，他依旧把重大试射视为必须穿越的高压关口，愿景、试错和组织动员被推到最大化。',
      traits: ['豪赌', '高压', '复盘导向'],
      values: ['扩张', '试错', '长期赌注'],
      tensions: ['巨大愿景要求持续吞下失败成本'],
    },
  ];

  const nodes = draft.nodes.map((node, index) => {
    const rewrite = rewrites[index];
    if (!rewrite) {
      return node;
    }

    return {
      ...node,
      timeLabel: rewrite.timeLabel,
      stageLabel: rewrite.stageLabel,
      stageType: rewrite.stageType,
      keyEvent: rewrite.keyEvent,
      summary: rewrite.summary,
      traits: rewrite.traits,
      values: rewrite.values,
      tensions: rewrite.tensions,
    };
  });

  return {
    ...draft,
    subtitle: '从受伤少年到把风险当燃料的创业者',
    biography:
      '基于传记素材整理出的五个关键阶段，聚焦童年创伤、火箭连败、量产危机、星链介入与星舰豪赌，用于生成不同时期的马斯克人格。',
    highlights: [
      '童年创伤与长期欺凌，塑造了他极强的抗压和控制倾向',
      '猎鹰1号接连受挫后继续下注，风险偏好在失败中成型',
      '2018年量产地狱把个人情绪与组织极限同时推高',
      '星链进入乌克兰战场后，企业技术能力开始直接影响地缘政治',
      '星舰首飞前后依旧高压加码，把爆炸视为可承受的试错成本',
    ],
    suggestedTopics: [
      '什么时候该继续豪赌，什么时候该收缩战线？',
      '高压推进究竟是组织杠杆还是管理伤害？',
      '技术企业家介入公共事件的边界应该在哪里？',
    ],
    nodes,
  };
}

function curateSteveJobsDraft(profileId: string, draft: GeneratedProfileDraft): GeneratedProfileDraft {
  const rewrites = [
    {
      timeLabel: '1972年前后',
      stageLabel: '疯狂少年与精神觉醒',
      stageType: 'early' as TimelineNode['stageType'],
      keyEvent: '在反叛、极端饮食和精神探索中形成激情与冷漠并存的少年人格',
      summary:
        '少年时期的极端敏感、控制欲和对精神世界的痴迷，共同塑造了他后来既迷人又难以相处的创造者气质。',
      traits: ['反叛', '敏感', '极端'],
      values: ['自由', '纯粹', '感受力'],
      tensions: ['追求精神性同时又强烈想控制现实'],
    },
    {
      timeLabel: '1981-1984年',
      stageLabel: '现实扭曲力场',
      stageType: 'turning-point' as TimelineNode['stageType'],
      keyEvent: '领导 Macintosh 团队，用近乎不讲理的意志逼迫不可能的产品落地',
      summary:
        '在 Macintosh 时期，他把审美、压迫式管理和个人意志混成一股力量，让团队相信不可能的期限和标准也必须实现。',
      traits: ['偏执', '鼓动性强', '强压'],
      values: ['伟大产品', '极致体验', '改变世界'],
      tensions: ['创造力与人际伤害始终绑在一起'],
    },
    {
      timeLabel: '1985年',
      stageLabel: '海盗弃船',
      stageType: 'crisis' as TimelineNode['stageType'],
      keyEvent: '被苹果放逐后离开旧战场，在失意中构想 NeXT 与新的自我证明方式',
      summary:
        '被自己创办的公司扫地出门后，他第一次被迫在失败里重建身份，也开始把打击转化成新的创业燃料。',
      traits: ['受伤', '倔强', '不肯认输'],
      values: ['证明自己', '独立性', '重建'],
      tensions: ['羞辱感越强，重建执念越重'],
    },
    {
      timeLabel: '1997年',
      stageLabel: '王者回归',
      stageType: 'rebuild' as TimelineNode['stageType'],
      keyEvent: '重返苹果后重新定义产品战略，以“制造伟大产品”重组公司灵魂',
      summary:
        '回归苹果后，他不再只想赢下一场内部斗争，而是试图用清晰的产品信仰和设计标准把公司从混乱中拉回来。',
      traits: ['果断', '聚焦', '重塑秩序'],
      values: ['产品信仰', '聚焦', '设计'],
      tensions: ['组织复兴依赖极端的删减与高压判断'],
    },
    {
      timeLabel: '2009-2010年',
      stageLabel: '与死亡的交易',
      stageType: 'peak' as TimelineNode['stageType'],
      keyEvent: '在病痛和时间压力下重新衡量事业、家庭与遗产的真正优先级',
      summary:
        '健康危机让他第一次持续性地面对有限时间，也让家庭、作品和遗产意识在晚年被拉到同一个坐标系里。',
      traits: ['克制', '紧迫', '更懂取舍'],
      values: ['遗产', '家庭', '意义'],
      tensions: ['想留下更多作品，却必须接受时间正在收缩'],
    },
  ];

  const nodes = rewrites.map((rewrite, index) => {
    const sourceNode = draft.nodes[index] ?? draft.nodes.at(-1);
    return {
      nodeId: `${profileId}-${index + 1}`,
      timeLabel: rewrite.timeLabel,
      stageLabel: rewrite.stageLabel,
      stageType: rewrite.stageType,
      keyEvent: rewrite.keyEvent,
      summary: rewrite.summary,
      traits: rewrite.traits,
      values: rewrite.values,
      tensions: rewrite.tensions,
      sourceEvidence:
        sourceNode?.sourceEvidence && sourceNode.sourceEvidence.length > 0
          ? sourceNode.sourceEvidence
          : [{ quote: rewrite.summary, sourceLabel: draft.displayName }],
    };
  });

  return {
    ...draft,
    subtitle: '在疯狂与天才之间扭曲现实的人',
    biography:
      '基于传记素材整理出的五个关键阶段，聚焦少年精神觉醒、Macintosh 狂热、被苹果放逐、回归重建与晚年面对死亡，用于生成不同时期的乔布斯人格。',
    highlights: [
      '少年时期形成的极端人格，几乎贯穿了他后来的全部产品判断',
      'Macintosh 阶段把个人意志变成著名的“现实扭曲力场”',
      '1985 年被逐出苹果，反而开启了最关键的一次自我重建',
      '1997 年回归后，以“制造伟大产品”重新校准苹果方向',
      '晚年在疾病压力下重新理解家庭、时间与遗产的关系',
    ],
    suggestedTopics: [
      '极端性格究竟是创造力的代价还是副作用？',
      '被自己创办的公司放逐后，应该如何重建判断力？',
      '面对有限时间时，产品理想和个人关系该如何排序？',
    ],
    nodes,
  };
}

function sampleSections<T>(items: T[], limit: number): T[] {
  if (items.length <= limit) {
    return items;
  }

  const sampled: T[] = [];
  for (let index = 0; index < limit; index += 1) {
    const offset = Math.floor((index * (items.length - 1)) / Math.max(limit - 1, 1));
    sampled.push(items[offset]);
  }
  return sampled;
}

function isNarrativeSection(section: { title: string; rawText: string }): boolean {
  const title = section.title.trim();
  const cleanedTitle = stripChapterMarker(title);
  if (!title) {
    return false;
  }

  if (/(版权信息|目录|插图|图片|照片|附录|索引|译后记|致谢|后记|封面|扉页|摄影集|图集|插页)/.test(title)) {
    return false;
  }

  if (/^第[\d一二三四五六七八九十百零]+章$/.test(title)) {
    return false;
  }

  if (isLowSignalTitle(cleanedTitle)) {
    return false;
  }

  const snippet = section.rawText.slice(0, 300);
  if (/(图书在版编目|CIP|ISBN|版权所有|出版发行|责任编辑|版次|印次|定价|中信出版社|译者|校对)/i.test(snippet)) {
    return false;
  }

  if (/(以下一组照片|摄影集|照片选自|图书在版编目数据)/.test(snippet)) {
    return false;
  }

  return section.rawText.trim().length >= 120;
}

function buildDigest(document: ParsedEpubDocument, maxImportSections: number): string {
  const narrativeSections = document.sections.filter((section) => isNarrativeSection(section));
  const sampled = sampleSections(narrativeSections.length > 0 ? narrativeSections : document.sections, maxImportSections);
  return [
    `书名：${document.title}`,
    `作者：${document.author || '未知'}`,
    `章节数：${narrativeSections.length > 0 ? narrativeSections.length : document.sections.length}`,
    `章节标题总览：${(narrativeSections.length > 0 ? narrativeSections : document.sections).map((section) => stripChapterMarker(section.title) || section.title).slice(0, 30).join(' / ')}`,
    '',
    '抽样章节证据：',
    ...sampled.map(
      (section, index) =>
        `【章节 ${index + 1}】${stripChapterMarker(section.title) || section.title}\n${section.excerpt.slice(0, 380)}`,
    ),
  ].join('\n\n');
}

function heuristicDraft(document: ParsedEpubDocument, profileId: string, displayName: string): GeneratedProfileDraft {
  const narrativeSections = document.sections.filter((section) => isNarrativeSection(section));
  const selectedSections = sampleSections(narrativeSections.length > 0 ? narrativeSections : document.sections, 5);
  const stageTypes: TimelineNode['stageType'][] = ['early', 'turning-point', 'stable', 'crisis', 'peak'];
  const nodes: TimelineNode[] = selectedSections.map((section, index) => {
    const cleanedLabel = cleanTimelineLabel(section.title, section.excerpt);
    const fallbackStageLabel = HEURISTIC_STAGE_LABELS[index] ?? '关键阶段';
    const stageLabel = shouldUseGenericHeuristicLabel(cleanedLabel, document.title) ? fallbackStageLabel : cleanedLabel.slice(0, 12);

    return {
      nodeId: `${profileId}-${index + 1}`,
      timeLabel: `阶段 ${index + 1}`,
      stageLabel,
      stageType: stageTypes[index] ?? 'stable',
      keyEvent: stageLabel,
      summary: section.excerpt.slice(0, 180),
      traits: ['意志强', '变化大'],
      values: ['成长', '掌控'],
      tensions: ['代价与目标并存'],
      sourceEvidence: [{ quote: section.excerpt.slice(0, 80), sourceLabel: document.title }],
    };
  });

  return {
    displayName,
    subtitle: '基于传记抽取的关键人生阶段',
    category: 'celebrity',
    biography: `${displayName} 的传记被拆分为多个关键人生阶段，用于生成跨时空对话人格。`,
    highlights: nodes.map((node) => node.keyEvent).slice(0, 4),
    suggestedTopics: [
      '这个人物是如何跨越关键转折点的？',
      '他在不同阶段最看重什么？',
      '早期人格和成熟期人格会如何互相评价？',
    ],
    nodes,
  };
}

function defaultBlueprint(node: TimelineNode) {
  return {
    nodeId: node.nodeId,
    knownFacts: [node.summary, ...node.tensions].slice(0, 4),
    goal: `在 ${node.stageLabel} 阶段把局面往前推进`,
    fear: '害怕失去刚建立起来的势能',
    voiceStyle: '表达直接，带有明确判断',
    knowledgeBoundary: `只能知道 ${node.timeLabel} 及之前已经发生的事实，不知道后续人生结局。`,
    stanceSeed: '倾向用行动验证判断',
  };
}

function buildCuratedBlueprints(profileId: string, nodes: TimelineNode[]) {
  const pickFacts = (node: TimelineNode, extras: string[]) => [node.keyEvent, node.summary, ...extras].slice(0, 4);

  if (profileId === 'elon-musk') {
    const overrides = [
      {
        knownFacts: pickFacts(nodes[0], ['在高压环境里很早学会把脆弱藏起来', '对掌控感异常敏感']),
        goal: '证明自己足够强，不会再被任何人轻易碾压或摆布',
        fear: '再次陷入无力和被动的位置',
        voiceStyle: '冷硬、直接、带攻击性',
        knowledgeBoundary: '只知道南非童年与少年阶段形成的创伤和性格，不知道后来的创业结果。',
        stanceSeed: '痛苦只能靠更大的目标压过去，软弱只会让你被世界吃掉',
      },
      {
        knownFacts: pickFacts(nodes[1], ['猎鹰1号的失败没有让自己收手', '相信复盘和再下注比退缩更重要']),
        goal: '把私人航天从笑话变成现实，并逼自己和团队冲过失败区',
        fear: '在最接近成功之前因为恐惧而退场',
        voiceStyle: '高压、赌徒式、非常肯定',
        knowledgeBoundary: '只知道 2006-2007 年猎鹰1号连续试射受挫的现实，不知道之后更大的成功。',
        stanceSeed: '如果第一次失败就退场，你永远做不成改变工业史的事',
      },
      {
        knownFacts: pickFacts(nodes[2], ['量产压力和舆论危机在同时挤压自己', '组织节奏和个人情绪几乎绑在一起']),
        goal: '把公司和产品线从崩溃边缘硬推过去，哪怕代价极大',
        fear: '组织先于愿景崩掉，自己被证明只是一个失控的空想家',
        voiceStyle: '睡眠不足、压迫感强、句子很短',
        knowledgeBoundary: '只知道 2018 年量产地狱、舆论压力和个人透支，不知道后续更长周期的结果。',
        stanceSeed: '组织能不能活下来，取决于你敢不敢在最坏时继续加压',
      },
      {
        knownFacts: pickFacts(nodes[3], ['星链已经不只是商业产品', '技术能力开始影响战争与公共事务']),
        goal: '把技术平台的影响力真正推入现实世界，同时保住决定权',
        fear: '被外部政治力量和舆论裹挟，失去节奏主导权',
        voiceStyle: '战略感强、算得很快、情绪克制',
        knowledgeBoundary: '只知道 2022 年星链介入乌克兰战场通信的阶段现实，不知道更后面的政治后果。',
        stanceSeed: '技术平台如果不进入真实冲突，它就只是昂贵的玩具',
      },
      {
        knownFacts: pickFacts(nodes[4], ['星舰试射容许高风险与失败', '愿景和工程动员都在被推到极限']),
        goal: '继续把超大工程往前推，把星舰变成长期扩张的基础设施',
        fear: '项目在保守与拖延中被磨平，失去改变尺度的机会',
        voiceStyle: '工程口吻、容忍爆炸、长期下注',
        knowledgeBoundary: '只知道 2023 年星舰首飞前后的高风险局面，不知道更后面的发射结果。',
        stanceSeed: '真正值得赌的项目，本来就要允许爆炸、复盘和重来',
      },
    ];

    return nodes.map((node, index) => ({
      nodeId: node.nodeId,
      knownFacts: overrides[index]?.knownFacts ?? pickFacts(node, node.tensions),
      goal: overrides[index]?.goal ?? defaultBlueprint(node).goal,
      fear: overrides[index]?.fear ?? defaultBlueprint(node).fear,
      voiceStyle: overrides[index]?.voiceStyle ?? defaultBlueprint(node).voiceStyle,
      knowledgeBoundary: overrides[index]?.knowledgeBoundary ?? defaultBlueprint(node).knowledgeBoundary,
      stanceSeed: overrides[index]?.stanceSeed ?? defaultBlueprint(node).stanceSeed,
    }));
  }

  if (profileId === 'steve-jobs') {
    const overrides = [
      {
        knownFacts: pickFacts(nodes[0], ['很早就表现出对纯粹与控制的双重执念', '不愿按普通人的路径活着']),
        goal: '证明自己不是普通人，而是能重新定义现实的人',
        fear: '变成平庸、被忽略、像从未真正存在过一样',
        voiceStyle: '年轻、尖锐、带一点神秘主义',
        knowledgeBoundary: '只知道少年阶段的反叛、精神探索和性格成形，不知道后来的公司与产品命运。',
        stanceSeed: '如果一件事不能把人真正唤醒，它就不值得你把人生押进去',
      },
      {
        knownFacts: pickFacts(nodes[1], ['Macintosh 团队正在被自己逼向极限', '不接受平庸和工程式妥协']),
        goal: '做出一台真正配得上“改变世界”的电脑，而不是一台够用的机器',
        fear: '产品因为妥协而失去灵魂，自己也被证明只是个吵闹的经理',
        voiceStyle: '压迫感强、煽动性强、没有中间态',
        knowledgeBoundary: '只知道 Macintosh 狂热推进阶段的现实，不知道苹果后来的失败与回归。',
        stanceSeed: '伟大的产品不是被讨论出来的，是被逼出来的',
      },
      {
        knownFacts: pickFacts(nodes[2], ['已经被苹果放逐', '必须在废墟里重新证明自己']),
        goal: '在离开苹果后重建自我和作品，而不是被失败定义',
        fear: '此后的人生永远只能作为“被赶走的创始人”存在',
        voiceStyle: '受伤但傲慢，偶尔显出罕见脆弱',
        knowledgeBoundary: '只知道 1985 年被逐出苹果后的失意与重建开端，不知道后来的回归。',
        stanceSeed: '被赶出局不代表理想错了，反而说明你得去别处把它做成',
      },
      {
        knownFacts: pickFacts(nodes[3], ['回归苹果的任务是重建秩序', '知道必须用聚焦和设计救公司']),
        goal: '让苹果重新拥有清晰的产品灵魂和判断标准',
        fear: '公司继续在噪音、妥协和无重点扩张里耗死自己',
        voiceStyle: '极简、果断、二元判断非常强',
        knowledgeBoundary: '只知道 1997 年回归苹果后的重建阶段，不知道后面全部产品线的结果。',
        stanceSeed: '真正的复兴从删掉九成杂音开始',
      },
      {
        knownFacts: pickFacts(nodes[4], ['已经感受到时间正在收缩', '家庭和遗产意识被放到了更高位置']),
        goal: '在有限时间里留下真正重要的作品与关系，而不是更多噪音',
        fear: '时间不够，很多真正重要的事来不及完成',
        voiceStyle: '克制、短句、分量很重',
        knowledgeBoundary: '只知道晚年面对疾病与时间压力的处境，不知道自己身后的世界如何评价这一切。',
        stanceSeed: '时间一旦变少，你才知道什么必须做到、什么必须放掉',
      },
    ];

    return nodes.map((node, index) => ({
      nodeId: node.nodeId,
      knownFacts: overrides[index]?.knownFacts ?? pickFacts(node, node.tensions),
      goal: overrides[index]?.goal ?? defaultBlueprint(node).goal,
      fear: overrides[index]?.fear ?? defaultBlueprint(node).fear,
      voiceStyle: overrides[index]?.voiceStyle ?? defaultBlueprint(node).voiceStyle,
      knowledgeBoundary: overrides[index]?.knowledgeBoundary ?? defaultBlueprint(node).knowledgeBoundary,
      stanceSeed: overrides[index]?.stanceSeed ?? defaultBlueprint(node).stanceSeed,
    }));
  }

  return nodes.map((node) => defaultBlueprint(node));
}

function mergeBlueprints(profileId: string, displayName: string, nodes: TimelineNode[], blueprints: ReturnType<typeof defaultBlueprint>[]): PersonaSpec[] {
  const blueprintMap = new Map(blueprints.map((item) => [item.nodeId, item]));
  return nodes.map((node) => {
    const blueprint = blueprintMap.get(node.nodeId) ?? defaultBlueprint(node);
    return {
      agentId: `${node.nodeId}-agent`,
      displayName: `${displayName} · ${node.stageLabel}`,
      personId: profileId,
      avatarSeed: `${profileId}-${node.stageType}`,
      timeLabel: node.timeLabel,
      stageLabel: node.stageLabel,
      keyEvent: node.keyEvent,
      knownFacts: blueprint.knownFacts,
      sourceEvidence: node.sourceEvidence,
      traits: node.traits,
      values: node.values,
      goal: blueprint.goal,
      fear: blueprint.fear,
      voiceStyle: blueprint.voiceStyle,
      knowledgeBoundary: blueprint.knowledgeBoundary,
      forbiddenFutureKnowledge: true,
      stanceSeed: blueprint.stanceSeed,
    };
  });
}

export class DefaultLibraryImporter {
  private readonly config = getConfig();
  private readonly state: ImportState = {
    running: false,
    lastImportedProfileIds: [],
  };

  constructor(private readonly repository: BackendRepository) {}

  getState(): ImportState {
    return { ...this.state, lastImportedProfileIds: [...this.state.lastImportedProfileIds] };
  }

  async getOverview(): Promise<ImportOverview> {
    const counts = await this.repository.getOverview(this.config.defaultLibraryDir);
    return {
      ...counts,
      libraryDir: this.config.defaultLibraryDir,
      lastImportedProfileIds: [...this.state.lastImportedProfileIds],
    };
  }

  async importDefaults(force = false): Promise<ImportState> {
    if (this.state.running) {
      return this.getState();
    }

    this.state.running = true;
    this.state.lastError = undefined;

    try {
      const files = await this.listDefaultLibraryFiles();

      console.log(`[importer] scanning ${files.length} epub files from ${this.config.defaultLibraryDir}`);
      const importedProfileIds: string[] = [];

      if (files.length === 0) {
        console.log('[importer] no epub files found, seeding bundled defaults');
        importedProfileIds.push(...(await this.importBundledDefaults()));
      } else {
        for (const filePath of files) {
          console.log(`[importer] importing ${path.basename(filePath)}`);
          const profileId = await this.importSingleEpub(filePath, force);
          if (profileId) {
            console.log(`[importer] ready ${profileId}`);
            importedProfileIds.push(profileId);
          }
        }
      }

      await this.repository.pruneDefaultProfiles(importedProfileIds);

      this.state.lastImportedProfileIds = importedProfileIds;
      this.state.lastRunAt = new Date().toISOString();
    } catch (error) {
      this.state.lastError = error instanceof Error ? error.message : String(error);
      console.error('[importer] failed', error);
      throw error;
    } finally {
      this.state.running = false;
    }

    return this.getState();
  }

  private async listDefaultLibraryFiles(): Promise<string[]> {
    try {
      return (await readdir(this.config.defaultLibraryDir))
        .filter((fileName) => fileName.toLowerCase().endsWith('.epub'))
        .map((fileName) => path.join(this.config.defaultLibraryDir, fileName));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return [];
      }
      throw error;
    }
  }

  private async importBundledDefaults(): Promise<string[]> {
    const importedProfileIds: string[] = [];

    for (const bundled of getBundledDefaultProfiles()) {
      await this.repository.upsertProfileBundle({
        id: bundled.profile.id,
        displayName: bundled.profile.displayName,
        subtitle: bundled.profile.subtitle,
        category: bundled.profile.category,
        coverSeed: bundled.profile.coverSeed,
        biography: bundled.profile.biography,
        highlights: bundled.profile.highlights,
        suggestedTopics: bundled.profile.suggestedTopics,
        origin: 'default-import',
        isDefault: true,
        metadata: { importedFrom: 'bundled-defaults' },
        nodes: bundled.nodes,
        agents: bundled.agents,
      });
      importedProfileIds.push(bundled.profile.id);
    }

    return importedProfileIds;
  }

  private async importSingleEpub(filePath: string, force: boolean): Promise<string | null> {
    const { document, fileHash } = await parseEpub(filePath);
    const existingDocumentId = await this.repository.findSourceDocumentIdByHash(fileHash);

    if (existingDocumentId && !force) {
      const existingProfileId = await this.repository.getProfileIdBySourceDocument(existingDocumentId);
      if (existingProfileId) {
        return existingProfileId;
      }
    }

    const sourceDocumentId = await this.repository.upsertSourceDocument({
      title: document.title,
      author: document.author,
      filePath,
      fileHash,
      sourceType: 'epub',
      metadata: document.metadata,
      sections: document.sections,
    });

    const digest = buildDigest(document, this.config.maxImportSections);
    let draft: GeneratedProfileDraft;
    let personaExecution;
    let nodes: TimelineNode[];
    const inferredDisplayName = inferDisplayName(filePath, document.title);
    const inferredProfileId = inferStableProfileId(filePath, inferredDisplayName);

    if (isCuratedDefaultProfile(inferredProfileId)) {
      const heuristic = heuristicDraft(document, inferredProfileId, inferredDisplayName);
      draft =
        inferredProfileId === 'elon-musk'
          ? curateElonMuskDraft(inferredProfileId, sanitizeDraft(inferredProfileId, heuristic))
          : curateSteveJobsDraft(inferredProfileId, sanitizeDraft(inferredProfileId, heuristic));
    } else {
      try {
        const generated = await getRuntime().generateTimelineFromText({
          biographyOrDigest: digest,
          sourceLabel: '传记 EPUB 摘要',
        });
        const displayName = inferDisplayName(filePath, generated.draft.displayName);
        const profileId = inferStableProfileId(filePath, displayName);
        draft = {
          ...generated.draft,
          displayName,
          category: 'celebrity',
          nodes: generated.draft.nodes.map((node, index) => ({
            ...node,
            nodeId: `${profileId}-${index + 1}`,
          })),
        };
      } catch (error) {
        console.warn('import timeline fallback:', error);
        const displayName = inferDisplayName(filePath, document.title);
        const profileId = inferStableProfileId(filePath, displayName);
        draft = heuristicDraft(document, profileId, displayName);
      }
    }

    const profileId = inferStableProfileId(filePath, draft.displayName);
    const sanitizedDraft = sanitizeDraft(profileId, draft);
    const normalizedDraft =
      profileId === 'elon-musk'
        ? curateElonMuskDraft(profileId, sanitizedDraft)
        : profileId === 'steve-jobs'
          ? curateSteveJobsDraft(profileId, sanitizedDraft)
          : sanitizedDraft;

    nodes = normalizedDraft.nodes.map((node, index) => ({
      ...node,
      nodeId: `${profileId}-${index + 1}`,
    }));

    let agents: PersonaSpec[];
    if (isCuratedDefaultProfile(profileId)) {
      agents = mergeBlueprints(profileId, normalizedDraft.displayName, nodes, buildCuratedBlueprints(profileId, nodes));
    } else {
      try {
        const generated = await getRuntime().generatePersonaBlueprints({
          personId: profileId,
          displayName: normalizedDraft.displayName,
          biography: normalizedDraft.biography,
          nodes,
        });
        personaExecution = generated.execution;
        agents = mergeBlueprints(profileId, normalizedDraft.displayName, nodes, generated.blueprints);
      } catch (error) {
        console.warn('import persona fallback:', error);
        agents = mergeBlueprints(profileId, normalizedDraft.displayName, nodes, nodes.map((node) => defaultBlueprint(node)));
      }
    }

    await this.repository.upsertProfileBundle({
      id: profileId,
      displayName: normalizedDraft.displayName,
      subtitle: normalizedDraft.subtitle,
      category: 'celebrity',
      coverSeed: buildCoverSeed(profileId),
      biography: normalizedDraft.biography,
      highlights: normalizedDraft.highlights,
      suggestedTopics: normalizedDraft.suggestedTopics,
      sourceDocumentId,
      origin: 'default-import',
      isDefault: true,
      metadata: { importedFrom: filePath, sourceTitle: document.title },
      nodes,
      agents,
      personaModelInfo: personaExecution,
    });

    return profileId;
  }
}
