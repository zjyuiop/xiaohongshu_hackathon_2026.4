import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import type { Request, Response } from 'express';

import { getConfig } from './config.js';
import type {
  ArenaOutputLinks,
  ArenaPosterRequest,
  ArenaRunRequest,
  ArenaStreamEvent,
  BuildAgentsRequest,
  MergeAgentsRequest,
  ParseTimelineRequest,
} from './domain.js';
import { BackendRepository } from './repository.js';
import {
  arenaPosterRequestSchema,
  arenaRunRequestSchema,
  buildAgentsRequestSchema,
  mergeAgentsRequestSchema,
  parseTimelineRequestSchema,
} from './schemas.js';
import { runArena } from './services/arena.js';
import { DefaultLibraryImporter } from './services/importer.js';
import { buildAgents, mergeAgents } from './services/persona.js';
import { generateArenaPoster } from './services/poster.js';
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

const activeArenaSessions = new Map<string, AbortController>();

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

    const controller = activeArenaSessions.get(sessionId);
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

app.post('/api/arena/stream', async (request: Request, response: Response) => {
  const parsed = arenaRunRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  const sessionId = parsed.data.sessionId?.trim() || `session-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const sessionController = new AbortController();
  activeArenaSessions.set(sessionId, sessionController);

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
    await runArena(
      repository,
      {
        ...(parsed.data as ArenaRunRequest),
        sessionId,
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
    activeArenaSessions.delete(sessionId);
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
