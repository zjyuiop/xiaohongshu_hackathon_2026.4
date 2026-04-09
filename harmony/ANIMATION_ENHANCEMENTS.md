# 动效优化总结

本次优化基于 HarmonyOS 官方文档和最佳实践，为应用增强了多层次的动效体验。

## 一、动画系统增强

### 1. 新增动画曲线 (`Animation.ets`)
- **Spring（弹簧）**: 自然的弹性效果
- **Friction（摩擦）**: 带阻尼的减速效果
- **Sharp（锐利）**: 快速响应的点击反馈
- **Rhythmic（韵律）**: 有节奏感的动画

### 2. 弹簧动画预设
```typescript
SpringPresets.gentle    // 温和弹性 (120, 14)
SpringPresets.bouncy    // 活泼弹跳 (180, 12)
SpringPresets.stiff     // 硬朗快速 (210, 20)
SpringPresets.slow      // 缓慢优雅 (280, 60)
```

### 3. 新增动画函数
- `getMicroInteraction()` - 微交互动画（按钮、图标）
- `getFlipAnimation()` - 卡片翻转动画
- `getElasticScaleIn()` - 弹性缩放入场
- `getSlideInAnimation()` - 可配置方向的滑入动画

### 4. 特效动画配置
- `PulseAnimation` - 脉冲动画（提示、通知）
- `BreathAnimation` - 呼吸灯动画（状态指示）

## 二、组件动效优化

### 1. RoleCard（角色卡片）
**优化前**: 简单的淡入 + 位移
**优化后**:
- ✨ 头像带旋转的弹性入场（SpringMotion 0.6, 0.9）
- ✨ 卡片滑入使用 FastOutSlowIn 曲线
- ✨ 高亮标签交错弹出（每个延迟 40ms）
- ✨ 按压反馈使用 Sharp 曲线（100ms 快速响应）
- ✨ 释放时弹性回弹（SpringMotion 0.6, 0.8）
- ✨ 头像阴影随激活状态动态变化

**关键代码**:
```typescript
// 头像弹性入场
animateTo({
  duration: AnimationDuration.slower,
  curve: Curve.SpringMotion(0.6, 0.9),
}, () => {
  this.avatarScale = 1
  this.avatarRotate = 0
})

// 高亮标签交错动画
.animation({
  duration: AnimationDuration.normal,
  curve: Curve.SpringMotion(0.7, 1.0),
  delay: idx * 40
})
```

### 2. HeroSection（头部区域）
**优化前**: 基础淡入动画
**优化后**:
- ✨ 背景光晕缩放淡入（从 0.8 到 1.0）
- ✨ 渐变线条从上到下生长（transformOrigin 设置为顶部）
- ✨ 标题内容分层淡入
- ✨ 装饰点弹性弹出（SpringMotion 0.5, 0.7）
- ✨ 状态标签滑入效果

**关键代码**:
```typescript
// 线条生长动画
.scale({
  x: 1,
  y: this.lineScaleY
})
.transformOrigin({ x: 0.5, y: 0 })

// 光晕缩放
.scale({
  x: this.glowOpacity * 0.2 + 0.8,
  y: this.glowOpacity * 0.2 + 0.8
})
```

### 3. TabBar（底部导航）
**优化前**: 简单的淡入 + 位移
**优化后**:
- ✨ 整体弹性上浮（SpringMotion 0.6, 0.8）
- ✨ 带缩放的入场效果（0.95 → 1.0）
- ✨ Tab 按压缩放更明显（0.92）
- ✨ 激活 Tab 轻微上浮（-2px）
- ✨ 指示器弹性伸缩（SpringMotion 0.6, 0.9）
- ✨ 图标放大效果增强（1.12x）

**关键代码**:
```typescript
// 按压反馈
.scale({
  x: this.pressedIndex === index ? 0.92 : 1,
  y: this.pressedIndex === index ? 0.92 : 1
})
.animation({
  duration: this.pressedIndex === index ? 120 : 240,
  curve: this.pressedIndex === index ? Curve.Sharp : Curve.SpringMotion(0.6, 0.8)
})
```

### 4. MessageBubble（消息气泡）
**优化前**: 简单的透明度过渡
**优化后**:
- ✨ 弹性缩放入场（0.95 → 1.0）
- ✨ 向上滑入效果（10px）
- ✨ SpringMotion 曲线（0.6, 0.9）

### 5. LoadingOverlay（加载遮罩）
**优化前**: 简单淡入
**优化后**:
- ✨ 弹性缩放入场（0.9 → 1.0）
- ✨ SpringMotion 曲线（0.6, 0.8）
- ✨ 300ms 流畅过渡

### 6. SummaryCard（纪要卡片）
**优化前**: 简单透明度过渡
**优化后**:
- ✨ 卡片整体弹性入场（400ms）
- ✨ 内容项延迟淡入（200ms 后）
- ✨ 列表项交错滑入（每项延迟 50ms）
- ✨ 叙事钩子带缩放效果
- ✨ 分层动画增强视觉层次

**关键代码**:
```typescript
// 列表项交错动画
ForEach(this.disagreements, (item: string, index: number) => {
  Row({ space: Spacing.sm }) {
    // ...
  }
  .opacity(this.itemsOpacity)
  .translate({
    x: this.itemsOpacity > 0 ? 0 : -10,
    y: 0
  })
  .animation({
    duration: 300,
    curve: Curve.FastOutSlowIn,
    delay: 250 + index * 50
  })
})
```

### 7. AnimatedButton（新增组件）
**全新的按钮组件**，包含：
- ✨ 涟漪点击效果（Ripple）
- ✨ 按压缩放反馈（0.96x）
- ✨ 悬停放大效果（1.02x）
- ✨ 加载状态动画
- ✨ 禁用状态处理
- ✨ 三种样式：primary、secondary、outline

## 三、动画时序优化

### 交错动画（Stagger Animation）
多个元素按顺序出现，营造流畅的视觉流：

| 组件 | 基础延迟 | 交错间隔 |
|------|---------|---------|
| RoleCard | index × 60ms | - |
| RoleCard 高亮标签 | - | 40ms |
| SummaryCard 列表项 | 250ms | 50ms |

### 分层动画（Layered Animation）
同一组件内不同元素的动画分层：

**HeroSection 时序**:
1. 光晕淡入（0ms）
2. 线条生长（100ms）
3. 标题淡入（200ms）
4. 装饰点弹出（300ms）
5. 状态标签滑入（400ms）

**RoleCard 时序**:
1. 头像弹性入场（delay）
2. 卡片滑入（delay + 80ms）
3. 内容淡入（delay + 150ms）
4. 高亮标签（delay + 220ms）

## 四、交互反馈优化

### 按压反馈（Press Feedback）
- **快速响应**: 100-120ms，使用 Sharp 曲线
- **明显缩放**: 0.92-0.96x（原来 0.95-0.985x）
- **弹性回弹**: SpringMotion(0.6, 0.8)

### 状态转换
- **Tab 切换**: 280ms FastOutSlowIn
- **卡片激活**: 阴影、边框、缩放同步变化
- **图标切换**: 220ms SpringMotion

## 五、性能优化

### 动画性能最佳实践
1. ✅ 使用 `animateTo` 而非 `.animation()` 进行状态驱动
2. ✅ 避免在动画中修改布局（使用 transform）
3. ✅ 合理使用 SpringMotion（不超过 3 层嵌套）
4. ✅ 交错动画间隔控制在 40-60ms
5. ✅ 入场动画总时长不超过 500ms

### 曲线选择指南
| 场景 | 推荐曲线 | 时长 |
|------|---------|------|
| 按压反馈 | Sharp | 100-120ms |
| 释放回弹 | SpringMotion(0.6, 0.8) | 200-240ms |
| 卡片入场 | SpringMotion(0.6, 0.9) | 350-400ms |
| 内容淡入 | FastOutSlowIn | 280-350ms |
| Tab 切换 | FastOutSlowIn | 280ms |

## 六、视觉层次

### 阴影动态变化
```typescript
// 卡片阴影随状态变化
.shadow({
  radius: this.isActive ? 24 : (this.isPressed ? 8 : 12),
  color: this.isActive ? 'rgba(99, 102, 241, 0.14)' : ...,
  offsetY: this.isActive ? 8 : (this.isPressed ? 2 : 4)
})
```

### 缩放层次
- 微交互: 0.95-0.98
- 按压反馈: 0.92-0.96
- 入场动画: 0.9-1.0
- 悬停效果: 1.02-1.05

## 七、参考资料

本次优化参考了以下 HarmonyOS 官方文档：
- [HarmonyOS Next 之各类动画实现详解](https://www.cnblogs.com/study-ww/articles/18950557)
- [HarmonyOS 开发实践 —— 基于ArkUI的动效能力](https://cloud.tencent.cn/developer/article/2480004)
- HarmonyOS 官方 SpringMotion API 文档

## 八、使用建议

### 1. 保持一致性
所有卡片类组件使用相同的入场动画模式：
- 整体弹性缩放
- 内容延迟淡入
- 列表项交错出现

### 2. 适度使用
- 避免过度动画（每个交互不超过 2-3 个动画属性）
- 关键路径优先（首屏、主要交互）
- 次要元素可简化动画

### 3. 性能监控
- 使用 DevEco Studio Profiler 监控帧率
- 确保动画期间保持 60fps
- 低端设备可考虑降级方案

## 九、后续优化方向

1. **页面转场动画**: 使用 `pageTransition` API
2. **手势动画**: 结合 PanGesture 实现拖拽效果
3. **粒子效果**: 使用 Particle API 增强视觉冲击
4. **共享元素转场**: 页面间元素的连续性动画
5. **骨架屏动画**: 加载状态的优雅过渡

---

**优化完成时间**: 2026-04-09
**优化组件数**: 7 个核心组件
**新增动画函数**: 8 个
**新增组件**: 1 个（AnimatedButton）
