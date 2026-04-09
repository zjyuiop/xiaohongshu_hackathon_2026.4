import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';

import { getConfig } from '../config.js';
import type {
  ArenaOutputLinks,
  ArenaPosterAsset,
  ArenaPosterRequest,
  ArenaPosterResponse,
  ArenaRun,
  ArenaRunStatus,
  PosterAspectRatio,
  PosterStylePreset,
} from '../domain.js';
import type { BackendRepository } from '../repository.js';
import { getRuntime } from './runtime.js';

const config = getConfig();
const execFileAsync = promisify(execFile);
const MAX_PROMPT_TOPIC_CHARS = 120;
const MAX_PROMPT_SUMMARY_CHARS = 320;
const MAX_PROMPT_ADVICE_ITEMS = 4;
const TITLE_MAX_CHARS = 48;
const SUBTITLE_MAX_CHARS = 160;
const KICKER_MAX_CHARS = 28;
const BULLET_MAX_CHARS = 48;
const CHIP_LABEL_MAX_CHARS = 34;
const TRANSCRIPT_SNIPPET_COUNT = 8;
const TRANSCRIPT_SNIPPET_MAX_CHARS = 140;
const VISUAL_PROMPT_MAX_CHARS = 220;
const TRANSCRIPT_EXCERPT_COUNT = 24;
const TRANSCRIPT_LINE_MAX_CHARS = 260;
const POSTER_COPY_DEADLINE_MS = 6000;
const POSTER_CACHE_MANIFEST_FILE = 'poster-manifest.json';

const SANS_FONT_FAMILY = `'Noto Sans SC','PingFang SC','Microsoft YaHei','Helvetica Neue',sans-serif`;
const MONO_FONT_FAMILY = `'JetBrains Mono','SFMono-Regular',Menlo,monospace`;
const INFOCARD_SKILL_NAME = 'editorial-card-screenshot';
const INFOCARD_REPO_CACHE_NAME = 'infocard-skills';
const INFOCARD_OUTPUT_DIR = 'deliverables';
const INFOCARD_HTML_FILE = 'editorial-card.html';
const INFOCARD_IMAGE_FILE = 'editorial-card.png';

interface PosterCopyPlan {
  title: string;
  subtitle: string;
  kicker: string;
  bullets: string[];
  visualPrompt: string;
}

interface PosterChip {
  label: string;
  tone: 'accent' | 'soft' | 'ghost';
}

interface PosterCacheManifest {
  runId: string;
  title: string;
  summary: string;
  stylePreset: PosterStylePreset;
  aspectRatio: PosterAspectRatio;
  generatedAt: string;
  imageFileName: string;
  promptFileName?: string;
  sourceFileName?: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, label: string): Promise<T> {
  let timer: NodeJS.Timeout | undefined;

  try {
    return await Promise.race([
      promise,
      new Promise<T>((_resolve, reject) => {
        timer = setTimeout(() => {
          reject(new Error(`${label}（>${timeoutMs}ms）`));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timer) {
      clearTimeout(timer);
    }
  }
}

function normalizeWhitespace(value: string): string {
  return value.replace(/\s+/g, ' ').trim();
}

function truncateText(value: string, maxChars: number): string {
  const normalized = normalizeWhitespace(value);
  if (normalized.length <= maxChars) {
    return normalized;
  }

  return `${normalized.slice(0, Math.max(0, maxChars - 3)).trim()}...`;
}

function compactText(value: string, maxChars: number): string {
  const normalized = normalizeWhitespace(value);
  return normalized.length > maxChars ? normalized.slice(0, maxChars) : normalized;
}

function splitByCharacters(value: string, maxCharsPerLine: number): string[] {
  const segments: string[] = [];
  let current = '';

  for (const char of value) {
    current += char;
    if (current.length >= maxCharsPerLine) {
      segments.push(current);
      current = '';
    }
  }

  if (current) {
    segments.push(current);
  }

  return segments;
}

function isTransientStatus(status: number): boolean {
  return status === 408 || status === 409 || status === 425 || status === 429 || status >= 500;
}

function extractJsonObject(rawContent: string): Record<string, unknown> {
  const trimmed = rawContent.trim();
  const fenceMatch = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  const primaryCandidate = fenceMatch ? fenceMatch[1].trim() : trimmed;
  const candidates = [primaryCandidate];

  const firstBrace = primaryCandidate.indexOf('{');
  const lastBrace = primaryCandidate.lastIndexOf('}');
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    candidates.push(primaryCandidate.slice(firstBrace, lastBrace + 1));
  }

  let lastError: unknown;
  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch (error) {
      lastError = error;
    }
  }

  throw new Error(`海报文案模型返回 JSON 无法解析: ${String(lastError ?? 'unknown parse error')}`);
}

function formatRunStatusLabel(status?: string): string {
  return status === 'interrupted' ? 'INTERRUPTED' : 'COMPLETED';
}

function getPromptStatusHint(run: ArenaRun): string {
  return run.status === 'interrupted'
    ? '这是一个中断但可继续的讨论，不要伪装成已完成。'
    : '这是一个已完成的讨论，语气可以更完整、更收束。';
}

function buildTranscriptSnippet(run: ArenaRun): PosterChip[] {
  return run.messages
    .slice(Math.max(0, run.messages.length - TRANSCRIPT_SNIPPET_COUNT))
    .map((message) => {
      const speaker = message.kind === 'user' ? 'YOU' : message.displayName;
      const phase = message.phase ? message.phase.toUpperCase() : 'RAW';
      const content = compactText(message.content, TRANSCRIPT_SNIPPET_MAX_CHARS);
      return {
        label: `${speaker} · ${phase} · ${content}`,
        tone: message.kind === 'user' ? 'ghost' : 'soft',
      };
    });
}

function buildPosterChips(run: ArenaRun): PosterChip[] {
  const chips: Array<PosterChip | undefined> = [
    { label: `STATUS / ${formatRunStatusLabel(run.status)}`, tone: run.status === 'interrupted' ? 'accent' : 'ghost' },
    { label: `MODE / ${run.mode.toUpperCase()}`, tone: 'soft' },
    run.config?.roundCount ? { label: `ROUNDS / ${run.config.roundCount}`, tone: 'ghost' } : undefined,
    run.config?.maxMessageChars ? { label: `CAP / ${run.config.maxMessageChars}`, tone: 'ghost' } : undefined,
    { label: `CAST / ${run.participants.length}`, tone: 'ghost' },
    run.sessionId ? { label: `SESSION / ${truncateText(run.sessionId, CHIP_LABEL_MAX_CHARS)}`, tone: 'soft' } : undefined,
    run.continuedFromRunId ? { label: `CONT / ${truncateText(run.continuedFromRunId, CHIP_LABEL_MAX_CHARS)}`, tone: 'ghost' } : undefined,
  ];

  return chips.filter((chip): chip is PosterChip => Boolean(chip));
}

function buildArenaLinks(runId: string): ArenaOutputLinks {
  return {
    runId,
    shareApiPath: `/api/arena/runs/${encodeURIComponent(runId)}`,
    suggestedSharePath: `/share/${encodeURIComponent(runId)}`,
  };
}

function toCacheToken(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48) || 'item';
}

function getSkillPosterCacheDir(runId: string, stylePreset: PosterStylePreset, aspectRatio: PosterAspectRatio): string {
  return path.join(config.generatedDir, 'arena-posters-cache', slugify(runId), `${stylePreset}-${toCacheToken(aspectRatio)}`);
}

function createWorkspaceSlug(run: ArenaRun): string {
  const nonce = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  return `${slugify(run.topic)}-${slugify(run.runId)}-${nonce}`;
}

function slugify(value: string): string {
  return (
    value
      .toLowerCase()
      .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 80) || 'arena-poster'
  );
}

function resolvePosterStylePreset(value?: PosterStylePreset): PosterStylePreset {
  return value ?? 'poster';
}

function resolvePosterAspectRatio(value?: PosterAspectRatio): PosterAspectRatio {
  return value ?? '3:4';
}

function toPublicAssetPath(filePath: string | undefined): string | undefined {
  if (!filePath) {
    return undefined;
  }

  const relative = path.relative(config.generatedDir, filePath).replace(/\\/g, '/');
  if (relative.startsWith('..')) {
    return undefined;
  }

  return `/generated/${relative}`;
}

function toAbsoluteAssetUrl(absoluteBaseUrl: string | undefined, publicPath: string | undefined): string | undefined {
  if (!publicPath) {
    return undefined;
  }

  return absoluteBaseUrl ? `${absoluteBaseUrl}${publicPath}` : publicPath;
}

function normalizeOutputPath(workspaceDir: string, filePath: string | undefined): string | undefined {
  if (!filePath) {
    return undefined;
  }

  const resolved = path.isAbsolute(filePath) ? filePath : path.resolve(workspaceDir, filePath);
  const normalizedWorkspace = path.resolve(workspaceDir);
  const normalizedResolved = path.resolve(resolved);

  if (!normalizedResolved.startsWith(normalizedWorkspace)) {
    throw new Error(`技能返回了工作目录之外的文件路径: ${filePath}`);
  }

  return normalizedResolved;
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

function buildPosterAsset(input: {
  runId: string;
  title: string;
  summary: string;
  stylePreset: PosterStylePreset;
  aspectRatio: PosterAspectRatio;
  outputDir: string;
  imagePath: string;
  promptPath?: string;
  sourcePath?: string;
  generatedAt: string;
  absoluteBaseUrl?: string;
}): ArenaPosterAsset {
  return {
    runId: input.runId,
    title: input.title,
    summary: input.summary,
    stylePreset: input.stylePreset,
    aspectRatio: input.aspectRatio,
    outputDir: input.outputDir,
    imagePath: input.imagePath,
    imageUrl: toAbsoluteAssetUrl(input.absoluteBaseUrl, toPublicAssetPath(input.imagePath)),
    promptPath: input.promptPath,
    promptUrl: toAbsoluteAssetUrl(input.absoluteBaseUrl, toPublicAssetPath(input.promptPath)),
    sourcePath: input.sourcePath,
    sourceUrl: toAbsoluteAssetUrl(input.absoluteBaseUrl, toPublicAssetPath(input.sourcePath)),
    generatedAt: input.generatedAt,
  };
}

async function pickGeneratedSkillFile(
  workspaceDir: string,
  preferredRelativePath: string,
  extension: '.html' | '.png',
): Promise<string | undefined> {
  const preferredPath = path.join(workspaceDir, preferredRelativePath);
  if (await fileExists(preferredPath)) {
    return preferredPath;
  }

  const deliverablesDir = path.join(workspaceDir, INFOCARD_OUTPUT_DIR);
  const entries = await fs.readdir(deliverablesDir, { withFileTypes: true }).catch(() => []);
  const candidates = entries
    .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(extension))
    .map((entry) => path.join(deliverablesDir, entry.name))
    .sort((left, right) => {
      const leftPreferred = path.basename(left).startsWith('editorial-card') ? -1 : 0;
      const rightPreferred = path.basename(right).startsWith('editorial-card') ? -1 : 0;
      return leftPreferred - rightPreferred || left.localeCompare(right);
    });

  return candidates[0];
}

async function detectChromeBinary(): Promise<string | undefined> {
  const candidates = [
    process.env.CHROME_BIN,
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
    '/snap/bin/chromium',
    '/usr/bin/microsoft-edge',
  ].filter((item): item is string => Boolean(item));

  for (const candidate of candidates) {
    if (await fileExists(candidate)) {
      return candidate;
    }
  }

  return undefined;
}

async function isMeaningfulPosterHtml(filePath: string, run: ArenaRun): Promise<boolean> {
  if (!filePath.toLowerCase().endsWith('.html')) {
    return true;
  }

  let rawHtml = '';
  try {
    rawHtml = await fs.readFile(filePath, 'utf8');
  } catch {
    return false;
  }

  const normalized = normalizeWhitespace(rawHtml);
  if (normalized.length < 600) {
    return false;
  }

  if (/recovered skill html|placeholder|todo/i.test(normalized)) {
    return false;
  }

  const anchorTexts = uniqueAnchorTexts([
    run.topic,
    run.summary.title,
    run.summary.consensus,
    ...run.participants.map((participant) => participant.displayName),
  ]);

  return anchorTexts.some((item) => normalized.includes(item));
}

function uniqueAnchorTexts(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const value of values) {
    const normalized = normalizeWhitespace(value);
    if (!normalized || normalized.length < 2) {
      continue;
    }

    if (seen.has(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.push(normalized);
  }

  return result;
}

async function recoverSkillPosterAsset(input: {
  run: ArenaRun;
  workspaceDir: string;
  sourceFilePath: string;
  htmlOutputRelativePath: string;
  imageOutputRelativePath: string;
  aspectRatio: PosterAspectRatio;
  stylePreset: PosterStylePreset;
  absoluteBaseUrl?: string;
}): Promise<ArenaPosterAsset | undefined> {
  const sourcePath =
    (await pickGeneratedSkillFile(input.workspaceDir, input.htmlOutputRelativePath, '.html')) ??
    input.sourceFilePath;
  let imagePath = await pickGeneratedSkillFile(input.workspaceDir, input.imageOutputRelativePath, '.png');
  const sourceHtmlLooksValid = await isMeaningfulPosterHtml(sourcePath, input.run);

  if (!imagePath && sourcePath.toLowerCase().endsWith('.html') && sourceHtmlLooksValid) {
    const captureScriptPath = path.join(
      input.workspaceDir,
      '.claude',
      'skills',
      INFOCARD_SKILL_NAME,
      'scripts',
      'capture_card.sh',
    );
    const targetImagePath = path.join(input.workspaceDir, input.imageOutputRelativePath);
    if (await fileExists(captureScriptPath)) {
      await capturePosterHtmlToPng({
        captureScriptPath,
        sourcePath,
        targetImagePath,
        aspectRatio: input.aspectRatio,
        cwd: input.workspaceDir,
      });
      imagePath = (await fileExists(targetImagePath)) ? targetImagePath : undefined;
    }
  }

  if (!imagePath || !sourceHtmlLooksValid) {
    return undefined;
  }

  return buildPosterAsset({
    runId: input.run.runId,
    title: input.run.summary.title || input.run.topic,
    summary: input.run.summary.consensus || input.run.summary.narrativeHook,
    stylePreset: input.stylePreset,
    aspectRatio: input.aspectRatio,
    outputDir: input.workspaceDir,
    imagePath,
    promptPath: input.sourceFilePath,
    sourcePath,
    generatedAt: new Date().toISOString(),
    absoluteBaseUrl: input.absoluteBaseUrl,
  });
}

async function loadCachedSkillPosterAsset(input: {
  run: ArenaRun;
  stylePreset: PosterStylePreset;
  aspectRatio: PosterAspectRatio;
  absoluteBaseUrl?: string;
}): Promise<ArenaPosterAsset | undefined> {
  const cacheDir = getSkillPosterCacheDir(input.run.runId, input.stylePreset, input.aspectRatio);
  const manifestPath = path.join(cacheDir, POSTER_CACHE_MANIFEST_FILE);

  let manifest: PosterCacheManifest;
  try {
    manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8')) as PosterCacheManifest;
  } catch {
    return undefined;
  }

  if (
    manifest.runId !== input.run.runId ||
    manifest.stylePreset !== input.stylePreset ||
    manifest.aspectRatio !== input.aspectRatio
  ) {
    return undefined;
  }

  const imagePath = path.join(cacheDir, manifest.imageFileName);
  const promptPath = manifest.promptFileName ? path.join(cacheDir, manifest.promptFileName) : undefined;
  const sourcePath = manifest.sourceFileName ? path.join(cacheDir, manifest.sourceFileName) : undefined;

  if (!(await fileExists(imagePath))) {
    return undefined;
  }

  if (sourcePath && sourcePath.toLowerCase().endsWith('.html') && !(await isMeaningfulPosterHtml(sourcePath, input.run))) {
    return undefined;
  }

  return buildPosterAsset({
    runId: input.run.runId,
    title: manifest.title,
    summary: manifest.summary,
    stylePreset: manifest.stylePreset,
    aspectRatio: manifest.aspectRatio,
    outputDir: cacheDir,
    imagePath,
    promptPath,
    sourcePath,
    generatedAt: manifest.generatedAt,
    absoluteBaseUrl: input.absoluteBaseUrl,
  });
}

async function persistSkillPosterAsset(input: {
  run: ArenaRun;
  poster: ArenaPosterAsset;
  absoluteBaseUrl?: string;
}): Promise<ArenaPosterAsset> {
  const cacheDir = getSkillPosterCacheDir(input.run.runId, input.poster.stylePreset, input.poster.aspectRatio);
  await fs.rm(cacheDir, { recursive: true, force: true });
  await ensureDir(cacheDir);

  const imageFileName = path.basename(input.poster.imagePath);
  const imagePath = path.join(cacheDir, imageFileName);
  await fs.copyFile(input.poster.imagePath, imagePath);

  let promptFileName: string | undefined;
  let promptPath: string | undefined;
  if (input.poster.promptPath && (await fileExists(input.poster.promptPath))) {
    promptFileName = path.basename(input.poster.promptPath);
    promptPath = path.join(cacheDir, promptFileName);
    await fs.copyFile(input.poster.promptPath, promptPath);
  }

  let sourceFileName: string | undefined;
  let sourcePath: string | undefined;
  if (input.poster.sourcePath && (await fileExists(input.poster.sourcePath))) {
    sourceFileName = path.basename(input.poster.sourcePath);
    sourcePath = path.join(cacheDir, sourceFileName);
    await fs.copyFile(input.poster.sourcePath, sourcePath);
  }

  const manifest: PosterCacheManifest = {
    runId: input.run.runId,
    title: input.poster.title,
    summary: input.poster.summary,
    stylePreset: input.poster.stylePreset,
    aspectRatio: input.poster.aspectRatio,
    generatedAt: input.poster.generatedAt,
    imageFileName,
    promptFileName,
    sourceFileName,
  };
  await fs.writeFile(path.join(cacheDir, POSTER_CACHE_MANIFEST_FILE), JSON.stringify(manifest, null, 2), 'utf8');

  return buildPosterAsset({
    runId: input.run.runId,
    title: input.poster.title,
    summary: input.poster.summary,
    stylePreset: input.poster.stylePreset,
    aspectRatio: input.poster.aspectRatio,
    outputDir: cacheDir,
    imagePath,
    promptPath,
    sourcePath,
    generatedAt: input.poster.generatedAt,
    absoluteBaseUrl: input.absoluteBaseUrl,
  });
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function wrapText(value: string, maxCharsPerLine: number): string[] {
  const normalized = normalizeWhitespace(value);
  if (!normalized) {
    return [''];
  }

  const words = normalized.split(' ');
  if (words.length === 1) {
    return splitByCharacters(normalized, maxCharsPerLine);
  }

  const lines: string[] = [];
  let current = '';

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length <= maxCharsPerLine) {
      current = candidate;
      continue;
    }

    if (current) {
      lines.push(current);
    }

    if (word.length > maxCharsPerLine) {
      const chunks = splitByCharacters(word, maxCharsPerLine);
      if (chunks.length > 1) {
        lines.push(...chunks.slice(0, -1));
        current = chunks[chunks.length - 1];
        continue;
      }

      current = chunks[0];
      continue;
    }

    current = word;
  }

  if (current) {
    lines.push(current);
  }

  return lines.length > 0 ? lines : [''];
}

function getPosterDimensions(aspectRatio: PosterAspectRatio) {
  switch (aspectRatio) {
    case '16:9':
      return { width: 1600, height: 900 };
    case '2.35:1':
      return { width: 1880, height: 800 };
    case '4:3':
      return { width: 1440, height: 1080 };
    case '3:2':
      return { width: 1500, height: 1000 };
    case '1:1':
      return { width: 1200, height: 1200 };
    case '3:4':
    default:
      return { width: 1200, height: 1600 };
  }
}

function getPosterPalette(stylePreset: PosterStylePreset, status?: ArenaRunStatus) {
  const interrupted = status === 'interrupted';
  if (stylePreset === 'cinematic') {
    return {
      backgroundStart: '#0f172a',
      backgroundEnd: '#111827',
      accent: interrupted ? '#f59e0b' : '#fb7185',
      accentSoft: interrupted ? 'rgba(245, 158, 11, 0.18)' : 'rgba(251, 113, 133, 0.18)',
      text: '#f8fafc',
      textMuted: '#cbd5e1',
      border: 'rgba(248, 250, 252, 0.12)',
      surface: 'rgba(255, 255, 255, 0.06)',
      surfaceStrong: 'rgba(255, 255, 255, 0.12)',
      grid: 'rgba(255, 255, 255, 0.06)',
    };
  }

  if (stylePreset === 'editorial') {
    return {
      backgroundStart: '#faf7f0',
      backgroundEnd: '#efe7d4',
      accent: interrupted ? '#ea580c' : '#7c3aed',
      accentSoft: interrupted ? 'rgba(234, 88, 12, 0.14)' : 'rgba(124, 58, 237, 0.12)',
      text: '#111827',
      textMuted: '#475569',
      border: 'rgba(17, 24, 39, 0.10)',
      surface: 'rgba(255, 255, 255, 0.58)',
      surfaceStrong: 'rgba(255, 255, 255, 0.72)',
      grid: 'rgba(17, 24, 39, 0.06)',
    };
  }

  return {
    backgroundStart: '#04111f',
    backgroundEnd: '#172554',
    accent: interrupted ? '#f59e0b' : '#67e8f9',
    accentSoft: interrupted ? 'rgba(245, 158, 11, 0.18)' : 'rgba(103, 232, 249, 0.18)',
    text: '#f8fafc',
    textMuted: '#cbd5e1',
    border: 'rgba(248, 250, 252, 0.12)',
    surface: 'rgba(255, 255, 255, 0.06)',
    surfaceStrong: 'rgba(255, 255, 255, 0.12)',
    grid: 'rgba(255, 255, 255, 0.06)',
  };
}

function renderArenaPosterSource(run: ArenaRun): string {
  const participants = run.participants
    .map((participant) => `- ${participant.displayName}｜${participant.stageLabel}｜价值观：${participant.values.join('、')}`)
    .join('\n');

  const transcript = run.messages
    .slice(Math.max(0, run.messages.length - TRANSCRIPT_EXCERPT_COUNT))
    .map((message) => {
      if (message.kind === 'user') {
        return `- 用户引导：${compactText(message.content, TRANSCRIPT_LINE_MAX_CHARS)}`;
      }

      const round = message.round ? `第${message.round}轮` : '未标注轮次';
      const phase = message.phase ?? '未标注阶段';
      return `- ${round} / ${phase} / ${message.displayName}（${message.stageLabel}）：${compactText(message.content, TRANSCRIPT_LINE_MAX_CHARS)}`;
    })
    .join('\n');

  return [
    `# ${run.summary.title}`,
    '',
    '## 运行信息',
    `- 状态：${formatRunStatusLabel(run.status)}`,
    `- 会话：${run.sessionId ?? run.runId}`,
    run.continuedFromRunId ? `- 续接自：${run.continuedFromRunId}` : '',
    run.config ? `- 轮数：${run.config.roundCount}，字符上限：${run.config.maxMessageChars}` : '',
    '',
    '## 讨论主题',
    run.topic,
    '',
    '## 叙事引子',
    run.summary.narrativeHook,
    '',
    '## 参与者',
    participants,
    '',
    '## 共识',
    run.summary.consensus,
    '',
    '## 分歧',
    ...run.summary.disagreements.map((item) => `- ${item}`),
    '',
    '## 行动建议',
    ...run.summary.actionableAdvice.map((item) => `- ${item}`),
    ...(run.summary.debateVerdict
      ? ['', '## 裁判结论', `- 胜者：${run.summary.debateVerdict.winnerDisplayName ?? '未指定'}`, `- 理由：${run.summary.debateVerdict.rationale}`]
      : []),
    '',
    '## 对话摘录',
    transcript,
    '',
  ].join('\n');
}

async function ensureDir(dirPath: string): Promise<void> {
  await fs.mkdir(dirPath, { recursive: true });
}

async function ensurePosterSkillsRepo(repoDir: string): Promise<void> {
  const gitDir = path.join(repoDir, '.git');

  try {
    await fs.access(gitDir);
    await execFileAsync('git', ['-C', repoDir, 'pull', '--ff-only'], {
      cwd: config.backendRoot,
    });
    return;
  } catch {
    await fs.rm(repoDir, { recursive: true, force: true });
  }

  await ensureDir(path.dirname(repoDir));
  await execFileAsync('git', ['clone', '--depth=1', config.posterSkillsRepoUrl, repoDir], {
    cwd: config.backendRoot,
  });
}

async function ensureCaptureScriptPath(): Promise<string | undefined> {
  const cacheDir = path.join(config.generatedDir, '.skill-cache', INFOCARD_REPO_CACHE_NAME);
  const captureScriptPath = path.join(cacheDir, 'skills', INFOCARD_SKILL_NAME, 'scripts', 'capture_card.sh');
  if (await fileExists(captureScriptPath)) {
    return captureScriptPath;
  }

  await ensurePosterSkillsRepo(cacheDir);
  return (await fileExists(captureScriptPath)) ? captureScriptPath : undefined;
}

async function capturePosterHtmlToPng(input: {
  captureScriptPath: string;
  sourcePath: string;
  targetImagePath: string;
  aspectRatio: PosterAspectRatio;
  cwd: string;
}): Promise<boolean> {
  const chromeBinary = await detectChromeBinary();
  if (!chromeBinary) {
    return false;
  }

  try {
    await execFileAsync(
      'bash',
      [input.captureScriptPath, input.sourcePath, input.targetImagePath, input.aspectRatio],
      {
        cwd: input.cwd,
        env: {
          ...process.env,
          CHROME_BIN: chromeBinary,
        },
      },
    );
  } catch (error) {
    console.warn('poster capture fallback failed:', error);
  }

  return fileExists(input.targetImagePath);
}

async function prepareSkillPosterWorkspace(
  run: ArenaRun,
): Promise<{
  workspaceDir: string;
  sourceFilePath: string;
  sourceFileRelativePath: string;
  htmlOutputRelativePath: string;
  imageOutputRelativePath: string;
}> {
  const cacheDir = path.join(config.generatedDir, '.skill-cache', INFOCARD_REPO_CACHE_NAME);
  await ensurePosterSkillsRepo(cacheDir);

  const workspaceDir = path.join(config.generatedDir, 'arena-posters', createWorkspaceSlug(run));
  const skillsDir = path.join(workspaceDir, '.claude', 'skills');
  const deliverablesDir = path.join(workspaceDir, INFOCARD_OUTPUT_DIR);

  await fs.rm(workspaceDir, { recursive: true, force: true });
  await ensureDir(skillsDir);
  await ensureDir(deliverablesDir);

  await fs.cp(path.join(cacheDir, 'skills', INFOCARD_SKILL_NAME), path.join(skillsDir, INFOCARD_SKILL_NAME), {
    recursive: true,
  });

  const sourceFilePath = path.join(workspaceDir, `source-${slugify(run.summary.title || run.topic)}.md`);
  await fs.writeFile(sourceFilePath, renderArenaPosterSource(run), 'utf8');

  return {
    workspaceDir,
    sourceFilePath,
    sourceFileRelativePath: path.relative(workspaceDir, sourceFilePath).replace(/\\/g, '/'),
    htmlOutputRelativePath: `${INFOCARD_OUTPUT_DIR}/${INFOCARD_HTML_FILE}`,
    imageOutputRelativePath: `${INFOCARD_OUTPUT_DIR}/${INFOCARD_IMAGE_FILE}`,
  };
}

function getCaptureDimensions(aspectRatio: PosterAspectRatio) {
  switch (aspectRatio) {
    case '16:9':
      return { width: 1920, height: 1080 };
    case '2.35:1':
      return { width: 2350, height: 1000 };
    case '4:3':
      return { width: 2000, height: 1500 };
    case '3:2':
      return { width: 1800, height: 1200 };
    case '1:1':
      return { width: 1800, height: 1800 };
    case '3:4':
    default:
      return { width: 1500, height: 2000 };
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderEditorialFallbackHtml(
  run: ArenaRun,
  copy: PosterCopyPlan,
  stylePreset: PosterStylePreset,
  aspectRatio: PosterAspectRatio,
): string {
  const { width, height } = getCaptureDimensions(aspectRatio);
  const portrait = height > width;
  const square = width === height;
  const palette =
    stylePreset === 'cinematic'
      ? {
          paper: '#11161d',
          ink: '#f4efe8',
          muted: '#c0c7cf',
          accent: '#f08c6c',
          line: 'rgba(255,255,255,0.14)',
          panel: 'rgba(255,255,255,0.06)',
          panelStrong: 'rgba(255,255,255,0.1)',
        }
      : stylePreset === 'poster'
        ? {
            paper: '#f3efe7',
            ink: '#111111',
            muted: '#5b5f66',
            accent: '#194866',
            line: 'rgba(17,17,17,0.12)',
            panel: 'rgba(17,17,17,0.04)',
            panelStrong: 'rgba(17,17,17,0.08)',
          }
        : {
            paper: '#f5f1e8',
            ink: '#171717',
            muted: '#58544d',
            accent: '#8b4b2d',
            line: 'rgba(23,23,23,0.12)',
            panel: 'rgba(23,23,23,0.035)',
            panelStrong: 'rgba(23,23,23,0.07)',
          };

  const actions = run.summary.actionableAdvice.slice(0, 3);
  const disagreements = run.summary.disagreements.slice(0, 3);
  const cast = run.participants.slice(0, portrait ? 6 : 4);
  const snippets = run.messages.slice(-4);
  const headline = escapeHtml(copy.title);
  const deck = escapeHtml(copy.subtitle || run.summary.consensus || run.summary.narrativeHook);
  const topic = escapeHtml(truncateText(run.topic, portrait ? 52 : 76));
  const consensus = escapeHtml(run.summary.consensus);
  const summaryBullets = copy.bullets.slice(0, 3).map((item) => `<li>${escapeHtml(item)}</li>`).join('');
  const actionItems = actions.map((item) => `<li>${escapeHtml(item)}</li>`).join('');
  const disagreementItems = disagreements.length > 0
    ? disagreements.map((item) => `<li>${escapeHtml(item)}</li>`).join('')
    : '<li>当前没有新的明显分歧，重点在执行与取舍。</li>';
  const castItems = cast
    .map(
      (item) => `
        <li class="cast-item">
          <strong>${escapeHtml(item.displayName)}</strong>
          <span>${escapeHtml(item.stageLabel)}</span>
        </li>`,
    )
    .join('');
  const snippetItems = snippets
    .map(
      (item) => `
        <article class="quote-item">
          <p class="quote-meta">${escapeHtml(item.displayName)} / ${escapeHtml(item.stageLabel)}</p>
          <p class="quote-body">${escapeHtml(truncateText(item.content, portrait ? 72 : 96))}</p>
        </article>`,
    )
    .join('');

  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${headline}</title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@700;900&family=Noto+Sans+SC:wght@400;500;700&family=Oswald:wght@500;700&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
      :root {
        --paper: ${palette.paper};
        --ink: ${palette.ink};
        --muted: ${palette.muted};
        --accent: ${palette.accent};
        --line: ${palette.line};
        --panel: ${palette.panel};
        --panel-strong: ${palette.panelStrong};
        --canvas-width: ${width}px;
        --canvas-height: ${height}px;
      }

      * { box-sizing: border-box; }
      html, body { margin: 0; width: 100%; height: 100%; background: var(--paper); }
      body {
        font-family: "Inter", "Noto Sans SC", "PingFang SC", sans-serif;
        color: var(--ink);
      }

      .frame { width: var(--canvas-width); height: var(--canvas-height); }
      .card {
        width: 100%;
        height: 100%;
        padding: ${portrait ? 54 : 48}px;
        display: grid;
        grid-template-rows: auto auto 1fr;
        gap: ${portrait ? 30 : 24}px;
        background:
          radial-gradient(circle at top right, rgba(0,0,0,0.04), transparent 24%),
          linear-gradient(180deg, rgba(255,255,255,0.24), transparent 22%),
          var(--paper);
        overflow: hidden;
        position: relative;
      }

      .card::before {
        content: "";
        position: absolute;
        inset: 0;
        pointer-events: none;
        opacity: 0.04;
        background-image:
          radial-gradient(circle at 20% 20%, rgba(0, 0, 0, 0.8) 0.5px, transparent 0.8px),
          radial-gradient(circle at 70% 40%, rgba(0, 0, 0, 0.6) 0.5px, transparent 0.9px);
        background-size: 8px 8px, 12px 12px;
      }

      .masthead {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 20px;
        position: relative;
        z-index: 1;
      }

      .kicker, .meta {
        margin: 0;
        font-family: "Oswald", "Inter", sans-serif;
        font-size: 18px;
        letter-spacing: 0.18em;
        text-transform: uppercase;
        color: var(--muted);
      }

      .hero {
        display: grid;
        grid-template-columns: ${portrait ? '1fr' : 'minmax(0, 1.15fr) minmax(360px, 0.85fr)'};
        gap: ${portrait ? 22 : 26}px;
        align-items: start;
        position: relative;
        z-index: 1;
      }

      .headline {
        margin: 0;
        font-family: "Noto Serif SC", serif;
        font-size: ${portrait ? 98 : square ? 88 : 76}px;
        line-height: 0.94;
        letter-spacing: -0.05em;
      }

      .deck {
        margin: 18px 0 0;
        font-size: ${portrait ? 28 : 24}px;
        line-height: 1.55;
        color: var(--muted);
      }

      .topic-line {
        margin: 22px 0 0;
        padding-top: 18px;
        border-top: 5px solid var(--accent);
        font-size: ${portrait ? 22 : 20}px;
        line-height: 1.6;
      }

      .hero-side {
        padding: 26px 28px;
        background: var(--panel-strong);
        border: 1px solid var(--line);
        display: grid;
        gap: 16px;
      }

      .hero-side h2,
      .section h3 {
        margin: 0;
        font-family: "Oswald", "Inter", sans-serif;
        font-size: 18px;
        letter-spacing: 0.12em;
        text-transform: uppercase;
      }

      .hero-side p {
        margin: 0;
        font-size: ${portrait ? 24 : 22}px;
        line-height: 1.62;
      }

      .content {
        display: grid;
        grid-template-columns: ${portrait ? '1fr' : 'minmax(0, 1.02fr) minmax(320px, 0.98fr)'};
        gap: ${portrait ? 20 : 24}px;
        min-height: 0;
        position: relative;
        z-index: 1;
      }

      .column {
        display: grid;
        gap: 18px;
        align-content: start;
      }

      .section {
        padding: 24px 26px;
        background: var(--panel);
        border: 1px solid var(--line);
      }

      .section ul {
        margin: 14px 0 0;
        padding-left: 22px;
        display: grid;
        gap: 12px;
        font-size: ${portrait ? 24 : 22}px;
        line-height: 1.56;
      }

      .cast-list {
        list-style: none;
        padding: 0;
        margin: 14px 0 0;
        display: grid;
        gap: 12px;
      }

      .cast-item {
        display: flex;
        justify-content: space-between;
        gap: 16px;
        padding: 14px 0;
        border-top: 1px solid var(--line);
      }

      .cast-item strong {
        font-size: 22px;
      }

      .cast-item span {
        font-size: 19px;
        color: var(--muted);
        text-align: right;
      }

      .quotes {
        display: grid;
        gap: 12px;
        margin-top: 14px;
      }

      .quote-item {
        padding: 16px 18px;
        background: rgba(255,255,255,0.35);
        border-left: 4px solid var(--accent);
      }

      .quote-meta {
        margin: 0 0 8px;
        font-size: 15px;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--muted);
      }

      .quote-body {
        margin: 0;
        font-size: ${portrait ? 21 : 19}px;
        line-height: 1.6;
      }

      .footer {
        display: flex;
        justify-content: space-between;
        gap: 20px;
        align-items: end;
        border-top: 1px solid var(--line);
        padding-top: 14px;
        position: relative;
        z-index: 1;
      }

      .footer-note {
        margin: 0;
        font-size: 16px;
        line-height: 1.5;
        color: var(--muted);
      }

      .footer-run {
        margin: 0;
        font-family: "Oswald", "Inter", sans-serif;
        font-size: 18px;
        letter-spacing: 0.12em;
        text-transform: uppercase;
        color: var(--muted);
      }

      @media (max-width: 900px) {
        html, body { width: auto; height: auto; }
        .frame { width: 100%; height: auto; }
        .card {
          width: auto;
          height: auto;
          padding: 24px;
          grid-template-rows: auto;
        }
        .hero, .content { grid-template-columns: 1fr; }
        .headline { font-size: 52px; }
        .deck, .hero-side p, .section ul, .quote-body { font-size: 18px; }
      }
    </style>
  </head>
  <body>
    <main class="frame">
      <article class="card">
        <header class="masthead">
          <p class="kicker">${escapeHtml(copy.kicker)}</p>
          <p class="meta">${escapeHtml(run.status === 'interrupted' ? 'Interrupted Session' : 'Completed Session')}</p>
        </header>

        <section class="hero">
          <div>
            <h1 class="headline">${headline}</h1>
            <p class="deck">${deck}</p>
            <p class="topic-line">${topic}</p>
          </div>

          <aside class="hero-side">
            <h2>Core Judgment</h2>
            <p>${consensus}</p>
          </aside>
        </section>

        <section class="content">
          <div class="column">
            <section class="section">
              <h3>What To Do Next</h3>
              <ul>${actionItems || summaryBullets}</ul>
            </section>
            <section class="section">
              <h3>Why This Matters</h3>
              <ul>${summaryBullets}</ul>
            </section>
          </div>

          <div class="column">
            <section class="section">
              <h3>Who Spoke</h3>
              <ul class="cast-list">${castItems}</ul>
            </section>
            <section class="section">
              <h3>Tension</h3>
              <ul>${disagreementItems}</ul>
            </section>
            <section class="section">
              <h3>Key Quotes</h3>
              <div class="quotes">${snippetItems}</div>
            </section>
          </div>
        </section>

        <footer class="footer">
          <p class="footer-note">${escapeHtml(copy.visualPrompt)}</p>
          <p class="footer-run">${escapeHtml(run.runId)}</p>
        </footer>
      </article>
    </main>
  </body>
</html>`;
}

async function generateEditorialFallbackPosterAsset(input: {
  run: ArenaRun;
  copy: PosterCopyPlan;
  stylePreset: PosterStylePreset;
  aspectRatio: PosterAspectRatio;
  workspaceDir: string;
  promptPath: string;
  absoluteBaseUrl?: string;
}): Promise<ArenaPosterAsset | undefined> {
  const captureScriptPath = await ensureCaptureScriptPath();
  if (!captureScriptPath) {
    return undefined;
  }

  const deliverablesDir = path.join(input.workspaceDir, INFOCARD_OUTPUT_DIR);
  await ensureDir(deliverablesDir);

  const htmlPath = path.join(deliverablesDir, INFOCARD_HTML_FILE);
  const imagePath = path.join(deliverablesDir, INFOCARD_IMAGE_FILE);
  await fs.writeFile(htmlPath, renderEditorialFallbackHtml(input.run, input.copy, input.stylePreset, input.aspectRatio), 'utf8');

  const captured = await capturePosterHtmlToPng({
    captureScriptPath,
    sourcePath: htmlPath,
    targetImagePath: imagePath,
    aspectRatio: input.aspectRatio,
    cwd: input.workspaceDir,
  });
  if (!captured) {
    return undefined;
  }

  return buildPosterAsset({
    runId: input.run.runId,
    title: input.copy.title,
    summary: input.copy.subtitle,
    stylePreset: input.stylePreset,
    aspectRatio: input.aspectRatio,
    outputDir: deliverablesDir,
    imagePath,
    promptPath: input.promptPath,
    sourcePath: htmlPath,
    generatedAt: new Date().toISOString(),
    absoluteBaseUrl: input.absoluteBaseUrl,
  });
}

async function preparePosterWorkspace(
  run: ArenaRun,
): Promise<{ workspaceDir: string; sourceFilePath: string; promptFilePath: string; copyFilePath: string }> {
  const workspaceSlug = createWorkspaceSlug(run);
  const workspaceDir = path.join(config.generatedDir, 'arena-posters', workspaceSlug);

  await ensureDir(workspaceDir);

  const sourceFilePath = path.join(workspaceDir, `source-${slugify(run.summary.title || run.topic)}.md`);
  const promptFilePath = path.join(workspaceDir, `poster-request-${slugify(run.topic)}.json`);
  const copyFilePath = path.join(workspaceDir, `poster-copy-plan-${slugify(run.topic)}.json`);

  await fs.writeFile(sourceFilePath, renderArenaPosterSource(run), 'utf8');

  return { workspaceDir, sourceFilePath, promptFilePath, copyFilePath };
}

async function resolveArenaRun(repository: BackendRepository, input: ArenaPosterRequest): Promise<ArenaRun> {
  if (input.run) {
    return input.run;
  }

  if (!input.runId) {
    throw new Error('缺少 runId 或 run');
  }

  const run = await repository.getArenaRun(input.runId);
  if (!run) {
    throw new Error(`未找到讨论记录: ${input.runId}`);
  }

  return run;
}

async function generateArenaPosterWithSkill(
  run: ArenaRun,
  stylePreset: PosterStylePreset,
  aspectRatio: PosterAspectRatio,
  language: string,
  absoluteBaseUrl?: string,
): Promise<ArenaPosterAsset> {
  const { workspaceDir, sourceFilePath, sourceFileRelativePath, htmlOutputRelativePath, imageOutputRelativePath } =
    await prepareSkillPosterWorkspace(run);
  const chromeBinary = await detectChromeBinary();
  if (chromeBinary && !process.env.CHROME_BIN) {
    process.env.CHROME_BIN = chromeBinary;
  }
  let generated:
    | {
        poster: {
          outputDir: string;
          imagePath: string;
          promptPath?: string;
          sourcePath?: string;
          title: string;
          summary: string;
        };
      }
    | undefined;

  try {
    generated = await getRuntime().generateArenaPoster({
      run,
      sourceFilePath: sourceFileRelativePath,
      workingDirectory: workspaceDir,
      stylePreset,
      aspectRatio,
      language,
      htmlOutputPath: htmlOutputRelativePath,
      imageOutputPath: imageOutputRelativePath,
    });
  } catch (error) {
    const recovered = await recoverSkillPosterAsset({
      run,
      workspaceDir,
      sourceFilePath,
      htmlOutputRelativePath,
      imageOutputRelativePath,
      aspectRatio,
      stylePreset,
      absoluteBaseUrl,
    });
    if (recovered) {
      console.warn('poster skill recovered from partial artifacts:', error);
      return recovered;
    }
    throw error;
  }

  const imagePath = normalizeOutputPath(workspaceDir, generated.poster.imagePath);
  if (!imagePath) {
    throw new Error('技能未返回海报文件路径');
  }

  await fs.access(imagePath);

  const promptPath = normalizeOutputPath(workspaceDir, generated.poster.promptPath) ?? sourceFilePath;
  const normalizedSourcePath =
    normalizeOutputPath(workspaceDir, generated.poster.sourcePath) ??
    path.join(workspaceDir, htmlOutputRelativePath);
  const outputDir = normalizeOutputPath(workspaceDir, generated.poster.outputDir) ?? workspaceDir;
  await fs.access(normalizedSourcePath);
  if (!(await isMeaningfulPosterHtml(normalizedSourcePath, run))) {
    throw new Error(`技能返回的 HTML 产物无效或仍是占位内容: ${normalizedSourcePath}`);
  }

  return buildPosterAsset({
    runId: run.runId,
    title: generated.poster.title,
    summary: generated.poster.summary,
    stylePreset,
    aspectRatio,
    outputDir,
    imagePath,
    promptPath,
    sourcePath: normalizedSourcePath,
    generatedAt: new Date().toISOString(),
    absoluteBaseUrl,
  });
}

function buildPosterPrompt(run: ArenaRun, stylePreset: PosterStylePreset, aspectRatio: PosterAspectRatio, language: string) {
  const transcriptSnippet = buildTranscriptSnippet(run).map((chip) => chip.label);

  return {
    system: [
      '你是高级视觉策划与文案导演。',
      '请把一场多人格讨论转成适合“全息海报”的中文文案方案。',
      '风格要像未来 HUD / 赛博展陈，而不是普通宣传页。',
      getPromptStatusHint(run),
      '只输出 JSON，不要输出 markdown，不要解释。',
    ].join(' '),
    user: {
      language,
      stylePreset,
      aspectRatio,
      status: run.status ?? 'completed',
      sessionId: run.sessionId,
      continuedFromRunId: run.continuedFromRunId,
      topic: compactText(run.topic, MAX_PROMPT_TOPIC_CHARS),
      summaryTitle: compactText(run.summary.title, MAX_PROMPT_TOPIC_CHARS),
      consensus: compactText(run.summary.consensus, MAX_PROMPT_SUMMARY_CHARS),
      narrativeHook: compactText(run.summary.narrativeHook, MAX_PROMPT_SUMMARY_CHARS),
      moderatorNote: run.summary.moderatorNote ? compactText(run.summary.moderatorNote, MAX_PROMPT_SUMMARY_CHARS) : undefined,
      debateVerdict: run.summary.debateVerdict
        ? {
            winnerDisplayName: run.summary.debateVerdict.winnerDisplayName,
            rationale: compactText(run.summary.debateVerdict.rationale, MAX_PROMPT_SUMMARY_CHARS),
          }
        : undefined,
      config: run.config
        ? {
            roundCount: run.config.roundCount,
            maxMessageChars: run.config.maxMessageChars,
            reasoningEffort: run.config.reasoningEffort,
          }
        : undefined,
      participants: run.participants.map((participant) => ({
        displayName: compactText(participant.displayName, 24),
        stageLabel: compactText(participant.stageLabel, 20),
        values: participant.values.slice(0, 4).map((item) => compactText(item, 12)),
      })),
      actionableAdvice: run.summary.actionableAdvice.slice(0, MAX_PROMPT_ADVICE_ITEMS).map((item) => compactText(item, 72)),
      transcriptSnippet,
    },
    schemaHint: {
      title: 'string',
      subtitle: 'string',
      kicker: 'string',
      bullets: ['string', 'string', 'string'],
      visualPrompt: 'string',
    },
  };
}

function buildFallbackBullets(run: ArenaRun): string[] {
  const merged = [
    run.status === 'interrupted' ? '保留中断点，支持续写与回溯' : '将结论转成下一步执行节奏',
    ...run.summary.actionableAdvice,
    ...run.summary.disagreements,
    `围绕“${run.topic}”设定可执行时间线`,
  ]
    .map((item) => truncateText(String(item), BULLET_MAX_CHARS))
    .filter((item) => item.length > 0);

  const result = merged.slice(0, 3);
  if (result.length >= 3) {
    return result;
  }

  const defaults = ['识别关键分歧与共识', '沉淀三条行动路径', '将讨论转化为下一步实验'];
  for (const item of defaults) {
    if (result.length >= 3) {
      break;
    }

    result.push(item);
  }

  return result;
}

function buildFallbackPosterCopy(run: ArenaRun): PosterCopyPlan {
  return {
    title: truncateText(run.summary.title || run.topic, TITLE_MAX_CHARS),
    subtitle: truncateText(run.summary.consensus || run.summary.narrativeHook || run.topic, SUBTITLE_MAX_CHARS),
    kicker: truncateText(run.status === 'interrupted' ? 'PARTIAL SIGNAL' : 'TIME PERSONA ARENA', KICKER_MAX_CHARS),
    bullets: buildFallbackBullets(run),
    visualPrompt: truncateText(`围绕“${run.topic}”的跨时空人格讨论海报，突出冲突、判断、成长与决断感。`, VISUAL_PROMPT_MAX_CHARS),
  };
}

async function requestPosterCopyFromLlm(
  run: ArenaRun,
  stylePreset: PosterStylePreset,
  aspectRatio: PosterAspectRatio,
  language: string,
): Promise<PosterCopyPlan | null> {
  if (!config.posterBaseUrl || !config.posterApiKey || !config.posterModel) {
    return null;
  }

  const prompt = buildPosterPrompt(run, stylePreset, aspectRatio, language);
  const payloadBody = JSON.stringify({
    model: config.posterModel,
    temperature: 0.7,
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content: prompt.system,
      },
      {
        role: 'user',
        content: JSON.stringify(prompt.user, null, 2),
      },
    ],
  });

  const maxAttempts = config.posterRequestRetryCount + 1;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.posterRequestTimeoutMs);

    try {
      const response = await fetch(`${config.posterBaseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${config.posterApiKey}`,
        },
        body: payloadBody,
        signal: controller.signal,
      });

      if (!response.ok) {
        const rawBody = (await response.text()).trim();
        if (isTransientStatus(response.status) && attempt < maxAttempts) {
          await sleep(400 * attempt);
          continue;
        }

        throw new Error(
          `海报文案模型请求失败: ${response.status}${rawBody ? ` - ${rawBody.slice(0, 160)}` : ''}`,
        );
      }

      const payload = (await response.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };

      const content = payload.choices?.[0]?.message?.content?.trim();
      if (!content) {
        throw new Error('海报文案模型未返回内容');
      }

      const parsed = extractJsonObject(content);
      const bullets = Array.isArray(parsed.bullets) ? parsed.bullets.map((item) => String(item)) : [];
      return {
        title: typeof parsed.title === 'string' ? parsed.title : '',
        subtitle: typeof parsed.subtitle === 'string' ? parsed.subtitle : '',
        kicker: typeof parsed.kicker === 'string' ? parsed.kicker : '',
        bullets,
        visualPrompt: typeof parsed.visualPrompt === 'string' ? parsed.visualPrompt : '',
      };
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        if (attempt < maxAttempts) {
          await sleep(400 * attempt);
          continue;
        }

        throw new Error(`海报文案模型请求超时（${config.posterRequestTimeoutMs}ms）`);
      }

      if (attempt < maxAttempts) {
        await sleep(400 * attempt);
        continue;
      }

      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  return null;
}

function sanitizePosterCopy(copy: PosterCopyPlan, fallback: PosterCopyPlan): PosterCopyPlan {
  const title = truncateText(copy.title || fallback.title, TITLE_MAX_CHARS);
  const subtitle = truncateText(copy.subtitle || fallback.subtitle, SUBTITLE_MAX_CHARS);
  const kicker = truncateText(copy.kicker || fallback.kicker, KICKER_MAX_CHARS);

  const bulletCandidates = copy.bullets
    .filter((item) => typeof item === 'string')
    .map((item) => truncateText(item, BULLET_MAX_CHARS))
    .filter((item) => item.length > 0);
  const bullets = (bulletCandidates.length > 0 ? bulletCandidates : fallback.bullets).slice(0, 3);

  return {
    title,
    subtitle,
    kicker,
    bullets,
    visualPrompt: truncateText(copy.visualPrompt || fallback.visualPrompt, VISUAL_PROMPT_MAX_CHARS),
  };
}

function renderChip(
  label: string,
  x: number,
  y: number,
  width: number,
  tone: PosterChip['tone'],
  palette: ReturnType<typeof getPosterPalette>,
): string {
  const fill = tone === 'accent' ? palette.accent : tone === 'soft' ? palette.accentSoft : palette.surfaceStrong;
  const stroke = tone === 'accent' ? palette.accent : palette.border;
  const textColor = tone === 'accent' ? '#ffffff' : palette.textMuted;
  const fontWeight = tone === 'accent' ? '700' : '500';

  return [
    `<rect x="${x}" y="${y - 28}" width="${width}" height="40" rx="20" fill="${fill}" stroke="${stroke}" />`,
    `<text x="${x + 18}" y="${y}" fill="${textColor}" font-size="18" font-weight="${fontWeight}" font-family="${MONO_FONT_FAMILY}">${escapeXml(label)}</text>`,
  ].join('');
}

function measureChipWidth(label: string): number {
  return Math.min(420, Math.max(120, label.length * 11 + 34));
}

function layoutChips(
  chips: PosterChip[],
  startX: number,
  startY: number,
  maxX: number,
  rowGap: number,
  gap: number,
  palette: ReturnType<typeof getPosterPalette>,
): string {
  let currentX = startX;
  let currentY = startY;

  return chips
    .map((chip) => {
      const width = measureChipWidth(chip.label);
      if (currentX > startX && currentX + width > maxX) {
        currentX = startX;
        currentY += rowGap;
      }

      const markup = renderChip(chip.label, currentX, currentY, width, chip.tone, palette);
      currentX += width + gap;
      return markup;
    })
    .join('');
}

function renderPosterSvg(run: ArenaRun, copy: PosterCopyPlan, stylePreset: PosterStylePreset, aspectRatio: PosterAspectRatio): string {
  const { width, height } = getPosterDimensions(aspectRatio);
  const palette = getPosterPalette(stylePreset, run.status);
  const isTall = aspectRatio === '3:4';
  const titleLines = wrapText(copy.title, isTall ? 10 : 14).slice(0, isTall ? 4 : 3);
  const subtitleLines = wrapText(copy.subtitle, isTall ? 18 : 24).slice(0, 4);
  const participantLimit = isTall ? 6 : 4;
  const participantRows = run.participants.slice(0, participantLimit).map((participant) => {
    return truncateText(`${participant.displayName} · ${participant.stageLabel}`, 28);
  });
  const extraParticipants = run.participants.length - participantRows.length;
  const participantChips: PosterChip[] = participantRows.map((label) => ({ label, tone: 'soft' as const }));
  if (extraParticipants > 0) {
    participantChips.push({ label: `+${extraParticipants} MORE`, tone: 'ghost' });
  }
  const metadataChips = buildPosterChips(run);
  const promptLabel = truncateText(copy.visualPrompt, 72);
  const summaryLine = truncateText(run.summary.narrativeHook, 88);
  const titleFontSize = isTall ? (titleLines.length >= 4 ? 58 : titleLines.length === 3 ? 66 : 76) : (titleLines.length >= 3 ? 52 : 64);
  const subtitleFontSize = isTall ? 28 : 26;
  const heroCardHeight = isTall ? 360 : 310;
  const heroCardY = isTall ? 168 : 156;
  const chipsY = heroCardY - 22;
  const participantStartY = isTall ? height - 500 : height - 382;
  const bulletStartY = height - (isTall ? 330 : 220);
  const participantXSpacing = isTall ? 360 : 390;
  const participantWidth = isTall ? 320 : 350;

  const titleSvg = titleLines
    .map(
      (line, index) =>
        `<tspan x="110" dy="${index === 0 ? 0 : isTall ? 82 : 70}">${escapeXml(line)}</tspan>`,
    )
    .join('');

  const subtitleSvg = subtitleLines
    .map(
      (line, index) =>
        `<tspan x="110" dy="${index === 0 ? 0 : 38}">${escapeXml(line)}</tspan>`,
    )
    .join('');

  const bulletSvg = copy.bullets
    .slice(0, 3)
    .map((bullet, index) => {
      const y = bulletStartY + index * 56;
      return [
        `<circle cx="124" cy="${y - 7}" r="6" fill="${palette.accent}" />`,
        `<text x="146" y="${y}" fill="${palette.textMuted}" font-size="27" font-family="${SANS_FONT_FAMILY}">${escapeXml(truncateText(bullet, 32))}</text>`,
      ].join('');
    })
    .join('');

  const participantSvg = participantChips
    .map((participant, index) => {
      const x = 110 + (index % 2) * participantXSpacing;
      const y = participantStartY + Math.floor(index / 2) * 54;
      return renderChip(participant.label, x, y, participantWidth, participant.tone, palette);
    })
    .join('');

  const metadataSvg = layoutChips(metadataChips, 110, chipsY, width - 110, 54, 14, palette);

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="${width}" y2="${height}" gradientUnits="userSpaceOnUse">
      <stop stop-color="${palette.backgroundStart}" />
      <stop offset="1" stop-color="${palette.backgroundEnd}" />
    </linearGradient>
    <radialGradient id="glowA" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(${width * 0.78} ${height * 0.18}) rotate(90) scale(${height * 0.28} ${width * 0.18})">
      <stop stop-color="${palette.accent}" stop-opacity="0.42"/>
      <stop offset="1" stop-color="${palette.accent}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowB" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(${width * 0.18} ${height * 0.76}) rotate(90) scale(${height * 0.22} ${width * 0.16})">
      <stop stop-color="#ffffff" stop-opacity="0.14"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <pattern id="scanline" patternUnits="userSpaceOnUse" width="8" height="8">
      <rect width="8" height="8" fill="transparent"/>
      <rect y="0" width="8" height="1" fill="${palette.grid}"/>
    </pattern>
    <pattern id="grid" width="42" height="42" patternUnits="userSpaceOnUse">
      <path d="M 42 0 L 0 0 0 42" fill="none" stroke="${palette.grid}" stroke-width="1"/>
    </pattern>
    <linearGradient id="holo" x1="0" y1="0" x2="${width}" y2="${height}" gradientUnits="userSpaceOnUse">
      <stop stop-color="#38bdf8" stop-opacity="0.24"/>
      <stop offset="0.35" stop-color="#22d3ee" stop-opacity="0.05"/>
      <stop offset="0.7" stop-color="#f472b6" stop-opacity="0.12"/>
      <stop offset="1" stop-color="#0ea5e9" stop-opacity="0.20"/>
    </linearGradient>
    <filter id="halo" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="12" />
    </filter>
    <filter id="sharpGlow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="4" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect width="${width}" height="${height}" rx="48" fill="url(#bg)" />
  <rect width="${width}" height="${height}" rx="48" fill="url(#glowA)" />
  <rect width="${width}" height="${height}" rx="48" fill="url(#glowB)" />
  <rect width="${width}" height="${height}" rx="48" fill="url(#holo)" />
  <rect width="${width}" height="${height}" rx="48" fill="url(#scanline)" />
  <rect width="${width}" height="${height}" rx="48" fill="url(#grid)" opacity="0.55" />
  <rect x="70" y="70" width="${width - 140}" height="${height - 140}" rx="36" stroke="${palette.border}" />
  <ellipse cx="${width * 0.78}" cy="${height * 0.24}" rx="${isTall ? 205 : 250}" ry="${isTall ? 112 : 130}" fill="none" stroke="${palette.accentSoft}" stroke-width="2.5" stroke-dasharray="16 14" filter="url(#halo)" />
  <ellipse cx="${width * 0.70}" cy="${height * 0.28}" rx="${isTall ? 280 : 330}" ry="${isTall ? 166 : 186}" fill="none" stroke="${palette.border}" stroke-width="1.5" stroke-dasharray="4 12" opacity="0.55" />
  <circle cx="${width * 0.80}" cy="${height * 0.21}" r="8" fill="${palette.accent}" filter="url(#sharpGlow)" />
  <circle cx="${width * 0.67}" cy="${height * 0.34}" r="5" fill="${palette.accent}" opacity="0.75" />
  <rect x="92" y="${heroCardY}" width="${width - 184}" height="${heroCardHeight}" rx="36" fill="${palette.surface}" stroke="${palette.border}" filter="url(#halo)" />
  <rect x="112" y="${heroCardY + 18}" width="${width - 224}" height="${heroCardHeight - 36}" rx="28" fill="${palette.surfaceStrong}" stroke="rgba(255,255,255,0.02)" />
  <text x="110" y="132" fill="${palette.accent}" font-size="26" font-family="${MONO_FONT_FAMILY}" letter-spacing="4">${escapeXml(copy.kicker)}</text>
  <text x="${width - 110}" y="132" fill="${palette.textMuted}" font-size="22" text-anchor="end" font-family="${MONO_FONT_FAMILY}">${escapeXml(formatRunStatusLabel(run.status))}</text>
  ${metadataSvg}
  <text x="110" y="${isTall ? 255 : 232}" fill="${palette.text}" font-size="${titleFontSize}" font-weight="700" font-family="${SANS_FONT_FAMILY}">${titleSvg}</text>
  <text x="110" y="${isTall ? 490 : 400}" fill="${palette.textMuted}" font-size="${subtitleFontSize}" font-family="${SANS_FONT_FAMILY}">${subtitleSvg}</text>
  <text x="110" y="${heroCardY + heroCardHeight - 34}" fill="${palette.textMuted}" font-size="22" font-family="${MONO_FONT_FAMILY}">SUMMARY / ${escapeXml(summaryLine)}</text>
  <text x="110" y="${height - (isTall ? 590 : 470)}" fill="${palette.text}" font-size="24" font-family="${MONO_FONT_FAMILY}">TOPIC / ${escapeXml(truncateText(run.topic, 44))}</text>
  <text x="${width - 110}" y="${heroCardY + heroCardHeight - 34}" fill="${palette.textMuted}" font-size="20" text-anchor="end" font-family="${MONO_FONT_FAMILY}">PROMPT / ${escapeXml(promptLabel)}</text>
  <path d="M 110 ${heroCardY + 56} L ${width - 110} ${heroCardY + 56}" stroke="${palette.border}" stroke-dasharray="8 12" />
  ${participantSvg}
  ${bulletSvg}
  <text x="110" y="${height - 120}" fill="${palette.textMuted}" font-size="23" font-family="${MONO_FONT_FAMILY}">${escapeXml(run.runId)}</text>
</svg>`;
}

export async function generateArenaPoster(
  repository: BackendRepository,
  input: ArenaPosterRequest,
  absoluteBaseUrl?: string,
): Promise<ArenaPosterResponse> {
  const run = await resolveArenaRun(repository, input);
  const stylePreset = resolvePosterStylePreset(input.stylePreset);
  const aspectRatio = resolvePosterAspectRatio(input.aspectRatio);
  const language = input.language ?? 'zh';
  const links = buildArenaLinks(run.runId);

  const cachedSkillPoster = await loadCachedSkillPosterAsset({
    run,
    stylePreset,
    aspectRatio,
    absoluteBaseUrl,
  });
  if (cachedSkillPoster) {
    return {
      runId: run.runId,
      links: {
        ...links,
        shareApiUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.shareApiPath}` : undefined,
        suggestedShareUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.suggestedSharePath}` : undefined,
      },
      poster: cachedSkillPoster,
    };
  }

  try {
    const poster = await generateArenaPosterWithSkill(run, stylePreset, aspectRatio, language, absoluteBaseUrl);
    const cachedPoster = await persistSkillPosterAsset({
      run,
      poster,
      absoluteBaseUrl,
    });
    return {
      runId: run.runId,
      links: {
        ...links,
        shareApiUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.shareApiPath}` : undefined,
        suggestedShareUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.suggestedSharePath}` : undefined,
      },
      poster: cachedPoster,
    };
  } catch (error) {
    console.warn('poster skill fallback:', error);
  }

  const { workspaceDir, sourceFilePath, promptFilePath, copyFilePath } = await preparePosterWorkspace(run);

  const promptPayload = buildPosterPrompt(run, stylePreset, aspectRatio, language);
  await fs.writeFile(promptFilePath, JSON.stringify(promptPayload, null, 2), 'utf8');

  const fallbackCopy = buildFallbackPosterCopy(run);
  let copy = fallbackCopy;
  try {
    const remoteCopy = await withTimeout(
      requestPosterCopyFromLlm(run, stylePreset, aspectRatio, language),
      POSTER_COPY_DEADLINE_MS,
      '海报文案超时，改用本地文案',
    );
    if (remoteCopy) {
      copy = remoteCopy;
    }
  } catch (error) {
    console.warn('poster llm fallback:', error);
  }
  copy = sanitizePosterCopy(copy, fallbackCopy);
  await fs.writeFile(copyFilePath, JSON.stringify(copy, null, 2), 'utf8');

  const editorialFallbackPoster = await generateEditorialFallbackPosterAsset({
    run,
    copy,
    stylePreset,
    aspectRatio,
    workspaceDir,
    promptPath: copyFilePath,
    absoluteBaseUrl,
  });
  if (editorialFallbackPoster) {
    return {
      runId: run.runId,
      links: {
        ...links,
        shareApiUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.shareApiPath}` : undefined,
        suggestedShareUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.suggestedSharePath}` : undefined,
      },
      poster: editorialFallbackPoster,
    };
  }

  const imagePath = path.join(workspaceDir, `arena-poster-${stylePreset}-${slugify(run.runId)}.svg`);
  await fs.writeFile(imagePath, renderPosterSvg(run, copy, stylePreset, aspectRatio), 'utf8');

  const poster = buildPosterAsset({
    runId: run.runId,
    title: copy.title,
    summary: copy.subtitle,
    stylePreset,
    aspectRatio,
    outputDir: workspaceDir,
    imagePath,
    promptPath: promptFilePath,
    sourcePath: sourceFilePath,
    generatedAt: new Date().toISOString(),
    absoluteBaseUrl,
  });

  return {
    runId: run.runId,
    links: {
      ...links,
      shareApiUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.shareApiPath}` : undefined,
      suggestedShareUrl: absoluteBaseUrl ? `${absoluteBaseUrl}${links.suggestedSharePath}` : undefined,
    },
    poster,
  };
}
