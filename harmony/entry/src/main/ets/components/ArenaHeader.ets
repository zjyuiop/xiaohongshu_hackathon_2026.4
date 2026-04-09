import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { ArenaMode } from '../common/Models'

// ArenaHeader 组件属性
export interface ArenaHeaderProps {
  profileName: string
  discussionMode: ArenaMode
}

// ArenaHeader 组件 - 议会头部
@Component
export struct ArenaHeader {
  @Prop profileName: string = ''
  @Prop discussionMode: ArenaMode = 'chat'
  onModeChange: (mode: ArenaMode) => void = () => {}

  build() {
    Column({ space: Spacing.card.large }) {
      Text('ARENA / COUNCIL')
        .fontSize(Typography.size.caption)
        .fontColor(Colors.primary)
        .letterSpacing(Typography.letterSpacing.wide)

      Text(this.profileName.length > 0 ? `${this.profileName} 的阶段议会` : '先去角色页选择人物')
        .fontSize(Typography.size.xxl)
        .fontWeight(Typography.weight.bold)
        .fontColor(Colors.textPrimary)

      Text('选择不同人生阶段的"人格体"参与议会讨论，为你的人生决策提供多角度建议。')
        .fontSize(Typography.size.body)
        .fontColor(Colors.textTertiary)
        .lineHeight(Typography.lineHeight.relaxed)

      Row({ space: Spacing.sm }) {
        this.buildModeButton('CHAT', 'chat')
        this.buildModeButton('DEBATE', 'debate')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.huge)
    .backgroundColor(Colors.cardPrimary)
    .borderRadius(BorderRadius.card.large)
  }

  @Builder
  buildModeButton(label: string, mode: ArenaMode) {
    Button(label)
      .height(34)
      .fontSize(Typography.size.sm)
      .fontWeight(Typography.weight.medium)
      .fontColor(this.discussionMode === mode ? Colors.primaryDark : Colors.textSecondary)
      .backgroundColor(this.discussionMode === mode ? Colors.primary : Colors.tagMuted)
      .borderRadius(BorderRadius.pill)
      .animation({
        duration: 150,
        curve: Curve.EaseOut
      })
      .onClick(() => {
        this.onModeChange(mode)
      })
  }
}
