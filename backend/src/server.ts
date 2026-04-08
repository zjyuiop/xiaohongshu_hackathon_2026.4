import 'dotenv/config';

import cors from 'cors';
import express from 'express';

import { getConfig } from './config.js';
import type { ArenaRunRequest, BuildAgentsRequest, ParseTimelineRequest } from './domain.js';
import { BackendRepository } from './repository.js';
import { arenaRunRequestSchema, buildAgentsRequestSchema, parseTimelineRequestSchema } from './schemas.js';
import { runArena } from './services/arena.js';
import { DefaultLibraryImporter } from './services/importer.js';
import { buildAgents } from './services/persona.js';
import { describeRuntime } from './services/runtime.js';
import { parseTimeline } from './services/timeline.js';

const config = getConfig();
const repository = new BackendRepository(config.databaseUrl);
const importer = new DefaultLibraryImporter(repository);

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

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

app.post('/api/arena/run', async (request, response) => {
  const parsed = arenaRunRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await runArena(repository, parsed.data as ArenaRunRequest);
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
