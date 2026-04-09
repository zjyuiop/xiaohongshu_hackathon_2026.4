import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import {
  AnimationDuration,
  AnimationCurve
} from '../common/styles/Animation'

export interface HeroSectionProps {
  selectedProfileName: string
  connectionLabel: string
}

@Component
export struct HeroSection {
  @Prop public selectedProfileName: string = ''
  @Prop public connectionLabel: string = '连接中'
  @State private lineOpacity: number = 0
  @State private lineScaleY: number = 0
  @State private contentOpacity: number = 0
  @State private chipOpacity: number = 0
  @State private badgeTranslateY: number = 12
  @State private glowOpacity: number = 0
  @State private dotScale: number = 0

  aboutToAppear(): void {
    // 光晕淡入
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slower,
        curve: AnimationCurve.emphasized
      }, () => {
        this.glowOpacity = 1
      })
    }, 0)

    // 线条从上到下生长
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.lineOpacity = 1
        this.lineScaleY = 1
      })
    }, AnimationDuration.instant)

    // 标题内容淡入
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.contentOpacity = 1
      })
    }, AnimationDuration.fast)

    // 装饰点弹出
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.normal,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.dotScale = 1
      })
    }, AnimationDuration.normal)

    // 状态标签滑入
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.normal,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.chipOpacity = 1
        this.badgeTranslateY = 0
      })
    }, AnimationDuration.slow)
  }

  private isLiveConnection(): boolean {
    const status = this.connectionLabel.toUpperCase()
    return status.includes('LIVE') || status.includes('成功') || status.includes('ONLINE')
  }

  private getRoleLabel(): string {
    return this.selectedProfileName.length > 0 ? this.selectedProfileName : '待选择角色'
  }

  private getStatusColor(): string {
    return this.isLiveConnection() ? Colors.success : Colors.warning
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(122)
        .height(122)
        .borderRadius(61)
        .backgroundColor('rgba(99, 102, 241, 0.08)')
        .blur(36)
        .position({ x: -28, y: -18 })
        .opacity(this.glowOpacity)
        .scale({
          x: this.glowOpacity * 0.2 + 0.8,
          y: this.glowOpacity * 0.2 + 0.8
        })

      Row({ space: Spacing.sm }) {
        Column()
          .width(4)
          .height(64)
          .borderRadius(2)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#6366F1', 0], ['#A78BFA', 1]]
          })
          .scale({
            x: 1,
            y: this.lineScaleY
          })
          .opacity(this.lineOpacity)

        Column({ space: Spacing.sm }) {
          Row({ space: Spacing.sm }) {
            Text('时序人格')
              .fontSize(Typography.size.display)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.textPrimary)
              .opacity(this.contentOpacity)
              .translate({
                x: this.contentOpacity > 0 ? 0 : -20,
                y: 0
              })
              .animation({
                duration: AnimationDuration.slow,
                curve: AnimationCurve.emphasized
              })

            Column()
              .width(10)
              .height(10)
              .borderRadius(5)
              .backgroundColor('#F59E0B')
              .margin({ top: 12 })
              .opacity(this.contentOpacity)
              .scale({
                x: this.dotScale,
                y: this.dotScale
              })
          }
          .width('100%')

          Text('Chronological Persona')
            .fontSize(Typography.size.sm)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(99, 102, 241, 0.72)')
            .letterSpacing(1.6)
            .fontStyle(FontStyle.Italic)
            .width('100%')
            .opacity(this.contentOpacity)
            .translate({
              x: this.contentOpacity > 0 ? 0 : -16,
              y: 0
            })
            .animation({
              duration: AnimationDuration.slow,
              delay: AnimationDuration.fast,
              curve: AnimationCurve.emphasized
            })

          Text('收集与创造多元思想切片')
            .fontSize(Typography.size.bodyLg)
            .fontColor(Colors.textTertiary)
            .letterSpacing(0.5)
            .width('100%')
            .opacity(this.contentOpacity)
            .translate({
              x: this.contentOpacity > 0 ? 0 : -16,
              y: 0
            })
            .animation({
              duration: AnimationDuration.slow,
              delay: AnimationDuration.fast,
              curve: AnimationCurve.emphasized
            })

          Row({ space: Spacing.sm }) {
            this.buildInfoChip(this.getRoleLabel(), Colors.primary, 'rgba(99, 102, 241, 0.08)')
            this.buildInfoChip(this.connectionLabel, this.getStatusColor(), this.isLiveConnection() ? 'rgba(16, 185, 129, 0.10)' : 'rgba(245, 158, 11, 0.12)')
          }
          .width('100%')
          .opacity(this.chipOpacity)
          .translate({ x: 0, y: this.badgeTranslateY })
          .animation({
            duration: AnimationDuration.normal,
            curve: AnimationCurve.emphasized
          })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .padding({
      left: Spacing.xs,
      right: Spacing.xs,
      top: Spacing.lg,
      bottom: Spacing.md
    })
  }

  @Builder
  buildInfoChip(label: string, dotColor: string, backgroundColor: string) {
    Row({ space: 6 }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(dotColor)

      Text(label)
        .fontSize(Typography.size.xs)
        .fontColor(Colors.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({
      left: Spacing.sm,
      right: Spacing.sm,
      top: 6,
      bottom: 6
    })
    .backgroundColor(backgroundColor)
    .borderRadius(BorderRadius.pill)
    .border({
      width: 1,
      color: 'rgba(255, 255, 255, 0.55)',
      radius: BorderRadius.pill
    })
  }
}
