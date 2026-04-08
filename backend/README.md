# Backend

最小后端负责把人物传记转成时间线节点、节点 Persona 和 Arena 对话结果。

## 运行

```bash
cd /Users/mychanging/Desktop/hackhathon/backend
npm install
npm run dev
```

默认端口：`3030`

## API

- `GET /health`
- `GET /api/presets`
- `POST /api/timeline/parse`
- `POST /api/agents/build`
- `POST /api/arena/run`

## 环境变量

- `PORT`
- `AGENT_RUNTIME=mock|claude-code-sdk`
- `TARGET_MODEL=glm-5|gpt-5.4`
- `CLAUDE_CODE_GATEWAY_BASE_URL`

说明：

- 当前默认使用 `mock` runtime，保证无 key 也能跑通 Demo。
- `claude-code-sdk` 入口已经预留在 `src/services/runtime.ts`。
- 如果后续需要真的通过 Claude Code SDK 切模型，可以把 SDK 连接到网关层，再由网关把请求路由到 `GLM-5` 或 `GPT-5.4`。
