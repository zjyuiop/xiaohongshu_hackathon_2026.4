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
import { parseEpub } from './epub.js';
import { getRuntime } from './runtime.js';

function slugify(input: string): string {
  const value = input
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return value || `profile-${Date.now()}`;
}

function inferStableProfileId(filePath: string, displayName: string): string {
  if (/jobs|乔布斯/i.test(filePath)) {
    return 'steve-jobs';
  }
  if (/musk|马斯克/i.test(filePath)) {
    return 'elon-musk';
  }
  return slugify(displayName);
}

function inferDisplayName(filePath: string, detectedDisplayName: string): string {
  if (/jobs|乔布斯/i.test(filePath)) {
    return '史蒂夫·乔布斯';
  }
  if (/musk|马斯克/i.test(filePath)) {
    return '埃隆·马斯克';
  }
  return detectedDisplayName;
}

function buildCoverSeed(profileId: string): string {
  return profileId.replace(/[^a-z0-9-]+/g, '-');
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
  if (!title) {
    return false;
  }

  if (/(版权信息|目录|插图|图片|照片|附录|索引|译后记|致谢|后记)/.test(title)) {
    return false;
  }

  if (/^第[\d一二三四五六七八九十百零]+章$/.test(title)) {
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
    `章节标题总览：${(narrativeSections.length > 0 ? narrativeSections : document.sections).map((section) => section.title).slice(0, 30).join(' / ')}`,
    '',
    '抽样章节证据：',
    ...sampled.map(
      (section, index) =>
        `【章节 ${index + 1}】${section.title}\n${section.excerpt.slice(0, 380)}`,
    ),
  ].join('\n\n');
}

function heuristicDraft(document: ParsedEpubDocument, profileId: string, displayName: string): GeneratedProfileDraft {
  const narrativeSections = document.sections.filter((section) => isNarrativeSection(section));
  const selectedSections = sampleSections(narrativeSections.length > 0 ? narrativeSections : document.sections, 5);
  const stageTypes: TimelineNode['stageType'][] = ['early', 'turning-point', 'stable', 'crisis', 'peak'];
  const nodes: TimelineNode[] = selectedSections.map((section, index) => ({
    nodeId: `${profileId}-${index + 1}`,
    timeLabel: `阶段 ${index + 1}`,
    stageLabel: section.title.slice(0, 12),
    stageType: stageTypes[index] ?? 'stable',
    keyEvent: section.title,
    summary: section.excerpt.slice(0, 180),
    traits: ['意志强', '变化大'],
    values: ['成长', '掌控'],
    tensions: ['代价与目标并存'],
    sourceEvidence: [{ quote: section.excerpt.slice(0, 80), sourceLabel: document.title }],
  }));

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
      const files = (await readdir(this.config.defaultLibraryDir))
        .filter((fileName) => fileName.toLowerCase().endsWith('.epub'))
        .map((fileName) => path.join(this.config.defaultLibraryDir, fileName));

      console.log(`[importer] scanning ${files.length} epub files from ${this.config.defaultLibraryDir}`);
      const importedProfileIds: string[] = [];
      for (const filePath of files) {
        console.log(`[importer] importing ${path.basename(filePath)}`);
        const profileId = await this.importSingleEpub(filePath, force);
        if (profileId) {
          console.log(`[importer] ready ${profileId}`);
          importedProfileIds.push(profileId);
        }
      }

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

    const profileId = inferStableProfileId(filePath, draft.displayName);
    nodes = draft.nodes.map((node, index) => ({
      ...node,
      nodeId: `${profileId}-${index + 1}`,
    }));

    let agents: PersonaSpec[];
    try {
      const generated = await getRuntime().generatePersonaBlueprints({
        personId: profileId,
        displayName: draft.displayName,
        biography: draft.biography,
        nodes,
      });
      personaExecution = generated.execution;
      agents = mergeBlueprints(profileId, draft.displayName, nodes, generated.blueprints);
    } catch (error) {
      console.warn('import persona fallback:', error);
      agents = mergeBlueprints(profileId, draft.displayName, nodes, nodes.map((node) => defaultBlueprint(node)));
    }

    await this.repository.upsertProfileBundle({
      id: profileId,
      displayName: draft.displayName,
      subtitle: draft.subtitle,
      category: 'celebrity',
      coverSeed: buildCoverSeed(profileId),
      biography: draft.biography,
      highlights: draft.highlights,
      suggestedTopics: draft.suggestedTopics,
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
