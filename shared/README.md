# Shared Contract

这个目录存放三端共享的最小产品语义：

- `contracts.ts`
  定义时间线节点、阶段 Persona、Arena 对话和 API 请求/响应结构。
- `presets.ts`
  定义演示预设人物，供 Web、Harmony 和 Backend 统一使用。

当前约束：

- P0 只处理已发生的人生阶段，不做未来预测。
- 每个人物建议抽取 `3-6` 个时间节点。
- Arena 只做稳定的 `2-3` 人对话，不做高轮次自由辩论。
- 节点 Persona 必须来自时间线事实，不允许完全凭空设定。
