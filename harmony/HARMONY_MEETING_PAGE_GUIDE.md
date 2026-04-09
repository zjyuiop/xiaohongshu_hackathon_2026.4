# 鸿蒙会议页指导文档（基于 Web 讨论页）

最后核对时间：2026-04-09  
适用仓库：`/Users/mychanging/Desktop/hackhathon`  
目标范围：只覆盖鸿蒙 `会议` 页面，以及它与已经完成的 `角色` / `纪要` 页之间的连接方式。

## 1. 先说结论

当前 Web 端的讨论页不是一个“输入议题然后等结果”的简单页面，而是一个完整工作台：

- 左侧是人格素材和历史入口
- 中间是开局设定与实时讨论现场
- 右侧是结果、分享和海报出口

鸿蒙端不要照抄桌面三栏布局，要保留它的行为，再改成移动端结构。  
对当前项目来说，最稳的方案是：

1. 保留 `Index.ets` 作为三 tab 容器
2. `角色` 页负责选人物、选阶段人格、进入会议
3. `会议` 页负责 setup、stream、interrupt、continue、live transcript
4. `纪要` 页负责 summary、history、run 回放入口、poster/share 出口

一句话概括：`角色` 负责“准备输入”，`会议` 负责“跑过程”，`纪要` 负责“看结果和回放”。

## 2. 这份文档参考了哪些代码

- Web 会议页：`d/src/pages/ArenaStudio.tsx`
- Web API 封装：`d/src/lib/api.ts`
- Web 类型：`d/src/types.ts`
- 鸿蒙当前入口：`harmony/entry/src/main/ets/pages/Index.ets`
- 鸿蒙当前会议页组件：`harmony/entry/src/main/ets/components/ArenaTab.ets`
- 鸿蒙当前纪要页组件：`harmony/entry/src/main/ets/components/RecordsTab.ets`
- 鸿蒙当前数据模型：`harmony/entry/src/main/ets/common/Models.ets`
- 鸿蒙当前服务层：`harmony/entry/src/main/ets/service/PersonaApi.ets`
- 后端接口基线：`backend/API_DOCUMENTATION.md`

## 3. Web 会议页真正包含什么能力

Web `ArenaStudio` 可以拆成 3 块能力，而不是 1 个页面：

### 3.1 素材区

- 载入默认人物 `GET /api/presets` + `GET /api/profiles/:profileId`
- 导入自定义人物 `POST /api/timeline/parse` + `POST /api/agents/build`
- 人格融合 `POST /api/agents/merge`
- 选择 2 到 3 个阶段人格参会
- 查看历史 run 列表 `GET /api/arena/history`

### 3.2 会场区

- 配置 `topic / mode / roundCount / maxMessageChars / guidance`
- 默认走 `POST /api/arena/stream`
- 按 SSE 事件实时渲染消息、草稿、总结
- 支持中断 `POST /api/arena/sessions/:sessionId/interrupt`
- 支持基于当前结果继续 `continueFromRunId + sessionId`

### 3.3 结果区

- 展示当前 run 的 summary
- 打开分享页 `GET /api/arena/runs/:runId`
- 生成 poster `POST /api/arena/poster`

对鸿蒙来说，会议页至少要把第 3.2 块完整接住；第 3.1 和第 3.3 的能力则分别和 `角色` / `纪要` 页联动。

## 4. 鸿蒙端应该怎么拆

### 4.1 不建议做的事

- 不要把 web 的三栏拖拽、可折叠侧边栏直接搬到手机上
- 不要在会议页里重新实现完整角色库
- 不要把历史列表塞回会议页顶部，手机上会挤爆

### 4.2 推荐结构

继续沿用你们现在的 `Index.ets` 三 tab 架构：

- `Tab 0 角色`
  - 负责选择人物
  - 负责选择 2 到 3 个阶段人格
  - 负责把 `topic` 初始化成 suggested topic
  - 点击“进入会议”后切到 `Tab 1`

- `Tab 1 会议`
  - 只负责这一次会话的 setup 和 live discussion
  - 上半段是“开局设定”
  - 下半段是“讨论现场”
  - 运行中支持中断、人工 steer、继续

- `Tab 2 纪要`
  - 顶部展示当前 run 的 summary
  - 下方展示 `history`
  - 点击历史卡片后，先载入 run，再跳回 `Tab 1` 做回放或继续

## 5. 会议页的信息架构

会议页建议按移动端改成两段式，而不是三栏式。

### 5.1 顶部状态区

保留 web 的“状态感”，但压缩成移动端卡片：

- 当前人物名
- 已选人格数
- 当前状态：`等待发起 / 讨论进行中 / 已打断 / 已完成`
- 当前阶段：例如 `第 2 轮 · 交锋`
- 当前会话 `sessionId` 的简短展示

### 5.2 分段切换：`设定` / `现场`

这是移动端最关键的替代设计。

- `设定`
  - 选中人格横向 chips
  - topic 输入框
  - guidance 输入框
  - mode 切换：`chat / debate`
  - 高级配置折叠区：`roundCount / maxMessageChars`
  - 主按钮：`启动讨论`

- `现场`
  - 消息流
  - 流式草稿气泡
  - live summary
  - 人工 steer 输入框
  - `打断并继续` / `只打断` / `继续这场讨论`

### 5.3 底部动作区

会议页底部只保留和“过程”直接相关的操作：

- 运行前：`启动讨论`
- 运行中：`打断`、`打断并按引导继续`
- 已完成：`查看纪要`
- 已打断：`继续这场讨论`

`分享` 和 `海报` 不放在会议页主流程里，交给 `纪要` 页。

## 6. `角色 -> 会议 -> 纪要` 的连接规则

这是当前鸿蒙最需要补齐的部分。

### 6.1 角色页进入会议页

`角色` 页需要给 `会议` 页提供一份稳定输入：

- `selectedProfile`
- `agents`
- `selectedAgentIds`
- `topic`

建议继续由 `Index.ets` 持有这些状态，不必在 tab 切换时重新请求。

角色页上的几个入口统一做成同一动作：

- 角色卡 CTA
- 时间线页 CTA
- “带入议会”按钮

统一执行：

1. 确保已选中至少 2 个阶段人格
2. 如有 suggested topic，用它初始化 `topic`
3. `activeTab = 1`
4. 会议页直接读取当前 `Index.ets` 状态，不再重新拉 profile

### 6.2 会议页写回纪要页

会议页一旦收到 `done` 事件，需要把以下数据写回 `Index.ets` 或独立 store：

- `currentRun`
- `currentLinks`
- `history`
- `summaryTitle`
- `consensus`
- `disagreements`
- `actionableAdvice`
- `narrativeHook`

这样 `纪要` 页可以立即展示本次结果，而不是再发一次新的 run。

### 6.3 纪要页回到会议页

`纪要` 页至少要支持两种回跳：

- 点“回到议会”
  - 直接切回 `activeTab = 1`
  - 如果 `currentRun` 已存在，会议页展示回放内容

- 点历史卡片
  - 先 `GET /api/arena/runs/:runId`
  - 把结果写入 `currentRun`
  - 再切回 `activeTab = 1`
  - 如果 `status === "interrupted"`，会议页显示“继续这场讨论”

## 7. 会议页要接住哪些 web 状态

Web `ArenaStudio` 的核心不是 UI，而是这套状态机。鸿蒙端要抄的是状态，不是布局。

### 7.1 基础状态

- `streaming`
- `interrupting`
- `phaseLabel`
- `activeSessionId`
- `currentRun`
- `currentLinks`
- `streamMessages`
- `liveDrafts`
- `liveSummaryText`
- `error`

### 7.2 建议新增的 ArkTS 状态字段

放在 `Index.ets` 或单独 `MeetingStore` 中：

```ts
@State streaming: boolean = false
@State interrupting: boolean = false
@State phaseLabel: string = ''
@State guidance: string = ''
@State roundCount: number = 3
@State maxMessageChars: number = 180
@State activeSessionId: string = ''
@State streamMessages: ArenaMessage[] = []
@State liveDrafts: LiveDraft[] = []
@State liveSummaryText: string = ''
@State currentRun: ArenaRun | null = null
@State currentLinks: ArenaOutputLinks | null = null
@State historyRuns: ArenaRunHistoryItem[] = []
```

说明：

- `messages` 不应再只是最终结果，要拆成 `streamMessages + liveDrafts`
- `summaryTitle / consensus` 这些可以继续保留给纪要页，但最终来源应来自 `currentRun.summary`

## 8. 鸿蒙会议页的接口策略

### 8.1 默认走流式，不要默认走同步 run

会议页应优先接：

- `POST /api/arena/stream`
- `POST /api/arena/sessions/:sessionId/interrupt`
- `GET /api/arena/history`
- `GET /api/arena/runs/:runId`

保留 `POST /api/arena/run` 作为兜底或调试路径。

原因很简单：

- Web 会议页的体验本来就是流式会场
- 移动端更需要“有反馈”的过程，而不是长时间白屏等待
- `continue`、`interrupt`、`manual steer` 都依赖 `stream + sessionId`

### 8.2 会议页请求体要与 Web 对齐

请求体至少支持：

```ts
interface ArenaRunRequest {
  topic: string
  mode: 'chat' | 'debate'
  selectedAgentIds: string[]
  agents: PersonaSpec[]
  roundCount?: number
  maxMessageChars?: number
  guidance?: string
  continueFromRunId?: string
  sessionId?: string
}
```

注意：

- `agents` 必须传完整列表，不能只传 `selectedAgentIds`
- `selectedAgentIds` 范围依然是 2 到 3 个
- `guidance` 在继续讨论时也要能传

## 9. 需要补齐的数据模型

当前 `Models.ets` 还偏早期，会议页要补齐这些字段：

### 9.1 `ArenaMessage`

至少增加：

- `kind?: 'agent' | 'user'`
- `round?: number`
- `phase?: 'opening' | 'reflection' | 'rebuttal' | 'synthesis' | 'closing'`
- `replyToAgentId?: string`
- `replyToDisplayName?: string`

### 9.2 `ArenaSummary`

至少增加：

- `moderatorNote?: string`
- `debateVerdict?: DebateVerdict`

### 9.3 `ArenaRun`

至少增加：

- `sessionId?: string`
- `continuedFromRunId?: string`
- `status?: 'completed' | 'interrupted'`
- `config?: { roundCount: number; maxMessageChars: number; reasoningEffort: string }`
- `createdAt?: string`

### 9.4 新增类型

- `ArenaOutputLinks`
- `ArenaRunResponseEnvelope`
- `ArenaRunHistoryItem`
- `ArenaPosterAsset`
- `ArenaPosterResponse`
- `ArenaStreamEvent` 系列
- `LiveDraft`

## 10. 会议页 UI 到鸿蒙组件的映射建议

| Web 能力 | 鸿蒙落点 | 说明 |
|---|---|---|
| 已选人格 ribbon | `MeetingHeader` 或 `ArenaTab` 顶部横向 chips | 可左右滑动，点击取消选择 |
| topic + guidance + mode + round | `设定` 分段 | 不要一次全摊开，round/max chars 放高级区 |
| 流式消息列表 | `现场` 分段 + `MessageList` | 需要支持增量更新和自动滚到底 |
| typing draft | `DraftBubble` | 没内容时显示 typing dots |
| live summary | 现场页底部卡片 | 只在 summary 阶段显示 |
| interrupt / continue | 现场页底部固定动作栏 | 动作优先级高于分享 |
| history list | `纪要` 页 | 不再塞进会议页 |
| share / poster | `纪要` 页顶部结果卡 | 属于结果出口，不属于会场 |

## 11. 推荐的代码改造点

### 11.1 `Index.ets`

保留它作为总容器，但职责改成“会话总状态持有者”：

- 持有当前 profile、agents、selectedAgentIds、topic
- 持有 currentRun、history、links
- 持有 meeting 运行时状态
- 负责 tab 切换

### 11.2 `ArenaTab.ets`

从“静态配置卡”升级成真正会议页：

- 增加 `设定 / 现场` segmented
- 增加流式消息区
- 增加 interrupt / continue / steer
- 增加状态头部

### 11.3 `PersonaApi.ets`

至少新增：

- `runArenaStream(request, onEvent)`
- `interruptArenaSession(sessionId)`
- `getArenaHistory(limit)`
- `getArenaRun(runId)`

可作为第二批新增：

- `generateArenaPoster`
- `mergeAgents`

### 11.4 `RecordsTab.ets`

不要继续用 mock 记录做最终交互，改成读取真实 `historyRuns` 和 `currentRun`：

- 顶部展示当前 run summary
- 下方展示历史列表
- 点击卡片时触发 `loadRun + switchTab(1)`

## 12. 建议的实现顺序

### 第一轮

- 扩 `Models.ets`
- 扩 `PersonaApi.ets`
- `Index.ets` 持有 `currentRun + historyRuns + meeting runtime state`

目标：数据结构先齐。

### 第二轮

- 重写 `ArenaTab.ets`
- 先接 `runArenaStream`
- 把 `设定 / 现场` 分段跑通

目标：会议页能实时开跑。

### 第三轮

- 接 `interrupt`
- 接 `continue`
- 接 `loadRun(history card -> tab 1)`

目标：会议页与纪要页连起来。

### 第四轮

- 纪要页读取真实 `history`
- 增加 `查看纪要`、`回到会议`、`继续讨论`
- 最后再补 `poster/share`

目标：三页闭环。

## 13. 最低验收标准

会议页完成后，至少要满足下面 8 条：

1. 从 `角色` 页选择 2 到 3 个阶段人格后，能无刷新进入 `会议` 页
2. `会议` 页能显示当前所选人物和所选人格 chips
3. 启动后使用流式事件更新消息，而不是等整场结束再一次性显示
4. 运行中能看到阶段状态和草稿气泡
5. 中断后状态变成 `interrupted`
6. 从 `纪要` 页点击历史卡片，能把那场 run 载回 `会议` 页
7. 被打断的 run 在 `会议` 页能继续讨论
8. 当前 run 完成后，`纪要` 页能立即看到 summary，不需要手动刷新

## 14. 一句话的落地建议

如果你们现在只差会议页，不要再单独新开一套鸿蒙页面体系。  
最省路径是：以 `Index.ets` 为总壳，重做 `ArenaTab.ets`，让它吃到 web 的 `stream + interrupt + continue + history replay` 这套状态流，再把结果写回 `RecordsTab.ets`。
