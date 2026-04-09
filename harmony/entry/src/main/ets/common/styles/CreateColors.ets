// 创造新识页面统一颜色规范
// 低饱和淡紫色、淡浅绿色、浅蓝色配色方案

// 创造页颜色接口
export interface CreateColorsScheme {
  // 主色调 - 淡紫色系
  purple: string
  purpleLight: string
  purplePale: string
  purpleBg: string
  
  // 辅助色 - 淡浅绿色系
  green: string
  greenLight: string
  greenPale: string
  greenBg: string
  
  // 点缀色 - 浅蓝色系
  blue: string
  blueLight: string
  bluePale: string
  blueBg: string
  
  // 渐变色组合
  gradientPurpleGreen: string[]
  gradientPurpleBlue: string[]
  gradientGreenBlue: string[]
  
  // 插画背景色
  illustrationBg: string
  illustrationAccent1: string
  illustrationAccent2: string
  illustrationAccent3: string
  
  // 输入框相关
  inputBg: string
  inputFocusBorder: string
  inputPlaceholder: string
  
  // 按钮状态
  buttonPrimary: string
  buttonPrimaryHover: string
  buttonSecondary: string
  buttonSecondaryHover: string
}

// 创造页颜色类
@Observed
class CreateColorsClass implements CreateColorsScheme {
  // 主色调 - 淡紫色系
  purple: string = '#B39DDB'
  purpleLight: string = '#D1C4E9'
  purplePale: string = '#EDE7F6'
  purpleBg: string = '#FAF5FF'
  
  // 辅助色 - 淡浅绿色系
  green: string = '#81C784'
  greenLight: string = '#A5D6A7'
  greenPale: string = '#E8F5E9'
  greenBg: string = '#F0FFF4'
  
  // 点缀色 - 浅蓝色系
  blue: string = '#64B5F6'
  blueLight: string = '#90CAF9'
  bluePale: string = '#E3F2FD'
  blueBg: string = '#F0F9FF'
  
  // 渐变色组合
  gradientPurpleGreen: string[] = ['#E8E0F0', '#D4EDDA']
  gradientPurpleBlue: string[] = ['#E8E0F0', '#D6EAF8']
  gradientGreenBlue: string[] = ['#D4EDDA', '#D6EAF8']
  
  // 插画背景色
  illustrationBg: string = '#F8F9FF'
  illustrationAccent1: string = '#B39DDB'
  illustrationAccent2: string = '#81C784'
  illustrationAccent3: string = '#64B5F6'
  
  // 输入框相关
  inputBg: string = '#FAFAFA'
  inputFocusBorder: string = '#B39DDB'
  inputPlaceholder: string = '#C5CAE9'
  
  // 按钮状态
  buttonPrimary: string = '#B39DDB'
  buttonPrimaryHover: string = '#9575CD'
  buttonSecondary: string = '#FFFFFF'
  buttonSecondaryHover: string = '#F5F5F5'
}

// 导出实例
export const CreateColors: CreateColorsScheme = new CreateColorsClass()
