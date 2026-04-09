import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'

// SummaryCard 组件属性
export interface SummaryCardProps {
  summaryTitle: string
  consensus: string
  disagreements: string[]
  actionableAdvice: string[]
  narrativeHook: string
}

// SummaryCard 组件 - 清新风格会议纪要卡片
@Component
export struct SummaryCard {
  @Prop public summaryTitle: string = ''
  @Prop public consensus: string = ''
  @Prop public disagreements: string[] = []
  @Prop public actionableAdvice: string[] = []
  @Prop public narrativeHook: string = ''
  @State private cardOpacity: number = 0
  @State private cardScale: number = 0.95
  @State private itemsOpacity: number = 0
  public onGoArena: () => void = () => {}
  public onGoRole: () => void = () => {}

  aboutToAppear(): void {
    if (this.summaryTitle.length > 0) {
      // 卡片入场
      setTimeout(() => {
        animateTo({
          duration: 400,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.cardOpacity = 1
          this.cardScale = 1
        })
      }, 0)

      // 内容项延迟淡入
      setTimeout(() => {
        animateTo({
          duration: 350,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.itemsOpacity = 1
        })
      }, 200)
    }
  }

  build() {
    if (this.summaryTitle.length > 0) {
      Column({ space: Spacing.card.large }) {
        // 标题
        Text(this.summaryTitle)
          .fontSize(Typography.size.xxl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
          .width('100%')
          .opacity(this.cardOpacity)

        // 共识
        Text(this.consensus)
          .fontSize(Typography.size.bodyLg)
          .fontColor(Colors.textSecondary)
          .lineHeight(Typography.lineHeight.relaxed)
          .width('100%')
          .opacity(this.itemsOpacity)

        // 分隔线
        Divider()
          .color(Colors.borderLight)
          .margin({ top: Spacing.md, bottom: Spacing.md })
          .opacity(this.itemsOpacity)

        // 主要分歧
        Text('主要分歧')
          .fontSize(Typography.size.subtitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textTertiary)
          .width('100%')
          .opacity(this.itemsOpacity)

        ForEach(this.disagreements, (item: string, index: number) => {
          Row({ space: Spacing.sm }) {
            Text('•')
              .fontSize(Typography.size.body)
              .fontColor(Colors.error)
            Text(item)
              .fontSize(Typography.size.bodyLg)
              .fontColor(Colors.textSecondary)
              .lineHeight(Typography.lineHeight.relaxed)
          }
          .width('100%')
          .opacity(this.itemsOpacity)
          .translate({
            x: this.itemsOpacity > 0 ? 0 : -10,
            y: 0
          })
          .animation({
            duration: 300,
            curve: Curve.FastOutSlowIn,
            delay: 250 + index * 50
          })
        }, (item: string) => item)

        // 分隔线
        Divider()
          .color(Colors.borderLight)
          .margin({ top: Spacing.md, bottom: Spacing.md })
          .opacity(this.itemsOpacity)

        // 行动建议
        Text('行动建议')
          .fontSize(Typography.size.subtitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textTertiary)
          .width('100%')
          .opacity(this.itemsOpacity)

        ForEach(this.actionableAdvice, (item: string, index: number) => {
          Row({ space: Spacing.sm }) {
            Text('•')
              .fontSize(Typography.size.body)
              .fontColor(Colors.success)
            Text(item)
              .fontSize(Typography.size.bodyLg)
              .fontColor(Colors.textSecondary)
              .lineHeight(Typography.lineHeight.relaxed)
          }
          .width('100%')
          .opacity(this.itemsOpacity)
          .translate({
            x: this.itemsOpacity > 0 ? 0 : -10,
            y: 0
          })
          .animation({
            duration: 300,
            curve: Curve.FastOutSlowIn,
            delay: 300 + index * 50
          })
        }, (item: string) => item)

        // 叙事钩子
        if (this.narrativeHook.length > 0) {
          Text(`"${this.narrativeHook}"`)
            .fontSize(Typography.size.bodyLg)
            .fontColor(Colors.primary)
            .lineHeight(Typography.lineHeight.relaxed)
            .padding(Spacing.huge)
            .backgroundColor(Colors.accentPurple)
            .borderRadius(BorderRadius.huge)
            .width('100%')
            .opacity(this.itemsOpacity)
            .scale({
              x: this.itemsOpacity * 0.05 + 0.95,
              y: this.itemsOpacity * 0.05 + 0.95
            })
        }

        // 分隔线
        Divider()
          .color(Colors.borderLight)
          .margin({ top: Spacing.md })
          .opacity(this.itemsOpacity)

        // 操作按钮
        Row({ space: Spacing.card.large }) {
          Button('回到议会')
            .layoutWeight(1)
            .height(48)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor(Colors.primary)
            .borderRadius(BorderRadius.huge)
            .shadow({
              radius: 15,
              color: 'rgba(99, 102, 241, 0.15)',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              this.onGoArena()
            })

          Button('换角色')
            .layoutWeight(1)
            .height(48)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textSecondary)
            .backgroundColor(Colors.cardPrimary)
            .borderRadius(BorderRadius.huge)
            .shadow({
              radius: 10,
              color: 'rgba(0, 0, 0, 0.04)',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              this.onGoRole()
            })
        }
        .width('100%')
        .opacity(this.itemsOpacity)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(Spacing.huge)
      .backgroundColor(Colors.cardPrimary)
      .borderRadius(BorderRadius.huge)
      .backdropBlur(30)
      .shadow({
        radius: 30,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetX: 0,
        offsetY: 8
      })
      .opacity(this.cardOpacity)
      .scale({
        x: this.cardScale,
        y: this.cardScale
      })
    } else {
      Column({ space: Spacing.md }) {
        Text('暂无纪要')
          .fontSize(Typography.size.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)

        Text('启动一次议会后，这里会直接显示会议纪要。')
          .fontSize(Typography.size.bodyLg)
          .fontColor(Colors.textTertiary)
          .lineHeight(Typography.lineHeight.relaxed)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(Spacing.huge)
      .backgroundColor(Colors.cardPrimary)
      .borderRadius(BorderRadius.huge)
      .backdropBlur(30)
    }
  }
}
