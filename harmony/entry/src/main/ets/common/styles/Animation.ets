// 统一动效规范 - HarmonyOS ArkTS 动画工具类
// 时长与曲线对齐华为设计体系：强调动效用 EaseOut / FastOutSlowIn，物理感滚动与回弹可配合 Friction + EdgeEffect.Spring

// 动效时长
export class AnimationDurationClass {
  instant: number = 100
  fast: number = 200
  normal: number = 300
  slow: number = 400
  slower: number = 500
  page: number = 350
}
export const AnimationDuration: AnimationDurationClass = new AnimationDurationClass()

// 动效曲线 - 使用官方推荐的曲线
export class AnimationCurveClass {
  standard: Curve = Curve.Ease
  emphasized: Curve = Curve.EaseOut
  decelerated: Curve = Curve.EaseOut
  accelerated: Curve = Curve.EaseIn
  smooth: Curve = Curve.FastOutSlowIn
  bounce: Curve = Curve.FastOutLinearIn
  linear: Curve = Curve.Linear
  // 新增：更丰富的曲线
  spring: Curve = Curve.FastOutSlowIn
  friction: Curve = Curve.Friction
  sharp: Curve = Curve.Sharp
  rhythmic: Curve = Curve.Rhythm
}
export const AnimationCurve: AnimationCurveClass = new AnimationCurveClass()

// 预设动画配置
export interface AnimationPreset {
  duration: number
  curve: Curve
}

// 预设动画配置类
export class AnimationPresetsClass implements AnimationPreset {
  duration: number = 0
  curve: Curve = Curve.EaseOut

  constructor(duration: number, curve: Curve) {
    this.duration = duration
    this.curve = curve
  }
}

// AnimationPresets 类
export class AnimationPresetsContainerClass {
  quick: AnimationPreset = new AnimationPresetsClass(AnimationDuration.fast, AnimationCurve.emphasized)
  standard: AnimationPreset = new AnimationPresetsClass(AnimationDuration.normal, AnimationCurve.emphasized)
  slow: AnimationPreset = new AnimationPresetsClass(AnimationDuration.slow, AnimationCurve.decelerated)
  bounce: AnimationPreset = new AnimationPresetsClass(AnimationDuration.normal, AnimationCurve.bounce)
}
export const AnimationPresets: AnimationPresetsContainerClass = new AnimationPresetsContainerClass()

// 交错动画延迟计算
export function getStaggerDelay(index: number, baseDelay: number = 50): number {
  return index * baseDelay
}

/** 页面内多段内容错峰出现的基础间隔（ms） */
export const PAGE_SECTION_STAGGER_MS: number = 80

// 组件出现动画配置（从下方滑入 + 淡入）
export function getAppearAnimation(delay: number = 0): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
    .combine(TransitionEffect.translate({ y: 30 }))
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
}

// 组件消失动画配置（向下滑出 + 淡出）
export function getDisappearAnimation(): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({
      duration: AnimationDuration.fast,
      curve: AnimationCurve.decelerated
    })
    .combine(TransitionEffect.translate({ y: 20 }))
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.decelerated
    })
}

// 缩放入场动画
export function getScaleInAnimation(delay: number = 0): TransitionEffect {
  return TransitionEffect.OPACITY
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
    .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
}

// 卡片悬停效果参数
export interface HoverEffect {
  scaleX: number
  scaleY: number
  shadowRadius: number
  shadowOffsetY: number
}

// 悬停效果配置类
export class HoverEffectClass implements HoverEffect {
  scaleX: number = 1
  scaleY: number = 1
  shadowRadius: number = 8
  shadowOffsetY: number = 3

  constructor(scaleX: number, scaleY: number, shadowRadius: number, shadowOffsetY: number) {
    this.scaleX = scaleX
    this.scaleY = scaleY
    this.shadowRadius = shadowRadius
    this.shadowOffsetY = shadowOffsetY
  }
}

// HoverEffects 容器类
export class HoverEffectsContainerClass {
  subtle: HoverEffect = new HoverEffectClass(0.98, 0.98, 6, 2)
  medium: HoverEffect = new HoverEffectClass(0.97, 0.97, 12, 4)
  prominent: HoverEffect = new HoverEffectClass(0.96, 0.96, 20, 8)
}
export const HoverEffects: HoverEffectsContainerClass = new HoverEffectsContainerClass()

// 按钮点击效果参数
export interface PressEffect {
  scaleX: number
  scaleY: number
  duration: number
}

// 点击效果配置类
export class PressEffectClass implements PressEffect {
  scaleX: number = 1
  scaleY: number = 1
  duration: number = 200

  constructor(scaleX: number, scaleY: number, duration: number) {
    this.scaleX = scaleX
    this.scaleY = scaleY
    this.duration = duration
  }
}

// PressEffects 容器类
export class PressEffectsContainerClass {
  light: PressEffect = new PressEffectClass(0.98, 0.98, AnimationDuration.fast)
  medium: PressEffect = new PressEffectClass(0.96, 0.96, AnimationDuration.fast)
  strong: PressEffect = new PressEffectClass(0.94, 0.94, AnimationDuration.instant)
}
export const PressEffects: PressEffectsContainerClass = new PressEffectsContainerClass()

// 旋转动画配置
export function getRotateAnimation(from: number, to: number, duration: number = 300): TransitionEffect {
  return TransitionEffect.asymmetric(
    TransitionEffect.OPACITY.animation({
      duration: duration / 2,
      curve: AnimationCurve.standard
    }).combine(
      TransitionEffect.rotate({ angle: from })
    ),
    TransitionEffect.OPACITY.animation({
      duration: duration / 2,
      curve: AnimationCurve.standard
    }).combine(
      TransitionEffect.rotate({ angle: to })
    )
  )
}

// 骨架屏闪烁动画配置
export class ShimmerAnimationClass {
  duration: number = 1500
  iterations: number = -1
  curve: Curve = Curve.Linear
}
export const ShimmerAnimation: ShimmerAnimationClass = new ShimmerAnimationClass()

// 弹簧动画配置
export interface SpringConfig {
  velocity: number
  mass: number
  stiffness: number
  damping: number
}

export class SpringConfigClass implements SpringConfig {
  velocity: number = 0
  mass: number = 1
  stiffness: number = 100
  damping: number = 10

  constructor(velocity: number, mass: number, stiffness: number, damping: number) {
    this.velocity = velocity
    this.mass = mass
    this.stiffness = stiffness
    this.damping = damping
  }
}

// 弹簧动画预设
export class SpringPresetsClass {
  gentle: SpringConfig = new SpringConfigClass(0, 1, 120, 14)
  bouncy: SpringConfig = new SpringConfigClass(0, 1, 180, 12)
  stiff: SpringConfig = new SpringConfigClass(0, 1, 210, 20)
  slow: SpringConfig = new SpringConfigClass(0, 1, 280, 60)
}
export const SpringPresets: SpringPresetsClass = new SpringPresetsClass()

// 微交互动画 - 用于按钮、图标等小元素
export function getMicroInteraction(delay: number = 0): TransitionEffect {
  return TransitionEffect.scale({ x: 0.95, y: 0.95 })
    .animation({
      duration: AnimationDuration.instant,
      curve: AnimationCurve.sharp,
      delay: delay
    })
    .combine(TransitionEffect.OPACITY)
    .animation({
      duration: AnimationDuration.fast,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
}

// 卡片翻转动画
export function getFlipAnimation(duration: number = 400): TransitionEffect {
  return TransitionEffect.rotate({ x: 0, y: 1, z: 0, angle: 180 })
    .animation({
      duration: duration,
      curve: AnimationCurve.smooth
    })
    .combine(TransitionEffect.OPACITY)
    .animation({
      duration: duration / 2,
      curve: AnimationCurve.emphasized
    })
}

// 弹性缩放入场
export function getElasticScaleIn(delay: number = 0): TransitionEffect {
  return TransitionEffect.scale({ x: 0.3, y: 0.3 })
    .animation({
      duration: AnimationDuration.slower,
      curve: AnimationCurve.smooth,
      delay: delay
    })
    .combine(TransitionEffect.OPACITY)
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
}

// 滑动淡入（从指定方向）
export interface SlideInConfig {
  x?: number
  y?: number
  duration?: number
  delay?: number
}

export function getSlideInAnimation(config: SlideInConfig): TransitionEffect {
  const x = config.x ?? 0
  const y = config.y ?? 0
  const duration = config.duration ?? AnimationDuration.normal
  const delay = config.delay ?? 0

  return TransitionEffect.translate({ x: x, y: y })
    .animation({
      duration: duration,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
    .combine(TransitionEffect.OPACITY)
    .animation({
      duration: duration,
      curve: AnimationCurve.emphasized,
      delay: delay
    })
}

// 脉冲动画配置（用于提示、通知等）
export class PulseAnimationClass {
  duration: number = 1000
  iterations: number = -1
  scaleFrom: number = 1.0
  scaleTo: number = 1.05
  curve: Curve = Curve.EaseInOut
}
export const PulseAnimation: PulseAnimationClass = new PulseAnimationClass()

// 呼吸灯动画配置
export class BreathAnimationClass {
  duration: number = 2000
  iterations: number = -1
  opacityFrom: number = 0.4
  opacityTo: number = 1.0
  curve: Curve = Curve.EaseInOut
}
export const BreathAnimation: BreathAnimationClass = new BreathAnimationClass()
