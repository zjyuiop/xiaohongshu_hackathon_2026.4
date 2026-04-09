import crypto from 'node:crypto';
import path from 'node:path';
import { mkdir, writeFile } from 'node:fs/promises';

import * as cheerio from 'cheerio';

import { getConfig } from '../config.js';
import type {
  GeneratedProfileDraft,
  ProfileBundle,
  ProfileImportRequest,
  ProfileImportResponse,
  ProfileImportSourceSummary,
  ProfileImportType,
  SourceSection,
  TimelineNode,
} from '../domain.js';
import type { BackendRepository, SourceDocumentInput } from '../repository.js';
import { parseEpub } from './epub.js';
import { buildAgents } from './persona.js';
import { getRuntime } from './runtime.js';

const config = getConfig();

const plainTextExtensions = new Set([
  '.txt',
  '.md',
  '.markdown',
  '.csv',
  '.log',
  '.json',
  '.html',
  '.htm',
  '.xml',
]);

interface StoredUpload {
  storedPath: string;
  extension: string;
  fileHash: string;
}

interface PreparedImportSource {
  title: string;
  sourceType: 'epub' | 'text';
  sourceLabel: string;
  rawText: string;
  analysisText: string;
  sections: SourceSection[];
  metadata: Record<string, unknown>;
  messageCount?: number;
}

function slugify(input: string): string {
  const normalized = input
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 72);

  return normalized || 'imported-profile';
}

function sanitizeFilename(value: string): string {
  const parsed = path.parse(value);
  const safeName = parsed.name.replace(/[^a-zA-Z0-9\u4e00-\u9fa5._-]+/g, '-').replace(/-+/g, '-').slice(0, 80) || 'upload';
  const safeExt = parsed.ext.replace(/[^a-zA-Z0-9.]+/g, '').slice(0, 12);
  return `${safeName}${safeExt}`;
}

function normalizeText(input: string): string {
  return input
    .replace(/\u00a0/g, ' ')
    .replace(/\r/g, '\n')
    .split('\n')
    .map((line) => line.replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .join('\n');
}

function toFileTitle(originalFileName: string): string {
  return path.basename(originalFileName, path.extname(originalFileName)).replace(/[_-]+/g, ' ').trim() || originalFileName;
}

function limitTextForModel(input: string, maxChars: number): string {
  const normalized = normalizeText(input);
  if (normalized.length <= maxChars) {
    return normalized;
  }

  const headLength = Math.floor(maxChars * 0.7);
  const tailLength = Math.max(800, maxChars - headLength);

  return [
    normalized.slice(0, headLength).trimEnd(),
    '',
    `[中间内容已截断，原始文本共 ${normalized.length} 个字符]`,
    '',
    normalized.slice(-tailLength).trimStart(),
  ].join('\n');
}

function asNonEmptyString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value !== 'string') {
      continue;
    }

    const trimmed = value.trim();
    if (trimmed) {
      return trimmed;
    }
  }

  return undefined;
}

function extractTextFromHtml(html: string): string {
  const $ = cheerio.load(html);
  $('script,style,noscript,template,svg,img').remove();

  const blocks = $('body')
    .find('h1,h2,h3,h4,h5,h6,p,li,blockquote,pre,td,th')
    .map((_, element) => normalizeText($(element).text()))
    .get()
    .filter(Boolean);

  return normalizeText(blocks.length > 0 ? blocks.join('\n') : $('body').text());
}

function extractTextFromJson(content: string): { text: string; messageCount?: number } {
  const parsed = JSON.parse(content) as unknown;
  const lines: string[] = [];
  let messageCount = 0;

  const visit = (value: unknown, depth = 0): void => {
    if (depth > 8 || value == null) {
      return;
    }

    if (Array.isArray(value)) {
      for (const item of value) {
        visit(item, depth + 1);
      }
      return;
    }

    if (typeof value === 'object') {
      const record = value as Record<string, unknown>;
      const sender = asNonEmptyString(
        record.sender_name,
        record.sender,
        record.displayName,
        record.nickname,
        record.role,
        record.author,
        record.username,
      );
      const contentText = asNonEmptyString(
        record.content,
        record.text,
        record.message,
        record.body,
        record.summary,
        record.des,
      );
      const title = asNonEmptyString(record.title);
      const time = asNonEmptyString(
        record.time_str,
        record.time,
        record.timestamp,
        record.datetime,
        record.date,
        record.createdAt,
      );
      const referContent = asNonEmptyString(record.refer_content);

      if (contentText || title) {
        const mainText = contentText ?? title!;
        const prefix = [time ? `[${time}]` : '', sender ? `${sender}:` : ''].filter(Boolean).join(' ');
        lines.push(`${prefix ? `${prefix} ` : ''}${mainText}`.trim());
        if (referContent) {
          lines.push(`引用: ${referContent}`);
        }
        if (sender || time) {
          messageCount += 1;
        }
        return;
      }

      for (const entry of Object.values(record)) {
        visit(entry, depth + 1);
      }
      return;
    }

    if (typeof value === 'string') {
      const normalized = normalizeText(value);
      if (normalized.length >= 2) {
        lines.push(normalized);
      }
    }
  };

  visit(parsed);

  return {
    text: normalizeText(lines.join('\n')),
    messageCount: messageCount > 0 ? messageCount : undefined,
  };
}

function buildTextSections(title: string, rawText: string): SourceSection[] {
  const paragraphs = rawText
    .split(/\n{2,}/)
    .map((item) => normalizeText(item))
    .filter(Boolean);

  if (paragraphs.length === 0) {
    return [
      {
        ordinal: 1,
        title,
        rawText,
        excerpt: rawText.slice(0, 700),
      },
    ];
  }

  const sections: SourceSection[] = [];
  let current: string[] = [];
  let currentLength = 0;

  for (const paragraph of paragraphs) {
    if (current.length > 0 && currentLength + paragraph.length > 3500) {
      const rawSectionText = current.join('\n\n');
      sections.push({
        ordinal: sections.length + 1,
        title: sections.length === 0 ? title : `${title}（片段 ${sections.length + 1}）`,
        rawText: rawSectionText,
        excerpt: rawSectionText.slice(0, 700),
      });
      current = [];
      currentLength = 0;
    }

    current.push(paragraph);
    currentLength += paragraph.length;
  }

  if (current.length > 0) {
    const rawSectionText = current.join('\n\n');
    sections.push({
      ordinal: sections.length + 1,
      title: sections.length === 0 ? title : `${title}（片段 ${sections.length + 1}）`,
      rawText: rawSectionText,
      excerpt: rawSectionText.slice(0, 700),
    });
  }

  return sections;
}

function buildSourceLabel(importType: ProfileImportType): string {
  if (importType === 'manual') {
    return '手动输入上传文件';
  }

  if (importType === 'wechat') {
    return '微信聊天记录上传文件';
  }

  return '聊天记录上传文件';
}

function buildAnalysisText(input: ProfileImportRequest, source: {
  title: string;
  rawText: string;
  sourceLabel: string;
  originalFileName: string;
  messageCount?: number;
}): string {
  const intro =
    input.importType === 'manual'
      ? '这是一份用户手动准备的人物材料文件。请直接从内容中提炼人物的真实阶段、关键经历、价值观和冲突。'
      : input.importType === 'wechat'
        ? '这是一份微信聊天记录导出文件。聊天里可能有噪音、寒暄和多人对话。请优先围绕第一人称“我”、被反复描述的主角，或 displayNameHint 所指向的人物，提炼可讨论的人格时间线。'
        : '这是一份聊天记录导出文件。内容可能是 AI 对话、社交聊天或访谈记录。请基于持续出现的自我描述、决策冲突和经历线索，提炼单个主角的人格时间线。';

  return [
    `导入方式：${source.sourceLabel}`,
    input.displayNameHint ? `人物名提示：${input.displayNameHint}` : '人物名提示：未指定，如原文可推断请自行识别',
    input.title?.trim() ? `用户标题：${input.title.trim()}` : `文件标题：${source.title}`,
    `文件名：${source.originalFileName}`,
    source.messageCount ? `消息条数：约 ${source.messageCount} 条` : '',
    '',
    intro,
    '',
    '以下是从上传文件中抽取的原始文本：',
    limitTextForModel(source.rawText, config.profileImportMaxSourceChars),
  ]
    .filter(Boolean)
    .join('\n');
}

async function persistUpload(file: Express.Multer.File): Promise<StoredUpload> {
  await mkdir(config.profileImportUploadDir, { recursive: true });

  const fileHash = crypto.createHash('sha256').update(file.buffer).digest('hex');
  const safeName = sanitizeFilename(file.originalname || 'upload.txt');
  const extension = path.extname(safeName).toLowerCase();
  const storedPath = path.join(
    config.profileImportUploadDir,
    `${new Date().toISOString().replace(/[:.]/g, '-')}-${fileHash.slice(0, 10)}-${safeName}`,
  );

  await writeFile(storedPath, file.buffer);

  return {
    storedPath,
    extension,
    fileHash,
  };
}

async function prepareImportSource(input: ProfileImportRequest, file: Express.Multer.File, upload: StoredUpload): Promise<PreparedImportSource> {
  const title = input.title?.trim() || toFileTitle(file.originalname || path.basename(upload.storedPath));
  const sourceLabel = buildSourceLabel(input.importType);

  if (upload.extension === '.epub') {
    const { document } = await parseEpub(upload.storedPath);
    const rawText = normalizeText(document.sections.map((section) => `${section.title}\n${section.rawText}`).join('\n\n'));
    return {
      title: input.title?.trim() || document.title || title,
      sourceType: 'epub',
      sourceLabel,
      rawText,
      analysisText: buildAnalysisText(input, {
        title: input.title?.trim() || document.title || title,
        rawText,
        sourceLabel,
        originalFileName: file.originalname,
      }),
      sections: document.sections,
      metadata: {
        importType: input.importType,
        originalFileName: file.originalname,
        mimeType: file.mimetype,
        sectionCount: document.sections.length,
      },
    };
  }

  if (!plainTextExtensions.has(upload.extension)) {
    throw new Error(`暂不支持的文件类型: ${upload.extension || 'unknown'}。当前支持 txt/md/csv/log/json/html/xml/epub`);
  }

  const rawString = file.buffer.toString('utf8');
  let rawText = '';
  let messageCount: number | undefined;

  if (upload.extension === '.html' || upload.extension === '.htm' || file.mimetype.includes('html')) {
    rawText = extractTextFromHtml(rawString);
  } else if (upload.extension === '.json' || file.mimetype.includes('json')) {
    const parsed = extractTextFromJson(rawString);
    rawText = parsed.text;
    messageCount = parsed.messageCount;
  } else {
    rawText = normalizeText(rawString);
  }

  if (rawText.length < 20) {
    throw new Error('上传文件中可提取的文本过少，无法用于角色导入');
  }

  return {
    title,
    sourceType: 'text',
    sourceLabel,
    rawText,
    analysisText: buildAnalysisText(input, {
      title,
      rawText,
      sourceLabel,
      originalFileName: file.originalname,
      messageCount,
    }),
    sections: buildTextSections(title, rawText),
    metadata: {
      importType: input.importType,
      originalFileName: file.originalname,
      mimeType: file.mimetype,
      messageCount,
    },
    messageCount,
  };
}

function normalizeDraftNodes(profileId: string, draft: GeneratedProfileDraft): TimelineNode[] {
  return draft.nodes.map((node, index) => ({
    ...node,
    nodeId: `${profileId}-${index + 1}`,
  }));
}

function buildProfileId(preferredId: string | undefined, displayName: string): string {
  if (preferredId?.trim()) {
    return preferredId.trim();
  }

  return `${slugify(displayName)}-${Date.now().toString(36).slice(-6)}`;
}

function buildSourceDocumentInput(source: PreparedImportSource, upload: StoredUpload): SourceDocumentInput {
  return {
    title: source.title,
    filePath: upload.storedPath,
    fileHash: upload.fileHash,
    sourceType: source.sourceType,
    metadata: {
      ...source.metadata,
      storedPath: upload.storedPath,
    },
    sections: source.sections,
  };
}

function buildImportSummary(
  input: ProfileImportRequest,
  file: Express.Multer.File,
  upload: StoredUpload,
  source: PreparedImportSource,
): ProfileImportSourceSummary {
  return {
    importType: input.importType,
    sourceLabel: source.sourceLabel,
    title: source.title,
    originalFileName: file.originalname,
    mimeType: file.mimetype,
    extension: upload.extension || path.extname(file.originalname).toLowerCase(),
    charCount: source.rawText.length,
    messageCount: source.messageCount,
  };
}

export async function importProfileFromUpload(
  repository: BackendRepository,
  input: ProfileImportRequest,
  file: Express.Multer.File,
): Promise<ProfileImportResponse> {
  const upload = await persistUpload(file);
  const source = await prepareImportSource(input, file, upload);
  const sourceDocumentId = await repository.upsertSourceDocument(buildSourceDocumentInput(source, upload));

  const generated = await getRuntime().generateTimelineFromText({
    displayNameHint: input.displayNameHint?.trim() || undefined,
    biographyOrDigest: source.analysisText,
    sourceLabel: source.sourceLabel,
  });

  const profileId = buildProfileId(input.profileId, generated.draft.displayName);
  const nodes = normalizeDraftNodes(profileId, generated.draft);

  await repository.upsertProfileBundle({
    id: profileId,
    displayName: generated.draft.displayName,
    subtitle: generated.draft.subtitle,
    category: generated.draft.category,
    coverSeed: slugify(generated.draft.displayName),
    biography: generated.draft.biography,
    highlights: generated.draft.highlights,
    suggestedTopics: generated.draft.suggestedTopics,
    sourceDocumentId,
    origin: 'manual',
    isDefault: false,
    rawInput: source.analysisText,
    metadata: {
      ...source.metadata,
      timelineExecution: generated.execution,
    },
    nodes,
  });

  await buildAgents(repository, {
    personId: profileId,
    displayName: generated.draft.displayName,
    biography: generated.draft.biography,
    nodes,
  });

  const bundle = (await repository.getProfileBundle(profileId)) as ProfileBundle | null;
  if (!bundle) {
    throw new Error(`导入后的 profile 不存在: ${profileId}`);
  }

  return {
    bundle,
    import: buildImportSummary(input, file, upload, source),
  };
}
