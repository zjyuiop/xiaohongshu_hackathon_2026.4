import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'

// SummaryHeader 组件属性
export interface SummaryHeaderProps {
  hasContent: boolean
}

// SummaryHeader 组件 - 纪要页头部
@Component
export struct SummaryHeader {
  @Prop hasContent: boolean = false

  build() {
    Column({ space: Spacing.card.large }) {
      Text('EXPORT / SUMMARY')
        .fontSize(Typography.size.caption)
        .fontColor(Colors.primary)
        .letterSpacing(Typography.letterSpacing.wide)

      Text('会议纪要与来源')
        .fontSize(Typography.size.xxl)
        .fontWeight(Typography.weight.bold)
        .fontColor(Colors.textPrimary)

      Text(this.hasContent
        ? '议会已经生成纪要，可在这里快速回看共识、分歧与行动建议。'
        : '这里承接议会结果，在移动端只保留最关键的输出。')
        .fontSize(Typography.size.body)
        .fontColor(Colors.textTertiary)
        .lineHeight(Typography.lineHeight.relaxed)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.huge)
    .backgroundColor(Colors.cardPrimary)
    .borderRadius(BorderRadius.card.large)
  }
}
