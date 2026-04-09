# HarmonyOS Motion Notes

最后更新：2026-04-08

这份笔记记录了本项目在动效层面参考过的华为官方资料，以及已经落地到当前 HarmonyOS 页面中的实现原则。

## 本次查阅的华为官方资料

1. HarmonyOS 技术支持与资源总览
   [https://developer.huawei.com/consumer/cn/hmos/overview/](https://developer.huawei.com/consumer/cn/hmos/overview/)
2. HarmonyOS 应用开发知识地图
   [https://developer.huawei.com/consumer/cn/app/knowledge-map/](https://developer.huawei.com/consumer/cn/app/knowledge-map/)
3. HarmonyOS 设计理念
   [https://developer.huawei.com/consumer/cn/design/concept/](https://developer.huawei.com/consumer/cn/design/concept/)
4. HDC 2023 Codelabs - 转场动画的使用（ArkTS）
   [https://developer.huawei.com/consumer/cn/hdc/hdc2023/codelabs/index.html](https://developer.huawei.com/consumer/cn/hdc/hdc2023/codelabs/index.html)

## 从官方资料提炼出的关键信息

### 1. 动效要和页面结构一起设计

华为官方资源总览把开发指南、API 参考、示例代码、Codelabs 和知识地图放在同一套学习路径里，意味着动效实现不应该只看某一个 API，而应该和导航、布局、状态切换一起设计。

对这个项目来说，重点不是堆更多动画，而是让搜索、筛选、卡片列表和详情跳转形成连续体验。

### 2. HarmonyOS 的视觉语义强调“悬浮、吸引、立体空间”

华为官方设计理念页里，和本项目最相关的关键词有：

- `悬浮`：适用于选择类场景
- `吸引`：强调元素之间的汇聚关系
- `轻拟物`：强调真实、轻盈的立体感
- `立体空间设计`：强调空间秩序
- `舒适圆角`：强调柔和而清晰的卡片边界

落到页面上，更适合使用轻微位移、缩放、透明度和层级阴影，而不是过度夸张的弹跳。

### 3. 官方 Codelab 将转场拆成三类

HDC 2023 的 ArkTS 转场 Codelab 明确覆盖了三类能力：

- 页面间转场
- 组件间转场
- 共享元素转场

这对项目的启发是：

- 当前首页、搜索页优先做好组件级状态转场
- `寻访前人 -> 人物详情` 后续非常适合升级为共享元素转场
- 页面路由的切换节奏，最好和组件动效统一，不要彼此割裂

### 4. 华为官方知识地图里的 UI 路径很适合当前项目

知识地图中当前和项目最相关的部分包括：

- 使用 Navigation 导航
- 构建列表布局
- 开发沉浸式页面
- 开发自定义弹窗

这意味着我们的优化顺序也应该是：

1. 先把列表和筛选的局部动效做顺
2. 再统一页面切换过渡
3. 最后再扩展到分享、导出、弹层等覆盖层体验

## 本次已经落地到项目里的改动

### ExplorePersonas 页面

文件：
`entry/src/main/ets/pages/ExplorePersonas.ets`

已应用的 Harmony 风格动效：

- 标题区、搜索区、分类区、结果区采用分层入场
- 分类 Chip 增加轻微上浮、缩放和阴影，强化“选择类场景”的悬浮感
- 搜索或分类切换时，结果列表先轻微收束，再平滑替换并重新分批出现
- 人物卡片使用透明度 + 位移 + 缩放的层级式入场，减少整页一起出现的生硬感

### 公共动画语义

文件：
`entry/src/main/ets/common/styles/Animation.ets`
`entry/src/main/ets/common/styles/Effects.ets`

已调整：

- 将 `decelerated` 对应到 `Curve.EaseOut`
- 将 `accelerated` 对应到 `Curve.EaseIn`

这样缓动命名和实际语义更一致，后续统一列表刷新、卡片收起和页面退出时更不容易混乱。

## 后续建议

1. 为 `ProfileDetail` 和 `SummaryDetailPage` 补统一的页面进场节奏
2. 给 `RoleCard` / `PersonaAvatar` 增加更轻的按压反馈
3. 在“寻访前人 -> 人物详情”之间尝试头像或卡片容器的共享元素转场
4. 如果后续接入更完整的 Navigation 体系，再统一页面级过渡规范
