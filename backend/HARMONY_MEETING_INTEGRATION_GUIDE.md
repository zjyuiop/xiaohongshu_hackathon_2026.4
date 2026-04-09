# 鸿蒙会议页接入指导文档

最后核对时间：2026-04-09 11:30 UTC  
适用项目：`/Users/mychanging/Desktop/hackhathon/backend`  
目标：给鸿蒙端补齐“会议页”和“角色页 / 纪要页”的连接，不参考本地旧版 `harmony` 目录。

## 1. 这份文档基于什么

这份文档只基于以下真实来源整理：

- web 会议页实现：`d/src/pages/ArenaStudio.tsx`
- web API 封装：`d/src/lib/api.ts`
- 前端类型定义：`d/src/types.ts`
- 后端接口实现：`backend/src/server.ts`
- 后端请求/响应类型：`backend/src/domain.ts`
- 后端校验规则：`backend/src/schemas.ts`
- 线上服务实测：`https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/health`

不使用本地旧版 `harmony` 目录做判断。

## 2. 结论先看

鸿蒙会议页如果要和当前 web 方案对齐，核心结论只有 6 条：

1. 会议页主链路要走 `POST /api/arena/stream`，不要把 `POST /api/arena/run` 当主入口。
2. 会议页发起讨论时，必须上传完整 `agents[]`，不能只传 `selectedAgentIds[]`。
3. `selectedAgentIds` 只表示本场真正参会的人格，数量要求至少 `2` 个，不设上限。
4. 如果要完全对齐 web 会议页，除了角色加载，还要包含 `POST /api/agents/merge` 这条人格融合接口。
5. 纪要页不要只吃会议页内存态，必须支持通过 `runId` 调 `GET /api/arena/runs/:runId` 回读。
6. 中途打断、继续续聊、人工 steer 都依赖 `sessionId` 和 `continueFromRunId`，这两个字段不能丢。

## 3. 当前线上服务状态

### 3.1 Base URL

```txt
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com
```

### 3.2 `/health` 实测

2026-04-09 11:29 UTC 实测结果：

```json
{
  "ok": true,
  "runtime": {
    "mode": "claude-agent-sdk",
    "claudeBinary": "/home/ubuntu/hackhathon/backend/bin/claude-via-ccs.sh",
    "ccsProfile": "hackhathon-glm",
    "requestedModel": "Pro/MiniMaxAI/MiniMax-M2.5",
    "requestedEffort": "xhigh",
    "fallbackModel": "glm-5",
    "fallbackEffort": "max",
    "unsupportedModels": [],
    "siliconFlowEnabled": true,
    "siliconFlowFallbackModels": [
      "Pro/MiniMaxAI/MiniMax-M2.5",
      "Pro/moonshotai/Kimi-K2.5"
    ]
  },
  "import": {
    "documents": 7,
    "defaultProfiles": 6,
    "arenaRuns": 99
  }
}
```

这说明当前线上会议链路的真实运行时是：

- Claude Code SDK
- 主模型：`Pro/MiniMaxAI/MiniMax-M2.5`
- 回退链路里包含：`Pro/moonshotai/Kimi-K2.5`

### 3.3 鸿蒙端必须固定的请求设置

普通 JSON 接口：

```http
Content-Type: application/json
```

SSE 会议流：

```http
Content-Type: application/json
Accept: text/event-stream
```

补充说明：

- 当前接口未做鉴权
- 已开启 CORS
- 返回编码统一为 UTF-8
- SSE 有心跳包 `: ping`

## 4. 会议相关接口总览

| 方法 | 路径 | 用途 | 鸿蒙端是否必须接 |
|---|---|---|---|
| `GET` | `/health` | 检查服务和当前模型配置 | 建议接 |
| `GET` | `/api/presets` | 拉默认角色列表 | 如果角色页还要支持默认人物，则接 |
| `GET` | `/api/profiles/:profileId` | 拉完整角色 bundle | 建议接 |
| `POST` | `/api/timeline/parse` | 文本解析时间线 | 仅自定义纯文本导入时需要 |
| `POST` | `/api/agents/build` | 从时间线生成阶段人格 | 仅自定义纯文本导入时需要 |
| `POST` | `/api/agents/merge` | 融合两个人格生成新人格 | 如果会议页要对齐 web 的人格融合能力，则接 |
| `POST` | `/api/profile-imports` | 文件上传式角色导入 | 如果角色页用文件导入，则接 |
| `POST` | `/api/arena/stream` | 流式跑会议 | 必接 |
| `POST` | `/api/arena/run` | 同步返回完整结果 | 只建议做调试/兜底 |
| `GET` | `/api/arena/history` | 拉历史会议列表 | 建议接 |
| `GET` | `/api/arena/runs/:runId` | 按 `runId` 拉完整会议结果 | 必接 |
| `POST` | `/api/arena/sessions/:sessionId/messages` | 实时插入一条用户消息并触发安全打断 | 如果要做微信式聊天输入，则必接 |
| `POST` | `/api/arena/sessions/:sessionId/interrupt` | 中途打断会议 | 如果要支持打断和人工 steer，则必接 |
| `POST` | `/api/arena/poster` | 生成海报/信息图 | 如果纪要页要出图，则接 |

### 4.1 当前文档已覆盖的 web 会议页接口清单

按 `ArenaStudio.tsx` 实际调用核对，这份文档现在已经覆盖了下面这些接口：

| web 调用名 | 后端接口 | 是否已写进文档 |
|---|---|---|
| `loadPresets` | `GET /api/presets` | 是 |
| `loadProfile` | `GET /api/profiles/:profileId` | 是 |
| `parseTimeline` | `POST /api/timeline/parse` | 是 |
| `buildAgents` | `POST /api/agents/build` | 是 |
| `requestMergedAgent` | `POST /api/agents/merge` | 是 |
| `runArenaStream` | `POST /api/arena/stream` | 是 |
| `loadArenaHistory` | `GET /api/arena/history` | 是 |
| `loadArenaRun` | `GET /api/arena/runs/:runId` | 是 |
| `sendArenaSessionMessage` | `POST /api/arena/sessions/:sessionId/messages` | 是 |
| `interruptArenaSession` | `POST /api/arena/sessions/:sessionId/interrupt` | 是 |
| `generateArenaPoster` | `POST /api/arena/poster` | 是 |

补充说明：

- `buildSuggestedShareUrl` 是前端本地 helper，不是后端接口
- `POST /api/profile-imports` 不在 `ArenaStudio.tsx` 当前会议页主链路里，但如果角色页采用文件导入，它也已经写进本文档

## 5. 角色页和会议页之间到底要传什么

会议页不是只吃一个 `profileId` 就能跑起来。  
当前 web 的真实要求是：会议页发请求时，必须有完整 `agents[]`。

因此，角色页到会议页，最少要传以下数据之一：

### 5.1 推荐方案

直接把完整 bundle 传给会议页：

```ts
{
  profile: PresetProfile
  nodes: TimelineNode[]
  agents: PersonaSpec[]
}
```

### 5.2 次优方案

角色页只传 `profileId`，会议页自己再调：

1. `GET /api/profiles/:profileId`
2. 拿到 `profile + nodes + agents`
3. 再进入会议发起链路

### 5.3 不够用的方案

只传下面这些都不够：

- 只传 `profileId`
- 只传 `selectedAgentIds`
- 只传角色名称
- 只传时间线节点但没有 `agents`

原因是后端 `POST /api/arena/stream` 和 `POST /api/arena/run` 都强依赖完整 `agents[]`。

### 5.4 如果要接 web 的人格融合，还要多带一条接口

当前 web 左侧人物素材区还有“人格融合”能力，对应接口是：

```txt
POST /api/agents/merge
```

请求体：

```ts
interface MergeAgentsRequest {
  primary: PersonaSpec
  secondary: PersonaSpec
  displayName?: string
  mergePrompt?: string
}
```

返回体：

```ts
interface MergeAgentsResponse {
  agent: PersonaSpec
  execution?: {
    requestedModel: string
    requestedEffort: 'low' | 'medium' | 'high' | 'xhigh'
    effectiveModel: string
    effectiveEffort: 'low' | 'medium' | 'high' | 'max'
    fallbackUsed: boolean
    sessionId?: string
    durationMs: number
  }
}
```

语义：

- `primary` 和 `secondary` 必须是两个不同的人格
- 返回的是一个新的 `PersonaSpec`
- 这个新人格可以直接加入会议页的 `agents[]` 候选池，再参与后续讨论

## 6. 鸿蒙发起会议时要提交哪些字段

会议页真正发给后端的请求体是：

```ts
interface ArenaRunRequestPayload {
  topic: string
  mode: 'chat' | 'debate'
  selectedAgentIds: string[]
  agents: PersonaSpec[]
  reasoningEffort?: 'low' | 'medium' | 'high' | 'xhigh'
  roundCount?: number
  maxMessageChars?: number
  guidance?: string
  pendingUserMessages?: Array<{
    id?: string
    content: string
    createdAt?: string
  }>
  continueFromRunId?: string
  sessionId?: string
}
```

后端校验规则：

- `topic`: 必填
- `mode`: 只能是 `chat` 或 `debate`
- `selectedAgentIds`: 至少 `2` 个
- `agents`: 至少 2 个
- `roundCount`: 正整数，不设上限
- `maxMessageChars`: `60 ~ 500`
- `guidance`: 去空格后 `1 ~ 1000` 字符
- `pendingUserMessages[*].content`: 去空格后 `1 ~ 4000` 字符

### 6.1 字段语义

`topic`

- 这场会议真正讨论的议题

`mode`

- `chat`：更像多角色对谈
- `debate`：更像对立辩论

`selectedAgentIds`

- 只表示本场真正参会的角色集合
- 至少选 `2` 个
- 当前不设上限，但角色越多，请求越慢、消息越多、总结越重

`agents`

- 必须上传完整人格列表
- 一般来自角色页加载好的 `bundle.agents`
- web 端会把“角色库人格 + 融合人格 + 当前 run participants”去重后一起维护

`guidance`

- 是人工给这场讨论的额外引导
- 新开一场时，会变成 transcript 里的 `kind: 'user'` 消息
- 中途打断后继续时，也会作为新的 steer 插入

`pendingUserMessages`

- 是像微信聊天一样插进去的用户消息
- 会按顺序写回 transcript
- 更适合聊天页底部输入框，而不是 setup 页的一次性引导

`continueFromRunId`

- 表示不是新开一场，而是基于已有 run 继续

`sessionId`

- 用来维持同一条会话链
- 打断、继续、人工 steer 都依赖它

### 6.2 web 默认值

如果你要和当前 web 行为尽量一致，默认值建议保持：

- `mode = 'chat'`
- `roundCount = 3`
- `maxMessageChars = 180`
- `guidance = ''`
- `selectedAgentIds` 不做前端数量上限
- `roundCount` 输入框不做前端最大值限制

其中，web 的角色选择策略是：

- 没选中过：直接加入
- 已选中过：取消选择
- 不再自动踢掉旧角色

## 7. 为什么鸿蒙会议页要优先接 `/api/arena/stream`

原因不是风格问题，而是 web 实现和线上行为都表明流式更合适：

- web 的实际会议页只调用了 `runArenaStream(...)`
- UI 依赖 `speaker_delta` 做实时打字效果
- UI 依赖 `summary_delta` 做实时总结预览
- 中途打断链路基于正在运行的 `sessionId`
- 同步接口更适合“等最终结果”，不适合移动端实时会议页

另外，2026-04-09 稍早外网联调时，`/api/arena/run` 曾多次撞上大约 60 秒的网关超时。  
所以鸿蒙端不要把同步接口当主路径。

## 7.1 微信式聊天输入需要再接一条会话接口

如果你要把会议页做成“像微信一样随时插话”，只接 `interrupt` 还不够，还要接：

```txt
POST /api/arena/sessions/:sessionId/messages
```

请求体：

```json
{
  "content": "先别继续争论了，请直接回答我现在最该先保住什么。",
  "clientMessageId": "user-1710000000000-abcd12",
  "createdAt": "2026-04-09T12:34:56.000Z"
}
```

行为：

1. 前端先把这条消息乐观显示到聊天列表
2. 后端把消息排进当前会话的待插入队列
3. 如果当前正有角色在生成，后端会安全打断
4. 前端续流后，后端会把这条消息作为正式 `kind: 'user'` 消息写回 transcript
5. 多个角色再基于这条新消息继续讨论

这就是现在 web 端优化后的“聊天式插话”主链路。

## 8. `/api/arena/stream` 的事件模型

### 8.1 请求头

```http
Content-Type: application/json
Accept: text/event-stream
```

### 8.2 事件类型

```ts
type ArenaStreamEvent =
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

每个事件都带这些公共字段：

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

### 8.3 鸿蒙端至少要处理哪些事件

最低可用版本至少处理：

- `message`
- `summary`
- `done`
- `error`

如果要对齐 web 的实时体验，再补：

- `run_started`
- `phase_started`
- `speaker_started`
- `speaker_delta`
- `speaker_completed`
- `summary_started`
- `summary_delta`

### 8.4 各事件在 UI 里的真实作用

`run_started`

- 记录 `sessionId`
- 初始化 phase 状态
- 确认当前计划轮次

`phase_started`

- 更新顶部 phase 文案

`speaker_started`

- 在聊天列表里插入一个“正在输入”的 draft 气泡

`speaker_delta`

- 持续覆盖对应 draft 的 `accumulatedText`
- 只处理 `channel = 'text'`
- `channel = 'thinking'` 可忽略

`message`

- 把 draft 转成正式消息
- 从“正在输入列表”移除对应 draft

`summary_started`

- 开始显示实时总结区域

`summary_delta`

- 用 `accumulatedText` 持续覆盖总结草稿

`summary`

- 把最终总结写入页面

`done`

- 这是唯一表示流式成功完整结束的事件
- 拿到最终 `result` 和 `links`
- 此时应落下完整 run，刷新历史列表

`error`

- 结束当前流式会话
- 显示错误文案

### 8.5 SSE 解析注意事项

后端会发标准 SSE 文本块，例如：

```txt
event: message
data: {...}

event: done
data: {...}
```

还有心跳：

```txt
: ping
```

鸿蒙端要点：

- 忽略以 `:` 开头的心跳行
- 以空行作为一个事件块结束
- 把同一个块里的多行 `data:` 拼起来再 JSON.parse
- 只有拿到 `done` 或 `error` 才算终态
- 如果连接断了但没收到 `done/error`，要按失败处理

## 9. web 会议页的真实实现方案

当前 web `ArenaStudio` 不是一个单纯聊天页，而是一个三段式工作台：

### 9.1 左侧：人格素材 / 历史

包括两部分：

- 角色库
- 最近讨论历史

角色库负责：

- 加载默认人物
- 展开人物时间线
- 勾选至少 `2` 个阶段人格
- 可选导入自定义人物
- 可选通过 `POST /api/agents/merge` 融合两个角色生成新人格

历史负责：

- 拉 `GET /api/arena/history`
- 点某条历史后，调 `GET /api/arena/runs/:runId`
- 把历史 run 重新载入会议页

### 9.2 中间：开局设定 / 讨论现场

`开局设定` 页面负责：

- 选参会人格
- 填 `topic`
- 选 `mode`
- 改 `roundCount`
- 改 `maxMessageChars`
- 填 `guidance`
- 启动讨论
- 基于当前结果继续
- 中途打断

`讨论现场` 页面负责：

- 实时显示已完成消息
- 实时显示正在输入的 draft
- 实时显示 summary draft
- 支持人工 steer

### 9.3 右侧：结果与分享

只有会议跑出结果后才显示：

- 分享页入口
- 海报/信息图入口

这说明鸿蒙会议页至少也要有三类状态：

1. 会议前的 setup 状态
2. 会议中的 streaming 状态
3. 会议后的 output 状态

## 10. web 的核心状态机

以下状态是 web 端真实在维护的，鸿蒙端建议至少保留同等语义：

| 状态 | 作用 |
|---|---|
| `selectedAgentIds` | 当前选中的参会人格 |
| `topic` | 当前议题 |
| `arenaMode` | `chat` 或 `debate` |
| `roundCount` | 讨论轮数 |
| `maxMessageChars` | 单条字数上限 |
| `guidance` | 人工引导文案 |
| `streaming` | 当前是否在流式生成 |
| `interrupting` | 当前是否正在发起打断 |
| `phaseLabel` | 顶部状态文案 |
| `error` | 错误提示 |
| `activeSessionId` | 当前会话 id |
| `streamMessages` | 已完成的消息列表 |
| `liveDrafts` | 正在输入中的草稿消息 |
| `liveSummaryText` | 实时总结草稿 |
| `currentRun` | 最终会议结果 |
| `currentLinks` | 分享相关链接 |
| `history` | 历史会议列表 |
| `posterResponse` | 海报结果 |

### 10.1 启动会议时 web 做了什么

web 的 `startArena(...)` 实际流程是：

1. 校验是否已经选够 2 个角色
2. 校验 `topic` 不为空
3. 清空旧错误、旧海报、旧 draft
4. 切到聊天视图
5. 如果是续聊，先把旧消息放进 `streamMessages`
6. 创建新的 `AbortController`
7. 调 `runArenaStream(...)`
8. 把 SSE 事件交给 `handleArenaEvent(...)`

### 10.2 载入历史 run 时 web 做了什么

点历史记录后：

1. 先停止现有流
2. `GET /api/arena/runs/:runId`
3. 把返回结果写进：
   - `currentRun`
   - `currentLinks`
   - `topic`
   - `arenaMode`
   - `roundCount`
   - `maxMessageChars`
   - `activeSessionId`
   - `streamMessages`
4. 切到聊天页展示

### 10.3 中断和续聊时 web 做了什么

中断流程：

1. 当前必须处于 `streaming = true`
2. 必须已经拿到 `activeSessionId`
3. 调 `POST /api/arena/sessions/:sessionId/interrupt`

只打断：

- 等流自己收到 `done`
- `result.status` 会变成 `interrupted`

打断并继续：

1. 先中断
2. 等 `done`
3. 如果 `result.status === 'interrupted'`
4. 自动再调用一次 `startArena(true, event.result)`
5. 新的请求带上：
   - `continueFromRunId = 上一个 runId`
   - `sessionId = 上一个 sessionId`
   - `guidance = 当前输入的 steer`

## 11. 会议页和纪要页怎么连

纪要页不要假设自己一定从会议页内存态进入。  
正确做法是同时支持这两条链路：

### 11.1 链路 A：会议页直接跳纪要页

会议页完成后可直接把这些数据给纪要页：

```ts
{
  runId: currentRun.runId
  run: currentRun
  links: currentLinks
}
```

### 11.2 链路 B：纪要页自己按 `runId` 回读

如果用户是从历史、分享链接、通知、恢复会话进入纪要页：

1. 纪要页先拿到 `runId`
2. 调 `GET /api/arena/runs/:runId`
3. 再自己渲染 summary / messages / participants

这条链路必须存在，否则：

- App 重开后内容会丢
- 深链接打不开
- 分享页和纪要页无法解耦

## 12. 角色页、会议页、纪要页的推荐数据流

推荐按下面这条主链路接：

### 12.1 角色页

职责：

- 选默认人物，或做文件导入
- 形成完整 bundle：`profile + nodes + agents`
- 选择本次参会的 `selectedAgentIds`

输出给会议页：

```ts
{
  bundle,
  selectedAgentIds
}
```

### 12.2 会议页

职责：

- 维护 setup 参数
- 发起 `arena/stream`
- 渲染实时消息
- 支持 interrupt / continue
- 落 runId

输出给纪要页：

```ts
{
  runId,
  run,
  links
}
```

### 12.3 纪要页

职责：

- 渲染最终标题、共识、分歧、建议
- 展示参与人格和关键对话
- 可按需生成海报

必要时自己回读：

```txt
GET /api/arena/runs/:runId
```

## 13. 如果角色页已经做好，鸿蒙会议页最小接入方案

如果你现在想先把会议链路打通，不追求一次把所有细节都补齐，最小方案如下：

1. 角色页确保能拿到一个完整 `bundle.agents`
2. 会议页允许用户勾选至少 `2` 个角色
3. 会议页允许填写 `topic`
4. 会议页固定使用默认值：
   - `mode = chat`
   - `roundCount = 3`
   - `maxMessageChars = 180`
5. 直接接 `POST /api/arena/stream`
6. 先只处理这 4 类事件：
   - `message`
   - `summary`
   - `done`
   - `error`
7. 完成后把 `runId` 传给纪要页
8. 纪要页支持 `GET /api/arena/runs/:runId`

这套做完，基本就能先连通。

## 14. 如果要完整对齐 web，还要补哪些能力

要和 web 真正一致，还要补下面这些：

- `speaker_started / speaker_delta / speaker_completed` 的实时打字效果
- `summary_delta` 的实时总结区
- `GET /api/arena/history` 的历史记录面板
- `POST /api/arena/sessions/:sessionId/interrupt` 的中途打断
- “打断并按引导继续”的自动续聊
- `POST /api/arena/poster` 的信息图输出
- 角色融合人格的接入

## 15. 服务器重新部署时不能漏的设置

如果后面你们换机器或重传环境变量，至少要确认这些配置还在：

```env
TARGET_MODEL=Pro/MiniMaxAI/MiniMax-M2.5
REASONING_EFFORT=xhigh
FALLBACK_MODEL=claude-opus-4-6
FALLBACK_EFFORT=max
CCS_PROFILE=hackhathon-glm
SILICONFLOW_FALLBACK_MODELS=Pro/MiniMaxAI/MiniMax-M2.5,Pro/moonshotai/Kimi-K2.5
ARENA_SPEAKER_TIMEOUT_MS=90000
ARENA_SUMMARY_TIMEOUT_MS=120000
ARENA_RUN_TIMEOUT_MS=480000
```

含义：

- `TARGET_MODEL`：当前主模型
- `SILICONFLOW_FALLBACK_MODELS`：当前回退模型链
- `CCS_PROFILE`：当前 Claude Code SDK 走的桥接 profile
- `ARENA_*_TIMEOUT_MS`：会议生成和总结超时阈值

这些不是鸿蒙端上传时要传的字段，但它们决定了线上会议页是否真的能跑通。

## 16. 推荐给鸿蒙开发的落地顺序

建议不要一上来就照搬 web 全量 UI，而是按这个顺序：

1. 先打通角色页 -> 会议页的数据传递
2. 再接 `POST /api/arena/stream`
3. 先只渲染 `message / summary / done / error`
4. 再补 `runId` -> 纪要页回读
5. 再补 `speaker_delta` 和 `summary_delta`
6. 最后再补 interrupt / continue / poster / history

## 17. 一份可直接照抄的最小请求示例

```json
{
  "topic": "我现在要不要离开这份长期消耗我的工作？",
  "mode": "chat",
  "selectedAgentIds": [
    "example-agent-1",
    "example-agent-2"
  ],
  "agents": [
    {
      "agentId": "example-agent-1",
      "displayName": "我·冲劲最强的时候",
      "personId": "example-person",
      "avatarSeed": "example-1",
      "timeLabel": "2020",
      "stageLabel": "高速推进期",
      "keyEvent": "进入高压环境后快速证明自己",
      "knownFacts": ["连续高强度工作", "追求外部认可"],
      "sourceEvidence": [],
      "traits": ["冲劲强", "控制感强"],
      "values": ["成长", "胜利"],
      "goal": "继续向上突破",
      "fear": "停下来就被淘汰",
      "voiceStyle": "锋利直接",
      "knowledgeBoundary": "只知道当时的处境",
      "forbiddenFutureKnowledge": true,
      "stanceSeed": "支持继续冲"
    },
    {
      "agentId": "example-agent-2",
      "displayName": "我·开始重建边界的时候",
      "personId": "example-person",
      "avatarSeed": "example-2",
      "timeLabel": "2024",
      "stageLabel": "重建期",
      "keyEvent": "从透支状态里退出来重建节奏",
      "knownFacts": ["意识到长期透支不可持续", "开始重建边界"],
      "sourceEvidence": [],
      "traits": ["克制", "自省"],
      "values": ["稳定", "清醒"],
      "goal": "做可持续的选择",
      "fear": "再次失去自我",
      "voiceStyle": "平静但坚定",
      "knowledgeBoundary": "只知道当时的处境",
      "forbiddenFutureKnowledge": true,
      "stanceSeed": "支持先收缩再判断"
    }
  ],
  "roundCount": 3,
  "maxMessageChars": 180
}
```

## 18. 最后一条判断标准

鸿蒙会议页是否真的接通，不看页面长得像不像 web，而看下面 4 件事是否成立：

1. 能从角色页拿到完整 `agents[]`
2. 能流式收到会议消息并渲染
3. 能拿到 `runId / sessionId`
4. 纪要页能只靠 `runId` 重新拉回整场会议结果

这 4 条都满足，会议主链路就算真正接通了。
