import { Colors } from '../common/styles/Colors'

export type IconType =
  | 'search'
  | 'close'
  | 'arrowLeft'
  | 'arrowRight'
  | 'check'
  | 'clock'
  | 'star'
  | 'starOutline'
  | 'circle'
  | 'square'
  | 'diamond'
  | 'hexagon'
  | 'triangle'
  | 'person'
  | 'chat'
  | 'ai'
  | 'sad'
  | 'plus'
  | 'minus'
  | 'edit'
  | 'grid'
  | 'briefcase'
  | 'coin'
  | 'cpu'
  | 'landmark'
  | 'palette'
  | 'trophy'
  | 'bookOpen'
  | 'brain'
  | 'sparkles'
  | 'dot'

export interface IIconSize {
  xs: number
  sm: number
  md: number
  lg: number
  xl: number
  xxl: number
}

export const IconSize: IIconSize = {
  xs: 10,
  sm: 12,
  md: 14,
  lg: 16,
  xl: 20,
  xxl: 24
}

export interface CategoryIconConfig {
  id: string
  name: string
  bgColor: string
  iconColor: string
  iconType: IconType
}

export const CategoryIcons: CategoryIconConfig[] = [
  { id: 'all', name: '全部', bgColor: Colors.backgroundTertiary, iconColor: Colors.textSecondary, iconType: 'grid' },
  { id: 'business', name: '商业', bgColor: 'rgba(99, 102, 241, 0.1)', iconColor: '#6366F1', iconType: 'briefcase' },
  { id: 'finance', name: '金融', bgColor: 'rgba(245, 158, 11, 0.1)', iconColor: '#F59E0B', iconType: 'coin' },
  { id: 'tech', name: '科技', bgColor: 'rgba(6, 182, 212, 0.1)', iconColor: '#06B6D4', iconType: 'cpu' },
  { id: 'politics', name: '政治', bgColor: 'rgba(139, 92, 246, 0.1)', iconColor: '#8B5CF6', iconType: 'landmark' },
  { id: 'culture', name: '文化', bgColor: 'rgba(236, 72, 153, 0.1)', iconColor: '#EC4899', iconType: 'palette' },
  { id: 'sports', name: '体育', bgColor: 'rgba(16, 185, 129, 0.1)', iconColor: '#10B981', iconType: 'trophy' },
  { id: 'entertainment', name: '娱乐', bgColor: 'rgba(244, 63, 94, 0.1)', iconColor: '#F43F5E', iconType: 'sparkles' },
  { id: 'education', name: '教育', bgColor: 'rgba(99, 102, 241, 0.08)', iconColor: '#6366F1', iconType: 'bookOpen' },
  { id: 'philosophy', name: '哲学', bgColor: 'rgba(168, 85, 247, 0.1)', iconColor: '#A855F7', iconType: 'brain' }
]

export function getCategoryBgColor(categoryId: string): string {
  const config = CategoryIcons.find(item => item.id === categoryId)
  return config ? config.bgColor : Colors.backgroundTertiary
}

export function getCategoryIconColor(categoryId: string): string {
  const config = CategoryIcons.find(item => item.id === categoryId)
  return config ? config.iconColor : Colors.textSecondary
}

export function getCategoryIconType(categoryId: string): IconType {
  const config = CategoryIcons.find(item => item.id === categoryId)
  return config ? config.iconType : 'grid'
}

@Component
export struct Icon {
  @Prop iconType: IconType = 'circle'
  @Prop iconSize: number = IconSize.md
  @Prop iconColor: string = Colors.primary
  @Prop strokeWidth: number = 1.7

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.buildIconContent()
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  private resolvedStrokeWidth(): number {
    if (this.iconSize <= IconSize.sm) {
      return 1.35
    }
    if (this.iconSize >= IconSize.xl) {
      return 1.85
    }
    return this.strokeWidth
  }

  private lineRadius(): number {
    return this.resolvedStrokeWidth() / 2
  }

  private px(scale: number): number {
    return this.iconSize * scale
  }

  private transparent(): string {
    return 'rgba(0, 0, 0, 0)'
  }

  @Builder
  private buildLine(widthScale: number, angle: number = 0, xScale: number = 0, yScale: number = 0) {
    Column()
      .width(this.px(widthScale))
      .height(this.resolvedStrokeWidth())
      .backgroundColor(this.iconColor)
      .borderRadius(this.lineRadius())
      .rotate({ angle })
      .position({ x: this.px(xScale), y: this.px(yScale) })
  }

  @Builder
  private buildOutlinedCircle(scale: number, xScale: number = 0, yScale: number = 0) {
    Column()
      .width(this.px(scale))
      .height(this.px(scale))
      .borderRadius(this.px(scale) / 2)
      .border({
        width: this.resolvedStrokeWidth(),
        color: this.iconColor,
        radius: this.px(scale) / 2
      })
      .position({ x: this.px(xScale), y: this.px(yScale) })
  }

  @Builder
  private buildOutlinedRect(widthScale: number, heightScale: number, radiusScale: number, xScale: number = 0, yScale: number = 0) {
    Column()
      .width(this.px(widthScale))
      .height(this.px(heightScale))
      .borderRadius(this.px(radiusScale))
      .border({
        width: this.resolvedStrokeWidth(),
        color: this.iconColor,
        radius: this.px(radiusScale)
      })
      .position({ x: this.px(xScale), y: this.px(yScale) })
  }

  @Builder
  private buildFilledDot(scale: number, xScale: number = 0, yScale: number = 0) {
    Column()
      .width(this.px(scale))
      .height(this.px(scale))
      .borderRadius(this.px(scale) / 2)
      .backgroundColor(this.iconColor)
      .position({ x: this.px(xScale), y: this.px(yScale) })
  }

  @Builder
  private buildDiamond(scale: number, xScale: number = 0, yScale: number = 0, outlined: boolean = false) {
    Column()
      .width(this.px(scale))
      .height(this.px(scale))
      .borderRadius(this.px(scale * 0.16))
      .backgroundColor(outlined ? this.transparent() : this.iconColor)
      .border(outlined ? {
        width: this.resolvedStrokeWidth(),
        color: this.iconColor,
        radius: this.px(scale * 0.16)
      } : {
        width: 0,
        color: this.transparent(),
        radius: this.px(scale * 0.16)
      })
      .rotate({ angle: 45 })
      .position({ x: this.px(xScale), y: this.px(yScale) })
  }

  @Builder
  buildIconContent() {
    if (this.iconType === 'search') {
      this.buildSearchIcon()
    } else if (this.iconType === 'close') {
      this.buildCloseIcon()
    } else if (this.iconType === 'arrowLeft') {
      this.buildArrowLeftIcon()
    } else if (this.iconType === 'arrowRight') {
      this.buildArrowRightIcon()
    } else if (this.iconType === 'check') {
      this.buildCheckIcon()
    } else if (this.iconType === 'clock') {
      this.buildClockIcon()
    } else if (this.iconType === 'star') {
      this.buildStarIcon(true)
    } else if (this.iconType === 'starOutline') {
      this.buildStarIcon(false)
    } else if (this.iconType === 'circle') {
      this.buildCircleIcon()
    } else if (this.iconType === 'square') {
      this.buildSquareIcon()
    } else if (this.iconType === 'diamond') {
      this.buildDiamondIcon()
    } else if (this.iconType === 'hexagon') {
      this.buildHexagonIcon()
    } else if (this.iconType === 'triangle') {
      this.buildTriangleIcon()
    } else if (this.iconType === 'person') {
      this.buildPersonIcon()
    } else if (this.iconType === 'chat') {
      this.buildChatIcon()
    } else if (this.iconType === 'ai') {
      this.buildAiIcon()
    } else if (this.iconType === 'sad') {
      this.buildSadIcon()
    } else if (this.iconType === 'plus') {
      this.buildPlusIcon()
    } else if (this.iconType === 'minus') {
      this.buildMinusIcon()
    } else if (this.iconType === 'edit') {
      this.buildEditIcon()
    } else if (this.iconType === 'grid') {
      this.buildGridIcon()
    } else if (this.iconType === 'briefcase') {
      this.buildBriefcaseIcon()
    } else if (this.iconType === 'coin') {
      this.buildCoinIcon()
    } else if (this.iconType === 'cpu') {
      this.buildCpuIcon()
    } else if (this.iconType === 'landmark') {
      this.buildLandmarkIcon()
    } else if (this.iconType === 'palette') {
      this.buildPaletteIcon()
    } else if (this.iconType === 'trophy') {
      this.buildTrophyIcon()
    } else if (this.iconType === 'bookOpen') {
      this.buildBookOpenIcon()
    } else if (this.iconType === 'brain') {
      this.buildBrainIcon()
    } else if (this.iconType === 'sparkles') {
      this.buildSparklesIcon()
    } else if (this.iconType === 'dot') {
      this.buildDotIcon()
    } else {
      this.buildCircleIcon()
    }
  }

  @Builder
  buildSearchIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.54, 0.08, 0.08)
      this.buildLine(0.26, 45, 0.56, 0.56)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildCloseIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.60, 45, 0.20, 0.49)
      this.buildLine(0.60, -45, 0.20, 0.49)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildArrowLeftIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.44, 0, 0.34, 0.49)
      this.buildLine(0.26, -45, 0.18, 0.38)
      this.buildLine(0.26, 45, 0.18, 0.60)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildArrowRightIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.44, 0, 0.22, 0.49)
      this.buildLine(0.26, 45, 0.56, 0.38)
      this.buildLine(0.26, -45, 0.56, 0.60)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildCheckIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.22, 45, 0.18, 0.60)
      this.buildLine(0.44, -45, 0.32, 0.50)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildClockIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.68, 0.16, 0.16)
      this.buildLine(0.18, 90, 0.49, 0.40)
      this.buildLine(0.16, 0, 0.49, 0.49)
      this.buildFilledDot(0.07, 0.47, 0.47)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildStarIcon(filled: boolean) {
    Text(filled ? '★' : '☆')
      .fontSize(this.iconSize * 0.92)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.iconColor)
      .textAlign(TextAlign.Center)
      .width(this.iconSize)
      .height(this.iconSize)
  }

  @Builder
  buildCircleIcon() {
    Column()
      .width(this.px(0.46))
      .height(this.px(0.46))
      .borderRadius(this.px(0.23))
      .backgroundColor(this.iconColor)
  }

  @Builder
  buildDotIcon() {
    Column()
      .width(this.px(0.28))
      .height(this.px(0.28))
      .borderRadius(this.px(0.14))
      .backgroundColor(this.iconColor)
  }

  @Builder
  buildSquareIcon() {
    Column()
      .width(this.px(0.42))
      .height(this.px(0.42))
      .borderRadius(this.px(0.10))
      .backgroundColor(this.iconColor)
  }

  @Builder
  buildDiamondIcon() {
    this.buildDiamond(0.34, 0.33, 0.33)
  }

  @Builder
  buildTriangleIcon() {
    Column()
      .width(0)
      .height(0)
      .borderWidth({
        top: this.px(0.48),
        left: this.px(0.32),
        right: this.px(0.32)
      })
      .borderColor({
        top: this.iconColor,
        left: this.transparent(),
        right: this.transparent()
      })
  }

  @Builder
  buildHexagonIcon() {
    Column()
      .width(this.px(0.54))
      .height(this.px(0.42))
      .borderRadius(this.px(0.12))
      .backgroundColor(this.iconColor)
  }

  @Builder
  buildPersonIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.28, 0.36, 0.12)
      this.buildOutlinedRect(0.50, 0.28, 0.16, 0.25, 0.56)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildChatIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedRect(0.66, 0.42, 0.12, 0.14, 0.20)
      this.buildLine(0.16, 45, 0.22, 0.58)
      this.buildLine(0.14, 0, 0.30, 0.70)
      this.buildLine(0.12, 0, 0.28, 0.36)
      this.buildLine(0.18, 0, 0.28, 0.50)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildAiIcon() {
    this.buildSparklesIcon()
  }

  @Builder
  buildSadIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.68, 0.16, 0.16)
      this.buildFilledDot(0.08, 0.34, 0.38)
      this.buildFilledDot(0.08, 0.58, 0.38)
      this.buildLine(0.24, 0, 0.38, 0.62)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildPlusIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.52, 0, 0.24, 0.49)
      this.buildLine(0.52, 90, 0.49, 0.24)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildMinusIcon() {
    this.buildLine(0.52, 0, 0.24, 0.49)
  }

  @Builder
  buildEditIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.48, -45, 0.28, 0.42)
      this.buildDiamond(0.10, 0.62, 0.22)
      this.buildLine(0.36, 0, 0.22, 0.74)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildGridIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedRect(0.20, 0.20, 0.06, 0.12, 0.12)
      this.buildOutlinedRect(0.20, 0.20, 0.06, 0.56, 0.12)
      this.buildOutlinedRect(0.20, 0.20, 0.06, 0.12, 0.56)
      this.buildOutlinedRect(0.20, 0.20, 0.06, 0.56, 0.56)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildBriefcaseIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedRect(0.64, 0.42, 0.12, 0.18, 0.30)
      this.buildLine(0.20, 0, 0.40, 0.14)
      this.buildLine(0.10, 90, 0.36, 0.16)
      this.buildLine(0.10, 90, 0.54, 0.16)
      this.buildLine(0.60, 0, 0.20, 0.50)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildCoinIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.62, 0.19, 0.19)
      this.buildLine(0.20, 90, 0.49, 0.32)
      this.buildLine(0.18, 0, 0.38, 0.40)
      this.buildLine(0.18, 0, 0.38, 0.58)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildCpuIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedRect(0.48, 0.48, 0.12, 0.26, 0.26)
      this.buildLine(0.12, 90, 0.34, 0.08)
      this.buildLine(0.12, 90, 0.54, 0.08)
      this.buildLine(0.12, 90, 0.34, 0.80)
      this.buildLine(0.12, 90, 0.54, 0.80)
      this.buildLine(0.12, 0, 0.08, 0.34)
      this.buildLine(0.12, 0, 0.08, 0.54)
      this.buildLine(0.12, 0, 0.80, 0.34)
      this.buildLine(0.12, 0, 0.80, 0.54)
      this.buildFilledDot(0.10, 0.45, 0.45)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildLandmarkIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildLine(0.30, -35, 0.20, 0.28)
      this.buildLine(0.30, 35, 0.50, 0.28)
      this.buildLine(0.10, 90, 0.24, 0.50)
      this.buildLine(0.10, 90, 0.44, 0.50)
      this.buildLine(0.10, 90, 0.64, 0.50)
      this.buildLine(0.62, 0, 0.18, 0.74)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildPaletteIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.68, 0.16, 0.16)
      this.buildFilledDot(0.08, 0.34, 0.32)
      this.buildFilledDot(0.08, 0.52, 0.26)
      this.buildFilledDot(0.08, 0.58, 0.46)
      this.buildFilledDot(0.08, 0.38, 0.56)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildTrophyIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedRect(0.40, 0.24, 0.12, 0.30, 0.20)
      this.buildLine(0.12, 0, 0.16, 0.34)
      this.buildLine(0.12, 0, 0.72, 0.34)
      this.buildLine(0.18, 90, 0.49, 0.46)
      this.buildLine(0.32, 0, 0.34, 0.74)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildBookOpenIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedRect(0.28, 0.46, 0.08, 0.12, 0.18)
      this.buildOutlinedRect(0.28, 0.46, 0.08, 0.60, 0.18)
      this.buildLine(0.44, 90, 0.49, 0.18)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildBrainIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOutlinedCircle(0.34, 0.20, 0.24)
      this.buildOutlinedCircle(0.34, 0.46, 0.24)
      this.buildLine(0.18, 90, 0.49, 0.48)
      this.buildLine(0.18, 0, 0.41, 0.74)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  buildSparklesIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildDiamond(0.24, 0.38, 0.38, true)
      this.buildLine(0.16, 0, 0.42, 0.50)
      this.buildLine(0.16, 90, 0.50, 0.42)
      this.buildFilledDot(0.08, 0.70, 0.16)
      this.buildFilledDot(0.07, 0.20, 0.66)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }
}

@Component
export struct CategoryIconWidget {
  @Prop categoryId: string = 'all'
  @Prop iconSize: number = IconSize.sm
  @Prop iconColor: string = ''

  build() {
    Icon({
      iconType: getCategoryIconType(this.categoryId),
      iconSize: this.iconSize,
      iconColor: this.iconColor ? this.iconColor : getCategoryIconColor(this.categoryId)
    })
  }
}
