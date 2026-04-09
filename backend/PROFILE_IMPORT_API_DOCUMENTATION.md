# 角色导入 API 文档

最后核对时间：2026-04-09  
适用项目：`/Users/mychanging/Desktop/hackhathon/backend`  
目标：给鸿蒙端接入“手动输入 / 微信记录 / 聊天导入”三种角色导入方式。

## 1. 结论先看

当前线上角色导入已经统一成一条后端链路：

1. 鸿蒙上传文件
2. 后端抽取文件文本
3. 后端调用 Claude Code SDK 解析
4. 模型走当前 backend 的 MiniMax / Kimi 配置
5. 后端一次性返回完整 `bundle`

也就是说，鸿蒙端不需要再分开调用：

- `POST /api/timeline/parse`
- `POST /api/agents/build`

新的统一入口是：

```txt
POST /api/profile-imports
```

## 2. 线上实测结果

本节全部是 2026-04-09 基于已部署服务器的真实核对结果，不是本地推断。

### 2.1 Base URL

```txt
https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com
```

### 2.2 `/health` 实测

实测时间：2026-04-09 10:25 UTC

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
  }
}
```

这说明当前线上角色导入链路确实会走：

- Claude Code SDK
- `Pro/MiniMaxAI/MiniMax-M2.5` 主模型
- `Pro/moonshotai/Kimi-K2.5` 作为 SiliconFlow 回退链路

### 2.3 空上传校验实测

公网实测：

```bash
curl -X POST \
  https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/profile-imports \
  -F "importType=manual"
```

返回：

```json
{
  "error": "缺少上传文件字段 file"
}
```

### 2.4 导入耗时现状

这部分是当前接入最关键的事实：

- 公网用一个最小 `txt` 样例做真实导入，命中 `504 Gateway Time-out`
- 服务器本机回环 `http://localhost:3030/api/profile-imports` 在 240 秒内也没有完成返回

结论：

- 接口已经上线
- 参数校验正常
- 但“真实导入”当前是长请求
- 鸿蒙端不能把它当成一个稳定的秒级同步接口

## 3. 接口信息

### 3.1 路径

```txt
POST /api/profile-imports
```

### 3.2 Content-Type

```txt
multipart/form-data
```

### 3.3 文件字段

上传文件字段固定为：

```txt
file
```

## 4. 请求字段

除 `file` 外，其余字段都是普通表单字段。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `importType` | `manual \| wechat \| chat` | 是 | 导入方式 |
| `displayNameHint` | `string` | 否 | 人物名提示，给模型做锚点 |
| `title` | `string` | 否 | 前端给的标题；不传则使用文件名 |
| `profileId` | `string` | 否 | 自定义 profile id；不传则后端自动生成 |
| `file` | `binary` | 是 | 上传文件本体 |

## 5. 三种导入方式怎么传

### 5.1 手动输入

适合上传用户自己整理的人物材料文件。

```txt
importType=manual
file=<txt/md/html/json/...>
```

### 5.2 微信记录导入

适合上传微信聊天记录导出文件。  
这里不是访问本地微信数据库，而是前端把导出文件直接传给 backend。

```txt
importType=wechat
file=<txt/html/json/...>
```

建议尽量上传包含时间、发送者、消息内容的导出格式。

### 5.3 聊天导入

适合上传 AI 对话、访谈记录、普通聊天导出文件。

```txt
importType=chat
file=<txt/md/html/json/...>
```

## 6. 当前支持的文件类型

当前后端支持：

- `.txt`
- `.md`
- `.markdown`
- `.csv`
- `.log`
- `.json`
- `.html`
- `.htm`
- `.xml`
- `.epub`

如果上传其他类型，后端当前会返回错误：

```json
{
  "error": "暂不支持的文件类型: .pdf。当前支持 txt/md/csv/log/json/html/xml/epub"
}
```

## 7. 返回结构

这一节里的“成功响应”当前是根据已经部署的服务端代码结构推断出来的返回格式，不是线上成功样例实测值。  
原因：2026-04-09 的真实样例导入请求在公网 60 秒内被网关超时，服务器本机 240 秒内也没有完成返回。

成功响应结构如下：

```json
{
  "bundle": {
    "profile": {
      "id": "imported-role-k4h82x",
      "displayName": "张三",
      "subtitle": "从聊天材料中提炼的人生节点",
      "category": "self",
      "coverSeed": "zhang-san",
      "biography": "......",
      "highlights": ["......"],
      "suggestedTopics": ["......"]
    },
    "nodes": [
      {
        "nodeId": "imported-role-k4h82x-1",
        "timeLabel": "2020 年前后",
        "stageLabel": "关键转向期",
        "stageType": "turning-point",
        "keyEvent": "......",
        "summary": "......",
        "traits": ["......"],
        "values": ["......"],
        "tensions": ["......"],
        "sourceEvidence": [
          {
            "quote": "......",
            "sourceLabel": "微信聊天记录上传文件"
          }
        ]
      }
    ],
    "agents": [
      {
        "agentId": "imported-role-k4h82x-1-agent",
        "displayName": "张三 · 关键转向期",
        "personId": "imported-role-k4h82x",
        "avatarSeed": "zhang-san-turning-point",
        "timeLabel": "2020 年前后",
        "stageLabel": "关键转向期",
        "keyEvent": "......",
        "knownFacts": ["......"],
        "sourceEvidence": [
          {
            "quote": "......",
            "sourceLabel": "微信聊天记录上传文件"
          }
        ],
        "traits": ["......"],
        "values": ["......"],
        "goal": "......",
        "fear": "......",
        "voiceStyle": "......",
        "knowledgeBoundary": "......",
        "forbiddenFutureKnowledge": true,
        "stanceSeed": "......"
      }
    ],
    "sourceDocument": {
      "id": "uuid",
      "title": "文件标题",
      "filePath": "/abs/path/to/uploaded/file",
      "importedAt": "2026-04-09T10:00:00.000Z",
      "sectionCount": 3
    }
  },
  "import": {
    "importType": "wechat",
    "sourceLabel": "微信聊天记录上传文件",
    "title": "文件标题",
    "originalFileName": "wechat-export.html",
    "mimeType": "text/html",
    "extension": ".html",
    "charCount": 18432,
    "messageCount": 286
  }
}
```

## 8. 前端最关心的字段

鸿蒙端接入时，至少关心这几个字段：

- `bundle.profile`
- `bundle.nodes`
- `bundle.agents`
- `bundle.sourceDocument`
- `import.importType`
- `import.title`
- `import.originalFileName`

如果鸿蒙端要直接进入后续角色页或会议页，优先使用：

- `bundle.profile.id`
- `bundle.agents`
- `bundle.nodes`

## 9. cURL 示例

### 9.1 手动输入

```bash
curl -X POST https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/profile-imports \
  -F "importType=manual" \
  -F "displayNameHint=王小明" \
  -F "title=我的人物材料" \
  -F "file=@/path/to/profile-notes.txt"
```

### 9.2 微信记录导入

```bash
curl -X POST https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/profile-imports \
  -F "importType=wechat" \
  -F "displayNameHint=我" \
  -F "title=微信聊天导出" \
  -F "file=@/path/to/wechat-export.html"
```

### 9.3 聊天导入

```bash
curl -X POST https://hackhathon.69d5c46af2ab61f5dd649c62.servers.onzeabur.com/api/profile-imports \
  -F "importType=chat" \
  -F "title=AI 对话导出" \
  -F "file=@/path/to/chat-export.json"
```

## 10. 错误响应

### 10.1 缺少文件

```json
{
  "error": "缺少上传文件字段 file"
}
```

### 10.2 文件过大

```json
{
  "error": "上传文件过大，当前上限为 15MB"
}
```

### 10.3 字段错误

```json
{
  "error": {
    "formErrors": [],
    "fieldErrors": {
      "importType": ["Invalid enum value"]
    }
  }
}
```

### 10.4 文件类型不支持

```json
{
  "error": "暂不支持的文件类型: .pdf。当前支持 txt/md/csv/log/json/html/xml/epub"
}
```

### 10.5 当前最常见的线上失败

真实导入样例当前可能遇到：

```html
<html>
<head><title>504 Gateway Time-out</title></head>
<body>
<center><h1>504 Gateway Time-out</h1></center>
</body>
</html>
```

这不是字段校验失败，而是当前导入链路耗时过长，公网网关先超时了。

## 11. 模型与运行时说明

这条导入链路不会绕开现有模型配置。

仍然走：

- Claude Code SDK
- 当前 backend 的 `TARGET_MODEL`
- 当前 backend 的 `SILICONFLOW_FALLBACK_MODELS`

当前线上核对到的实际模型配置是：

- `Pro/MiniMaxAI/MiniMax-M2.5`
- `Pro/moonshotai/Kimi-K2.5`

## 12. 鸿蒙端接入建议

鸿蒙端最少要做 4 件事：

1. 让三个入口都选择文件
2. 根据入口分别传 `importType=manual / wechat / chat`
3. 把文件作为 `file` 字段上传
4. 拿到 `bundle` 后直接进入现有角色选择或详情链路

最简接法：

1. 上传成功后把 `bundle.profile` 加入角色列表
2. 用 `bundle.nodes` 渲染时间线
3. 用 `bundle.agents` 作为后续会议页输入

## 13. 当前接入风险

如果你们现在立刻接鸿蒙，需要默认接受下面这个现实：

- `/api/profile-imports` 已经上线
- 参数校验正常
- 但真实导入耗时很长
- 公网入口前面有 `504` 风险
- 当前更像“长任务同步接口”，不是“稳定的同步秒返接口”

所以在鸿蒙端，至少要做：

1. 上传后显示明确的长时间 loading 文案
2. 60 秒左右若收到 504，要提示“导入耗时较长，请稍后重试”
3. 不要把 504 归类成表单错误
4. 上传失败时保留原文件和表单状态，方便一键重试
5. 后续如果要提高可用性，建议把这条链路改成异步任务接口
