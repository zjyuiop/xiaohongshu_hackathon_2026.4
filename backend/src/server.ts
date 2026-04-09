import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import type { NextFunction, Request, Response } from 'express';
import multer from 'multer';

import { getConfig } from './config.js';
import type {
  ArenaOutputLinks,
  ArenaPosterRequest,
  ArenaRunRequest,
  ArenaStreamEvent,
  BuildAgentsRequest,
  MergeAgentsRequest,
  ParseTimelineRequest,
  ProfileImportRequest,
} from './domain.js';
import { BackendRepository } from './repository.js';
import {
  arenaPosterRequestSchema,
  arenaRunRequestSchema,
  arenaSessionMessageRequestSchema,
  buildAgentsRequestSchema,
  mergeAgentsRequestSchema,
  parseTimelineRequestSchema,
  profileImportRequestSchema,
} from './schemas.js';
import { runArena } from './services/arena.js';
import { DefaultLibraryImporter } from './services/importer.js';
import { buildAgents, mergeAgents } from './services/persona.js';
import { generateArenaPoster } from './services/poster.js';
import { importProfileFromUpload } from './services/profile-import.js';
import { describeRuntime } from './services/runtime.js';
import { parseTimeline } from './services/timeline.js';

const config = getConfig();
const repository = new BackendRepository(config.databaseUrl);
const importer = new DefaultLibraryImporter(repository);

const app = express();
app.set('trust proxy', true);
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use('/generated', express.static(config.generatedDir));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: config.profileImportMaxFileSizeBytes,
  },
});

interface ActiveArenaSessionState {
  sessionId: string;
  controller?: AbortController;
  queuedMessages: Array<{
    id?: string;
    content: string;
    createdAt?: string;
  }>;
  lastTouchedAt: number;
}

const arenaSessions = new Map<string, ActiveArenaSessionState>();

function getArenaSessionState(sessionId: string): ActiveArenaSessionState {
  const existing = arenaSessions.get(sessionId);
  if (existing) {
    existing.lastTouchedAt = Date.now();
    return existing;
  }

  const created: ActiveArenaSessionState = {
    sessionId,
    queuedMessages: [],
    lastTouchedAt: Date.now(),
  };
  arenaSessions.set(sessionId, created);
  return created;
}

function releaseArenaSessionState(sessionId: string): void {
  const session = arenaSessions.get(sessionId);
  if (!session) {
    return;
  }

  if (session.controller || session.queuedMessages.length > 0) {
    session.lastTouchedAt = Date.now();
    return;
  }

  arenaSessions.delete(sessionId);
}

function resolveAbsoluteBaseUrl(request: Request): string {
  if (config.publicBaseUrl) {
    return config.publicBaseUrl;
  }

  return `${request.protocol}://${request.get('host')}`;
}

function attachAbsoluteLinks(links: ArenaOutputLinks | undefined, request: Request): ArenaOutputLinks | undefined {
  if (!links) {
    return undefined;
  }

  const baseUrl = resolveAbsoluteBaseUrl(request);
  return {
    ...links,
    shareApiUrl: `${baseUrl}${links.shareApiPath}`,
    suggestedShareUrl: `${baseUrl}${links.suggestedSharePath}`,
  };
}

function writeSseEvent(response: Response, event: ArenaStreamEvent): void {
  response.write(`event: ${event.type}\n`);
  response.write(`data: ${JSON.stringify(event)}\n\n`);
}

function startSse(response: Response): void {
  response.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  response.setHeader('Cache-Control', 'no-cache, no-transform');
  response.setHeader('Connection', 'keep-alive');
  response.setHeader('X-Accel-Buffering', 'no');
  response.flushHeaders();
}

app.get('/health', async (_request, response) => {
  try {
    await repository.ping();
    const overview = await importer.getOverview();
    response.json({
      ok: true,
      runtime: describeRuntime(),
      import: {
        ...importer.getState(),
        ...overview,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    response.status(500).json({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      runtime: describeRuntime(),
      timestamp: new Date().toISOString(),
    });
  }
});

app.get('/api/presets', async (_request, response) => {
  try {
    response.json({
      presets: await repository.listDefaultPresets(),
    });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.get('/api/profiles/:profileId', async (request, response) => {
  try {
    const bundle = await repository.getProfileBundle(request.params.profileId);
    if (!bundle) {
      response.status(404).json({ error: 'profile not found' });
      return;
    }
    response.json(bundle);
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.get('/api/arena/runs/:runId', async (request, response) => {
  try {
    const run = await repository.getArenaRun(request.params.runId);
    if (!run) {
      response.status(404).json({ error: 'arena run not found' });
      return;
    }

    response.json({
      result: run,
      links: attachAbsoluteLinks(
        {
          runId: run.runId,
          shareApiPath: `/api/arena/runs/${encodeURIComponent(run.runId)}`,
          suggestedSharePath: `/share/${encodeURIComponent(run.runId)}`,
        },
        request,
      ),
    });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.get('/api/arena/history', async (request, response) => {
  try {
    const limit = Number(request.query.limit ?? 20);
    response.json({
      runs: await repository.listArenaRunHistory(limit),
    });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/timeline/parse', async (request, response) => {
  const parsed = parseTimelineRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await parseTimeline(repository, parsed.data as ParseTimelineRequest);
    response.json(result);
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/agents/build', async (request, response) => {
  const parsed = buildAgentsRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await buildAgents(repository, parsed.data as BuildAgentsRequest);
    response.json(result);
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/profile-imports', upload.single('file'), async (request, response) => {
  const parsed = profileImportRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  if (!request.file) {
    response.status(400).json({ error: '缺少上传文件字段 file' });
    return;
  }

  try {
    const result = await importProfileFromUpload(repository, parsed.data as ProfileImportRequest, request.file);
    response.json(result);
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/agents/merge', async (request, response) => {
  const parsed = mergeAgentsRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await mergeAgents(parsed.data as MergeAgentsRequest);
    response.json(result);
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/arena/run', async (request, response) => {
  const parsed = arenaRunRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await runArena(repository, parsed.data as ArenaRunRequest);
    response.json({
      ...result,
      links: attachAbsoluteLinks(result.links, request),
    });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/arena/sessions/:sessionId/interrupt', async (request, response) => {
  try {
    const sessionId = request.params.sessionId?.trim();
    if (!sessionId) {
      response.status(400).json({ error: '缺少 sessionId' });
      return;
    }

    const session = arenaSessions.get(sessionId);
    const controller = session?.controller;
    if (!controller) {
      response.status(404).json({ error: `未找到正在运行的会话: ${sessionId}` });
      return;
    }

    if (!controller.signal.aborted) {
      controller.abort(new Error('用户手动中断讨论'));
    }

    response.json({ ok: true, sessionId });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/arena/sessions/:sessionId/messages', async (request, response) => {
  const parsed = arenaSessionMessageRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const sessionId = request.params.sessionId?.trim();
    if (!sessionId) {
      response.status(400).json({ error: '缺少 sessionId' });
      return;
    }

    const session = getArenaSessionState(sessionId);
    session.queuedMessages.push({
      id: parsed.data.clientMessageId,
      content: parsed.data.content.trim(),
      createdAt: parsed.data.createdAt,
    });

    if (session.controller && !session.controller.signal.aborted) {
      session.controller.abort(new Error('用户插入了新的消息'));
    }

    response.json({
      ok: true,
      sessionId,
      queuedMessages: session.queuedMessages.length,
    });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/arena/stream', async (request: Request, response: Response) => {
  const parsed = arenaRunRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  const sessionId = parsed.data.sessionId?.trim() || `session-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const session = getArenaSessionState(sessionId);
  const sessionController = new AbortController();
  session.controller = sessionController;

  startSse(response);

  let closed = false;
  let terminalEventSent = false;
  const heartbeat = setInterval(() => {
    if (!closed) {
      response.write(': ping\n\n');
    }
  }, 15000);

  const markClosed = () => {
    if (closed) {
      return;
    }

    closed = true;
    clearInterval(heartbeat);
  };

  request.on('aborted', () => {
    sessionController.abort(new Error('客户端已断开连接'));
    markClosed();
  });
  response.on('close', () => {
    if (!terminalEventSent) {
      sessionController.abort(new Error('流式连接已关闭'));
    }
    markClosed();
  });

  try {
    const queuedMessages = session.queuedMessages.splice(0);
    await runArena(
      repository,
      {
        ...(parsed.data as ArenaRunRequest),
        sessionId,
        pendingUserMessages: [
          ...queuedMessages,
          ...((parsed.data as ArenaRunRequest).pendingUserMessages ?? []),
        ],
      },
      {
        signal: sessionController.signal,
        onEvent: async (event) => {
          if (!closed) {
            const outgoingEvent =
              event.type === 'done'
                ? {
                    ...event,
                    links: attachAbsoluteLinks(event.links, request),
                  }
                : event;
          if (event.type === 'error' || event.type === 'done') {
            terminalEventSent = true;
          }
          writeSseEvent(response, outgoingEvent);
        }
        },
      },
    );
  } catch (error) {
    if (!closed && !terminalEventSent) {
      terminalEventSent = true;
      writeSseEvent(response, {
        type: 'error',
        runId: `run-error-${Date.now()}`,
        mode: parsed.data.mode,
        topic: parsed.data.topic,
        sequence: -1,
        timestamp: new Date().toISOString(),
        error: error instanceof Error ? error.message : String(error),
      });
    }
  } finally {
    clearInterval(heartbeat);
    if (session.controller === sessionController) {
      session.controller = undefined;
    }
    releaseArenaSessionState(sessionId);
    if (!closed) {
      response.end();
    }
  }
});

app.post('/api/arena/poster', async (request, response) => {
  const parsed = arenaPosterRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await generateArenaPoster(
      repository,
      parsed.data as ArenaPosterRequest,
      resolveAbsoluteBaseUrl(request),
    );
    response.json(result);
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.post('/api/admin/import-defaults', async (_request, response) => {
  try {
    const result = await importer.importDefaults(true);
    const overview = await importer.getOverview();
    response.json({ state: result, overview });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.get('/api/admin/import-status', async (_request, response) => {
  try {
    response.json({
      state: importer.getState(),
      overview: await importer.getOverview(),
    });
  } catch (error) {
    response.status(500).json({ error: error instanceof Error ? error.message : String(error) });
  }
});

app.use((error: unknown, _request: Request, response: Response, _next: NextFunction) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      response.status(400).json({
        error: `上传文件过大，当前上限为 ${Math.floor(config.profileImportMaxFileSizeBytes / 1024 / 1024)}MB`,
      });
      return;
    }

    response.status(400).json({ error: error.message });
    return;
  }

  if (error instanceof Error) {
    response.status(500).json({ error: error.message });
    return;
  }

  response.status(500).json({ error: 'unknown server error' });
});

async function bootstrap(): Promise<void> {
  await repository.init();

  app.listen(config.port, () => {
    console.log(`time-persona backend listening on http://localhost:${config.port}`);
  });

  if (config.importOnBoot) {
    void importer.importDefaults().catch((error) => {
      console.error('default import failed', error);
    });
  }
}

bootstrap().catch((error) => {
  console.error('backend bootstrap failed', error);
  process.exitCode = 1;
});
