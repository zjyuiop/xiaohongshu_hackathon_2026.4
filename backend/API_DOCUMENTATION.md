# Time Persona Backend API 文档

适用项目：`/Users/mychanging/Desktop/hackhathon`

当前后端地址：

```txt
http://localhost:3030
```

这份文档面向前端接入，重点说明：

- 页面应该怎么调接口
- 每个接口的请求/响应结构
- 字段含义
- 错误处理
- 当前默认人物和接入建议

## 1. 接入总览

当前后端已经支持两条链路：

1. 默认人物链路
   - 直接读取已导入数据库的人物
   - 当前默认人物：
     - `steve-jobs`
     - `elon-musk`

2. 自定义人物链路
   - 用户输入人物背景
   - 后端生成时间线节点
   - 再生成该人物各时间段 agent
   - 最后进入 arena 对话 / 对战

## 2. 前端推荐接入流程

### 2.1 角色录入页

如果是默认人物：

1. `GET /api/presets`
2. 用户点选某个 preset
3. `GET /api/profiles/:profileId`
4. 直接拿到：
   - `profile`
   - `nodes`
   - `agents`

如果是自定义人物：

1. 用户输入 `displayName + biography`
2. `POST /api/timeline/parse`
3. 拿到 `personId + nodes`
4. 再调用 `POST /api/agents/build`
5. 拿到 `agents`
6. 页面本地缓存：
   - `personId`
   - `displayName`
   - `nodes`
   - `agents`

### 2.2 人生沙盘页

使用：

- 默认人物：`GET /api/profiles/:profileId`
- 自定义人物：直接用前一步 `parse/build` 返回结果即可

页面最主要消费的是：

- `nodes[]`
- `agents[]`

建议：

- 节点卡片展示 `timeLabel / stageLabel / keyEvent / summary`
- 点击节点时，用 `nodeId` 关联到对应 `agentId = ${nodeId}-agent`

### 2.3 Arena 页

1. 用户选择 2~3 个 agent
2. 输入 `topic`
3. 选择 `mode`
   - `chat`
   - `debate`
4. `POST /api/arena/run`
5. 渲染：
   - `result.messages`
   - `result.summary`

## 3. 通用说明

### 3.1 Content-Type

所有 `POST` 请求统一使用：

```http
Content-Type: application/json
```

### 3.2 错误响应

#### 400 参数校验错误

返回结构：

```json
{
  "error": {
    "formErrors": [],
    "fieldErrors": {
      "displayName": ["String must contain at least 1 character(s)"]
    }
  }
}
```

说明：

- 这是 Zod 的 `flatten()` 结构
- 前端直接读 `error.fieldErrors`

#### 404 资源不存在

```json
{
  "error": "profile not found"
}
```

#### 500 服务错误

```json
{
  "error": "具体错误信息"
}
```

### 3.3 重要接入约束

- `personId` 和 `profileId` 一律当作 opaque string 处理
- 不要假设它一定是英文 slug
- 自定义人物的 `personId` 可能是中文，例如：`测试角色`
- arena 接口要求传完整的 `agents[]`，不是只传 ID
- 大模型接口有明显耗时，前端必须做好 loading 状态

建议的前端超时时间：

- `/api/timeline/parse`：60s~180s
- `/api/agents/build`：60s~180s
- `/api/arena/run`：60s~180s

## 4. 数据模型

## 4.1 PresetProfile

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

字段说明：

- `id`: 默认人物 ID，前端用于详情页加载
- `displayName`: 人物显示名
- `subtitle`: 人物一句话定位
- `category`: 类型
- `coverSeed`: 可作为头像/封面生成种子
- `biography`: 简版背景
- `highlights`: 关键经历摘要
- `suggestedTopics`: 推荐讨论话题

## 4.2 TimelineNode

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

字段说明：

- `nodeId`: 节点唯一 ID
- `timeLabel`: 时间标签，例如 `1972年前后`、`阶段 1`
- `ageLabel`: 年龄标签，可选
- `stageLabel`: 阶段名称，建议作为卡片主标题
- `stageType`: 阶段类型，用于 UI 风格 / 标签色
- `keyEvent`: 该阶段核心事件
- `summary`: 该阶段摘要
- `traits`: 人格特征
- `values`: 价值观关键词
- `tensions`: 内在冲突
- `sourceEvidence`: 证据引用

## 4.3 SourceEvidence

```ts
interface SourceEvidence {
  quote: string
  sourceLabel: string
}
```

字段说明：

- `quote`: 原文引文或贴近原文的短证据
- `sourceLabel`: 来源标签，例如章节名、材料来源

## 4.4 PersonaSpec

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

字段说明：

- `agentId`: agent 唯一 ID
- `displayName`: 展示名，例如 `史蒂夫·乔布斯 · 疯狂少年与精神觉醒`
- `personId`: 所属人物 ID
- `avatarSeed`: 可做头像种子
- `timeLabel / stageLabel / keyEvent`: 节点映射信息
- `knownFacts`: 这个人格已知的关键事实
- `goal`: 这个阶段最想实现什么
- `fear`: 这个阶段最怕什么
- `voiceStyle`: 说话风格
- `knowledgeBoundary`: 知识边界
- `forbiddenFutureKnowledge`: 是否禁止知道未来
- `stanceSeed`: 讨论立场种子

## 4.5 ArenaRun

```ts
interface ArenaRun {
  runId: string
  mode: 'chat' | 'debate'
  topic: string
  participants: PersonaSpec[]
  messages: ArenaMessage[]
  summary: ArenaSummary
}
```

## 4.6 ArenaMessage

```ts
interface ArenaMessage {
  id: string
  agentId: string
  displayName: string
  stageLabel: string
  content: string
  stance: 'support' | 'oppose' | 'reflective' | 'neutral'
}
```

## 4.7 ArenaSummary

```ts
interface ArenaSummary {
  title: string
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
}
```

## 5. 接口明细

## 5.1 健康检查

### `GET /health`

用途：

- 检查后端是否可用
- 查看数据库和默认导入状态
- 查看当前 Claude Code runtime 配置

响应示例：

```json
{
  "ok": true,
  "runtime": {
    "mode": "claude-code-sdk",
    "claudeBinary": "/Users/mychanging/Desktop/hackhathon/backend/node_modules/.bin/claude",
    "requestedModel": "gpt-5.4",
    "requestedEffort": "xhigh",
    "fallbackModel": "claude-opus-4-6",
    "fallbackEffort": "max",
    "unsupportedModels": ["gpt-5.4"]
  },
  "import": {
    "running": false,
    "lastImportedProfileIds": [],
    "documents": 2,
    "defaultProfiles": 2,
    "arenaRuns": 1,
    "libraryDir": "/Users/mychanging/Desktop/知识库收集"
  },
  "timestamp": "2026-04-08T00:00:00.000Z"
}
```

前端用途：

- 调试页
- 启动页自检
- 管理页展示 runtime/import 状态

## 5.2 获取默认人物列表

### `GET /api/presets`

用途：

- 拉取默认人物列表
- 首页 / 角色选择页展示

响应：

```json
{
  "presets": [
    {
      "id": "elon-musk",
      "displayName": "埃隆·马斯克",
      "subtitle": "从冒险少年到高压创业者",
      "category": "celebrity",
      "coverSeed": "elon-musk",
      "biography": "基于传记与章节证据整理出的关键人生阶段，供跨时空人格沙盘使用。",
      "highlights": ["第0章 简介", "第23节 两次发射", "第47节 开环警告", "第70节 支持和平"],
      "suggestedTopics": ["什么时候应该继续豪赌？", "野心和组织摩擦该如何平衡？", "高速推进的代价值不值得？"]
    }
  ]
}
```

前端建议：

- 这个接口只返回人物概览
- 进入人物详情页后，再调 `GET /api/profiles/:profileId`

## 5.3 获取完整人物详情

### `GET /api/profiles/:profileId`

用途：

- 获取人物完整数据包
- 包含 profile + timeline nodes + persona agents

路径参数：

- `profileId: string`

响应结构：

```json
{
  "profile": {
    "id": "steve-jobs",
    "displayName": "史蒂夫·乔布斯",
    "subtitle": "在疯狂与天才之间扭曲现实的人",
    "category": "celebrity",
    "coverSeed": "steve-jobs",
    "biography": "...",
    "highlights": ["..."],
    "suggestedTopics": ["..."]
  },
  "nodes": [],
  "agents": [],
  "sourceDocument": {
    "id": "uuid",
    "title": "史蒂夫·乔布斯传（修订版）",
    "author": "[美]沃尔特·艾萨克森",
    "filePath": "/Users/mychanging/Desktop/知识库收集/...",
    "importedAt": "2026-04-08T00:00:00.000Z",
    "sectionCount": 54
  }
}
```

字段说明：

- `profile`: 人物总览
- `nodes`: 时间线节点
- `agents`: 对应节点的人格体
- `sourceDocument`: 源文档信息，只有默认传记人物一般会带

前端建议：

- 这是默认人物详情页的主接口
- 如果你做“角色详情子页”，直接用这个接口
- `nodes[]` 和 `agents[]` 可以一起缓存

## 5.4 解析自定义人物时间线

### `POST /api/timeline/parse`

用途：

- 将用户输入的人物背景转成时间线节点
- 同时把基础 profile + nodes 持久化进数据库

请求体：

```json
{
  "displayName": "测试角色",
  "biography": "测试角色大学毕业后进入内容行业，前两年高速成长，但也在高压环境中频繁怀疑自己。经历一次创业失败后，他开始重新理解长期主义、团队协作与节奏控制。后来他带着更清晰的边界重新创业，并逐渐形成更稳定的判断。"
}
```

可选请求体：

```json
{
  "profileId": "steve-jobs",
  "displayName": "史蒂夫·乔布斯",
  "biography": "可传可不传"
}
```

说明：

- 如果传入已有 `profileId`，后端会直接返回该 profile 的 `nodes`
- 对默认人物场景，不推荐走这个接口，直接 `GET /api/profiles/:id`

响应：

```json
{
  "personId": "测试角色",
  "displayName": "测试角色",
  "nodes": [
    {
      "nodeId": "测试角色-1",
      "timeLabel": "阶段 1",
      "stageLabel": "起点探索期",
      "stageType": "early",
      "keyEvent": "...",
      "summary": "...",
      "traits": ["..."],
      "values": ["..."],
      "tensions": ["..."],
      "sourceEvidence": [
        {
          "quote": "...",
          "sourceLabel": "用户输入"
        }
      ]
    }
  ]
}
```

前端建议：

- 这个接口返回后，还没有 arena 可用的 `agents`
- 下一步必须调 `POST /api/agents/build`

## 5.5 构建时间节点 agent

### `POST /api/agents/build`

用途：

- 根据时间线节点生成各阶段人格 agent
- 同时将 agents 持久化进数据库

请求体：

```json
{
  "personId": "测试角色",
  "displayName": "测试角色",
  "biography": "可选，建议传，能提高生成质量",
  "nodes": [
    {
      "nodeId": "测试角色-1",
      "timeLabel": "阶段 1",
      "stageLabel": "起点探索期",
      "stageType": "early",
      "keyEvent": "...",
      "summary": "...",
      "traits": ["..."],
      "values": ["..."],
      "tensions": ["..."],
      "sourceEvidence": [
        {
          "quote": "...",
          "sourceLabel": "用户输入"
        }
      ]
    }
  ]
}
```

响应：

```json
{
  "agents": [
    {
      "agentId": "测试角色-1-agent",
      "displayName": "测试角色 · 起点探索期",
      "personId": "测试角色",
      "avatarSeed": "测试角色-early",
      "timeLabel": "阶段 1",
      "stageLabel": "起点探索期",
      "keyEvent": "...",
      "knownFacts": ["..."],
      "sourceEvidence": [
        {
          "quote": "...",
          "sourceLabel": "用户输入"
        }
      ],
      "traits": ["..."],
      "values": ["..."],
      "goal": "...",
      "fear": "...",
      "voiceStyle": "...",
      "knowledgeBoundary": "...",
      "forbiddenFutureKnowledge": true,
      "stanceSeed": "..."
    }
  ]
}
```

前端建议：

- 这个接口的返回值可以直接作为 arena 的输入
- 如果前端后续需要完整人物页，可以再调一次 `GET /api/profiles/:personId`

## 5.6 运行 arena 对话 / 对战

### `POST /api/arena/run`

用途：

- 启动 2~3 个 agent 的跨时空讨论
- 返回完整消息流和总结

请求体：

```json
{
  "topic": "现在该不该继续创业？",
  "mode": "debate",
  "selectedAgentIds": [
    "测试角色-1-agent",
    "测试角色-2-agent"
  ],
  "agents": [
    {
      "agentId": "测试角色-1-agent",
      "displayName": "测试角色 · 起点探索期",
      "personId": "测试角色",
      "avatarSeed": "测试角色-early",
      "timeLabel": "阶段 1",
      "stageLabel": "起点探索期",
      "keyEvent": "...",
      "knownFacts": ["..."],
      "sourceEvidence": [
        {
          "quote": "...",
          "sourceLabel": "用户输入"
        }
      ],
      "traits": ["..."],
      "values": ["..."],
      "goal": "...",
      "fear": "...",
      "voiceStyle": "...",
      "knowledgeBoundary": "...",
      "forbiddenFutureKnowledge": true,
      "stanceSeed": "..."
    }
  ]
}
```

约束：

- `mode` 只能是：
  - `chat`
  - `debate`
- `selectedAgentIds.length` 必须是 `2~3`
- `agents[]` 里必须包含被选中的 agent 全量数据

响应：

```json
{
  "result": {
    "runId": "run-1775608930264",
    "mode": "debate",
    "topic": "现在该不该继续创业？",
    "participants": [],
    "messages": [
      {
        "id": "run-1775608930264-msg-1",
        "agentId": "测试角色-1-agent",
        "displayName": "测试角色 · 起点探索期",
        "stageLabel": "起点探索期",
        "content": "......",
        "stance": "support"
      }
    ],
    "summary": {
      "title": "势头与方向：一个人的两次创业独白",
      "consensus": "......",
      "disagreements": ["......"],
      "actionableAdvice": ["......"],
      "narrativeHook": "......"
    }
  }
}
```

前端建议：

- `messages[]` 可直接渲染聊天气泡
- `summary` 可渲染成会议纪要 / 故事总结卡片
- `stance` 可做颜色区分
  - `support`
  - `oppose`
  - `reflective`
  - `neutral`

## 5.7 手动触发默认人物导入

### `POST /api/admin/import-defaults`

用途：

- 管理接口
- 强制重新导入默认传记人物

前端普通业务页面一般不需要接

响应：

```json
{
  "state": {
    "running": false,
    "lastImportedProfileIds": ["steve-jobs", "elon-musk"],
    "lastRunAt": "2026-04-08T00:00:00.000Z"
  },
  "overview": {
    "documents": 2,
    "defaultProfiles": 2,
    "arenaRuns": 1,
    "libraryDir": "/Users/mychanging/Desktop/知识库收集",
    "lastImportedProfileIds": ["steve-jobs", "elon-musk"]
  }
}
```

## 5.8 查看默认导入状态

### `GET /api/admin/import-status`

用途：

- 管理页查看导入状态

响应：

```json
{
  "state": {
    "running": false,
    "lastImportedProfileIds": ["steve-jobs", "elon-musk"],
    "lastRunAt": "2026-04-08T00:00:00.000Z"
  },
  "overview": {
    "documents": 2,
    "defaultProfiles": 2,
    "arenaRuns": 1,
    "libraryDir": "/Users/mychanging/Desktop/知识库收集",
    "lastImportedProfileIds": ["steve-jobs", "elon-musk"]
  }
}
```

## 6. 推荐前端状态管理方式

建议在前端维护以下状态：

```ts
type SelectedProfileState = {
  profile?: PresetProfile
  personId?: string
  displayName?: string
  nodes: TimelineNode[]
  agents: PersonaSpec[]
  selectedAgentIds: string[]
  arenaRun?: ArenaRun
}
```

推荐缓存策略：

- `presets`: 全局缓存
- `profile bundle`: 按 `profileId` 缓存
- `custom person`: 按 `personId` 缓存
- `arenaRun`: 页面级状态即可

## 7. 推荐页面对接方式

## 7.1 Profile Input 页

默认人物：

```ts
const presets = await GET('/api/presets')
const bundle = await GET(`/api/profiles/${profileId}`)
```

自定义人物：

```ts
const parsed = await POST('/api/timeline/parse', {
  displayName,
  biography
})

const built = await POST('/api/agents/build', {
  personId: parsed.personId,
  displayName: parsed.displayName,
  biography,
  nodes: parsed.nodes
})
```

## 7.2 Timeline Sandbox 页

渲染：

- `profile`
- `nodes`
- `agents`

节点 -> agent 对应关系：

```ts
const relatedAgent = agents.find(agent => agent.agentId === `${node.nodeId}-agent`)
```

## 7.3 Arena 页

```ts
const arena = await POST('/api/arena/run', {
  topic,
  mode,
  selectedAgentIds,
  agents
})
```

渲染：

- `arena.result.messages`
- `arena.result.summary`

## 8. 已验证的真实返回情况

目前服务已验证通过：

- `GET /api/presets`
  - 返回 2 个默认人物

- `GET /api/profiles/steve-jobs`
  - 返回 `6` 个时间节点
  - 返回 `6` 个 persona agents

- `GET /api/profiles/elon-musk`
  - 返回 `5` 个时间节点
  - 返回 `5` 个 persona agents

- `POST /api/timeline/parse`
  - 自定义人物成功返回节点

- `POST /api/agents/build`
  - 自定义人物成功返回 agents

- `POST /api/arena/run`
  - 已成功返回 `4` 条消息和 summary

## 9. 运行时说明

当前底层运行时是：

- Claude Code agent runtime

当前模型策略：

- 先请求：`gpt-5.4 + xhigh`
- 如果当前本机 Claude Code 无该模型权限，则自动回退：
  - `claude-opus-4-6 + max`

这件事会影响：

- 生成耗时
- 文案风格
- 结构化输出稳定性

但不影响前端接口形状。

## 10. 给前端的最终建议

前端实际接入时，不要把默认人物也走 `parse -> build` 两段链路。

最稳的方式是：

1. 默认人物：
   - `GET /api/presets`
   - `GET /api/profiles/:id`

2. 自定义人物：
   - `POST /api/timeline/parse`
   - `POST /api/agents/build`

3. Arena：
   - `POST /api/arena/run`

如果你需要，我下一步可以直接继续补：

- 一份给 web 前端的 TypeScript API client
- 一份 `openapi.yaml`
- 一份 `shared/types.ts` 的前后端统一类型导出
