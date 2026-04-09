import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { AnimationDuration } from '../common/styles/Animation'

// AnimatedButton 组件属性
export interface AnimatedButtonProps {
  label: string
  type?: 'primary' | 'secondary' | 'outline'
  disabled?: boolean
  loading?: boolean
  icon?: Resource
}

// AnimatedButton 组件 - 带微交互的按钮
@Component
export struct AnimatedButton {
  @Prop label: string = ''
  @Prop type: string = 'primary'
  @Prop disabled: boolean = false
  @Prop loading: boolean = false
  @Prop icon: Resource | null = null
  @State private isPressed: boolean = false
  @State private isHovered: boolean = false
  @State private rippleScale: number = 0
  @State private rippleOpacity: number = 0
  onClick: () => void = () => {}

  private getBackgroundColor(): string {
    if (this.disabled) {
      return Colors.borderLight
    }
    switch (this.type) {
      case 'primary':
        return Colors.primary
      case 'secondary':
        return Colors.cardPrimary
      case 'outline':
        return 'transparent'
      default:
        return Colors.primary
    }
  }

  private getTextColor(): string {
    if (this.disabled) {
      return Colors.textMuted
    }
    switch (this.type) {
      case 'primary':
        return '#FFFFFF'
      case 'secondary':
        return Colors.textSecondary
      case 'outline':
        return Colors.primary
      default:
        return '#FFFFFF'
    }
  }

  private getBorderColor(): string {
    if (this.type === 'outline') {
      return this.disabled ? Colors.borderLight : Colors.primary
    }
    return 'transparent'
  }

  private triggerRipple(): void {
    this.rippleScale = 0
    this.rippleOpacity = 0.3

    animateTo({
      duration: 600,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.rippleScale = 2
      this.rippleOpacity = 0
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 涟漪效果
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(BorderRadius.huge)
        .backgroundColor(this.type === 'primary' ? '#FFFFFF' : Colors.primary)
        .scale({
          x: this.rippleScale,
          y: this.rippleScale
        })
        .opacity(this.rippleOpacity)

      // 按钮主体
      Row({ space: Spacing.sm }) {
        if (this.loading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.getTextColor())
        } else if (this.icon) {
          Image(this.icon)
            .width(20)
            .height(20)
            .fillColor(this.getTextColor())
        }

        Text(this.label)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getTextColor())
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.getBackgroundColor())
      .borderRadius(BorderRadius.huge)
      .border({
        width: this.type === 'outline' ? 1.5 : 0,
        color: this.getBorderColor()
      })
      .shadow({
        radius: this.type === 'primary' ? (this.isPressed ? 8 : 15) : 10,
        color: this.type === 'primary' ? 'rgba(99, 102, 241, 0.15)' : 'rgba(0, 0, 0, 0.04)',
        offsetX: 0,
        offsetY: this.isPressed ? 2 : 4
      })
      .scale({
        x: this.isPressed ? 0.96 : (this.isHovered ? 1.02 : 1),
        y: this.isPressed ? 0.96 : (this.isHovered ? 1.02 : 1)
      })
      .animation({
        duration: this.isPressed ? AnimationDuration.instant : AnimationDuration.fast,
        curve: this.isPressed ? Curve.Sharp : Curve.FastOutSlowIn
      })
      .onTouch((event: TouchEvent) => {
        if (this.disabled || this.loading) {
          return
        }

        if (event.type === TouchType.Down) {
          animateTo({
            duration: AnimationDuration.instant,
            curve: Curve.Sharp
          }, () => {
            this.isPressed = true
          })
          this.triggerRipple()
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          animateTo({
            duration: AnimationDuration.fast,
            curve: Curve.FastOutSlowIn
          }, () => {
            this.isPressed = false
          })
        }
      })
      .onClick(() => {
        if (!this.disabled && !this.loading) {
          this.onClick()
        }
      })
    }
    .width('100%')
    .height(48)
  }
}
