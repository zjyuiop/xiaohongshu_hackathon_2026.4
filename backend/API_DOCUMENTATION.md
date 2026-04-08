# Time Persona Backend API 文档

最后核对时间：2026-04-09  
代码基线：`backend/src/server.ts`、`backend/src/domain.ts`、`backend/src/schemas.ts`  
线上核对：`https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com`

这份文档以当前仓库实现为准，并补充了 2026-04-09 的线上实测结果。

## 1. 基本信息

### 1.1 Base URL

```txt
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com
```

### 1.2 协议与通用约定

- 普通接口返回 `application/json`
- SSE 接口 `/api/arena/stream` 返回 `text/event-stream; charset=utf-8`
- 所有 `POST` 请求默认使用：

```http
Content-Type: application/json
```

- 当前未做鉴权
- 已开启 CORS
- 编码统一为 UTF-8
- 后端会把生成产物通过 `/generated/*` 暴露为静态资源

### 1.3 当前线上运行时

2026-04-09 对线上 `/health` 的实测结果：

```json
{
  "ok": true,
  "runtime": {
    "mode": "claude-agent-sdk",
    "claudeBinary": "/home/ubuntu/hackhathon/backend/bin/claude-via-ccs.sh",
    "ccsProfile": "hackhathon-glm",
    "requestedModel": "glm-5",
    "requestedEffort": "xhigh",
    "fallbackModel": "glm-5",
    "fallbackEffort": "max",
    "unsupportedModels": []
  },
  "import": {
    "running": false,
    "lastImportedProfileIds": [],
    "documents": 6,
    "defaultProfiles": 6,
    "arenaRuns": 31,
    "libraryDir": "/home/ubuntu/library"
  }
}
```

### 1.4 前端接入必须知道的事实

- 默认人物链路：`GET /api/presets` -> `GET /api/profiles/:profileId`
- 自定义人物链路：`POST /api/timeline/parse` -> `POST /api/agents/build`
- `arena` 请求必须传完整 `agents[]`，不支持只传 `agentId[]`
- `selectedAgentIds` 只决定本次实际参会人格，范围是 2 到 3 个
- 分享/回放链路：`GET /api/arena/runs/:runId`
- 海报/信息图链路：`POST /api/arena/poster`
- 生成出来的 PNG / HTML / Markdown 资源，通常可通过返回的 `imageUrl` / `sourceUrl` / `promptUrl` 直接访问

### 1.5 多模型回退与超时策略

- 主运行时仍通过 Claude Code SDK 发起结构化调用
- 当主模型是 `gpt-5.4` 或 `codex` 系列，并且出现超时错误时，后端会自动切到 SiliconFlow Chat Completions
- 当前默认 SiliconFlow 回退顺序：
  - `Pro/moonshotai/Kimi-K2.5`
  - `Pro/MiniMaxAI/MiniMax-M2.5`
- arena 相关超时现已拆分为三层：
  - `ARENA_SPEAKER_TIMEOUT_MS`
  - `ARENA_SUMMARY_TIMEOUT_MS`
  - `ARENA_RUN_TIMEOUT_MS`
- 若整场讨论被中断或超时，服务端会尽量保存已生成的部分消息，并返回 `status: "interrupted"` 的结果，而不是一直悬挂

## 2. 接口总览

| 方法 | 路径 | 用途 |
|---|---|---|
| `GET` | `/health` | 健康检查、运行时信息、导入概览 |
| `GET` | `/api/presets` | 获取默认人物列表 |
| `GET` | `/api/profiles/:profileId` | 获取人物完整 bundle |
| `POST` | `/api/timeline/parse` | 从 biography 提取时间线 |
| `POST` | `/api/agents/build` | 从 timeline 生成阶段人格 |
| `POST` | `/api/arena/run` | 返回完整 arena 结果 |
| `POST` | `/api/arena/stream` | 以 SSE 返回 arena 过程 |
| `GET` | `/api/arena/history` | 获取最近讨论历史 |
| `GET` | `/api/arena/runs/:runId` | 获取已保存的 arena 结果 |
| `POST` | `/api/arena/sessions/:sessionId/interrupt` | 中断运行中的会话 |
| `POST` | `/api/arena/poster` | 生成信息图 / 海报资源 |
| `GET` | `/api/admin/import-status` | 查看默认人物导入状态 |
| `POST` | `/api/admin/import-defaults` | 触发默认人物重导入 |
| `GET` | `/generated/*` | 访问生成目录中的静态产物 |

## 3. 推荐调用流程

### 3.1 默认人物

1. 调 `GET /api/presets`
2. 用户选择人物后调 `GET /api/profiles/:profileId`
3. 用返回的 `profile + nodes + agents + sourceDocument` 渲染详情

### 3.2 自定义人物

1. 调 `POST /api/timeline/parse`
2. 拿到 `personId + nodes`
3. 调 `POST /api/agents/build`
4. 拿到 `agents`
5. 再进入 arena 链路

### 3.3 Arena 讨论 / 辩论

1. 选择 `2 ~ 3` 个阶段人格
2. 准备 `topic + mode + selectedAgentIds + agents`
3. 按需要补充 `reasoningEffort / roundCount / maxMessageChars / guidance`
4. 如果是连续会话，传 `continueFromRunId`，可选再传 `sessionId`
5. 如果需要实时 UI，走 `POST /api/arena/stream`
6. 如果只要最终结果，走 `POST /api/arena/run`
7. 结果保存后，可用 `GET /api/arena/runs/:runId` 回放
8. 如果要生成信息图，调 `POST /api/arena/poster`

## 4. 核心数据模型

### 4.1 `PresetProfile`

```ts
interface PresetProfile {
  id: string
  displayName: string
  subtitle: string
  category: 'self' | 'celebrity' | 'history' | 'fictional'
  coverSeed: string
  biography: string
  highlights: string[]
  suggestedTopics: string[]
}
```

### 4.2 `SourceEvidence`

```ts
interface SourceEvidence {
  quote: string
  sourceLabel: string
}
```

### 4.3 `TimelineNode`

```ts
interface TimelineNode {
  nodeId: string
  timeLabel: string
  ageLabel?: string
  stageLabel: string
  stageType: 'early' | 'turning-point' | 'stable' | 'crisis' | 'rebuild' | 'peak'
  keyEvent: string
  summary: string
  traits: string[]
  values: string[]
  tensions: string[]
  sourceEvidence: SourceEvidence[]
}
```

### 4.4 `PersonaSpec`

```ts
interface PersonaSpec {
  agentId: string
  displayName: string
  personId: string
  avatarSeed: string
  timeLabel: string
  stageLabel: string
  keyEvent: string
  knownFacts: string[]
  sourceEvidence: SourceEvidence[]
  traits: string[]
  values: string[]
  goal: string
  fear: string
  voiceStyle: string
  knowledgeBoundary: string
  forbiddenFutureKnowledge: boolean
  stanceSeed: string
}
```

### 4.5 `ProfileBundle`

```ts
interface ProfileBundle {
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
  sourceDocument?: SourceDocumentSummary | null
}
```

### 4.6 `SourceDocumentSummary`

```ts
interface SourceDocumentSummary {
  id: string
  title: string
  author?: string | null
  filePath: string
  importedAt: string
  sectionCount: number
}
```

### 4.7 `ArenaMessage`

```ts
interface ArenaMessage {
  id: string
  kind?: 'agent' | 'user'
  agentId: string
  displayName: string
  stageLabel: string
  content: string
  stance: 'support' | 'oppose' | 'reflective' | 'neutral'
  round?: number
  phase?: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
  replyToAgentId?: string
  replyToDisplayName?: string
}
```

说明：

- `guidance` 会在 transcript 前插入一条 `kind: 'user'` 的消息
- `replyTo*` 只有明确回复对象时才会出现

### 4.8 `ArenaSummary`

```ts
interface DebateJudgeScorecard {
  agentId: string
  displayName: string
  argumentScore: number
  evidenceScore: number
  responsivenessScore: number
  comments: string
}

interface DebateVerdict {
  winnerAgentId?: string
  winnerDisplayName?: string
  rationale: string
  scorecards: DebateJudgeScorecard[]
}

interface ArenaSummary {
  title: string
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
  moderatorNote?: string
  debateVerdict?: DebateVerdict
}
```

### 4.9 `ArenaRun`

```ts
interface ArenaRun {
  runId: string
  sessionId?: string
  continuedFromRunId?: string
  status?: 'completed' | 'interrupted'
  mode: 'chat' | 'debate'
  topic: string
  participants: PersonaSpec[]
  messages: ArenaMessage[]
  summary: ArenaSummary
  config?: {
    roundCount: number
    maxMessageChars: number
    reasoningEffort: 'low' | 'medium' | 'high' | 'xhigh'
  }
  createdAt?: string
}
```

### 4.10 `ArenaOutputLinks`

```ts
interface ArenaOutputLinks {
  runId: string
  shareApiPath: string
  shareApiUrl?: string
  suggestedSharePath: string
  suggestedShareUrl?: string
}
```

### 4.11 `ArenaPosterAsset`

```ts
interface ArenaPosterAsset {
  runId: string
  title: string
  summary: string
  stylePreset: 'poster' | 'editorial' | 'cinematic'
  aspectRatio: '16:9' | '2.35:1' | '4:3' | '3:2' | '1:1' | '3:4'
  outputDir: string
  imagePath: string
  imageUrl?: string
  promptPath?: string
  promptUrl?: string
  sourcePath?: string
  sourceUrl?: string
  generatedAt: string
}
```

## 5. 详细接口说明

## 5.1 `GET /health`

用途：

- 检查服务是否正常
- 检查数据库是否可连接
- 查看运行时模型配置
- 查看默认人物导入概况

请求：无

成功响应：

```json
{
  "ok": true,
  "runtime": {
    "mode": "claude-agent-sdk",
    "claudeBinary": "/home/ubuntu/hackhathon/backend/bin/claude-via-ccs.sh",
    "ccsProfile": "hackhathon-glm",
    "requestedModel": "glm-5",
    "requestedEffort": "xhigh",
    "fallbackModel": "glm-5",
    "fallbackEffort": "max",
    "unsupportedModels": []
  },
  "import": {
    "running": false,
    "lastImportedProfileIds": [],
    "documents": 6,
    "defaultProfiles": 6,
    "arenaRuns": 31,
    "libraryDir": "/home/ubuntu/library"
  },
  "timestamp": "2026-04-08T16:49:37.417Z"
}
```

失败响应：

```json
{
  "ok": false,
  "error": "具体错误信息",
  "runtime": {
    "mode": "claude-agent-sdk"
  },
  "timestamp": "2026-04-08T16:49:37.417Z"
}
```

## 5.2 `GET /api/presets`

用途：获取默认人物列表。

请求：无

响应结构：

```ts
{
  presets: PresetProfile[]
}
```

示例：

```json
{
  "presets": [
    {
      "id": "warren-buffett",
      "displayName": "沃伦·巴菲特",
      "subtitle": "基于传记抽取的关键人生阶段",
      "category": "celebrity",
      "coverSeed": "warren-buffett",
      "biography": "沃伦·巴菲特 的传记被拆分为多个关键人生阶段，用于生成跨时空对话人格。",
      "highlights": ["不作逢迎", "珠穆朗玛峰"],
      "suggestedTopics": ["他在不同阶段最看重什么？"]
    }
  ]
}
```

## 5.3 `GET /api/profiles/:profileId`

用途：获取人物完整 bundle。

Path 参数：

- `profileId: string`

成功响应：

```ts
ProfileBundle
```

404：

```json
{
  "error": "profile not found"
}
```

联调建议：

- 默认人物通常会有 `sourceDocument`
- 自定义人物通常没有 `sourceDocument`
- 前端应把 `sourceDocument` 按可选字段处理

## 5.4 `POST /api/timeline/parse`

用途：从 `displayName + biography` 提取时间线节点。

请求体：

```ts
interface ParseTimelineRequest {
  profileId?: string
  displayName: string
  biography: string
}
```

约束：

- `displayName` 至少 1 个字符
- `biography` 至少 10 个字符

成功响应：

```ts
interface ParseTimelineResponse {
  personId: string
  displayName: string
  nodes: TimelineNode[]
}
```

示例请求：

```json
{
  "displayName": "测试人物API文档样例",
  "biography": "大学阶段长期想证明自己，毕业后进入大厂高速推进项目。一次重大失败后开始反思控制欲和关系问题，后来选择重建节奏，重新定义工作与生活的边界。"
}
```

400 校验错误示例：

```json
{
  "error": {
    "formErrors": [],
    "fieldErrors": {
      "biography": [
        "Too small: expected string to have >=10 characters"
      ]
    }
  }
}
```

说明：

- `personId` 应被视为 opaque string，不要在前端猜它的生成规则
- `parse` 完成后不要直接进入 arena，必须再调用 `POST /api/agents/build`

## 5.5 `POST /api/agents/build`

用途：根据 timeline nodes 生成阶段人格。

请求体：

```ts
interface BuildAgentsRequest {
  personId: string
  displayName: string
  biography?: string
  nodes: TimelineNode[]
}
```

约束：

- `personId` 必填
- `displayName` 必填
- `nodes` 至少 1 个
- `biography` 可选，但传了就至少 10 个字符

成功响应：

```ts
{
  agents: PersonaSpec[]
}
```

说明：

- 如果同一 `personId + nodes` 已经生成过 agents，服务端可能直接复用已有结果

## 5.6 `POST /api/arena/run`

用途：同步返回一次完整 arena 结果。

请求体：

```ts
interface ArenaRunRequest {
  topic: string
  mode: 'chat' | 'debate'
  selectedAgentIds: string[]
  agents: PersonaSpec[]
  reasoningEffort?: 'low' | 'medium' | 'high' | 'xhigh'
  roundCount?: number
  maxMessageChars?: number
  guidance?: string
  continueFromRunId?: string
  sessionId?: string
}
```

字段约束：

- `topic`: 必填
- `mode`: `chat | debate`
- `selectedAgentIds`: `2 ~ 3`
- `agents`: 至少 2 个
- `roundCount`: `1 ~ 20`
- `maxMessageChars`: `60 ~ 500`
- `guidance`: trim 后 `1 ~ 1000`

重要语义：

- `agents` 是完整候选人格集合
- `selectedAgentIds` 决定本次真正参会的人
- 若按 `selectedAgentIds` 过滤后少于 2 人，服务端会报错
- 若传 `continueFromRunId`，新 transcript 会继承上一条对话
- 若未显式传 `sessionId`，服务端会尽量沿用会话链上的 `sessionId`

成功响应：

```ts
{
  result: ArenaRun
  links?: ArenaOutputLinks
}
```

行为特征：

- `chat` 的典型阶段：`opening -> reflection -> synthesis`
- `debate` 的典型阶段：`opening -> rebuttal -> closing`
- `guidance` 会转成一条 `kind: 'user'` 的消息写入结果
- 结果会持久化到数据库，可再通过 `GET /api/arena/runs/:runId` 拉取

## 5.7 `POST /api/arena/stream`

用途：以 SSE 返回 arena 过程，适合实时 UI。

请求体：与 `/api/arena/run` 完全一致。

响应头：

```http
Content-Type: text/event-stream; charset=utf-8
Cache-Control: no-cache, no-transform
Connection: keep-alive
X-Accel-Buffering: no
```

事件类型：

```ts
type ArenaStreamEventType =
  | 'run_started'
  | 'phase_started'
  | 'speaker_started'
  | 'speaker_delta'
  | 'speaker_completed'
  | 'message'
  | 'phase_completed'
  | 'summary_started'
  | 'summary_delta'
  | 'summary'
  | 'done'
  | 'error'
```

公共字段：

```ts
{
  type: string
  runId: string
  mode: 'chat' | 'debate'
  topic: string
  sequence: number
  timestamp: string
}
```

关键事件结构：

`run_started`

```ts
{
  type: 'run_started'
  reasoningEffort: 'low' | 'medium' | 'high' | 'xhigh'
  config: {
    roundCount: number
    maxMessageChars: number
    reasoningEffort: 'low' | 'medium' | 'high' | 'xhigh'
  }
  sessionId: string
  continuedFromRunId?: string
  participants: PersonaSpec[]
  plannedRounds: Array<{ round: number; phase: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing' }>
}
```

`speaker_started`

```ts
{
  type: 'speaker_started'
  round: number
  phase: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
  messageId: string
  participant: {
    agentId: string
    displayName: string
    stageLabel: string
  }
  replyTarget?: {
    agentId: string
    displayName: string
  }
}
```

`speaker_delta`

```ts
{
  type: 'speaker_delta'
  round: number
  phase: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
  messageId: string
  agentId: string
  displayName: string
  channel: 'text' | 'thinking'
  delta: string
  accumulatedText: string
}
```

`message`

```ts
{
  type: 'message'
  round: number
  phase: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
  message: ArenaMessage
}
```

`summary_delta`

```ts
{
  type: 'summary_delta'
  channel: 'text' | 'thinking'
  delta: string
  accumulatedText: string
}
```

`done`

```ts
{
  type: 'done'
  result: ArenaRun
  links?: ArenaOutputLinks
}
```

`error`

```ts
{
  type: 'error'
  error: string
  round?: number
  phase?: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
}
```

典型顺序：

1. `run_started`
2. `phase_started`
3. `speaker_started`
4. 多个 `speaker_delta`
5. `message`
6. `speaker_completed`
7. `phase_completed`
8. 下一个 phase 重复
9. `summary_started`
10. 多个 `summary_delta`
11. `summary`
12. `done`

心跳：

```txt
: ping
```

说明：

- 前端应忽略心跳
- 只有收到 `done`，才表示本次流式成功结束
- 业务失败时会发 `error` 事件
- 如果连接 EOF，但没有收到 `done` 或 `error`，前端应把它当作异常断流处理，不要继续显示“讨论中”

## 5.8 `GET /api/arena/history`

用途：获取最近的讨论历史列表。

Query 参数：

- `limit?: number`

说明：

- 默认值是 `20`
- 服务端最终会限制在 `1 ~ 100`

成功响应：

```ts
{
  runs: ArenaRunHistoryItem[]
}
```

返回特征：

- 按 `createdAt` 倒序
- 只返回摘要字段，不返回完整消息
- `latestGuidance` 取最近一条 `kind === 'user'` 的消息内容

## 5.9 `GET /api/arena/runs/:runId`

用途：根据 `runId` 获取已保存的 arena 结果，适合分享页和回放页。

成功响应：

```ts
{
  result: ArenaRun
  links: ArenaOutputLinks
}
```

404：

```json
{
  "error": "arena run not found"
}
```

## 5.10 `POST /api/arena/sessions/:sessionId/interrupt`

用途：中断当前内存中的运行会话。

Path 参数：

- `sessionId: string`

成功响应：

```json
{
  "ok": true,
  "sessionId": "session-xxx"
}
```

404：

```json
{
  "error": "未找到正在运行的会话: session-xxx"
}
```

说明：

- 这个接口只影响当前进程内的运行状态
- 会话结束后或服务重启后，这个 sessionId 就不会再存在

## 5.11 `POST /api/arena/poster`

用途：为某次讨论结果生成信息图 / 海报资源。

请求体：

```ts
interface ArenaPosterRequest {
  runId?: string
  run?: ArenaRun
  stylePreset?: 'poster' | 'editorial' | 'cinematic'
  aspectRatio?: '16:9' | '2.35:1' | '4:3' | '3:2' | '1:1' | '3:4'
  language?: string
}
```

约束：

- `runId` 和 `run` 至少提供一个
- `stylePreset` 只能是 `poster | editorial | cinematic`
- `aspectRatio` 只能是 `16:9 | 2.35:1 | 4:3 | 3:2 | 1:1 | 3:4`
- `language` 长度范围是 `2 ~ 12`

生成策略：

- 优先走 Claude Code Skill 链路
- 当前默认 skill 是 `editorial-card-screenshot`
- 典型成功产物是：
  - 1 个 Markdown 源文件
  - 1 个 HTML 信息卡
  - 1 个 PNG 截图
- 如果 skill 主链路失败，后端会回退到本地 SVG 方案

2026-04-09 起新增的恢复逻辑：

- 如果 Claude Code 在返回最终 schema 前失败，但工作目录里已经生成了 HTML 或 PNG，后端会优先恢复这些真实产物
- 如果只有 HTML、还没有 PNG，后端会尝试再次调用 skill 自带截图脚本补出 PNG
- 只有在真实产物也无法恢复时，才会继续回退到本地 SVG

成功响应：

```ts
{
  runId: string
  links: ArenaOutputLinks
  poster: ArenaPosterAsset
}
```

典型返回字段：

```json
{
  "runId": "run-xxx",
  "links": {
    "runId": "run-xxx",
    "shareApiPath": "/api/arena/runs/run-xxx",
    "shareApiUrl": "https://your-domain/api/arena/runs/run-xxx",
    "suggestedSharePath": "/share/run-xxx",
    "suggestedShareUrl": "https://your-domain/share/run-xxx"
  },
  "poster": {
    "runId": "run-xxx",
    "title": "把 AI 建议权锁进可审计的人类责任链",
    "summary": "AI 可以参与高风险决策辅助，但不能脱离人工签字、过程留痕与责任归属。",
    "stylePreset": "editorial",
    "aspectRatio": "3:4",
    "outputDir": "/abs/path/to/generated/arena-posters/xxx",
    "imagePath": "/abs/path/to/generated/arena-posters/xxx/deliverables/editorial-card.png",
    "imageUrl": "https://your-domain/generated/arena-posters/xxx/deliverables/editorial-card.png",
    "promptPath": "/abs/path/to/generated/arena-posters/xxx/source-xxx.md",
    "promptUrl": "https://your-domain/generated/arena-posters/xxx/source-xxx.md",
    "sourcePath": "/abs/path/to/generated/arena-posters/xxx/deliverables/editorial-card.html",
    "sourceUrl": "https://your-domain/generated/arena-posters/xxx/deliverables/editorial-card.html",
    "generatedAt": "2026-04-08T16:29:49.421Z"
  }
}
```

联调建议：

- 前端展示优先使用 `imageUrl`
- 调试时可保留 `sourceUrl` 和 `promptUrl`
- 如果返回的是 SVG fallback，`imagePath` / `imageUrl` 仍然会指向最终可访问资源

## 5.12 `GET /api/admin/import-status`

用途：查看默认人物导入状态。

成功响应：

```ts
{
  state: {
    running: boolean
    lastRunAt?: string
    lastError?: string
    lastImportedProfileIds: string[]
  }
  overview: {
    documents: number
    defaultProfiles: number
    arenaRuns: number
    libraryDir: string
    lastImportedProfileIds?: string[]
  }
}
```

## 5.13 `POST /api/admin/import-defaults`

用途：触发默认人物重导入。

请求：无

成功响应：与 `/api/admin/import-status` 同结构。

说明：

- 这是管理接口，不建议直接暴露给普通用户态页面

## 5.14 `GET /generated/*`

用途：访问后端生成目录中的静态产物。

来源：

- 服务端使用 `app.use('/generated', express.static(config.generatedDir))`
- 因此任何位于 `backend/generated/` 下的文件，都可能被映射到 `/generated/*`

典型资源：

- 信息图 PNG
- 信息图 HTML
- 海报 prompt markdown
- SVG fallback 海报

示例：

```txt
/generated/arena-posters/<workspace>/deliverables/editorial-card.png
/generated/arena-posters/<workspace>/deliverables/editorial-card.html
/generated/arena-posters/<workspace>/source-xxx.md
```

## 6. 错误响应约定

### 6.1 400 参数校验失败

当前统一使用 Zod `flatten()` 结构：

```json
{
  "error": {
    "formErrors": [],
    "fieldErrors": {
      "biography": [
        "Too small: expected string to have >=10 characters"
      ]
    }
  }
}
```

### 6.2 404 资源不存在

```json
{
  "error": "profile not found"
}
```

或：

```json
{
  "error": "arena run not found"
}
```

### 6.3 500 服务错误

```json
{
  "error": "具体错误信息"
}
```

## 7. 前端联调建议

- `GET /api/presets` 只做列表页，不要强绑详情请求
- arena 页面本地应缓存 `agents[]`，因为 `POST /api/arena/run` 和 `POST /api/arena/stream` 都需要完整传入
- SSE 场景下，前端至少要处理：
  - `message`
  - `summary`
  - `done`
  - `error`
- 如果要做“谁正在说话”的实时效果，再接：
  - `speaker_started`
  - `speaker_delta`
  - `speaker_completed`
- 分享页和信息图页不要直接依赖内存态，应始终能通过 `runId` 回读
- 海报资源渲染优先用 `imageUrl`，调试时再展示 `sourceUrl`

## 8. 可直接使用的 cURL 示例

### 8.1 健康检查

```bash
curl -sS https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/health
```

### 8.2 拉取默认人物

```bash
curl -sS https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/presets
```

### 8.3 拉取最近历史

```bash
curl -sS 'https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/arena/history?limit=10'
```

### 8.4 生成信息图

```bash
curl -sS \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{
    "runId": "run-xxx",
    "stylePreset": "editorial",
    "aspectRatio": "3:4",
    "language": "zh-CN"
  }' \
  https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/arena/poster
```
