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
- `TARGET_MODEL`
- `FALLBACK_MODEL`
- `REASONING_EFFORT`
- `CLAUDE_CODE_BIN`
- `CCS_PROFILE`
- `POSTER_SKILLS_REPO_URL`
- `POSTER_LLM_MODEL`
- `POSTER_LLM_BASE_URL`
- `POSTER_LLM_API_KEY`

说明：

- 当前运行时固定走 `claude-agent-sdk`。
- 默认直接调用本地 `claude` CLI；如果设置了 `CCS_PROFILE`，后端会自动改走 `backend/bin/claude-via-ccs.sh`，通过 `ccs` 把 Claude Code 请求桥接到兼容提供方。
- `POSTER_SKILLS_REPO_URL` 默认是 `https://github.com/shaom/infocard-skills.git`，海报链路会优先使用其中的 `editorial-card-screenshot` skill 生成 HTML + PNG 信息图卡。
- 如果 skill 链路失败，后端仍会回退到本地 SVG 方案，保证分享页不至于整条挂掉。
