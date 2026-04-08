import crypto from 'node:crypto';

import postgres, { type JSONValue, type Sql } from 'postgres';

import type {
  ArenaRun,
  ClaudeExecutionInfo,
  PersonaSpec,
  PresetProfile,
  ProfileBundle,
  ProfileCategory,
  SourceDocumentSummary,
  SourceSection,
  TimelineNode,
} from './domain.js';

function toIsoString(value: unknown): string {
  if (value instanceof Date) {
    return value.toISOString();
  }

  return new Date(String(value)).toISOString();
}

function ensureStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map((item) => String(item)) : [];
}

function ensureObjectArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function asJson(value: unknown): JSONValue {
  return JSON.parse(JSON.stringify(value)) as JSONValue;
}

interface ProfileRow {
  id: string;
  display_name: string;
  subtitle: string;
  category: ProfileCategory;
  cover_seed: string;
  biography: string;
  highlights: unknown;
  suggested_topics: unknown;
  source_document_id: string | null;
  origin: string;
  is_default: boolean;
  raw_input: string | null;
  metadata: Record<string, unknown>;
  created_at: Date | string;
  updated_at: Date | string;
}

interface TimelineNodeRow {
  id: string;
  profile_id: string;
  ordinal: number;
  time_label: string;
  age_label: string | null;
  stage_label: string;
  stage_type: TimelineNode['stageType'];
  key_event: string;
  summary: string;
  traits: unknown;
  values: unknown;
  tensions: unknown;
  source_evidence: unknown;
}

interface PersonaRow {
  id: string;
  profile_id: string;
  node_id: string;
  display_name: string;
  avatar_seed: string;
  time_label: string;
  stage_label: string;
  key_event: string;
  known_facts: unknown;
  source_evidence: unknown;
  traits: unknown;
  values: unknown;
  goal: string;
  fear: string;
  voice_style: string;
  knowledge_boundary: string;
  forbidden_future_knowledge: boolean;
  stance_seed: string;
}

interface SourceDocumentRow {
  id: string;
  title: string;
  author: string | null;
  file_path: string;
  imported_at: Date | string;
  section_count: number;
}

export interface SourceDocumentInput {
  title: string;
  author?: string;
  filePath: string;
  fileHash: string;
  sourceType: 'epub' | 'text';
  metadata: Record<string, unknown>;
  sections: SourceSection[];
}

export interface ProfileBundleInput {
  id: string;
  displayName: string;
  subtitle: string;
  category: ProfileCategory;
  coverSeed: string;
  biography: string;
  highlights: string[];
  suggestedTopics: string[];
  sourceDocumentId?: string | null;
  origin: 'default-import' | 'manual';
  isDefault: boolean;
  rawInput?: string;
  metadata?: Record<string, unknown>;
  nodes: TimelineNode[];
  agents?: PersonaSpec[];
  personaModelInfo?: ClaudeExecutionInfo;
}

export class BackendRepository {
  private readonly sql: Sql;

  constructor(databaseUrl: string) {
    this.sql = postgres(databaseUrl, {
      max: 5,
      idle_timeout: 20,
      connect_timeout: 20,
    });
  }

  async close(): Promise<void> {
    await this.sql.end({ timeout: 5 });
  }

  async ping(): Promise<void> {
    await this.sql`select 1`;
  }

  async init(): Promise<void> {
    await this.sql.unsafe(`
      create table if not exists source_documents (
        id uuid primary key,
        slug text not null,
        source_type text not null,
        title text not null,
        author text,
        file_path text not null,
        file_hash text not null unique,
        metadata jsonb not null default '{}'::jsonb,
        imported_at timestamptz not null default now()
      );

      create table if not exists source_sections (
        id uuid primary key,
        document_id uuid not null references source_documents(id) on delete cascade,
        ordinal integer not null,
        title text not null,
        href text,
        raw_text text not null,
        excerpt text not null
      );

      create unique index if not exists source_sections_document_ordinal_idx
        on source_sections(document_id, ordinal);

      create table if not exists profiles (
        id text primary key,
        display_name text not null,
        subtitle text not null,
        category text not null,
        cover_seed text not null,
        biography text not null,
        highlights jsonb not null,
        suggested_topics jsonb not null,
        source_document_id uuid references source_documents(id) on delete set null,
        origin text not null,
        is_default boolean not null default false,
        raw_input text,
        metadata jsonb not null default '{}'::jsonb,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      );

      create index if not exists profiles_source_document_idx on profiles(source_document_id);

      create table if not exists timeline_nodes (
        id text primary key,
        profile_id text not null references profiles(id) on delete cascade,
        ordinal integer not null,
        time_label text not null,
        age_label text,
        stage_label text not null,
        stage_type text not null,
        key_event text not null,
        summary text not null,
        traits jsonb not null,
        values jsonb not null,
        tensions jsonb not null,
        source_evidence jsonb not null
      );

      create unique index if not exists timeline_nodes_profile_ordinal_idx
        on timeline_nodes(profile_id, ordinal);

      create table if not exists persona_specs (
        id text primary key,
        profile_id text not null references profiles(id) on delete cascade,
        node_id text not null references timeline_nodes(id) on delete cascade,
        display_name text not null,
        avatar_seed text not null,
        time_label text not null,
        stage_label text not null,
        key_event text not null,
        known_facts jsonb not null,
        source_evidence jsonb not null,
        traits jsonb not null,
        values jsonb not null,
        goal text not null,
        fear text not null,
        voice_style text not null,
        knowledge_boundary text not null,
        forbidden_future_knowledge boolean not null default true,
        stance_seed text not null,
        prompt_context text not null default '',
        requested_model text,
        effective_model text,
        created_at timestamptz not null default now()
      );

      create unique index if not exists persona_specs_profile_node_idx
        on persona_specs(profile_id, node_id);

      create table if not exists arena_runs (
        id text primary key,
        topic text not null,
        mode text not null,
        participant_ids jsonb not null,
        participants jsonb not null,
        messages jsonb not null,
        summary jsonb not null,
        metadata jsonb not null default '{}'::jsonb,
        created_at timestamptz not null default now()
      );
    `);
  }

  async upsertSourceDocument(input: SourceDocumentInput): Promise<string> {
    const slug = input.title
      .toLowerCase()
      .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 80);

    return this.sql.begin(async (tx) => {
      const documentId = crypto.randomUUID();
      const rows = await tx<{ id: string }[]>`
        insert into source_documents (
          id, slug, source_type, title, author, file_path, file_hash, metadata
        ) values (
          ${documentId},
          ${slug},
          ${input.sourceType},
          ${input.title},
          ${input.author ?? null},
          ${input.filePath},
          ${input.fileHash},
          ${tx.json(asJson(input.metadata))}
        )
        on conflict (file_hash) do update set
          slug = excluded.slug,
          source_type = excluded.source_type,
          title = excluded.title,
          author = excluded.author,
          file_path = excluded.file_path,
          metadata = excluded.metadata,
          imported_at = now()
        returning id
      `;
      const persistedId = rows[0].id;

      await tx`delete from source_sections where document_id = ${persistedId}`;
      for (const section of input.sections) {
        await tx`
          insert into source_sections (
            id, document_id, ordinal, title, href, raw_text, excerpt
          ) values (
            ${crypto.randomUUID()},
            ${persistedId},
            ${section.ordinal},
            ${section.title},
            ${section.href ?? null},
            ${section.rawText},
            ${section.excerpt}
          )
        `;
      }

      return persistedId;
    });
  }

  async findSourceDocumentIdByHash(fileHash: string): Promise<string | null> {
    const rows = await this.sql<{ id: string }[]>`
      select id
      from source_documents
      where file_hash = ${fileHash}
      limit 1
    `;

    return rows[0]?.id ?? null;
  }

  async getProfileIdBySourceDocument(documentId: string): Promise<string | null> {
    const rows = await this.sql<{ id: string }[]>`
      select id
      from profiles
      where source_document_id = ${documentId}
      order by updated_at desc
      limit 1
    `;

    return rows[0]?.id ?? null;
  }

  async upsertProfileBundle(input: ProfileBundleInput): Promise<void> {
    await this.sql.begin(async (tx) => {
      await tx`
        insert into profiles (
          id, display_name, subtitle, category, cover_seed, biography,
          highlights, suggested_topics, source_document_id, origin, is_default,
          raw_input, metadata, updated_at
        ) values (
          ${input.id},
          ${input.displayName},
          ${input.subtitle},
          ${input.category},
          ${input.coverSeed},
          ${input.biography},
          ${tx.json(input.highlights)},
          ${tx.json(input.suggestedTopics)},
          ${input.sourceDocumentId ?? null},
          ${input.origin},
          ${input.isDefault},
          ${input.rawInput ?? null},
          ${tx.json(asJson(input.metadata ?? {}))},
          now()
        )
        on conflict (id) do update set
          display_name = excluded.display_name,
          subtitle = excluded.subtitle,
          category = excluded.category,
          cover_seed = excluded.cover_seed,
          biography = excluded.biography,
          highlights = excluded.highlights,
          suggested_topics = excluded.suggested_topics,
          source_document_id = excluded.source_document_id,
          origin = excluded.origin,
          is_default = excluded.is_default,
          raw_input = excluded.raw_input,
          metadata = excluded.metadata,
          updated_at = now()
      `;

      await tx`delete from persona_specs where profile_id = ${input.id}`;
      await tx`delete from timeline_nodes where profile_id = ${input.id}`;

      for (const [index, node] of input.nodes.entries()) {
        await tx`
          insert into timeline_nodes (
            id, profile_id, ordinal, time_label, age_label, stage_label, stage_type,
            key_event, summary, traits, values, tensions, source_evidence
          ) values (
            ${node.nodeId},
            ${input.id},
            ${index + 1},
            ${node.timeLabel},
            ${node.ageLabel ?? null},
            ${node.stageLabel},
            ${node.stageType},
            ${node.keyEvent},
            ${node.summary},
            ${tx.json(asJson(node.traits))},
            ${tx.json(asJson(node.values))},
            ${tx.json(asJson(node.tensions))},
            ${tx.json(asJson(node.sourceEvidence))}
          )
        `;
      }

      if (input.agents) {
        for (const agent of input.agents) {
          await tx`
            insert into persona_specs (
              id, profile_id, node_id, display_name, avatar_seed, time_label, stage_label,
              key_event, known_facts, source_evidence, traits, values, goal, fear,
              voice_style, knowledge_boundary, forbidden_future_knowledge, stance_seed,
              prompt_context, requested_model, effective_model
            ) values (
              ${agent.agentId},
              ${input.id},
              ${agent.agentId.replace(/-agent$/, '')},
              ${agent.displayName},
              ${agent.avatarSeed},
              ${agent.timeLabel},
              ${agent.stageLabel},
              ${agent.keyEvent},
              ${tx.json(asJson(agent.knownFacts))},
              ${tx.json(asJson(agent.sourceEvidence))},
              ${tx.json(asJson(agent.traits))},
              ${tx.json(asJson(agent.values))},
              ${agent.goal},
              ${agent.fear},
              ${agent.voiceStyle},
              ${agent.knowledgeBoundary},
              ${agent.forbiddenFutureKnowledge},
              ${agent.stanceSeed},
              ${JSON.stringify({
                goal: agent.goal,
                fear: agent.fear,
                voiceStyle: agent.voiceStyle,
                stanceSeed: agent.stanceSeed,
              })},
              ${input.personaModelInfo?.requestedModel ?? null},
              ${input.personaModelInfo?.effectiveModel ?? null}
            )
          `;
        }
      }
    });
  }

  async savePersonas(profileId: string, agents: PersonaSpec[], modelInfo?: ClaudeExecutionInfo): Promise<void> {
    await this.sql.begin(async (tx) => {
      await tx`delete from persona_specs where profile_id = ${profileId}`;

      for (const agent of agents) {
        await tx`
          insert into persona_specs (
            id, profile_id, node_id, display_name, avatar_seed, time_label, stage_label,
            key_event, known_facts, source_evidence, traits, values, goal, fear,
            voice_style, knowledge_boundary, forbidden_future_knowledge, stance_seed,
            prompt_context, requested_model, effective_model
          ) values (
            ${agent.agentId},
            ${profileId},
            ${agent.agentId.replace(/-agent$/, '')},
            ${agent.displayName},
            ${agent.avatarSeed},
            ${agent.timeLabel},
            ${agent.stageLabel},
            ${agent.keyEvent},
            ${tx.json(asJson(agent.knownFacts))},
            ${tx.json(asJson(agent.sourceEvidence))},
            ${tx.json(asJson(agent.traits))},
            ${tx.json(asJson(agent.values))},
            ${agent.goal},
            ${agent.fear},
            ${agent.voiceStyle},
            ${agent.knowledgeBoundary},
            ${agent.forbiddenFutureKnowledge},
            ${agent.stanceSeed},
            ${JSON.stringify({
              goal: agent.goal,
              fear: agent.fear,
              voiceStyle: agent.voiceStyle,
              stanceSeed: agent.stanceSeed,
            })},
            ${modelInfo?.requestedModel ?? null},
            ${modelInfo?.effectiveModel ?? null}
          )
        `;
      }
    });
  }

  async listDefaultPresets(): Promise<PresetProfile[]> {
    const rows = await this.sql<ProfileRow[]>`
      select *
      from profiles
      where is_default = true
      order by updated_at desc, display_name asc
    `;

    return rows.map((row) => this.mapProfileRow(row));
  }

  async getProfileBundle(profileId: string): Promise<ProfileBundle | null> {
    const profileRows = await this.sql<ProfileRow[]>`
      select *
      from profiles
      where id = ${profileId}
      limit 1
    `;

    const profileRow = profileRows[0];
    if (!profileRow) {
      return null;
    }

    const nodeRows = await this.sql<TimelineNodeRow[]>`
      select *
      from timeline_nodes
      where profile_id = ${profileId}
      order by ordinal asc
    `;
    const personaRows = await this.sql<PersonaRow[]>`
      select *
      from persona_specs
      where profile_id = ${profileId}
      order by node_id asc
    `;

    let sourceDocument: SourceDocumentSummary | null = null;
    if (profileRow.source_document_id) {
      const sourceRows = await this.sql<SourceDocumentRow[]>`
        select
          d.id,
          d.title,
          d.author,
          d.file_path,
          d.imported_at,
          coalesce(count(s.id), 0)::int as section_count
        from source_documents d
        left join source_sections s on s.document_id = d.id
        where d.id = ${profileRow.source_document_id}
        group by d.id
      `;
      if (sourceRows[0]) {
        sourceDocument = {
          id: sourceRows[0].id,
          title: sourceRows[0].title,
          author: sourceRows[0].author,
          filePath: sourceRows[0].file_path,
          importedAt: toIsoString(sourceRows[0].imported_at),
          sectionCount: sourceRows[0].section_count,
        };
      }
    }

    return {
      profile: this.mapProfileRow(profileRow),
      nodes: nodeRows.map((row) => this.mapNodeRow(row)),
      agents: personaRows.map((row) => this.mapPersonaRow(row)),
      sourceDocument,
    };
  }

  async getPersonasForProfile(profileId: string): Promise<PersonaSpec[]> {
    const rows = await this.sql<PersonaRow[]>`
      select *
      from persona_specs
      where profile_id = ${profileId}
      order by node_id asc
    `;

    return rows.map((row) => this.mapPersonaRow(row));
  }

  async saveArenaRun(run: ArenaRun, executions: ClaudeExecutionInfo[]): Promise<void> {
    await this.sql`
      insert into arena_runs (
        id, topic, mode, participant_ids, participants, messages, summary, metadata
      ) values (
        ${run.runId},
        ${run.topic},
        ${run.mode},
        ${this.sql.json(asJson(run.participants.map((item) => item.agentId)))},
        ${this.sql.json(asJson(run.participants))},
        ${this.sql.json(asJson(run.messages))},
        ${this.sql.json(asJson(run.summary))},
        ${this.sql.json(asJson({ executions }))}
      )
      on conflict (id) do update set
        topic = excluded.topic,
        mode = excluded.mode,
        participant_ids = excluded.participant_ids,
        participants = excluded.participants,
        messages = excluded.messages,
        summary = excluded.summary,
        metadata = excluded.metadata
    `;
  }

  async getOverview(libraryDir: string): Promise<{ documents: number; defaultProfiles: number; arenaRuns: number }> {
    const [documents] = await this.sql<{ count: string }[]>`select count(*)::text as count from source_documents`;
    const [defaultProfiles] = await this.sql<{ count: string }[]>`select count(*)::text as count from profiles where is_default = true`;
    const [arenaRuns] = await this.sql<{ count: string }[]>`select count(*)::text as count from arena_runs`;

    return {
      documents: Number(documents?.count ?? '0'),
      defaultProfiles: Number(defaultProfiles?.count ?? '0'),
      arenaRuns: Number(arenaRuns?.count ?? '0'),
    };
  }

  private mapProfileRow(row: ProfileRow): PresetProfile {
    return {
      id: row.id,
      displayName: row.display_name,
      subtitle: row.subtitle,
      category: row.category,
      coverSeed: row.cover_seed,
      biography: row.biography,
      highlights: ensureStringArray(row.highlights),
      suggestedTopics: ensureStringArray(row.suggested_topics),
    };
  }

  private mapNodeRow(row: TimelineNodeRow): TimelineNode {
    return {
      nodeId: row.id,
      timeLabel: row.time_label,
      ageLabel: row.age_label ?? undefined,
      stageLabel: row.stage_label,
      stageType: row.stage_type,
      keyEvent: row.key_event,
      summary: row.summary,
      traits: ensureStringArray(row.traits),
      values: ensureStringArray(row.values),
      tensions: ensureStringArray(row.tensions),
      sourceEvidence: ensureObjectArray(row.source_evidence),
    };
  }

  private mapPersonaRow(row: PersonaRow): PersonaSpec {
    return {
      agentId: row.id,
      displayName: row.display_name,
      personId: row.profile_id,
      avatarSeed: row.avatar_seed,
      timeLabel: row.time_label,
      stageLabel: row.stage_label,
      keyEvent: row.key_event,
      knownFacts: ensureStringArray(row.known_facts),
      sourceEvidence: ensureObjectArray(row.source_evidence),
      traits: ensureStringArray(row.traits),
      values: ensureStringArray(row.values),
      goal: row.goal,
      fear: row.fear,
      voiceStyle: row.voice_style,
      knowledgeBoundary: row.knowledge_boundary,
      forbiddenFutureKnowledge: row.forbidden_future_knowledge,
      stanceSeed: row.stance_seed,
    };
  }
}
