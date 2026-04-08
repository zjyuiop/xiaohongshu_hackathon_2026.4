import path from 'node:path';
import { fileURLToPath } from 'node:url';

import type { AgentRuntimeMode, ClaudeCliEffort, ReasoningEffort } from './domain.js';

export interface AppConfig {
  port: number;
  backendRoot: string;
  databaseUrl: string;
  agentRuntime: AgentRuntimeMode;
  targetModel: string;
  reasoningEffort: ReasoningEffort;
  fallbackModel: string;
  fallbackEffort: ClaudeCliEffort;
  claudeBinary: string;
  defaultLibraryDir: string;
  importOnBoot: boolean;
  maxImportSections: number;
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

export function mapEffortToClaude(effort: ReasoningEffort): ClaudeCliEffort {
  if (effort === 'xhigh') {
    return 'max';
  }

  return effort;
}

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(moduleDir, '..');

export function getConfig(): AppConfig {
  return {
    port: parseNumber(process.env.PORT, 3030),
    backendRoot,
    databaseUrl: process.env.DATABASE_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54329/time_persona',
    agentRuntime: 'claude-code-sdk',
    targetModel: process.env.TARGET_MODEL ?? 'gpt-5.4',
    reasoningEffort: (process.env.REASONING_EFFORT as ReasoningEffort | undefined) ?? 'xhigh',
    fallbackModel: process.env.FALLBACK_MODEL ?? 'claude-opus-4-6',
    fallbackEffort: (process.env.FALLBACK_EFFORT as ClaudeCliEffort | undefined) ?? 'max',
    claudeBinary: process.env.CLAUDE_CODE_BIN ?? path.resolve(backendRoot, 'node_modules/.bin/claude'),
    defaultLibraryDir: process.env.DEFAULT_LIBRARY_DIR ?? '/Users/mychanging/Desktop/知识库收集',
    importOnBoot: parseBoolean(process.env.IMPORT_ON_BOOT, true),
    maxImportSections: parseNumber(process.env.MAX_IMPORT_SECTIONS, 8),
  };
}
