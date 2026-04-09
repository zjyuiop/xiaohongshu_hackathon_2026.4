import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { PresetProfile } from '../common/Models'

// ProfilePanel 组件属性
export interface ProfilePanelProps {
  profile: PresetProfile
  selectedAgentCount: number
  topic: string
}

// ProfilePanel 组件 - 清新风格当前角色信息面板
@Component
export struct ProfilePanel {
  @Prop profile: PresetProfile
  @Prop selectedAgentCount: number = 0
  @Prop topic: string = ''
  onViewTimeline: () => void = () => {}

  build() {
    Column({ space: Spacing.card.large }) {
      // 角色名称
      Text(this.profile.displayName)
        .fontSize(Typography.size.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)

      // 副标题
      Text(this.profile.subtitle)
        .fontSize(Typography.size.bodyLg)
        .fontColor(Colors.accent)

      // 状态信息行
      Row({ space: Spacing.sm }) {
        // 已选人格数
        Text(`${this.selectedAgentCount} / 3 人格已选`)
          .fontSize(Typography.size.sm)
          .fontColor(Colors.textTertiary)
          .padding({
            left: Spacing.card.medium,
            right: Spacing.card.medium,
            top: Spacing.xs,
            bottom: Spacing.xs
          })
          .backgroundColor('rgba(241, 245, 249, 0.8)')
          .borderRadius(BorderRadius.pill)

        // 当前议题（如果有）
        if (this.topic.length > 0) {
          Text(`"${this.topic.substring(0, 15)}${this.topic.length > 15 ? '...' : ''}"`)
            .fontSize(Typography.size.sm)
            .fontColor(Colors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 140 })
        }
      }
      .width('100%')

      // 查看时间线按钮
      Button('查看时间线 · 选择人格 · 进入议会')
        .width('100%')
        .height(52)
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(Colors.primary)
        .borderRadius(BorderRadius.huge)
        .shadow({
          radius: 20,
          color: 'rgba(99, 102, 241, 0.15)',
          offsetX: 0,
          offsetY: 8
        })
        .scale({ x: 1, y: 1 })
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
        .onClick(() => {
          this.onViewTimeline()
        })
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
  }
}
