# 前端优化建议文档

更新时间：2026-04-08  
适用范围：`web`、`harmony` 两个前端  
对应后端：已部署到服务器的新版本 backend

---

## 1. 先说结论

这轮后端改动之后，前端最值得优先做的不是“换皮”，而是把以下 4 条链路接完整：

1. 讨论页支持用户自定义 `reasoningEffort`
2. 讨论页从一次性请求切到 SSE，实时展示发言过程
3. 输出页从“本地拼文案”升级为“可回放、可分享、可生成海报”
4. Web / Harmony 的类型与接口层统一，不再各自维护一套落后模型

如果只做一件事，优先做第 2 条。  
因为用户当前最强烈的体感问题，会是“不丝滑”、“像卡住了”、“不知道系统有没有在工作”。

---

## 2. 当前前端和新后端的差距

### 2.1 Web 当前状态

当前 [web/src/lib/api.ts](/Users/mychanging/Desktop/hackhathon/web/src/lib/api.ts) 里：

- `runArena(...)` 仍然只调 `POST /api/arena/run`
- 没有传 `reasoningEffort`
- 没有接 `POST /api/arena/stream`
- 没有接 `GET /api/arena/runs/:runId`
- 没有接 `POST /api/arena/poster`
- 失败后会直接 fallback 到 mock，这会掩盖真实线上问题

当前 [web/src/App.tsx](/Users/mychanging/Desktop/hackhathon/web/src/App.tsx) 里：

- 输出区“全息海报”“分享链接”还是占位按钮
- 消息区只能在最终结果返回后一次性渲染
- “耗时 3s”是写死的，不是真实数据

### 2.2 Harmony 当前状态

当前 [harmony/entry/src/main/ets/service/PersonaApi.ets](/Users/mychanging/Desktop/hackhathon/harmony/entry/src/main/ets/service/PersonaApi.ets) 里：

- `runArena(...)` 仍然只调 `POST /api/arena/run`
- `ArenaRunRequest` 没有 `reasoningEffort`
- 没有任何 SSE 消费能力
- 没有分享查询和海报生成能力

这意味着：

- 两个前端都还没吃到新后端最重要的能力
- 目前用户看到的“慢”和“卡”，很大程度是因为前端没有中间态，不一定只是后端慢

---

## 3. 后端现在已经给前端准备好的能力

服务器后端现在可用的关键接口：

- `POST /api/arena/run`
- `POST /api/arena/stream`
- `GET /api/arena/runs/:runId`
- `POST /api/arena/poster`

新增请求字段：

```ts
reasoningEffort?: 'low' | 'medium' | 'high' | 'xhigh'
```

新增流式事件：

- `run_started`
- `phase_started`
- `speaker_started`
- `speaker_delta`
- `speaker_completed`
- `message`
- `phase_completed`
- `summary_started`
- `summary_delta`
- `summary`
- `done`
- `error`

新增返回链接：

```ts
interface ArenaOutputLinks {
  runId: string
  shareApiPath: string
  shareApiUrl?: string
  suggestedSharePath: string
  suggestedShareUrl?: string
}
```

这套结构已经足够支撑“实时讨论页 + 输出页 + 分享页 + 海报页”。

---

## 4. 建议的前端改造优先级

### P0：必须立刻做

1. 讨论页改为优先走 `/api/arena/stream`
2. UI 增加 `reasoningEffort` 选择器
3. 输出页接 `links.runId`
4. 去掉 arena 失败时的静默 mock fallback

### P1：这一版一起做最好

1. 增加“分享页”路由，基于 `GET /api/arena/runs/:runId`
2. 增加“生成海报”按钮，接 `/api/arena/poster`
3. 让输出页支持从服务端结果重建，而不是只依赖内存态

### P2：体验增强

1. 为 `speaker_delta` 做逐字出现效果
2. 为 `summary_delta` 做“主持人正在总结”区域
3. 展示真实 phase 进度和参与者状态
4. 展示真实耗时，而不是写死

---

## 5. 讨论页的具体优化建议

### 5.1 改成双模式请求

建议统一封装成：

- `runArenaSync(...)` 对接 `/api/arena/run`
- `runArenaStream(...)` 对接 `/api/arena/stream`

默认走流式。

只有以下情况退回同步：

- 浏览器或端能力不方便处理 SSE
- 用户明确关闭“实时模式”
- 调试场景

### 5.2 `reasoningEffort` 的产品设计

不要直接对用户暴露英文枚举解释不清。建议前端文案做一层映射：

- `low`：快
- `medium`：均衡
- `high`：深入
- `xhigh`：极深

建议默认值：

- Web：`medium`
- Harmony：`medium`

不要默认 `xhigh`。  
因为移动端用户会更敏感于等待时间。

### 5.3 SSE 页面状态机

建议前端内部不要只存 `messages[]`，而要存一个完整运行态：

```ts
interface ArenaLiveState {
  status: 'idle' | 'running' | 'summarizing' | 'done' | 'error'
  runId?: string
  phase?: string
  currentSpeakerId?: string
  messages: ArenaMessage[]
  pendingDrafts: Record<string, { text: string; channel: 'text' | 'thinking' }>
  summaryDraft?: string
  finalResult?: ArenaRun
  links?: ArenaOutputLinks
  error?: string
}
```

原因：

- `speaker_delta` 不应该直接写进最终 `messages`
- `message` 才是最终落定消息
- `summary_delta` 是草稿，不是最终 summary

### 5.4 推荐的事件消费逻辑

#### `speaker_started`

- 高亮当前发言人物
- 创建一条“正在输入”的临时气泡

#### `speaker_delta`

- 更新临时气泡内容
- 如果是 `thinking`，不要直接展示“模型思维全文”
- 建议只映射成轻量状态，如“正在组织观点”

#### `message`

- 用正式消息替换临时气泡
- 这是最终可持久化的聊天内容

#### `speaker_completed`

- 结束当前人物 loading 状态
- 可用于记录该轮耗时

#### `summary_started`

- 把页面状态切到 `summarizing`

#### `summary_delta`

- 更新总结草稿区域

#### `done`

- 写入最终 `ArenaRun`
- 保存 `links`
- 页面进入可分享/可海报状态

### 5.5 错误处理不要再“悄悄 mock”

现在 web 的 arena 请求失败会 fallback 到 mock。  
这个行为在 demo 早期有用，但上线后会有两个严重问题：

1. 真实服务挂了，前端看起来像“还能用”
2. 用户看到的是假数据，后续分享/海报/回放都对不上

建议：

- `presets` 可以保留 mock 兜底
- `arena` 不要再 silent fallback
- arena 出错必须给用户真实错误

---

## 6. 输出页 / 分享页的优化建议

### 6.1 输出页不要只依赖当前页面内存

当前输出区是跟当前讨论页强绑定的。  
建议拆成两层：

1. 讨论完成后立即展示本地结果
2. 同时以 `runId` 作为主键，允许任何时候通过 `GET /api/arena/runs/:runId` 重建页面

这样可以解决：

- 页面刷新后内容丢失
- 分享给别人打不开
- Harmony 从讨论页跳转后状态断掉

### 6.2 分享页建议结构

建议前端新增一个独立路由：

- Web：`/share/:runId`
- Harmony：一个独立详情页，参数传 `runId`

页面加载逻辑：

1. 读取 `runId`
2. 请求 `GET /api/arena/runs/:runId`
3. 展示：
   - 标题
   - 参与者
   - 消息时间线
   - 总结
   - 再生成海报按钮

### 6.3 输出页里的按钮设计建议

“导出选项”至少应该变成真实三件事：

- `复制文本`
- `打开分享页`
- `生成海报`

不建议再保留“按钮点了只 alert”的状态。  
这会让用户觉得产品没有完成。

---

## 7. 海报链路的前端建议

### 7.1 调用方式

推荐优先传 `runId`：

```json
{
  "runId": "run-xxx",
  "stylePreset": "poster",
  "aspectRatio": "3:4",
  "language": "zh"
}
```

理由：

- 负载更小
- 后端可以从数据库重建
- 分享页和输出页都能复用

### 7.2 海报 UI 不要做成“一点就没反应”

海报生成比复制文本慢得多。建议按钮分 4 态：

- 默认：`生成海报`
- 请求中：`正在生成海报...`
- 成功：展示缩略图 + 下载/打开
- 失败：展示错误 + 重试

### 7.3 推荐默认参数

- `stylePreset`: `poster`
- `aspectRatio`: `3:4`
- `language`: `zh`

因为当前产品的使用场景更偏中文移动端分享。

---

## 8. Web 端的具体实现建议

### 8.1 类型层先补齐

优先更新 [web/src/types.ts](/Users/mychanging/Desktop/hackhathon/web/src/types.ts)：

- `ArenaRunRequest.reasoningEffort`
- `ArenaOutputLinks`
- `ArenaStreamEvent`
- `ArenaPosterResponse`

### 8.2 API 层建议新增的方法

建议在 [web/src/lib/api.ts](/Users/mychanging/Desktop/hackhathon/web/src/lib/api.ts) 新增：

- `runArenaStream(...)`
- `loadArenaRun(runId: string)`
- `generateArenaPoster(...)`

其中 `runArenaStream(...)` 建议返回事件订阅器或 async iterator，不要把 SSE 逻辑散落在 `App.tsx` 里。

### 8.3 组件拆分建议

当前 [web/src/App.tsx](/Users/mychanging/Desktop/hackhathon/web/src/App.tsx) 比较重。建议拆成：

- `ArenaComposer`
- `ArenaLiveStream`
- `ArenaSummaryPanel`
- `ArenaExportPanel`
- `SharePage`

这样后面你朋友接手输出页时，不需要在一个超大文件里翻逻辑。

### 8.4 UI 动效建议

Web 端最适合做三种轻动效：

- 当前 speaker 卡片脉冲高亮
- 临时消息逐字出现
- summary 区域的“正在收束”渐显

不要做花哨 loading。  
用户真正需要的是“知道系统在推进哪一步”。

---

## 9. Harmony 端的具体实现建议

### 9.1 先补模型定义

优先更新：

- [harmony/entry/src/main/ets/common/Models.ets](/Users/mychanging/Desktop/hackhathon/harmony/entry/src/main/ets/common/Models.ets)

至少补：

- `reasoningEffort`
- `ArenaOutputLinks`
- `ArenaStreamEvent`
- `ArenaPosterResponse`

### 9.2 网络层建议

当前 [PersonaApi.ets](/Users/mychanging/Desktop/hackhathon/harmony/entry/src/main/ets/service/PersonaApi.ets) 只有普通 JSON 请求。  
建议新增：

- `runArenaStream(...)`
- `getArenaRun(runId)`
- `generateArenaPoster(...)`

如果 Harmony 原生对 SSE 处理不方便，可以先走两步方案：

1. 第一版继续调 `/api/arena/run`
2. 但 UI 明确加 phase loading 和真实状态提示

不过中期还是建议接入流式，否则 Harmony 端会一直显得比 Web“笨重”。

### 9.3 页面结构建议

Harmony 更适合拆成：

- `讨论配置区`
- `过程流区`
- `总结区`
- `输出操作区`

不要把“发言流”和“总结结果”混在一个滚动区里。  
移动端里这会让用户非常难定位当前阶段。

### 9.4 性能建议

Harmony 端不要每来一个 delta 就整页刷新。  
建议：

- 临时草稿单独状态维护
- 正式消息才进最终列表
- `ForEach` 尽量只绑定最终 `messages`

否则流式事件一多，列表重绘会很明显。

---

## 10. 前后端契约建议

为了避免 Web 和 Harmony 再各自漂移，建议把共享契约抽出来。

最低成本做法：

1. 在 `shared/` 下维护一份 `arena-contract.md` 或 JSON schema
2. Web / Harmony 都按这份契约对齐
3. 每次后端加字段，先更新契约，再更新两个前端

当前最容易漂移的字段就是：

- `reasoningEffort`
- SSE 事件类型
- `links`
- `poster` 响应结构

---

## 11. 推荐的落地顺序

### 第一阶段：1 天内可完成

1. Web 接 `reasoningEffort`
2. Web 去掉 arena mock fallback
3. 输出页接 `links`
4. 补“分享链接”“海报生成”按钮的真实接口

### 第二阶段：1 到 2 天

1. Web 改为 SSE 实时流
2. Web 新增 `/share/:runId`
3. 输出页支持海报生成结果展示

### 第三阶段：再跟进 Harmony

1. Harmony 补新模型
2. Harmony 先接同步版输出链路
3. Harmony 再做 SSE 实时页

这是最稳的顺序。  
先把 Web 做成完整样板，再把同一套交互迁到 Harmony。

---

## 12. 我对你朋友的直接建议

如果你把这份文档转给做前端的人，我建议他先做这三件事：

1. 把 `runArena` 改造成支持 `reasoningEffort`
2. 把讨论页切到 `/api/arena/stream`
3. 把输出区接上 `/api/arena/runs/:runId` 和 `/api/arena/poster`

只要这三件完成，产品观感会立刻从“demo”变成“能交付”。

