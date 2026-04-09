# Harmony

HarmonyOS 客户端目录：

```txt
/Users/mychanging/Desktop/hackhathon/harmony
```

该端使用 ArkTS + ArkUI 实现，负责把 Time Persona Arena 的移动端体验落到 HarmonyOS 设备上。

## 1. 当前能力

Harmony 端已经不再依赖本地 mock，而是直接接真实后端：

- 加载预设人物列表
- 获取人物 bundle（profile + timeline + agents）
- 创建自定义角色
- 通过文件导入角色材料
- 发起 Arena 讨论 / 辩论
- 查看历史纪要与记录
- 查看分享与海报相关结果

## 2. 已注册页面

当前 `entry/src/main/resources/base/profile/main_pages.json` 中注册的页面包括：

- `pages/Index`
- `pages/ProfileDetail`
- `pages/SmartQuestionPrep`
- `pages/Arena`
- `pages/CreateRole`
- `pages/ExplorePersonas`
- `pages/SummaryDetailPage`
- `pages/SummaryListPage`
- `pages/PosterPreviewPage`
- `pages/MeetingParticipantPage`
- `pages/MeetingProfilePickerPage`
- `pages/MeetingChatPage`

其中：

- `Index` 是当前主入口，承载角色库 / 讨论 / 记录等主要流转。
- `CreateRole` 负责自定义角色与导入入口。
- `SummaryListPage` / `SummaryDetailPage` 负责历史结果浏览。
- `PosterPreviewPage` 对接海报结果查看。
- `Meeting*` 页面用于会议记录、人物选择与聊天联动体验。

## 3. 关键代码位置

- `entry/src/main/ets/common/Models.ets`
  Harmony 端的数据模型定义，与后端返回结构对齐。
- `entry/src/main/ets/service/PersonaApi.ets`
  所有网络请求和 Arena 请求压缩逻辑都在这里。
- `entry/src/main/ets/pages/Index.ets`
  当前主页面，负责角色加载、导入、选人、发起讨论和记录列表。
- `entry/src/main/ets/components/`
  复用 UI 组件。
- `entry/src/main/ets/common/styles/`
  颜色、字号、间距、圆角等设计令牌。
- `entry/src/main/ets/utils/`
  图片缓存、网络优化等工具能力。

## 4. 后端接入

当前客户端走真实 API，而不是本地静态数据。核心链路包括：

### 默认人物

- `GET /api/presets`
- `GET /api/profiles/:profileId`

### 自定义人物

- `POST /api/timeline/parse`
- `POST /api/agents/build`

### 文件导入

- `POST /api/profile-imports`

### 人格融合

- `POST /api/agents/merge`

### Arena / 纪要 / 海报

- `POST /api/arena/run`
- `POST /api/arena/stream`
- `POST /api/arena/sessions/:sessionId/messages`
- `POST /api/arena/sessions/:sessionId/interrupt`
- `GET /api/arena/history`
- `GET /api/arena/runs/:runId`
- `POST /api/arena/poster`

## 5. 默认后端地址

当前 `entry/src/main/ets/service/PersonaApi.ets` 中默认的服务地址是：

```txt
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com
```

如果你要切到本地服务，直接修改 `PersonaApi.ets` 里的 base URL 即可。

## 6. 运行方式

建议使用 DevEco Studio：

```text
Open Folder -> harmony/
```

建议环境：

- DevEco Studio
- HarmonyOS SDK `6.0.2(22)`
- 可用的 Previewer 或真机调试环境

当前工程配置要点：

- `targetSdkVersion`: `6.0.2(22)`
- `compatibleSdkVersion`: `6.0.2(22)`
- `deviceTypes`: `phone`, `tablet`
- 已声明权限：`ohos.permission.INTERNET`

## 7. 构建与调试说明

- 首次打开工程后需要同步 `oh_modules`
- 若命令行 `hvigor` 报 `SDK component missing`，说明本机 SDK 组件未装齐，优先回到 DevEco Studio 补齐后再运行
- 本地签名材料、调试证书、导出的 `.hap` 不应提交到仓库
- `signing/`、临时请求体、编辑器规则文件已建议加入忽略列表

## 8. 相关文档

- `API_DOCUMENTATION.md`
- `API_INTEGRATION_GUIDE.md`
- `HARMONYOS_FEATURES.md`
- `HARMONY_BACKEND_API_INTEGRATION.md`
- `HARMONY_MEETING_INTEGRATION_GUIDE.md`
- `HARMONY_MEETING_PAGE_GUIDE.md`

如果要继续接入或排查问题，优先从 `PersonaApi.ets` 和 `Models.ets` 开始，再回到具体页面联调。
