// 统一字体规范

// 字号接口
export interface FontSizes {
  xs: number
  sm: number
  caption: number
  body: number
  bodyLg: number
  subtitle: number
  lg: number
  xl: number
  xxl: number
  hero: number
  display: number
}

// 字重接口
export interface FontWeights {
  regular: FontWeight
  medium: FontWeight
  bold: FontWeight
}

// 行高接口
export interface LineHeights {
  tight: number
  normal: number
  relaxed: number
  loose: number
}

// 字间距接口
export interface LetterSpacings {
  tight: number
  normal: number
  wide: number
  wider: number
}

// 文本样式接口
export interface TextStyle {
  fontSize: number
  fontWeight: FontWeight
  fontColor: string
  letterSpacing?: number
}

// Typography 主接口
export interface TypographyScheme {
  size: FontSizes
  weight: FontWeights
  lineHeight: LineHeights
  letterSpacing: LetterSpacings
}

// Typography 类
@Observed
class TypographyClass implements TypographyScheme {
  size: FontSizes = {
    xs: 10,
    sm: 11,
    caption: 12,
    body: 14,
    bodyLg: 15,
    subtitle: 16,
    lg: 18,
    xl: 24,
    xxl: 28,
    hero: 34,
    display: 38
  }

  weight: FontWeights = {
    regular: FontWeight.Normal,
    medium: FontWeight.Medium,
    bold: FontWeight.Bold
  }

  lineHeight: LineHeights = {
    tight: 20,
    normal: 24,
    relaxed: 26,
    loose: 30
  }

  letterSpacing: LetterSpacings = {
    tight: 0.5,
    normal: 1,
    wide: 2,
    wider: 3
  }
}

// Typography 对象 - 新版本使用更大的字号
export const Typography: TypographyScheme = new TypographyClass()

// 预设文本样式接口
export interface TextStylesInterface {
  displayLarge: TextStyle
  displayMedium: TextStyle
  titleLarge: TextStyle
  titleMedium: TextStyle
  titleSmall: TextStyle
  bodyLarge: TextStyle
  bodyMedium: TextStyle
  bodySmall: TextStyle
  labelLarge: TextStyle
  labelMedium: TextStyle
  labelSmall: TextStyle
  caption: TextStyle
  overline: TextStyle
}

// 预设文本样式
@Observed
class TextStylesClass implements TextStylesInterface {
  displayLarge: TextStyle = {
    fontSize: 40,
    fontWeight: FontWeight.Bold,
    fontColor: '#1E293B'
  }
  displayMedium: TextStyle = {
    fontSize: 30,
    fontWeight: FontWeight.Bold,
    fontColor: '#1E293B'
  }
  titleLarge: TextStyle = {
    fontSize: 26,
    fontWeight: FontWeight.Bold,
    fontColor: '#1E293B'
  }
  titleMedium: TextStyle = {
    fontSize: 20,
    fontWeight: FontWeight.Bold,
    fontColor: '#1E293B'
  }
  titleSmall: TextStyle = {
    fontSize: 17,
    fontWeight: FontWeight.Medium,
    fontColor: '#475569'
  }
  bodyLarge: TextStyle = {
    fontSize: 16,
    fontWeight: FontWeight.Normal,
    fontColor: '#475569'
  }
  bodyMedium: TextStyle = {
    fontSize: 14,
    fontWeight: FontWeight.Normal,
    fontColor: '#64748B'
  }
  bodySmall: TextStyle = {
    fontSize: 11,
    fontWeight: FontWeight.Normal,
    fontColor: '#64748B'
  }
  labelLarge: TextStyle = {
    fontSize: 16,
    fontWeight: FontWeight.Medium,
    fontColor: '#64748B'
  }
  labelMedium: TextStyle = {
    fontSize: 12,
    fontWeight: FontWeight.Medium,
    fontColor: '#64748B'
  }
  labelSmall: TextStyle = {
    fontSize: 11,
    fontWeight: FontWeight.Medium,
    fontColor: '#94A3B8'
  }
  caption: TextStyle = {
    fontSize: 11,
    fontWeight: FontWeight.Normal,
    fontColor: '#94A3B8'
  }
  overline: TextStyle = {
    fontSize: 12,
    fontWeight: FontWeight.Medium,
    fontColor: '#6366F1',
    letterSpacing: 3
  }
}

export const TextStyles: TextStylesInterface = new TextStylesClass()
