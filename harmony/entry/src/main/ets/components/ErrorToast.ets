import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'

// ErrorToast 组件属性
export interface ErrorToastProps {
  message: string
}

// ErrorToast 组件 - 清新风格错误提示
@Component
export struct ErrorToast {
  @Prop message: string = ''
  onRetry: () => void = () => {}

  build() {
    if (this.message.length > 0) {
      Column({ space: Spacing.sm }) {
        Row({ space: Spacing.sm }) {
          Text('⚠')
            .fontSize(Typography.size.bodyLg)
            .fontColor(Colors.error)

          Text(this.message)
            .fontSize(Typography.size.bodyLg)
            .fontColor(Colors.textPrimary)
            .lineHeight(Typography.lineHeight.relaxed)
            .layoutWeight(1)

          Button('重试')
            .fontSize(Typography.size.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor(Colors.error)
            .borderRadius(BorderRadius.md)
            .padding({
              left: Spacing.card.medium,
              right: Spacing.card.medium,
              top: Spacing.xs,
              bottom: Spacing.xs
            })
            .onClick(() => {
              this.onRetry()
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .padding(Spacing.card.large)
      .backgroundColor(Colors.errorBg)
      .borderRadius(BorderRadius.huge)
      .shadow({
        radius: 15,
        color: 'rgba(244, 63, 94, 0.1)',
        offsetX: 0,
        offsetY: 4
      })
      .transition(TransitionEffect.OPACITY.animation({
        duration: 200,
        curve: Curve.EaseOut
      }))
    }
  }
}
