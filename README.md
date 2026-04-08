# xiaohongshu_hackathon_2026.4

时序人格局 Hackathon Workspace，小红书黑客松巅峰赛项目。

当前目录采用轻量多端结构：

```text
hackhathon/
  backend/   # Node.js + TypeScript API
  harmony/   # HarmonyOS ArkTS 前端
  shared/    # 三端共享的领域契约和预设数据
  web/       # Web 前端
```

## 当前实现原则

- P0 只处理已发生的人生阶段，不做未来预测。
- 输入可以是自述、他人经历或名人传记。
- 后端先提供稳定 demo 逻辑，再逐步接真实模型。
- Multi-Agent 采用“时间线节点 -> PersonaSpec -> Arena 讨论”的最小闭环。
- Claude Code SDK / Agent 机制作为可插拔 runtime 接口预留，模型目标支持 `GLM-5` 和 `GPT-5.4` 切换。

## 共享语义

- [shared/contracts.ts](shared/contracts.ts)
- [shared/presets.ts](shared/presets.ts)

## 页面约定

- 首页 / 角色库
- 角色详情子页
- Arena 议会页
- 结果区 / 总结页

角色详情子页展示人物的详细时间线与阶段节点。

## 当前开发方式

- `web`、`backend`、`harmony` 三条线并行开发
- `shared` 由主线程维护，作为联调语义基线
