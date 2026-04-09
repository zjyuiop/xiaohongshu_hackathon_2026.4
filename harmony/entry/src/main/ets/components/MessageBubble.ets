import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { ArenaMessage } from '../common/Models'

// 获取立场颜色
function getStanceColor(stance: string): string {
  switch (stance) {
    case 'support':
      return Colors.stance.support
    case 'oppose':
      return Colors.stance.oppose
    case 'reflective':
      return Colors.stance.reflective
    default:
      return Colors.stance.default
  }
}

// MessageBubble 组件属性
export interface MessageBubbleProps {
  message: ArenaMessage
}

// MessageBubble 组件 - 清新风格消息气泡
@Component
export struct MessageBubble {
  @Prop public message: ArenaMessage
  @State private bubbleOpacity: number = 0
  @State private bubbleScale: number = 0.95
  @State private bubbleTranslateY: number = 10
  public onLongPress: () => void = () => {}

  aboutToAppear(): void {
    // 气泡入场动画
    setTimeout(() => {
      animateTo({
        duration: 350,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.bubbleOpacity = 1
        this.bubbleScale = 1
        this.bubbleTranslateY = 0
      })
    }, 50)
  }

  build() {
    Column({ space: Spacing.sm }) {
      // 头部信息
      Row() {
        // 立场标签
        Text(this.message.stance.toUpperCase())
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(getStanceColor(this.message.stance))
          .padding({
            left: Spacing.sm,
            right: Spacing.sm,
            top: 4,
            bottom: 4
          })
          .backgroundColor(getStanceColor(this.message.stance) + '20')
          .borderRadius(BorderRadius.sm)

        Blank()

        // 显示名称
        Text(this.message.stageLabel + ' · ' + this.message.displayName)
          .fontSize(Typography.size.sm)
          .fontColor(Colors.accent)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      // 消息内容
      Text(this.message.content)
        .fontSize(Typography.size.bodyLg)
        .fontColor(Colors.textPrimary)
        .lineHeight(Typography.lineHeight.relaxed)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.huge)
    .backgroundColor(Colors.cardPrimary)
    .borderRadius(BorderRadius.huge)
    .shadow({
      radius: 20,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetX: 0,
      offsetY: 4
    })
    .opacity(this.bubbleOpacity)
    .scale({
      x: this.bubbleScale,
      y: this.bubbleScale
    })
    .translate({
      x: 0,
      y: this.bubbleTranslateY
    })
  }
}

// MessageList 组件属性
export interface MessageListProps {
  messages: ArenaMessage[]
  selectedAgentIds: string[]
}

// MessageList 组件 - 清新风格消息列表
@Component
export struct MessageList {
  @Prop public messages: ArenaMessage[] = []
  @Prop public selectedAgentIds: string[] = []
  @State private scrollToBottom: boolean = false

  build() {
    if (this.messages.length > 0) {
      Column({ space: Spacing.card.large }) {
        ForEach(this.messages, (message: ArenaMessage) => {
          MessageBubble({
            message: message
          })
        }, (message: ArenaMessage) => message.id)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: Spacing.sm }) {
        Text('等待启动')
          .fontSize(Typography.size.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)

        Text('这里承接 web 中间栏的对话流。点击"启动议会"后，会直接渲染返回的 messages。')
          .fontSize(Typography.size.bodyLg)
          .fontColor(Colors.textTertiary)
          .lineHeight(Typography.lineHeight.relaxed)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(Spacing.huge)
      .backgroundColor(Colors.cardPrimary)
      .borderRadius(BorderRadius.huge)
      .shadow({
        radius: 20,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetX: 0,
        offsetY: 4
      })
    }
  }
}
