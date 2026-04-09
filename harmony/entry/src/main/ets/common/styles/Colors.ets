// 统一颜色规范
// 浅色主题配色方案 (纯净清新风格)

export interface StageColors {
  early: string
  turningPoint: string
  crisis: string
  rebuild: string
  peak: string
  default: string
}

export interface StanceColors {
  support: string
  oppose: string
  reflective: string
  default: string
}

export interface ColorScheme {
  primary: string
  primaryDark: string
  primaryDarkAlt: string

  background: string
  backgroundSecondary: string
  backgroundTertiary: string
  backgroundElevated: string

  cardPrimary: string
  cardSecondary: string
  cardMuted: string

  textPrimary: string
  textSecondary: string
  textTertiary: string
  textMuted: string
  textPlaceholder: string

  accent: string
  accentAlt: string
  accentLight: string
  accentPurple: string

  success: string
  warning: string
  error: string
  errorLight: string
  errorBg: string

  loading: string
  loadingBg: string

  border: string
  borderLight: string

  tagBg: string
  tagMuted: string

  stage: StageColors
  stance: StanceColors
}

// 颜色类定义 - 使用类避免 ArkTS 对象字面量错误
@Observed
class ColorsClass implements ColorScheme {
  primary: string = '#6366F1'
  primaryDark: string = '#4338CA'
  primaryDarkAlt: string = '#4F46E5'

  background: string = '#FAFBFF'
  backgroundSecondary: string = '#F1F5F9'
  backgroundTertiary: string = '#E8EDF5'
  backgroundElevated: string = '#FFFFFF'

  cardPrimary: string = 'rgba(255, 255, 255, 0.75)'
  cardSecondary: string = 'rgba(255, 255, 255, 0.92)'
  cardMuted: string = 'rgba(248, 250, 252, 0.7)'

  textPrimary: string = '#1E293B'
  textSecondary: string = '#475569'
  textTertiary: string = '#64748B'
  textMuted: string = '#94A3B8'
  textPlaceholder: string = '#A0AEC0'

  accent: string = '#6366F1'
  accentAlt: string = '#818CF8'
  accentLight: string = '#C7D2FE'
  accentPurple: string = '#EEF2FF'

  success: string = '#10B981'
  warning: string = '#F59E0B'
  error: string = '#F43F5E'
  errorLight: string = '#FB7185'
  errorBg: string = '#FFF1F3'

  loading: string = '#818CF8'
  loadingBg: string = '#EEF2FF'

  border: string = 'rgba(226, 232, 240, 0.8)'
  borderLight: string = 'rgba(226, 232, 240, 0.5)'

  tagBg: string = 'rgba(241, 245, 249, 0.85)'
  tagMuted: string = 'rgba(226, 232, 240, 0.7)'

  stage: StageColors = {
    early: '#6366F1',
    turningPoint: '#10B981',
    crisis: '#F43F5E',
    rebuild: '#8B5CF6',
    peak: '#F59E0B',
    default: '#64748B'
  }

  stance: StanceColors = {
    support: '#10B981',
    oppose: '#F43F5E',
    reflective: '#8B5CF6',
    default: '#64748B'
  }
}

// 导出 Colors 实例
export const Colors: ColorScheme = new ColorsClass()

// 兼容旧代码的 ColorsLight
export const ColorsLight: ColorScheme = Colors
