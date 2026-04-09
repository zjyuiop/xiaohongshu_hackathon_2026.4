// 薄荷绿 + 低饱和淡紫色 配色方案
// Mint Green & Soft Lavender Color Scheme

export interface MintStageColors {
  early: string
  turningPoint: string
  crisis: string
  rebuild: string
  peak: string
  default: string
}

export interface MintStanceColors {
  support: string
  oppose: string
  reflective: string
  default: string
}

export interface MintColorScheme {
  // 主色：薄荷绿
  mint: string
  mintDark: string
  mintLight: string
  mintBg: string
  mintPale: string

  // 辅色：低饱和淡紫
  lavender: string
  lavenderDark: string
  lavenderLight: string
  lavenderBg: string
  lavenderPale: string

  // 主次比例色
  mintAccent: string
  lavenderAccent: string

  // 背景层次
  background: string
  backgroundSecondary: string
  backgroundTertiary: string
  surface: string
  surfaceGlass: string

  // 卡片
  cardPrimary: string
  cardSecondary: string
  cardElevated: string

  // 文字
  textPrimary: string
  textSecondary: string
  textMuted: string
  textPlaceholder: string

  // 功能色
  success: string
  warning: string
  error: string
  errorLight: string

  // 边框与分割
  border: string
  borderLight: string
  divider: string

  // 标签
  tagBg: string
  tagText: string

  // 分类色板（薄荷/淡紫双系）
  categoryAll: string
  categoryBusiness: string
  categoryFinance: string
  categoryTech: string
  categoryPolitics: string
  categoryCulture: string
  categorySports: string
  categoryEntertainment: string
  categoryEducation: string
  categoryPhilosophy: string

  // 阶段/立场色
  stage: MintStageColors
  stance: MintStanceColors
}

@Observed
class MintColorsClass implements MintColorScheme {
  // 薄荷绿系
  mint: string = '#4ECDC4'
  mintDark: string = '#3AB5AD'
  mintLight: string = '#7EDCD6'
  mintBg: string = 'rgba(78, 205, 196, 0.08)'
  mintPale: string = 'rgba(78, 205, 196, 0.12)'

  // 低饱和淡紫系
  lavender: string = '#B8A9D9'
  lavenderDark: string = '#9B8AC4'
  lavenderLight: string = '#D4C9E8'
  lavenderBg: string = 'rgba(184, 169, 217, 0.1)'
  lavenderPale: string = 'rgba(184, 169, 217, 0.15)'

  // 比例辅助
  mintAccent: string = '#45B7AA'
  lavenderAccent: string = '#A899C7'

  // 背景
  background: string = '#F7FCFB'
  backgroundSecondary: string = '#EEF6F5'
  backgroundTertiary: string = '#E3F1EF'
  surface: string = '#FFFFFF'
  surfaceGlass: string = 'rgba(255, 255, 255, 0.72)'

  // 卡片
  cardPrimary: string = 'rgba(255, 255, 255, 0.88)'
  cardSecondary: string = 'rgba(255, 255, 255, 0.95)'
  cardElevated: string = '#FFFFFF'

  // 文字
  textPrimary: string = '#2D3B47'
  textSecondary: string = '#5C6E7A'
  textMuted: string = '#8FA5B0'
  textPlaceholder: string = '#B0C4CB'

  // 功能色
  success: string = '#3DBD9C'
  warning: string = '#E8B86D'
  error: string = '#E07880'
  errorLight: string = '#F5A5AA'

  // 边框
  border: string = 'rgba(78, 205, 196, 0.15)'
  borderLight: string = 'rgba(184, 169, 217, 0.12)'
  divider: string = 'rgba(184, 169, 217, 0.1)'

  // 标签
  tagBg: string = 'rgba(78, 205, 196, 0.1)'
  tagText: string = '#4A8C84'

  // 分类色板
  categoryAll: string = 'rgba(78, 205, 196, 0.08)'
  categoryBusiness: string = 'rgba(78, 205, 196, 0.12)'
  categoryFinance: string = 'rgba(232, 184, 109, 0.12)'
  categoryTech: string = 'rgba(78, 205, 196, 0.1)'
  categoryPolitics: string = 'rgba(184, 169, 217, 0.12)'
  categoryCulture: string = 'rgba(224, 120, 128, 0.1)'
  categorySports: string = 'rgba(61, 189, 156, 0.12)'
  categoryEntertainment: string = 'rgba(168, 153, 199, 0.1)'
  categoryEducation: string = 'rgba(78, 205, 196, 0.08)'
  categoryPhilosophy: string = 'rgba(155, 138, 196, 0.12)'

  // 阶段/立场
  stage: MintStageColors = {
    early: '#4ECDC4',
    turningPoint: '#3DBD9C',
    crisis: '#E07880',
    rebuild: '#B8A9D9',
    peak: '#E8B86D',
    default: '#8FA5B0'
  }

  stance: MintStanceColors = {
    support: '#3DBD9C',
    oppose: '#E07880',
    reflective: '#B8A9D9',
    default: '#8FA5B0'
  }
}

export const MintColors: MintColorScheme = new MintColorsClass()
