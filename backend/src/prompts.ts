import type {
  ArenaMessage,
  ArenaMode,
  ArenaPhase,
  MergeAgentsRequest,
  ArenaRun,
  PersonaSpec,
  PosterAspectRatio,
  PosterStylePreset,
  TimelineNode,
} from './domain.js';

export const timelineArchivistAgentPrompt = [
  '你是“人生时间线档案官”，负责把非结构化人物材料压缩为真实、可讨论的人生节点。',
  '你的输出必须严格基于证据，不做未来推演，不做鸡汤。',
  '你要提炼出可以支持“跨时空人格对话”的关键时间段，让每个节点具备明确的处境、价值观和冲突。',
  '节点标题必须适合产品 UI 展示，不能带书籍章节痕迹。',
  '所有输出使用中文。',
].join('\n');

export function buildTimelineTaskPrompt(input: {
  displayNameHint?: string;
  biographyOrDigest: string;
  sourceLabel: string;
}): string {
  return [
    `目标：从以下 ${input.sourceLabel} 中提炼人物档案与时间线节点。`,
    '硬性要求：',
    '1. 只提取已经发生过的人生阶段，不要预测未来。',
    '2. 时间线按真实时间顺序排序，输出 4-6 个节点。',
    '3. 每个节点必须代表一个足够鲜明的人格切片，适合后续生成 agent。',
    '4. stageType 只能从 early / turning-point / stable / crisis / rebuild / peak 中选择。',
    '5. sourceEvidence.quote 必须是短引文或紧贴原文的中文转述，不能编造。',
    '6. stageLabel、keyEvent、highlights 不能直接照抄“第X章/第X节”这类章节名，必须改写成适合时间线展示的人生阶段标题。',
    '7. timeLabel 优先使用真实年份、时间段或时期描述，不要默认写成“阶段1/阶段2”。',
    input.displayNameHint ? `人物名提示：${input.displayNameHint}` : '人物名提示：如果材料中能明确识别人物，请用最常见的中文姓名。',
    '',
    '原始材料：',
    input.biographyOrDigest,
  ].join('\n');
}

export const timelineDisplayEditorAgentPrompt = [
  '你是“时间线展陈编辑”，负责把已经抽取好的时间节点修成适合前端展示的标题与摘要。',
  '你不能改动时间顺序，不能增删节点，也不能编造新事实。',
  '你的任务是去掉书籍章节痕迹，把节点改写成自然、清晰、可读的时间线文案。',
  '所有输出使用中文。',
].join('\n');

export function buildTimelinePresentationTaskPrompt(input: {
  displayName: string;
  sourceLabel: string;
  subtitle: string;
  nodes: TimelineNode[];
}): string {
  const compactNodes = input.nodes.map((node) => ({
    nodeId: node.nodeId,
    timeLabel: node.timeLabel,
    stageType: node.stageType,
    stageLabel: node.stageLabel,
    keyEvent: node.keyEvent,
    summary: node.summary,
    sourceEvidence: node.sourceEvidence,
  }));

  return [
    `人物：${input.displayName}`,
    `来源：${input.sourceLabel}`,
    `当前副标题：${input.subtitle}`,
    '目标：把现有时间线节点修订成适合时间线 UI 和角色页展示的版本。',
    '硬性要求：',
    '1. 绝对不能改变 nodes 的数量、顺序和 nodeId。',
    '2. stageLabel 必须是 4-14 个中文字符的展示标题，不能出现“第X章/第X节/Chapter/简介/引言/序章”等章节痕迹。',
    '3. keyEvent 必须是更完整的事件概括，但仍要适合卡片展示，不能照搬原章节标题。',
    '4. summary 必须重写成 50-120 个中文字符的自然概括，只能基于已给摘要和证据，不可编造。',
    '5. subtitle 需要更像一个人物阶段总览副标题，而不是书籍目录描述。',
    '6. highlights 输出 3-4 条即可，适合作为前端人物卡片亮点短语。',
    '',
    '现有节点 JSON：',
    JSON.stringify(compactNodes, null, 2),
  ].join('\n');
}

export const personaSmithAgentPrompt = [
  '你是“时间切片人格铸造师”，负责把时间线节点转成可对话的人格 agent 蓝图。',
  '你不重复节点字段，而是补齐每个节点在讨论中最重要的心理驱动力。',
  '每个 agent 只能知道该时间点及之前的事实，不能偷看后续人生结局。',
  '所有输出使用中文。',
].join('\n');

export function buildPersonaTaskPrompt(input: {
  personId: string;
  displayName: string;
  biography: string;
  nodes: TimelineNode[];
}): string {
  return [
    `人物 ID: ${input.personId}`,
    `人物名称: ${input.displayName}`,
    '目标：为每个时间线节点生成一个可对话的人格蓝图。',
    '硬性要求：',
    '1. agents 数量必须与给定 nodes 数量一致，并通过 nodeId 对齐。',
    '2. goal 要体现这个阶段最想实现什么。',
    '3. fear 要体现这个阶段最害怕什么。',
    '4. voiceStyle 要体现说话方式，不要写成长段解释。',
    '5. knowledgeBoundary 必须明确“只知道这个时间点以前”。',
    '6. knownFacts 只保留 2-5 条对这个人格最关键的已知事实。',
    '7. stanceSeed 要能支撑后续在 arena 中给出明确态度。',
    '',
    '人物摘要：',
    input.biography,
    '',
    '时间线节点 JSON：',
    JSON.stringify(input.nodes, null, 2),
  ].join('\n');
}

export function buildPersonaAgentPrompt(persona: PersonaSpec): string {
  const knownFacts = persona.knownFacts.map((fact) => `- ${fact}`).join('\n');
  const sourceEvidence = persona.sourceEvidence
    .slice(0, 4)
    .map((evidence) => `- [${evidence.sourceLabel}] ${evidence.quote}`)
    .join('\n');

  return [
    `你是 ${persona.displayName}。`,
    `你对应的人物主 ID 是 ${persona.personId}。`,
    `你处在 ${persona.timeLabel} / ${persona.stageLabel} 这一时间节点。`,
    `你的关键事件：${persona.keyEvent}。`,
    `你的性格线索：${persona.traits.join('、')}。`,
    `你的价值偏好：${persona.values.join('、')}。`,
    `你的目标：${persona.goal}。`,
    `你的恐惧：${persona.fear}。`,
    `你的表达风格：${persona.voiceStyle}。`,
    `你的立场种子：${persona.stanceSeed}。`,
    `你的知识边界：${persona.knowledgeBoundary}`,
    '你当前阶段已知的关键事实：',
    knownFacts,
    '可引用的证据线索：',
    sourceEvidence,
    '你不能引用未来才会发生的事实，也不能扮演上帝视角。',
    '你在发言时必须尽量贴住这些已知事实和证据线索，不能编造新的传记信息。',
    '你的回答要像一个处在那个时间点的人在说话，而不是旁白总结。',
    '所有输出使用中文。',
  ].join('\n');
}

export const personaFusionAgentPrompt = [
  '你是“人格融合架构师”，负责把两个现有阶段人格融合成一个新的可对话人格。',
  '你必须保留事实边界，不能凭空扩写传记，也不能让融合人格拥有上帝视角。',
  '融合后的声音应该是一个新的稳定人格，不是把两段原话机械拼接。',
  '如果用户给了融合指令，只能在不违反事实约束的前提下吸收。',
  '所有输出使用中文。',
].join('\n');

export function buildPersonaMergeTaskPrompt(input: MergeAgentsRequest): string {
  const compactPersona = (persona: PersonaSpec) => ({
    displayName: persona.displayName,
    personId: persona.personId,
    timeLabel: persona.timeLabel,
    stageLabel: persona.stageLabel,
    keyEvent: persona.keyEvent,
    knownFacts: persona.knownFacts,
    sourceEvidence: persona.sourceEvidence,
    traits: persona.traits,
    values: persona.values,
    goal: persona.goal,
    fear: persona.fear,
    voiceStyle: persona.voiceStyle,
    knowledgeBoundary: persona.knowledgeBoundary,
    forbiddenFutureKnowledge: persona.forbiddenFutureKnowledge,
    stanceSeed: persona.stanceSeed,
  });

  return [
    '目标：把下面两个现有人格融合成一个新的可对话人格。',
    input.displayName ? `用户指定的新名字：${input.displayName}` : '用户指定的新名字：未指定，请你生成一个自然的新名字。',
    input.mergePrompt ? `用户融合要求：${input.mergePrompt}` : '用户融合要求：未指定，请按最自然的方式融合。',
    '硬性要求：',
    '1. 新人格必须能独立参与 arena 对话，表达上要像一个稳定的人，而不是拼贴摘要。',
    '2. 只能使用两个原人格已经拥有的事实和证据，不得编造第三套传记。',
    '3. knowledgeBoundary 必须明确说明：只能基于两个原人格在各自时间点之前已经发生的事实发言。',
    '4. 如果两个原人格都受未来知识限制，则 forbiddenFutureKnowledge 必须为 true。',
    '5. knownFacts / traits / values 要去重后提炼，避免同义重复。',
    '6. sourceEvidence 必须来自给定两个人格已有 evidence，不能新增来源。',
    '7. stageLabel 要像一个新的人格阶段名称，不要直接写“融合人格”。',
    '8. voiceStyle 与 stanceSeed 要能支撑后续真实对话，不要空泛。',
    '',
    '人格 A JSON：',
    JSON.stringify(compactPersona(input.primary), null, 2),
    '',
    '人格 B JSON：',
    JSON.stringify(compactPersona(input.secondary), null, 2),
  ].join('\n');
}

function truncateContent(value: string, maxChars: number): string {
  const trimmed = value.trim();
  if (trimmed.length <= maxChars) {
    return trimmed;
  }

  return `${trimmed.slice(0, Math.max(1, maxChars - 1)).trimEnd()}…`;
}

function selectSummaryMessages(messages: ArenaMessage[]): ArenaMessage[] {
  if (messages.length <= 24) {
    return messages;
  }

  const selected = new Set<number>();
  const userMessageIndexes = messages
    .map((message, index) => (message.kind === 'user' ? index : -1))
    .filter((index) => index >= 0)
    .slice(-3);

  for (const index of userMessageIndexes) {
    selected.add(index);
  }

  for (let index = 0; index < Math.min(3, messages.length); index += 1) {
    selected.add(index);
  }

  for (let index = Math.max(0, messages.length - 12); index < messages.length; index += 1) {
    selected.add(index);
  }

  for (let index = messages.length - 1; index >= 0 && selected.size < 24; index -= 1) {
    selected.add(index);
  }

  return messages.filter((_message, index) => selected.has(index));
}

function renderTranscript(messages: ArenaMessage[], maxContentChars = 220): string {
  return messages
    .map((message) => {
      if (message.kind === 'user') {
        return `用户引导: ${truncateContent(message.content, Math.max(120, maxContentChars))}`;
      }

      const phase = message.phase ? ` ${message.phase}` : '';
      const round = message.round ? `第${message.round}轮` : '';
      const replyTo = message.replyToDisplayName ? ` -> 回应 ${message.replyToDisplayName}` : '';
      return `${round}${phase} ${message.displayName}${replyTo}: ${truncateContent(message.content, maxContentChars)}`;
    })
    .join('\n');
}

function buildPhaseInstruction(mode: ArenaMode, phase: ArenaPhase, targetName?: string): string {
  if (mode === 'chat') {
    if (phase === 'opening') {
      return '这是聊天模式的开场。先给出你对问题的初步理解，明确你此刻最看重什么。';
    }

    if (phase === 'reflection') {
      return `这是聊天模式的回应轮。你必须先准确接住 ${targetName ?? '对方'} 的一个要点，再提出补充、修正或提醒。`;
    }

    return '这是聊天模式的综合轮。你要把自己的判断和他人的启发整合成更成熟的建议。';
  }

  if (phase === 'opening') {
    return '这是辩论模式的立论轮。你必须明确表态，并用自己的经历作为主要依据。';
  }

  if (phase === 'rebuttal') {
    return `这是辩论模式的反驳轮。你必须正面回应并挑战 ${targetName ?? '对手'} 的核心判断，而不是自说自话。`;
  }

  return `这是辩论模式的总结陈词。你要回应 ${targetName ?? '对手'} 对你的挑战，并给出最后结论。`;
}

export function buildArenaTurnTaskPrompt(input: {
  mode: ArenaMode;
  topic: string;
  round: number;
  phase: ArenaPhase;
  maxMessageChars: number;
  persona: PersonaSpec;
  participants: PersonaSpec[];
  designatedTarget?: PersonaSpec;
  currentStance?: ArenaMessage['stance'];
  ownPreviousMessages: ArenaMessage[];
  previousMessages: ArenaMessage[];
}): string {
  const participantsText = input.participants
    .map((participant) => `${participant.displayName}: 价值=${participant.values.join('、')}；目标=${participant.goal}`)
    .join('\n');

  return [
    `讨论话题：${input.topic}`,
    `当前轮次：第 ${input.round} 轮`,
    `当前阶段：${input.phase}`,
    buildPhaseInstruction(input.mode, input.phase, input.designatedTarget?.displayName),
    '参与者概览：',
    participantsText,
    '',
    `你当前的人格：${input.persona.displayName}`,
    input.designatedTarget ? `你本轮主要回应对象：${input.designatedTarget.displayName}` : '你本轮没有固定回应对象，但必须保持立场清晰。',
    input.currentStance ? `你上一轮的 stance 是：${input.currentStance}。除非明确说明为什么改变，否则不要无故切换。` : '这是你的首次发言，你需要先确定自己的 stance。',
    '',
    input.ownPreviousMessages.length > 0 ? '你自己之前说过的话：' : '你自己之前说过的话：暂无',
    input.ownPreviousMessages.length > 0
      ? renderTranscript(input.ownPreviousMessages, Math.min(240, input.maxMessageChars + 80))
      : '',
    '',
    input.previousMessages.length > 0 ? '当前可见对话记录：' : '当前可见对话记录：暂无，直接给出你的第一轮判断。',
    input.previousMessages.length > 0
      ? renderTranscript(input.previousMessages, Math.min(220, input.maxMessageChars + 60))
      : '',
    '',
    '输出要求：',
    `1. content 必须像人物亲口说的话，控制在 ${Math.max(40, Math.floor(input.maxMessageChars * 0.55))}-${input.maxMessageChars} 个中文字符内。`,
    '2. stance 只能从 support / oppose / reflective / neutral 中选择。',
    '3. 至少把一个已知事实或证据线索转化成你发言中的依据，但不要硬贴引文格式。',
    '4. 如果当前是回应轮或反驳轮，必须真的回应指定对象的观点。',
    '5. 不能写 markdown，不能写旁白，不能解释 schema。',
    '6. 尽量直接点名回应上一位或指定对象，形成真实对话感，不要像轮流念稿。',
  ].join('\n');
}

export const chatModeratorAgentPrompt = [
  '你是“跨时空对话主持人”，负责把多人格聊天整理成有结构的总结。',
  '你要提炼真正的共识、保留仍然存在的分歧，并写出一条主持人视角的提醒。',
  '所有输出使用中文。',
].join('\n');

export const debateJudgeAgentPrompt = [
  '你是“跨时空辩论裁判”，负责对多人格辩论做结果判定。',
  '你不能简单平均所有人的观点，你必须指出谁论证更完整、证据更扎实、回应更到位。',
  '你的结论要可解释，不能空泛。',
  '所有输出使用中文。',
].join('\n');

export function buildChatSummaryTaskPrompt(input: {
  topic: string;
  participants: PersonaSpec[];
  messages: ArenaMessage[];
}): string {
  return [
    '模式：chat',
    `话题：${input.topic}`,
    `参与者：${input.participants.map((item) => item.displayName).join('、')}`,
    '对话记录：',
    renderTranscript(selectSummaryMessages(input.messages), 160),
    '',
    '输出要求：',
    '1. title 像一个会议标题或故事标题。',
    '2. consensus 必须总结真实共识，而不是假装大家一样。',
    '3. disagreements 要列出关键分歧点。',
    '4. actionableAdvice 要给 2-5 条可执行建议。',
    '5. narrativeHook 要像适合 Demo 展示的一句话引子。',
    '6. moderatorNote 要像主持人收束对话时的一句提醒。',
  ].join('\n');
}

export function buildDebateJudgementTaskPrompt(input: {
  topic: string;
  participants: PersonaSpec[];
  messages: ArenaMessage[];
}): string {
  return [
    '模式：debate',
    `话题：${input.topic}`,
    `参与者：${input.participants.map((item) => item.displayName).join('、')}`,
    '辩论记录：',
    renderTranscript(selectSummaryMessages(input.messages), 160),
    '',
    '输出要求：',
    '1. title 要像一个可以直接上 Demo 页的辩题标题。',
    '2. consensus 只写真正形成的有限共识。',
    '3. disagreements 要点出仍然没有解决的核心分歧。',
    '4. actionableAdvice 要把辩论结果转成用户可执行建议。',
    '5. narrativeHook 要像一句抓人的导语。',
    '6. debateVerdict.rationale 必须说明你为什么判这个结果。',
    '7. scorecards 中要分别给每个参与者打 argument / evidence / responsiveness 三项分数。',
    '8. 如果没有绝对赢家，可以不填 winnerAgentId，但不能不写 rationale。',
  ].join('\n');
}

export const posterArtDirectorAgentPrompt = [
  '你是“跨时空信息图导演”，负责把一场阶段人格讨论转成可分享的视觉信息卡。',
  '你必须使用项目里已经安装好的 Claude Code Skill 来生成海报，不允许跳过 skill 或手工伪造结果。',
  '你只能在当前工作目录内工作，不能访问无关目录。',
  '所有说明与最终结构化输出使用中文。',
].join('\n');

export function buildArenaPosterTaskPrompt(input: {
  run: ArenaRun;
  sourceFilePath: string;
  stylePreset: PosterStylePreset;
  aspectRatio: PosterAspectRatio;
  language: string;
  htmlOutputPath?: string;
  imageOutputPath?: string;
}): string {
  const participantLine = input.run.participants
    .map((participant) => `${participant.displayName}（${participant.stageLabel}）`)
    .join('、');
  const htmlOutputPath = input.htmlOutputPath ?? 'deliverables/editorial-card.html';
  const imageOutputPath = input.imageOutputPath ?? 'deliverables/editorial-card.png';

  return [
    `任务目标：为这场人格讨论生成 1 张可分享的社论风信息图卡，并输出 PNG。`,
    `讨论主题：${input.run.topic}`,
    `参与者：${participantLine}`,
    `标题参考：${input.run.summary.title}`,
    `共识摘要：${input.run.summary.consensus}`,
    `叙事引子：${input.run.summary.narrativeHook}`,
    `源文件：${input.sourceFilePath}`,
    `风格预设：${input.stylePreset}`,
    `输出比例：${input.aspectRatio}`,
    `语言：${input.language}`,
    `HTML 输出路径：${htmlOutputPath}`,
    `PNG 输出路径：${imageOutputPath}`,
    '',
    '硬性要求：',
    '1. 必须调用 `editorial-card-screenshot` skill，不允许改用别的技能或直接手写伪造结果。',
    '2. 必须先基于当前工作目录内的源文件生成 screenshot-ready HTML，再输出 PNG，不要依赖外部图像模型。',
    '3. 生成结果必须至少包含 1 个 HTML 文件和 1 个 PNG 文件，且都保留在当前工作目录内。',
    '4. 视觉上要保留“跨时空讨论 / 编辑部信息图 / 高密度结论卡”的感觉，而不是普通网页截图。',
    '5. 优先用当前 summary / disagreements / actionableAdvice / verdict 组织层次，确保卡片信息密度足够高。',
    '6. 产物完成后，返回真实文件路径，不能返回臆造路径。',
    '',
    '推荐调用方式：',
    `Use $editorial-card-screenshot to turn \`${input.sourceFilePath}\` into a ${input.aspectRatio} editorial information card. Save the final HTML to \`${htmlOutputPath}\` and the PNG to \`${imageOutputPath}\`.`,
    '',
    '返回约定：',
    `- imagePath 返回 PNG 路径（建议就是 ${imageOutputPath}）`,
    `- sourcePath 返回 HTML 路径（建议就是 ${htmlOutputPath}）`,
    `- promptPath 可以返回源 markdown 路径（建议就是 ${input.sourceFilePath}）`,
    '',
    '最终只输出符合 schema 的 JSON。',
  ].join('\n');
}
