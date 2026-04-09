# Time Persona Arena

小红书黑客松项目仓库。这个项目把人物传记、自述或聊天材料拆解成时间线节点，再把不同人生阶段的人格体放进同一场 Arena 里讨论同一个问题，最终输出讨论记录、总结、历史回放和分享海报。

当前仓库已经不是单一 Demo，而是一个可联调的多端工作区：

```text
hackhathon/
  backend/   # Node.js + TypeScript API / Arena runtime / 导入与海报生成
  d/         # React + Vite Web 前端（历史目录名，实际承担 Web 端）
  harmony/   # HarmonyOS ArkTS 客户端
  shared/    # 共享领域契约与预设人物
  deploy/    # 线上入口配置
```

## 1. 项目在做什么

项目的核心目标是把“一个人的不同人生阶段”产品化成可讨论、可回放、可分享的结构化体验：

1. 输入人物材料
   支持预设人物，也支持手动材料、微信导出、聊天记录上传。
2. 解析时间线
   从 biography / 导入材料中提取 `3~6` 个关键节点。
3. 生成人格体
   每个节点对应一个 `PersonaSpec`，只允许知道当时已经发生的事实，不允许偷看未来。
4. 运行 Arena
   让 2 个以上阶段人格围绕同一议题进行聊天或辩论。
5. 沉淀结果
   输出消息流、总结、历史记录、分享页和海报资源。

## 2. 核心能力

### 2.1 人物来源

- 预设人物：通过后端导入的默认角色库进入系统。
- 自定义人物：前端粘贴 biography，走 `timeline/parse -> agents/build` 两段式链路。
- 文件导入：统一走 `POST /api/profile-imports`，支持：
  - `manual`
  - `wechat`
  - `chat`

### 2.2 Arena 讨论能力

- 支持 `chat` / `debate` 两种模式。
- 支持同步接口和 SSE 流式接口。
- 支持用户在讨论中插入新消息。
- 支持中断会话并保留阶段性结果。
- 支持历史 run 回放与继续续聊。
- 支持人格融合，生成新的合成人格参与讨论。

### 2.3 结果沉淀与分享

- 保存 Arena 结果，提供 `runId` 供回放。
- 生成分享页与公开访问链接。
- 生成信息图 / 海报资源。
- 后端把生成资源通过 `/generated/*` 暴露出来。

### 2.4 多端协同

- `backend/` 提供 API、运行时、导入、持久化、海报生成。
- `d/` 提供 Web Arena Studio、分享页、信息图页。
- `harmony/` 提供 HarmonyOS 移动端角色库、创建角色、讨论、纪要与海报页。
- `shared/` 作为三端共享语义基线，避免类型和字段漂移。

## 3. 目录说明

| 目录 | 作用 |
| --- | --- |
| `backend/` | Express + TypeScript 服务，负责人物导入、时间线解析、人格构建、Arena 运行、海报生成、静态资源输出 |
| `d/` | React 19 + Vite Web 前端，包含 Arena Studio、分享页、历史回放、海报入口 |
| `harmony/` | HarmonyOS ArkTS 应用，包含角色库、导入、Arena、纪要、会议记录等页面 |
| `shared/` | 共享契约与预设数据，当前核心文件是 `contracts.ts` 和 `presets.ts` |
| `deploy/` | 当前线上入口配置，仓库中包含 `zeabur-ingress.yaml` |
| `docker-compose.yml` | 本地 PostgreSQL 16 开发环境 |

## 4. 技术栈

### 后端

- Node.js
- TypeScript
- Express 5
- PostgreSQL
- Zod
- Multer
- Claude Agent SDK / Claude Code
- SiliconFlow 兼容模型回退

### Web

- React 19
- React Router 7
- Vite
- TypeScript

### HarmonyOS

- ArkTS
- ArkUI
- NetworkKit
- DevEco Studio / HarmonyOS SDK 6.0.2(22)

## 5. 共享数据模型

`shared/contracts.ts` 定义了三端共用的核心结构：

- `TimelineNode`
- `PersonaSpec`
- `PresetProfile`
- `ArenaMessage`
- `ArenaSummary`
- `ArenaRun`

当前产品约束：

- 只讨论已经发生过的人生阶段，不做未来预测。
- 节点人格必须来源于时间线事实，不能完全凭空设定。
- 默认讨论聚焦 2~3 人格的小规模高质量对话。

## 6. 端到端调用流程

### 6.1 默认人物

```text
GET /api/presets
  -> GET /api/profiles/:profileId
  -> 选择阶段人格
  -> POST /api/arena/run 或 /api/arena/stream
  -> GET /api/arena/runs/:runId
  -> POST /api/arena/poster
```

### 6.2 自定义 biography

```text
POST /api/timeline/parse
  -> POST /api/agents/build
  -> POST /api/arena/run 或 /api/arena/stream
```

### 6.3 文件导入

```text
POST /api/profile-imports
  -> 返回完整 bundle（profile + nodes + agents）
  -> 直接进入 Arena 或角色详情链路
```

## 7. 快速启动

### 7.1 环境准备

建议本地准备：

- Node.js 20+
- npm
- Docker / Docker Compose
- DevEco Studio（若需要运行 Harmony 端）

### 7.2 启动 PostgreSQL

在仓库根目录执行：

```bash
docker compose up -d
```

默认数据库连接：

```txt
postgresql://postgres:postgres@127.0.0.1:54329/time_persona
```

### 7.3 启动后端

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

默认端口：`3030`

`backend/.env.example` 中当前最关键的变量包括：

- `DATABASE_URL`
- `TARGET_MODEL`
- `REASONING_EFFORT`
- `SILICONFLOW_API_KEY`
- `PROFILE_IMPORT_MAX_FILE_SIZE_MB`
- `POSTER_IMAGE_API_KEY`

### 7.4 启动 Web

```bash
cd d
npm install
npm run dev
```

默认开发地址会请求 `http://localhost:3030`。如需覆盖：

```bash
VITE_API_BASE_URL=http://localhost:3030 npm run dev
```

### 7.5 启动 HarmonyOS 客户端

建议直接用 DevEco Studio 打开 `harmony/`：

1. 安装 HarmonyOS SDK `6.0.2(22)`
2. 同步 `oh_modules`
3. 通过 Previewer 或真机运行

注意：

- 工程已申请 `ohos.permission.INTERNET`
- 当前命令行构建是否可用取决于本机 SDK 组件是否完整
- 本地签名材料、`.hap` 产物和调试证书不应提交到仓库

## 8. API 概览

当前后端的主要接口包括：

- `GET /health`
- `GET /api/presets`
- `GET /api/profiles/:profileId`
- `POST /api/timeline/parse`
- `POST /api/agents/build`
- `POST /api/profile-imports`
- `POST /api/agents/merge`
- `POST /api/arena/run`
- `POST /api/arena/stream`
- `POST /api/arena/sessions/:sessionId/messages`
- `POST /api/arena/sessions/:sessionId/interrupt`
- `GET /api/arena/history`
- `GET /api/arena/runs/:runId`
- `POST /api/arena/poster`

更完整说明见：

- `backend/API_DOCUMENTATION.md`
- `backend/PROFILE_IMPORT_API_DOCUMENTATION.md`
- `harmony/API_DOCUMENTATION.md`

## 9. 当前仓库状态

已经落地的部分：

- 后端基础 API、SSE Arena、历史记录、分享页数据源
- Web 端 Arena Studio、历史回放、分享页、信息图页
- Harmony 端角色库、创建角色、Arena、纪要、会议记录相关页面
- 人格融合、文件导入、海报生成链路

当前仍需注意的现实问题：

- 长文本导入是慢请求，经过公网网关时可能超时
- Harmony 命令行构建依赖完整 SDK 组件，不完整时需回到 DevEco Studio
- `harmony/signing/`、临时请求体、技能缓存等本地文件不应推送

## 10. 相关文件

- `shared/contracts.ts`
- `shared/presets.ts`
- `backend/src/server.ts`
- `backend/src/domain.ts`
- `d/src/pages/ArenaStudio.tsx`
- `harmony/entry/src/main/ets/service/PersonaApi.ets`

如果你要继续开发，建议从 `shared/` 读字段，再看 `backend/src/server.ts` 的接口入口，最后分别进入 `d/` 和 `harmony/` 对应页面联调。
