# Harmony

当前 HarmonyOS 前端直接修改于：

`/Users/mychanging/Desktop/hackhathon/harmony`

## 当前页面

- `pages/Index`
  单页移动工作台，底部三按钮切换 `角色 / 议会 / 纪要`
- `pages/ProfileDetail`
  旧版角色详情子页，当前保留作参考
- `pages/Arena`
  旧版议会子页，当前保留作参考

## 数据结构

- `entry/src/main/ets/common/Models.ets`
- `entry/src/main/ets/data/MockData.ets`
- `entry/src/main/ets/service/PersonaApi.ets`

当前首页已经接入真实后端优先的 service 层：

- 默认人物：
  - `GET /api/presets`
  - `GET /api/profiles/:profileId`
- 自定义人物：
  - `POST /api/timeline/parse`
  - `POST /api/agents/build`
- Arena：
  - `POST /api/arena/run`

当后端不可达时，首页角色列表仍会回退到本地 mock，方便纯 UI 演示。

## 联网说明

当前 `PersonaApi.ets` 默认会依次尝试以下后端地址：

- `http://192.168.51.148:3030`
- `http://10.0.2.2:3030`
- `http://127.0.0.1:3030`
- `http://localhost:3030`

说明：

- `192.168.51.148` 是这台开发机在当前网络下的局域网 IP，适合手机真机直连。
- 如果后续切换 Wi-Fi，这个 IP 可能变化，需要同步修改 `entry/src/main/ets/service/PersonaApi.ets`。
- 工程已经补上 `ohos.permission.INTERNET`，否则真机无法访问后端。

## 官方文档参考

- HarmonyOS 官方知识地图中的 ArkUI 路由与页面组织相关文档
- `使用Navigation导航`
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-navigation
- `HTTP数据请求`
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/http-request
- `状态管理最佳实践`
  https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-status-management
- HarmonyOS 官方 Codelab 中关于 `router.pushUrl` / 页面参数传递的示例
  当前 MVP 采用更稳的 `router.pushUrl + getParams` 方式做多页跳转

## 说明

当前机器可以通过 DevEco Studio 自带的 `hvigor` 拉起命令行构建，但这套 SDK 组件当前不完整，命令行预览构建会报 `SDK component missing`。建议在 DevEco Studio 中补齐 SDK 组件后，再打开 `harmony` 目录执行预览或真机运行。
