import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { SourceDocumentSummary } from '../common/Models'

// SourceDocument 组件属性
export interface SourceDocumentProps {
  document: SourceDocumentSummary
}

// SourceDocument 组件 - 源文档信息
@Component
export struct SourceDocument {
  @Prop document: SourceDocumentSummary

  build() {
    Column({ space: Spacing.sm }) {
      Text('SOURCE DOCUMENT')
        .fontSize(Typography.size.caption)
        .fontColor(Colors.accentAlt)
        .letterSpacing(Typography.letterSpacing.wide)

      Text(this.document.title)
        .fontSize(Typography.size.lg)
        .fontWeight(Typography.weight.bold)
        .fontColor(Colors.textPrimary)

      if (this.document.author && this.document.author.length > 0) {
        Text(this.document.author)
          .fontSize(Typography.size.body)
          .fontColor(Colors.textSecondary)
      }

      if (this.document.sectionCount > 0) {
        Text(`${this.document.sectionCount} sections`)
          .fontSize(Typography.size.sm)
          .fontColor(Colors.textTertiary)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.card.xlarge)
    .backgroundColor('#151025')
    .borderRadius(BorderRadius.card.xlarge)
  }
}
