# 鸿蒙端后端 API 接入文档（服务器直连版）

最后核对时间：2026-04-09  
适用仓库：`/Users/mychanging/Desktop/hackhathon`  
文档目标：基于当前后端真实实现，以及原 Web 前端的真实调用逻辑，输出一份面向鸿蒙 ArkTS/ETS 的详细接入说明。

重要约束：

- 鸿蒙端必须直接访问服务器后端。
- 不使用 `localhost`、`127.0.0.1`、`10.0.2.2`、局域网 IP。
- 文档中的接口地址均以线上服务器为准，而不是本地开发机。

## 1. 代码基线

本文档以以下代码为准：

- 后端入口：`backend/src/server.ts`
- 后端类型：`backend/src/domain.ts`
- 后端校验：`backend/src/schemas.ts`
- 时间线生成：`backend/src/services/timeline.ts`
- 人格生成/融合：`backend/src/services/persona.ts`
- Arena 讨论：`backend/src/services/arena.ts`
- 海报生成：`backend/src/services/poster.ts`
- 持久化：`backend/src/repository.ts`
- 原 Web API 封装：`d/src/lib/api.ts`
- 原 Web 页面逻辑：`d/src/pages/ArenaStudio.tsx`
- 鸿蒙现有 API 封装：`harmony/entry/src/main/ets/service/PersonaApi.ets`
- 鸿蒙现有数据模型：`harmony/entry/src/main/ets/common/Models.ets`
- 鸿蒙首页逻辑：`harmony/entry/src/main/ets/pages/Index.ets`
- 鸿蒙 Arena 页逻辑：`harmony/entry/src/main/ets/pages/Arena.ets`

## 2. 文档结论先看

当前鸿蒙端已经接上了 4 条核心链路：

1. `GET /api/presets`
2. `GET /api/profiles/:profileId`
3. `POST /api/timeline/parse` + `POST /api/agents/build`
4. `POST /api/arena/run`

但如果要达到 Web 端当前能力，鸿蒙还缺以下能力：

1. `POST /api/agents/merge`
2. `POST /api/arena/stream` 流式会话
3. `POST /api/arena/sessions/:sessionId/interrupt` 中断会话
4. `GET /api/arena/history` 历史记录
5. `GET /api/arena/runs/:runId` 历史回放/续聊载入
6. `POST /api/arena/poster` 海报/信息图生成
7. `ArenaRun.links`、`sessionId`、`status`、`continuedFromRunId`、`config`、`createdAt` 等字段
8. SSE 事件模型
9. `debateVerdict`、`moderatorNote`、`replyTo*`、`round`、`phase` 等增强字段

如果只是“能跑通”，现状足够。  
如果目标是“鸿蒙和 Web 行为一致”，则必须按本文第 11 节的改造清单补齐。

## 3. 服务基础信息

### 3.1 当前基准地址

鸿蒙现有代码写死为：

```ts
const SERVER_BASE_URL = 'https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com'
```

位置：`harmony/entry/src/main/ets/service/PersonaApi.ets`

线上基准地址：

```txt
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com
```

鸿蒙端所有接口都必须在此域名下访问，例如：

```txt
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/presets
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/profiles/:profileId
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/arena/run
```

Web 端则使用：

```ts
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''
```

位置：`d/src/lib/api.ts`

### 3.1.1 禁止使用的地址

以下地址在当前鸿蒙接入中都不应再出现：

- `http://localhost:3030`
- `http://127.0.0.1:3030`
- `http://10.0.2.2:3030`
- 任意开发机局域网 IP，如 `http://192.168.x.x:3030`

原因：

- 鸿蒙真机和模拟器并不和当前开发机天然同域。
- 当前后端已经部署在线上服务器。
- 统一使用服务器地址，才能保证鸿蒙端、Web 端和公网测试行为一致。

### 3.1.2 当前联通性验证

2026-04-09 已实测：

```txt
HEAD https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/presets
=> HTTP 200
```

这说明当前服务器后端可以被直接访问，鸿蒙端应以此为唯一入口。

### 3.2 通用协议约定

- 普通接口：`application/json`
- 流式接口：`text/event-stream; charset=utf-8`
- `POST` 默认 `Content-Type: application/json`
- 当前无鉴权
- 后端已启用 CORS
- `/generated/*` 为静态资源目录

### 3.4 Harmony 侧推荐写法

建议继续在 `PersonaApi.ets` 中只保留一个固定服务器地址：

```ts
const SERVER_BASE_URL: string = 'https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com'
const API_BASE_URLS: string[] = [SERVER_BASE_URL]
```

推荐规则：

- `GET /api/...` 与 `POST /api/...` 一律拼接到 `SERVER_BASE_URL`
- 图片、海报、信息图资源一律使用后端返回的 `imageUrl`
- 不要在鸿蒙端自行把 `/generated/...` 再拼成本地地址
- 如果未来域名变更，只改 `SERVER_BASE_URL` 一处

### 3.3 通用错误格式

后端失败时常见返回：

```json
{
  "error": "profile not found"
}
```

或者 Zod 校验错误：

```json
{
  "error": {
    "formErrors": [],
    "fieldErrors": {
      "topic": ["String must contain at least 1 character(s)"]
    }
  }
}
```

鸿蒙现有 `parseErrorMessage()` 已经兼容这两种模式，这部分方向是对的。

## 4. 后端真实业务模型

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

说明：

- 这是人物卡片层级的数据。
- `GET /api/presets` 只返回这个级别。
- `GET /api/profiles/:profileId` 返回的 `profile` 也是这个结构。

### 4.2 `TimelineNode`

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
  sourceEvidence: Array<{
    quote: string
    sourceLabel: string
  }>
}
```

说明：

- 这是“人生阶段时间线”的核心结构。
- `parseTimeline` 的产出核心就是 `nodes`。
- `buildAgents` 的输入也依赖 `nodes`。

### 4.3 `PersonaSpec`

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

说明：

- 这是真正参会的“阶段人格体”。
- `selectedAgentIds` 只是引用；真正开会时仍要把 `agents` 全量传给后端。
- `agentId` 规则通常是 `${nodeId}-agent`。

### 4.4 `ProfileBundle`

```ts
interface ProfileBundle {
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
  sourceDocument?: SourceDocumentSummary | null
}
```

说明：

- 这是默认人物详情页和时间线页最关键的数据包。
- Web 和鸿蒙都把它当作“选中人物后的完整快照”。

### 4.5 `ArenaRun`

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

说明：

- 这是 Arena 的持久化实体。
- 历史记录、回放、续聊、海报都围绕它展开。
- 鸿蒙当前 `Models.ets` 里这个类型明显不完整，必须补齐。

### 4.6 `ArenaMessage`

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

- Web 已使用 `kind / round / phase / replyTo*`。
- 鸿蒙当前模型只保留了最简字段，会丢失上下文信息。
- 如果要做消息气泡、轮次标记、追问引用、人工 guidance 展示，必须补齐。

### 4.7 `ArenaSummary`

```ts
interface ArenaSummary {
  title: string
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
  moderatorNote?: string
  debateVerdict?: {
    winnerAgentId?: string
    winnerDisplayName?: string
    rationale: string
    scorecards: Array<{
      agentId: string
      displayName: string
      argumentScore: number
      evidenceScore: number
      responsivenessScore: number
      comments: string
    }>
  }
}
```

说明：

- `chat` 模式重点使用 `moderatorNote`
- `debate` 模式重点使用 `debateVerdict`
- 鸿蒙当前只保留了基础摘要字段，没有裁判结果和主持人备注

## 5. 后端接口总览

| 方法 | 路径 | 用途 | 鸿蒙现状 |
|---|---|---|---|
| `GET` | `/health` | 健康检查 | 未接 |
| `GET` | `/api/presets` | 取默认人物列表 | 已接 |
| `GET` | `/api/profiles/:profileId` | 取人物完整 bundle | 已接 |
| `POST` | `/api/timeline/parse` | 传 biography 生成时间线 | 已接 |
| `POST` | `/api/agents/build` | 基于 timeline 生成阶段人格 | 已接 |
| `POST` | `/api/agents/merge` | 融合两个人格 | 未接 |
| `POST` | `/api/arena/run` | 一次性返回讨论结果 | 已接 |
| `POST` | `/api/arena/stream` | SSE 流式返回讨论过程 | 未接 |
| `POST` | `/api/arena/sessions/:sessionId/interrupt` | 中断正在进行的会话 | 未接 |
| `GET` | `/api/arena/history` | 最近讨论历史 | 未接 |
| `GET` | `/api/arena/runs/:runId` | 讨论结果回放 | 未接 |
| `POST` | `/api/arena/poster` | 生成信息图海报 | 未接 |
| `GET` | `/api/admin/import-status` | 默认资料导入状态 | 未接 |
| `POST` | `/api/admin/import-defaults` | 触发默认资料重导入 | 未接 |

## 6. 推荐的鸿蒙接入流程

### 6.1 默认人物流程

后端/前端顺序：

1. `GET /api/presets`
2. 用户点击人物
3. `GET /api/profiles/:profileId`
4. 本地缓存 `ProfileBundle`
5. 渲染时间线、人格列表、推荐议题

鸿蒙当前实现：

- `Index.ets` 启动后调 `PersonaApi.getPresets()`
- 选中人物后调 `PersonaApi.getProfileBundle(profile.id)`
- 会把 bundle 缓存在 `cachedBundles`

这一段和 Web 逻辑高度一致，属于当前最完整的链路。

### 6.2 自定义人物导入流程

后端/前端顺序：

1. 用户输入 `displayName + biography`
2. `POST /api/timeline/parse`
3. 拿到 `personId + displayName + nodes`
4. `POST /api/agents/build`
5. 拿到 `agents`
6. 尝试 `GET /api/profiles/:personId`
7. 如果服务端有落库后的 bundle，则用服务端 bundle
8. 否则前端自行拼 fallback bundle

鸿蒙当前 `PersonaApi.importCustomProfile()` 就是按这套逻辑写的，这一点和 Web 相比反而更稳。

### 6.3 Arena 讨论流程

Web 当前真实流程不是直接 `run`，而是优先走流式：

1. 选择 2 到 3 个人格
2. 设置 `topic`
3. 选择 `mode = chat | debate`
4. 可选设置 `roundCount`
5. 可选设置 `maxMessageChars`
6. 可选设置 `guidance`
7. `POST /api/arena/stream`
8. 前端实时消费 SSE 事件
9. 收到 `done` 事件后拿到完整 `result + links`
10. 讨论完成后再允许海报、分享、续聊

鸿蒙当前真实流程：

1. 选择人格
2. 输入 `topic`
3. `POST /api/arena/run`
4. 一次性拿到最终结果

这意味着鸿蒙目前没有以下体验：

- 实时打字流
- 轮次进度
- speaker started/completed 状态
- 中断
- 接入人工 guidance 后继续讨论
- 历史 run 的载入与再继续

## 7. 逐接口说明

## 7.1 `GET /api/presets`

### 作用

获取默认人物列表。

### 响应

```json
{
  "presets": [
    {
      "id": "steve-jobs",
      "displayName": "Steve Jobs",
      "subtitle": "...",
      "category": "history",
      "coverSeed": "steve-jobs",
      "biography": "...",
      "highlights": ["..."],
      "suggestedTopics": ["..."]
    }
  ]
}
```

### 鸿蒙映射

建议继续保留：

```ts
static async getPresets(): Promise<PresetProfile[]>
```

### UI 用途

- 首页角色列表
- 角色首页预热缓存

## 7.2 `GET /api/profiles/:profileId`

### 作用

获取人物完整 bundle。

### 响应

```json
{
  "profile": { "...": "PresetProfile" },
  "nodes": [{ "...": "TimelineNode" }],
  "agents": [{ "...": "PersonaSpec" }],
  "sourceDocument": {
    "id": "uuid",
    "title": "书名或来源文档名",
    "author": "作者",
    "filePath": "/path/to/source",
    "importedAt": "2026-04-09T00:00:00.000Z",
    "sectionCount": 12
  }
}
```

### 说明

- `404` 代表 profile 不存在
- 默认人物详情页、时间线页、阶段人格选择器都依赖这个接口
- 如果未来鸿蒙要做“来源证据页”，`sourceDocument` 很关键

## 7.3 `POST /api/timeline/parse`

### 作用

从 biography 中提炼时间线阶段。

### 请求

```json
{
  "displayName": "张三",
  "biography": "至少 10 个字以上的人物背景描述",
  "profileId": "optional-profile-id"
}
```

### 请求约束

- `displayName` 必填
- `biography` 至少 10 字符
- `profileId` 可选

### 响应

```json
{
  "personId": "zhang-san",
  "displayName": "张三",
  "nodes": [{ "...": "TimelineNode" }]
}
```

### 后端行为细节

- 若传了 `profileId` 且数据库已有该人物，则直接返回已存时间线
- 若没有，就走 LLM 生成
- 若 LLM 失败，退回启发式时间线生成
- 最终会把 profile 和 timeline 落库

### 鸿蒙接入建议

- 当前 `ParseTimelineRequest` 可保留
- 返回结构也已对齐
- 但要把 `personId` 当成服务端真实主键，不要继续自己二次造一套 `custom-${Date.now()}`

原因：

- Web 旧逻辑里导入后仍然会额外造一个 `custom-*` 的 UI id
- 这会导致 profileId 和数据库主键脱钩
- 鸿蒙当前 `importCustomProfile()` 已经比 Web 更合理，优先使用服务端 `personId`

## 7.4 `POST /api/agents/build`

### 作用

根据时间线节点生成阶段人格体。

### 请求

```json
{
  "personId": "zhang-san",
  "displayName": "张三",
  "biography": "可选，建议传原文",
  "nodes": [{ "...": "TimelineNode" }]
}
```

### 响应

```json
{
  "agents": [{ "...": "PersonaSpec" }]
}
```

### 后端行为细节

- 如果数据库里这个 `personId` 的人格已经存在，且数量与节点数对应，会直接复用
- 否则走 LLM 生成人格蓝图
- LLM 失败时，退回默认人格规则
- 最终会把人格写回数据库

### 鸿蒙接入建议

- 当前实现可继续沿用
- UI 上不要把 `selectedAgentIds` 和 `agents` 混为一个概念
- `agents` 是“候选人格全集”，`selectedAgentIds` 才是“本次参会人格”

## 7.5 `POST /api/agents/merge`

### 作用

融合两个阶段人格，生成一个新的组合人格。

### 请求

```json
{
  "primary": { "...": "PersonaSpec" },
  "secondary": { "...": "PersonaSpec" },
  "displayName": "可选，自定义融合人格名",
  "mergePrompt": "可选，给融合方向的额外指令"
}
```

### 约束

- `primary.agentId` 和 `secondary.agentId` 必须不同
- `displayName` 最长 60
- `mergePrompt` 最长 1200

### 响应

```json
{
  "agent": { "...": "PersonaSpec" },
  "execution": {
    "requestedModel": "...",
    "requestedEffort": "xhigh",
    "effectiveModel": "...",
    "effectiveEffort": "max",
    "fallbackUsed": false,
    "sessionId": "...",
    "durationMs": 12345
  }
}
```

### Web 现状

Web `ArenaStudio` 已使用这条链路，支持把融合人格加入参会列表。

### 鸿蒙建议

如果鸿蒙要与 Web 对齐，应新增：

- `MergeAgentsRequest`
- `MergeAgentsResponse`
- `PersonaApi.mergeAgents()`

并在 UI 上提供：

- 选择 primary / secondary
- 可选融合人格命名
- 可选融合提示词
- 融合后加入 `mergedAgents` 池

## 7.6 `POST /api/arena/run`

### 作用

一次性返回整场讨论结果。

### 请求

```json
{
  "topic": "现在该不该离职创业？",
  "mode": "chat",
  "selectedAgentIds": ["id-a", "id-b"],
  "agents": [{ "...": "PersonaSpec" }, { "...": "PersonaSpec" }],
  "reasoningEffort": "high",
  "roundCount": 3,
  "maxMessageChars": 180,
  "guidance": "先围绕现金流和长期后悔成本讨论",
  "continueFromRunId": "run-xxx",
  "sessionId": "run-xxx"
}
```

### 请求约束

- `topic` 必填
- `mode` 只能是 `chat` 或 `debate`
- `selectedAgentIds` 长度必须是 `2~3`
- `agents` 至少 2 个
- `roundCount` 范围 `1~20`
- `maxMessageChars` 范围 `60~500`
- `guidance` 最长 `1000`

### 响应

```json
{
  "result": { "...": "ArenaRun" },
  "links": {
    "runId": "run-174...",
    "shareApiPath": "/api/arena/runs/run-174...",
    "shareApiUrl": "https://host/api/arena/runs/run-174...",
    "suggestedSharePath": "/share/run-174...",
    "suggestedShareUrl": "https://host/share/run-174..."
  }
}
```

### 关键事实

1. `selectedAgentIds` 决定谁真的开会
2. `agents` 是本次可解析的完整人格池
3. 服务端会按 `selectedAgentIds` 从 `agents` 中筛出最多 3 人
4. 若 `continueFromRunId` 存在，会把上一场 `messages` 作为 transcript 前缀
5. 若传了 `guidance`，后端会把它作为一条 `kind: 'user'` 的消息插入 transcript

### 当前鸿蒙问题

鸿蒙 `ArenaRunRequest` 只有：

```ts
{
  topic,
  mode,
  selectedAgentIds,
  agents
}
```

缺少：

- `reasoningEffort`
- `roundCount`
- `maxMessageChars`
- `guidance`
- `continueFromRunId`
- `sessionId`

如果不补，鸿蒙无法实现：

- 调节轮次
- 控制发言长度
- 人工插话
- 续聊
- 断点恢复

## 7.7 `POST /api/arena/stream`

### 作用

以 SSE 流式返回讨论过程。

### 请求体

与 `/api/arena/run` 完全一致。

### 响应类型

`Content-Type: text/event-stream; charset=utf-8`

### 事件序列

后端真实可能发出的事件：

1. `run_started`
2. `phase_started`
3. `speaker_started`
4. `speaker_delta`
5. `speaker_completed`
6. `message`
7. `phase_completed`
8. `summary_started`
9. `summary_delta`
10. `summary`
11. `done`
12. `error`

### 典型流式块格式

```txt
event: speaker_delta
data: {"type":"speaker_delta","runId":"run-...","messageId":"run-...-msg-1","channel":"text","delta":"...","accumulatedText":"..."}
```

### `run_started`

关键字段：

- `sessionId`
- `participants`
- `plannedRounds`
- `config`
- `continuedFromRunId`

### `message`

关键字段：

- `message.id`
- `message.kind`
- `message.round`
- `message.phase`
- `message.replyToAgentId`
- `message.replyToDisplayName`

### `done`

关键字段：

- `result: ArenaRun`
- `links: ArenaOutputLinks`

### 鸿蒙接入建议

鸿蒙如果要做完整体验，必须新增：

- `ArenaStreamEvent` 联合类型
- `PersonaApi.runArenaStream()`
- SSE 解析器
- event dispatcher

建议不要在 `Arena.ets` 页面里直接堆解析逻辑，而是做成 service 层统一处理：

1. 建立连接
2. 累积文本 delta
3. 组装消息
4. 派发页面状态
5. 处理 done/error 收尾

## 7.8 `POST /api/arena/sessions/:sessionId/interrupt`

### 作用

中断正在执行的 Arena 会话。

### 请求

无 body。

### 响应

```json
{
  "ok": true,
  "sessionId": "run-174..."
}
```

### 说明

- 这个接口不是“删除结果”
- 它是“通知服务端停止继续生成”
- 服务端会尽量保留已生成的内容，并返回 `status: "interrupted"`

### Web 现状

Web 已支持：

- 点击打断
- 打断后自动重新续聊
- 用户插入 guidance 后重新继续

### 鸿蒙建议

如果要做“会议中人工介入”，这个接口是必需的。

## 7.9 `GET /api/arena/history`

### 作用

获取最近讨论历史。

### 请求参数

- `limit`，默认 20，最大 100

### 响应

```json
{
  "runs": [
    {
      "runId": "run-174...",
      "sessionId": "run-174...",
      "status": "completed",
      "topic": "现在该不该离职创业？",
      "mode": "chat",
      "title": "阶段人格会议纪要",
      "consensus": "...",
      "participantNames": ["A", "B"],
      "messageCount": 9,
      "createdAt": "2026-04-09T00:00:00.000Z",
      "continuedFromRunId": "run-173...",
      "latestGuidance": "先围绕现金流讨论"
    }
  ]
}
```

### 用途

- “最近讨论”列表
- 回放入口
- 续聊入口

## 7.10 `GET /api/arena/runs/:runId`

### 作用

获取某场讨论的完整结果和分享链接。

### 响应

```json
{
  "result": { "...": "ArenaRun" },
  "links": {
    "runId": "run-174...",
    "shareApiPath": "/api/arena/runs/run-174...",
    "shareApiUrl": "https://host/api/arena/runs/run-174...",
    "suggestedSharePath": "/share/run-174...",
    "suggestedShareUrl": "https://host/share/run-174..."
  }
}
```

### 用途

- 载入历史会话
- 继续讨论
- 分享前预览

### 鸿蒙建议

建议新增：

```ts
static async getArenaRun(runId: string): Promise<ArenaRunResponseEnvelope>
```

并在“记录”页点击卡片后：

1. 拉取 run
2. 恢复 `topic`
3. 恢复 `mode`
4. 恢复 `messages`
5. 恢复 `summary`
6. 恢复 `sessionId`
7. 如果 `status === "interrupted"`，显示“继续讨论”按钮

## 7.11 `POST /api/arena/poster`

### 作用

为某场 Arena 生成信息图海报。

### 请求

支持两种方式：

方式 A，传 `runId`：

```json
{
  "runId": "run-174..."
}
```

方式 B，直接传完整 `run`：

```json
{
  "run": { "...": "ArenaRun" },
  "stylePreset": "poster",
  "aspectRatio": "16:9",
  "language": "zh-CN"
}
```

### 约束

- `runId` 或 `run` 至少传一个
- `stylePreset` 只能是：
  - `poster`
  - `editorial`
  - `cinematic`
- `aspectRatio` 只能是：
  - `16:9`
  - `2.35:1`
  - `4:3`
  - `3:2`
  - `1:1`
  - `3:4`

### 响应

```json
{
  "runId": "run-174...",
  "links": { "...": "ArenaOutputLinks" },
  "poster": {
    "runId": "run-174...",
    "title": "海报标题",
    "summary": "海报摘要",
    "stylePreset": "poster",
    "aspectRatio": "16:9",
    "outputDir": "/abs/path/generated/...",
    "imagePath": "/abs/path/generated/.../editorial-card.png",
    "imageUrl": "https://host/generated/...",
    "promptPath": "...",
    "promptUrl": "...",
    "sourcePath": "...",
    "sourceUrl": "...",
    "generatedAt": "2026-04-09T00:00:00.000Z"
  }
}
```

### 用途

- 结果页生成信息图
- 打开可分享海报
- 二次分享素材

### 鸿蒙建议

至少支持：

- 调 `runId` 生成海报
- 打开 `poster.imageUrl`

进一步可以支持：

- 预览 `poster.summary`
- 下载图片
- 打开 `sourceUrl` 查看原始文案

## 8. Web 端真实交互逻辑，对鸿蒙有何启发

## 8.1 Web 不是只调用接口，它还有状态机

`d/src/pages/ArenaStudio.tsx` 的重点不是接口数量，而是状态完整：

- `selectedAgentIds`
- `mergedAgents`
- `history`
- `streamMessages`
- `liveDrafts`
- `liveSummaryText`
- `currentRun`
- `currentLinks`
- `activeSessionId`
- `posterResponse`
- `interrupting`
- `streaming`

鸿蒙如果只保留“静态结果页”思路，会很难平滑扩展到：

- 流式
- 历史
- 续聊
- 人工打断
- 海报

所以建议现在就把数据模型补完整，即使 UI 暂时不全部展示。

## 8.2 Web 会优先缓存 bundle

Web 和鸿蒙都在做 bundle cache，这个方向正确。  
建议鸿蒙继续保留：

- `cachedBundles`
- `selectedProfile`
- `selectedAgentIds`

并进一步补：

- `loadedRunsById`
- `historyRuns`
- `posterByRunId`

## 8.3 Web 的 arena 并不是“选中的 agents 直接发上去”

Web 实际上传：

```json
{
  "selectedAgentIds": ["已勾选人格"],
  "agents": ["当前可用人格全集"]
}
```

原因：

- 这样服务端既知道谁参会，也能知道候选人格全集
- 对续聊、融合人格、历史恢复都更灵活

鸿蒙当前 `PersonaApi.runArena()` 传的是 `selectedAgents` 直接构造出的 `agents`，这能跑，但能力受限。

更推荐改成两个参数：

```ts
runArena(input: {
  topic: string
  mode: ArenaMode
  selectedAgentIds: string[]
  agents: PersonaSpec[]
  roundCount?: number
  maxMessageChars?: number
  guidance?: string
  continueFromRunId?: string
  sessionId?: string
})
```

## 9. 鸿蒙当前模型与后端真实模型的差距

## 9.1 `Models.ets` 缺字段

当前缺失最明显的是：

- `ArenaMessage.kind`
- `ArenaMessage.round`
- `ArenaMessage.phase`
- `ArenaMessage.replyToAgentId`
- `ArenaMessage.replyToDisplayName`
- `ArenaSummary.moderatorNote`
- `ArenaSummary.debateVerdict`
- `ArenaRun.sessionId`
- `ArenaRun.continuedFromRunId`
- `ArenaRun.status`
- `ArenaRun.config`
- `ArenaRun.createdAt`
- `ArenaOutputLinks`
- `ArenaRunResponseEnvelope`
- `ArenaRunHistoryItem`
- `ArenaPosterAsset`
- `ArenaPosterResponse`
- `MergeAgentsRequest/Response`
- `ArenaStreamEvent` 系列类型

## 9.2 `PersonaApi.ets` 缺能力

当前缺：

- `mergeAgents`
- `runArenaStream`
- `interruptArenaSession`
- `getArenaHistory`
- `getArenaRun`
- `generateArenaPoster`
- `getHealth`

## 9.3 `Index.ets` 和 `Arena.ets` 的能力边界偏早期

现在更像第一阶段 Demo：

- 能选人
- 能导入
- 能一次性讨论

但还不具备 Web 的工作流能力：

- 历史记录
- 中途打断
- 续聊
- 流式渲染
- 海报分享
- 人格融合

## 10. 推荐的鸿蒙分层设计

## 10.1 Models 层

文件建议继续放在：

- `harmony/entry/src/main/ets/common/Models.ets`

建议补齐以下类型：

- `ReasoningEffort`
- `ArenaPhase`
- `ArenaRunStatus`
- `ArenaOutputLinks`
- `ArenaRunResponseEnvelope`
- `ArenaRunHistoryItem`
- `ArenaPosterAsset`
- `ArenaPosterResponse`
- `MergeAgentsRequest`
- `MergeAgentsResponse`
- `ArenaStreamEvent` 全量类型

## 10.2 API 层

文件建议继续放在：

- `harmony/entry/src/main/ets/service/PersonaApi.ets`

建议扩展为两类接口：

1. 同步 JSON 接口
2. 流式 SSE 接口

### JSON 接口建议清单

- `getHealth()`
- `getPresets()`
- `getProfileBundle(profileId)`
- `importCustomProfile(displayName, biography)`
- `buildAgents(request)`
- `mergeAgents(request)`
- `runArena(request)`
- `getArenaHistory(limit)`
- `getArenaRun(runId)`
- `interruptArenaSession(sessionId)`
- `generateArenaPoster(request)`

### SSE 接口建议

```ts
runArenaStream(
  request: ArenaRunRequest,
  callbacks: {
    onEvent: (event: ArenaStreamEvent) => void
    onError?: (message: string) => void
    onDone?: () => void
  }
): Promise<void>
```

## 10.3 页面层

建议分成四个页面/容器职责：

1. 首页 / 角色库
2. 人物详情 / 时间线
3. Arena 会场
4. 历史与分享

其中：

- 首页负责 `presets + bundle cache`
- 详情页负责 `profile + timeline + selected agents`
- Arena 页负责 `streaming + interrupt + continue`
- 历史页负责 `history + load run + poster`

## 11. 建议接入顺序

为了最稳，不建议一口气全上。建议分 4 轮。

### 第一轮：补齐类型与基础 JSON 接口

目标：

- 不动 UI 结构
- 先把模型补齐
- 增加历史 / 回放 / 海报 / 融合接口

要做：

1. 扩展 `Models.ets`
2. 扩展 `PersonaApi.ets`
3. 让 `ArenaRunResponse` 改为 envelope，而不是只读 `result`

### 第二轮：补齐历史与回放

目标：

- 让鸿蒙也能看到“最近讨论”
- 能点进某个 run 重看结果

要做：

1. `GET /api/arena/history`
2. `GET /api/arena/runs/:runId`
3. 页面状态恢复

### 第三轮：补齐流式 Arena

目标：

- 鸿蒙 Arena 页接近 Web 实时体验

要做：

1. SSE 解析器
2. `speaker_delta` 打字中效果
3. `summary_delta` 总结流
4. `done / error` 收尾

### 第四轮：补齐中断、续聊、海报、融合

目标：

- 实现完整生产级工作流

要做：

1. `interrupt`
2. `continueFromRunId + sessionId`
3. `generateArenaPoster`
4. `mergeAgents`

## 12. 鸿蒙端建议的请求对象定义

建议最终形态接近下面这样：

```ts
export type ReasoningEffort = 'low' | 'medium' | 'high' | 'xhigh'
export type ArenaMode = 'chat' | 'debate'
export type ArenaPhase = 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'
export type ArenaRunStatus = 'completed' | 'interrupted'

export interface ArenaRunRequest {
  topic: string
  mode: ArenaMode
  selectedAgentIds: string[]
  agents: PersonaSpec[]
  reasoningEffort?: ReasoningEffort
  roundCount?: number
  maxMessageChars?: number
  guidance?: string
  continueFromRunId?: string
  sessionId?: string
}

export interface ArenaRunResponseEnvelope {
  result: ArenaRun
  links?: ArenaOutputLinks
}
```

## 13. 推荐的错误处理策略

### 13.1 用户可见错误分层

建议分成三类：

1. 表单错误
2. 网络错误
3. 服务端业务错误

### 13.2 推荐文案

- `400`：参数不完整或格式错误，请检查输入
- `404`：请求的数据不存在，可能已被删除或尚未生成
- `500`：服务端执行失败，请稍后重试
- 超时：请求超时，请检查网络或稍后重试
- SSE 中断：讨论连接已断开，可重新开始或继续上一轮

### 13.3 重要行为

- `parse/build` 失败时，不要保留脏状态
- `runArenaStream` 失败时，要明确区分：
  - 用户主动取消
  - 网络断开
  - 服务端 error 事件
- `interrupt` 失败时，不要立刻清空会场，因为服务端可能仍在运行

## 14. 推荐的本地缓存策略

建议缓存以下数据：

- `ProfileBundle` by `profileId`
- `ArenaRun` by `runId`
- `ArenaPosterResponse` by `runId`
- `history list`

缓存收益：

- 首页切换更快
- 时间线页无需反复请求
- 历史记录打开更快
- 海报生成后可直接复用 URL

## 15. 测试清单

## 15.1 基础接口

1. `GET /api/presets` 成功返回列表
2. `GET /api/profiles/:id` 成功返回 bundle
3. 错误 `profileId` 时返回 404

## 15.2 自定义人物

1. biography 少于 10 字时前端拦截
2. `parseTimeline` 返回 `nodes`
3. `buildAgents` 返回 `agents`
4. 导入后能再次从 `/api/profiles/:personId` 取回

## 15.3 Arena

1. 少于 2 个人格不能开始
2. `chat` 模式成功
3. `debate` 模式成功
4. `roundCount` 超范围前端拦截
5. `guidance` 能进入 transcript
6. `continueFromRunId` 后消息能续上

## 15.4 流式

1. 能收到 `run_started`
2. 能收到 `speaker_delta`
3. 能收到 `summary_delta`
4. 一定要收到 `done` 或 `error`
5. 中断后状态应变成 `interrupted`

## 15.5 海报

1. `runId` 方式生成成功
2. `poster.imageUrl` 可访问
3. `promptUrl/sourceUrl` 有值时可打开

## 16. 最终建议

如果目标是快速交付，建议分两步：

1. 先把鸿蒙补齐 `history + run detail + poster + merge`
2. 再上 `stream + interrupt + continue`

如果目标是完全对齐 Web，现在鸿蒙最需要补的不是 UI，而是模型和 service 层。  
只要 `Models.ets` 和 `PersonaApi.ets` 一次补齐，后续页面扩展会顺很多；反过来如果继续沿用现在的简化模型，后面每加一个功能都会反复拆模型。

## 17. 建议的下一步实施清单

可以直接按下面顺序改代码：

1. 扩展 `harmony/entry/src/main/ets/common/Models.ets`
2. 扩展 `harmony/entry/src/main/ets/service/PersonaApi.ets`
3. 给 `Index.ets` 增加历史记录加载
4. 给 `Arena.ets` 改成支持 `ArenaRunResponseEnvelope`
5. 增加 `run history` 和 `run detail` 页面
6. 增加 `poster` 按钮
7. 最后再接入 `SSE + interrupt + continue`
