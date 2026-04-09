# Web

React + Vite 的黑客松展示前端，聚焦完整的演示链路：

1. 首页 / 角色库
2. 角色详情子页
3. Arena 阶段人格议会
4. Summary 结果区

## 运行

```bash
cd /Users/mychanging/Desktop/hackhathon/web
npm install
npm run dev
```

默认会请求 `http://localhost:3030`。

如果后端不在默认地址，可以通过环境变量覆盖：

```bash
VITE_API_BASE_URL=http://localhost:3030 npm run dev
```

即使后端没启动，前端也会退回本地 mock 数据，保证页面能演示。
