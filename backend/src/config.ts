import path from 'node:path';
import { fileURLToPath } from 'node:url';

import type { AgentRuntimeMode, ClaudeCliEffort, ReasoningEffort } from './domain.js';

export interface AppConfig {
  port: number;
  backendRoot: string;
  projectRoot: string;
  databaseUrl: string;
  agentRuntime: AgentRuntimeMode;
  targetModel: string;
  reasoningEffort: ReasoningEffort;
  fallbackModel: string;
  fallbackEffort: ClaudeCliEffort;
  claudeBinary: string;
  ccsProfile?: string;
  defaultLibraryDir: string;
  importOnBoot: boolean;
  maxImportSections: number;
  publicBaseUrl?: string;
  generatedDir: string;
  posterSkillsRepoUrl: string;
  posterModel?: string;
  posterBaseUrl?: string;
  posterApiKey?: string;
  posterRequestTimeoutMs: number;
  posterRequestRetryCount: number;
  posterImageModel?: string;
  posterImageBaseUrl?: string;
  posterImageApiKey?: string;
  posterImageTimeoutMs: number;
  siliconFlowBaseUrl: string;
  siliconFlowApiKey?: string;
  siliconFlowFallbackModels: string[];
  siliconFlowRequestTimeoutMs: number;
  profileImportUploadDir: string;
  profileImportMaxFileSizeBytes: number;
  profileImportMaxSourceChars: number;
  arenaSpeakerTimeoutMs: number;
  arenaSummaryTimeoutMs: number;
  arenaRunTimeoutMs: number;
}

function parseBoolean(input: string | undefined, fallback: boolean): boolean {
  if (input === undefined) {
    return fallback;
  }

  return ['1', 'true', 'yes', 'on'].includes(input.toLowerCase());
}

function parseNumber(input: string | undefined, fallback: number): number {
  const parsed = Number(input);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseInteger(input: string | undefined, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(input ?? '', 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(max, Math.max(min, parsed));
}

function parseStringList(input: string | undefined, fallback: string[]): string[] {
  if (!input?.trim()) {
    return fallback;
  }

  const result = input
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  return result.length > 0 ? result : fallback;
}

function shouldMigrateLegacyTargetModel(input: string, siliconFlowApiKey: string | undefined): boolean {
  if (!siliconFlowApiKey) {
    return false;
  }

  return /(gpt-5\.4|codex)/i.test(input.trim());
}

export function mapEffortToClaude(effort: ReasoningEffort): ClaudeCliEffort {
  if (effort === 'xhigh') {
    return 'max';
  }

  return effort;
}

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(moduleDir, '..');
const projectRoot = path.resolve(backendRoot, '..');

export function getConfig(): AppConfig {
  const ccsProfile = process.env.CCS_PROFILE?.trim() || undefined;
  const defaultClaudeBinary = ccsProfile
    ? path.resolve(backendRoot, 'bin/claude-via-ccs.sh')
    : path.resolve(backendRoot, 'node_modules/.bin/claude');
  const siliconFlowApiKey = process.env.SILICONFLOW_API_KEY?.trim() || undefined;
  const siliconFlowFallbackModels = parseStringList(process.env.SILICONFLOW_FALLBACK_MODELS, [
    'Pro/MiniMaxAI/MiniMax-M2.5',
    'Pro/moonshotai/Kimi-K2.5',
  ]);
  const requestedTargetModel = process.env.TARGET_MODEL?.trim() || 'Pro/MiniMaxAI/MiniMax-M2.5';
  const targetModel = shouldMigrateLegacyTargetModel(requestedTargetModel, siliconFlowApiKey)
    ? siliconFlowFallbackModels[0] ?? requestedTargetModel
    : requestedTargetModel;

  return {
    port: parseNumber(process.env.PORT, 3030),
    backendRoot,
    projectRoot,
    databaseUrl: process.env.DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54329/time_persona',
    agentRuntime: 'claude-agent-sdk',
    targetModel,
    reasoningEffort: (process.env.REASONING_EFFORT as ReasoningEffort | undefined) ?? 'xhigh',
    fallbackModel: process.env.FALLBACK_MODEL ?? 'claude-opus-4-6',
    fallbackEffort: (process.env.FALLBACK_EFFORT as ClaudeCliEffort | undefined) ?? 'max',
    claudeBinary: process.env.CLAUDE_CODE_BIN ?? defaultClaudeBinary,
    ccsProfile,
    defaultLibraryDir: process.env.DEFAULT_LIBRARY_DIR ?? '/Users/mychanging/Desktop/知识库收集',
    importOnBoot: parseBoolean(process.env.IMPORT_ON_BOOT, true),
    maxImportSections: parseNumber(process.env.MAX_IMPORT_SECTIONS, 8),
    publicBaseUrl: process.env.PUBLIC_BASE_URL?.replace(/\/+$/, '') || undefined,
    generatedDir: process.env.GENERATED_DIR ?? path.resolve(backendRoot, 'generated'),
    posterSkillsRepoUrl:
      process.env.POSTER_SKILLS_REPO_URL ??
      process.env.BAOYU_SKILLS_REPO_URL ??
      'https://github.com/shaom/infocard-skills.git',
    posterModel: process.env.POSTER_LLM_MODEL,
    posterBaseUrl: process.env.POSTER_LLM_BASE_URL?.replace(/\/+$/, '') || undefined,
    posterApiKey: process.env.POSTER_LLM_API_KEY,
    posterRequestTimeoutMs: parseInteger(process.env.POSTER_LLM_TIMEOUT_MS, 20000, 2000, 120000),
    posterRequestRetryCount: parseInteger(process.env.POSTER_LLM_RETRY_COUNT, 1, 0, 3),
    posterImageModel: process.env.POSTER_IMAGE_MODEL?.trim() || 'gemini-3-pro-image-preview',
    posterImageBaseUrl:
      process.env.POSTER_IMAGE_BASE_URL?.replace(/\/+$/, '') ||
      process.env.GEMINI_BASE_URL?.replace(/\/+$/, '') ||
      'https://generativelanguage.googleapis.com/v1beta',
    posterImageApiKey:
      process.env.POSTER_IMAGE_API_KEY?.trim() ||
      process.env.GEMINI_API_KEY?.trim() ||
      process.env.GOOGLE_API_KEY?.trim() ||
      undefined,
    posterImageTimeoutMs: parseInteger(process.env.POSTER_IMAGE_TIMEOUT_MS, 120000, 5000, 300000),
    siliconFlowBaseUrl: process.env.SILICONFLOW_BASE_URL?.replace(/\/+$/, '') || 'https://api.siliconflow.cn/v1',
    siliconFlowApiKey,
    siliconFlowFallbackModels,
    siliconFlowRequestTimeoutMs: parseInteger(process.env.SILICONFLOW_TIMEOUT_MS, 90000, 5000, 300000),
    profileImportUploadDir: process.env.PROFILE_IMPORT_UPLOAD_DIR ?? path.resolve(backendRoot, 'generated', 'uploaded-imports'),
    profileImportMaxFileSizeBytes: parseInteger(process.env.PROFILE_IMPORT_MAX_FILE_SIZE_MB, 15, 1, 100) * 1024 * 1024,
    profileImportMaxSourceChars: parseInteger(process.env.PROFILE_IMPORT_MAX_SOURCE_CHARS, 40000, 2000, 200000),
    arenaSpeakerTimeoutMs: parseInteger(process.env.ARENA_SPEAKER_TIMEOUT_MS, 90000, 10000, 300000),
    arenaSummaryTimeoutMs: parseInteger(process.env.ARENA_SUMMARY_TIMEOUT_MS, 120000, 10000, 300000),
    arenaRunTimeoutMs: parseInteger(process.env.ARENA_RUN_TIMEOUT_MS, 480000, 60000, 1800000),
  };
}
