import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'

// TopicInput 组件属性
export interface TopicInputProps {
  value: string
  isLoading: boolean
  canSubmit: boolean
}

// TopicInput 组件 - 议题输入框
@Component
export struct TopicInput {
  @Prop value: string = ''
  @Prop isLoading: boolean = false
  @Prop canSubmit: boolean = false
  onChange: (value: string) => void = () => {}
  onSubmit: () => void = () => {}

  build() {
    Column({ space: Spacing.card.large }) {
      TextArea({ text: this.value, placeholder: '输入议题，例如：现在该不该继续创业？' })
        .width('100%')
        .height(120)
        .fontSize(Typography.size.bodyLg)
        .fontColor(Colors.textPrimary)
        .placeholderColor(Colors.textPlaceholder)
        .backgroundColor(Colors.background)
        .borderRadius(BorderRadius.card.medium)
        .padding(Spacing.card.medium)
        .onChange((value: string) => {
          this.onChange(value)
        })

      Button('启动议会')
        .width('100%')
        .height(48)
        .fontSize(Typography.size.subtitle)
        .fontColor(this.canSubmit && !this.isLoading ? Colors.primaryDark : Colors.textMuted)
        .backgroundColor(this.canSubmit && !this.isLoading ? Colors.primary : Colors.tagMuted)
        .borderRadius(BorderRadius.pill)
        .enabled(this.canSubmit && !this.isLoading)
        .opacity(this.canSubmit && !this.isLoading ? 1 : 0.6)
        .scale({
          x: this.canSubmit && !this.isLoading ? 1 : 0.98,
          y: this.canSubmit && !this.isLoading ? 1 : 0.98
        })
        .animation({
          duration: 150,
          curve: Curve.EaseOut
        })
        .onClick(() => {
          if (this.canSubmit && !this.isLoading) {
            this.onSubmit()
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.huge)
    .backgroundColor(Colors.cardPrimary)
    .borderRadius(BorderRadius.card.large)
  }
}
