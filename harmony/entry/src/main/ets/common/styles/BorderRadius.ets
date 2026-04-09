// 统一圆角规范

// 头像圆角接口
export interface AvatarRadius {
  small: number
  medium: number
  large: number
  xlarge: number
  full: number
}

// 消息气泡圆角接口
export interface BubbleRadius {
  small: number
  medium: number
  large: number
}

// 卡片圆角接口
export interface CardRadius {
  small: number
  medium: number
  large: number
  xlarge: number
}

// 统一的圆角样式接口
export interface RadiiStyle {
  card: number
  cardSmall: number
  input: number
  button: number
  chip: number
  bubble: number
}

// 主 BorderRadius 接口
export interface BorderRadiusScheme {
  none: number
  xs: number
  sm: number
  md: number
  lg: number
  xl: number
  xxl: number
  xxl2: number
  xxl3: number
  huge: number
  button: number
  chip: number
  tag: number
  pill: number
  card: CardRadius
  input: number
  inputLarge: number
  avatar: AvatarRadius
  bubble: BubbleRadius
}

// 定义基础圆角值
const _none = 0
const _xs = 4
const _sm = 8
const _md = 12
const _lg = 16
const _xl = 18
const _xxl = 20
const _xxl2 = 22
const _xxl3 = 24
const _huge = 28
const _button = 99
const _chip = 99
const _tag = 99
const _pill = 99

// AvatarRadius 类
@Observed
class AvatarRadiusClass implements AvatarRadius {
  small: number = 16
  medium: number = 20
  large: number = 24
  xlarge: number = 28
  full: number = 999
}

// BubbleRadius 类
@Observed
class BubbleRadiusClass implements BubbleRadius {
  small: number = _md
  medium: number = _lg
  large: number = _xl
}

// CardRadius 类
@Observed
class CardRadiusClass implements CardRadius {
  small: number = _lg
  medium: number = _xl
  large: number = _xxl
  xlarge: number = _xxl2
}

// RadiiStyle 类
@Observed
class RadiiStyleClass implements RadiiStyle {
  card: number = _xxl2
  cardSmall: number = _xl
  input: number = _md
  button: number = _button
  chip: number = _chip
  bubble: number = _lg
}

// BorderRadius 类
@Observed
class BorderRadiusClass implements BorderRadiusScheme {
  none: number = _none
  xs: number = _xs
  sm: number = _sm
  md: number = _md
  lg: number = _lg
  xl: number = _xl
  xxl: number = _xxl
  xxl2: number = _xxl2
  xxl3: number = _xxl3
  huge: number = _huge

  button: number = _button
  chip: number = _chip
  tag: number = _tag
  pill: number = _pill

  card: CardRadius = new CardRadiusClass()

  input: number = _md
  inputLarge: number = _lg

  avatar: AvatarRadius = new AvatarRadiusClass()

  bubble: BubbleRadius = new BubbleRadiusClass()
}

// 导出实例
export const BorderRadius: BorderRadiusScheme = new BorderRadiusClass()
export const Radii: RadiiStyle = new RadiiStyleClass()
