import { SummaryRecord, SummaryParticipant } from '../common/Models'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { Icon } from './CustomIcon'

const EMPTY_SUMMARY_RECORD: SummaryRecord = {
  id: '',
  title: '',
  topic: '',
  createdAt: '',
  updatedAt: '',
  duration: 0,
  messageCount: 0,
  consensus: '',
  disagreements: [],
  actionableAdvice: [],
  narrativeHook: '',
  participants: [],
  highlights: [],
  tags: [],
  isFavorite: false,
  viewCount: 0,
  exportedAssets: [],
  messageIds: []
}

function formatSimpleDate(dateStr: string): string {
  if (!dateStr) {
    return ''
  }
  const date = new Date(dateStr)
  return `${date.getFullYear()}.${date.getMonth() + 1}.${date.getDate()}`
}

@Component
export struct ClassicSummaryCard {
  @Prop record: SummaryRecord = EMPTY_SUMMARY_RECORD
  @Prop showActions: boolean = true
  onShare: () => void = () => {}
  onFavorite: () => void = () => {}

  build() {
    Column({ space: Spacing.card.large }) {
      this.buildHeader()

      if (this.record.topic.length > 0) {
        this.buildSection('讨论主题', this.record.topic)
      }

      if (this.record.consensus.length > 0) {
        this.buildHighlightSection('核心共识', this.record.consensus, MintColors.mintBg, MintColors.mintDark)
      }

      if (this.record.disagreements.length > 0) {
        this.buildBulletSection('分歧焦点', this.record.disagreements, MintColors.error, 'rgba(224, 120, 128, 0.08)')
      }

      if (this.record.actionableAdvice.length > 0) {
        Column({ space: Spacing.sm }) {
          Text('行动建议')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.lavenderDark)

          ForEach(this.record.actionableAdvice, (item: string, index: number) => {
            Row({ space: Spacing.sm }) {
              Text(`${index + 1}`)
                .width(20)
                .height(20)
                .borderRadius(10)
                .textAlign(TextAlign.Center)
                .fontSize(Typography.size.xs)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .backgroundColor(MintColors.lavender)

              Text(item)
                .layoutWeight(1)
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textSecondary)
                .lineHeight(Typography.lineHeight.relaxed)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (item: string, index: number) => `${item}-${index}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(Spacing.md)
        .backgroundColor(MintColors.lavenderBg)
        .borderRadius(BorderRadius.xl)
      }

      if (this.record.narrativeHook.length > 0) {
        Column({ space: Spacing.xs }) {
          Text(`“${this.record.narrativeHook}”`)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Medium)
            .fontStyle(FontStyle.Italic)
            .fontColor(MintColors.textPrimary)
            .lineHeight(Typography.lineHeight.relaxed)
            .width('100%')

          if (this.record.participants.length > 0) {
            Text(`来自 ${this.record.participants[this.record.participants.length - 1].displayName}`)
              .fontSize(Typography.size.caption)
              .fontColor(MintColors.textMuted)
              .alignSelf(ItemAlign.End)
          }
        }
        .width('100%')
        .padding(Spacing.md)
        .backgroundColor('rgba(184, 169, 217, 0.12)')
        .borderRadius(BorderRadius.xl)
      }

      if (this.record.participants.length > 0) {
        this.buildParticipants()
      }

      this.buildFooter()

      if (this.showActions) {
        this.buildActions()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor(MintColors.cardPrimary)
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 0.5,
      color: MintColors.border,
      radius: BorderRadius.xxl2
    })
    .shadow({
      radius: 24,
      color: 'rgba(78, 205, 196, 0.08)',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  private buildHeader() {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Column()
          .width(26)
          .height(4)
          .borderRadius(2)
          .backgroundColor(MintColors.mint)

        Text('会议纪要')
          .fontSize(Typography.size.subtitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.record.title.length > 0 ? this.record.title : '未命名纪要')
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Medium)
        .fontColor(MintColors.textSecondary)
        .width('100%')
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSection(title: string, content: string) {
    Column({ space: Spacing.xs }) {
      Text(title)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textMuted)

      Text(content)
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textPrimary)
        .lineHeight(Typography.lineHeight.relaxed)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildHighlightSection(title: string, content: string, bgColor: string, titleColor: string) {
    Column({ space: Spacing.sm }) {
      Text(title)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(titleColor)

      Text(content)
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textPrimary)
        .lineHeight(Typography.lineHeight.relaxed)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.md)
    .backgroundColor(bgColor)
    .borderRadius(BorderRadius.xl)
  }

  @Builder
  private buildBulletSection(title: string, items: string[], dotColor: string, bgColor: string) {
    Column({ space: Spacing.sm }) {
      Text(title)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(dotColor)

      ForEach(items, (item: string, index: number) => {
        Row({ space: Spacing.xs }) {
          Column()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(index % 2 === 0 ? dotColor : MintColors.lavender)
            .margin({ top: 7 })

          Text(item)
            .layoutWeight(1)
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .lineHeight(Typography.lineHeight.relaxed)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (item: string, index: number) => `${item}-${index}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.md)
    .backgroundColor(bgColor)
    .borderRadius(BorderRadius.xl)
  }

  @Builder
  private buildParticipants() {
    Column({ space: Spacing.sm }) {
      Text('参与角色')
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textMuted)

      Row({ space: Spacing.sm }) {
        ForEach(this.record.participants.slice(0, 4), (participant: SummaryParticipant, index: number) => {
          Column({ space: 6 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(36)
                .height(36)
                .borderRadius(18)
                .backgroundColor(participant.accentColor)

              Text(participant.displayName.charAt(0))
                .fontSize(Typography.size.caption)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }

            Text(participant.displayName)
              .fontSize(Typography.size.xs)
              .fontColor(MintColors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width(60)
              .textAlign(TextAlign.Center)
          }
          .width(64)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: Spacing.sm, bottom: Spacing.sm })
          .backgroundColor('rgba(255, 255, 255, 0.5)')
          .borderRadius(BorderRadius.xl)
        }, (participant: SummaryParticipant, index: number) => `${participant.agentId}-${index}`)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildFooter() {
    Row() {
      Text(formatSimpleDate(this.record.createdAt))
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textMuted)

      Blank()

      Text(`${this.record.messageCount} 条消息`)
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textMuted)
    }
    .width('100%')
  }

  @Builder
  private buildActions() {
    Row({ space: Spacing.card.medium }) {
      Button('分享纪要')
        .layoutWeight(1)
        .height(42)
        .fontSize(Typography.size.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(MintColors.mintDark)
        .backgroundColor(MintColors.mintBg)
        .borderRadius(BorderRadius.xxl)
        .onClick(() => {
          this.onShare()
        })

      Button(this.record.isFavorite ? '已收藏' : '收藏')
        .layoutWeight(1)
        .height(42)
        .fontSize(Typography.size.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.record.isFavorite ? MintColors.warning : MintColors.textSecondary)
        .backgroundColor(this.record.isFavorite ? 'rgba(232, 184, 109, 0.16)' : MintColors.surface)
        .borderRadius(BorderRadius.xxl)
        .onClick(() => {
          this.onFavorite()
        })
    }
    .width('100%')
  }
}

@Component
export struct QuoteSummaryCard {
  @Prop quote: string = ''
  @Prop speaker: string = ''
  @Prop topic: string = ''
  @Prop tags: string[] = []
  @Prop cardColor: string = '#4ECDC4'
  onShare: () => void = () => {}

  build() {
    Column({ space: Spacing.lg }) {
      Blank().layoutWeight(1)

      Text('“')
        .fontSize(72)
        .fontWeight(FontWeight.Bold)
        .fontColor('rgba(255, 255, 255, 0.30)')
        .alignSelf(ItemAlign.Start)

      Text(this.quote.length > 0 ? this.quote : '这条纪要还没有可展示的金句。')
        .fontSize(Typography.size.xl)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .lineHeight(Typography.lineHeight.loose)
        .textAlign(TextAlign.Center)
        .width('100%')

      if (this.speaker.length > 0) {
        Text(`- ${this.speaker}`)
          .fontSize(Typography.size.body)
          .fontColor('rgba(255, 255, 255, 0.90)')
          .fontWeight(FontWeight.Medium)
      }

      if (this.topic.length > 0) {
        Text(this.topic)
          .fontSize(Typography.size.caption)
          .fontColor('rgba(255, 255, 255, 0.76)')
          .textAlign(TextAlign.Center)
      }

      if (this.tags.length > 0) {
        Row({ space: Spacing.sm }) {
          ForEach(this.tags.slice(0, 3), (tag: string, index: number) => {
            Text(`#${tag}`)
              .fontSize(Typography.size.xs)
              .fontColor('rgba(255, 255, 255, 0.88)')
              .padding({ left: Spacing.sm, right: Spacing.sm, top: 4, bottom: 4 })
              .backgroundColor('rgba(255, 255, 255, 0.16)')
              .borderRadius(BorderRadius.pill)
          }, (tag: string, index: number) => `${tag}-${index}`)
        }
      }

      Blank().layoutWeight(1)

      Button('分享卡片')
        .height(40)
        .fontSize(Typography.size.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.cardColor)
        .backgroundColor('rgba(255, 255, 255, 0.88)')
        .borderRadius(BorderRadius.xxl)
        .onClick(() => {
          this.onShare()
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding(Spacing.xl)
    .backgroundColor(this.cardColor)
    .borderRadius(BorderRadius.xxl2)
  }
}

@Component
export struct TimelineSummaryCard {
  @Prop record: SummaryRecord = EMPTY_SUMMARY_RECORD
  @Prop messageCount: number = 0
  @Prop duration: string = '未记录时长'
  @Prop highlightCount: number = 0
  onReplay: () => void = () => {}
  onShare: () => void = () => {}
  onFavorite: () => void = () => {}

  build() {
    Column({ space: Spacing.card.large }) {
      Row({ space: Spacing.sm }) {
        Icon({
          iconType: 'clock',
          iconSize: 16,
          iconColor: MintColors.lavenderDark
        })

        Text('会议回放概览')
          .fontSize(Typography.size.subtitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: Spacing.card.medium }) {
        this.buildStatCard('消息数', `${this.messageCount}`, MintColors.mintBg)
        this.buildStatCard('时长', this.duration, MintColors.lavenderBg)
        this.buildStatCard('亮点', `${this.highlightCount}`, 'rgba(232, 184, 109, 0.12)')
      }
      .width('100%')

      if (this.record.participants.length > 0) {
        Column({ space: Spacing.sm }) {
          Text('参与角色')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textMuted)

          Row({ space: Spacing.sm }) {
            ForEach(this.record.participants.slice(0, 3), (participant: SummaryParticipant, index: number) => {
              Column({ space: Spacing.xs }) {
                Stack({ alignContent: Alignment.Center }) {
                  Column()
                    .width(40)
                    .height(40)
                    .borderRadius(20)
                    .backgroundColor(participant.accentColor)

                  Text(participant.displayName.charAt(0))
                    .fontSize(Typography.size.caption)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                }

                Text(participant.displayName)
                  .fontSize(Typography.size.xs)
                  .fontColor(MintColors.textSecondary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width(68)
                  .textAlign(TextAlign.Center)
              }
              .width(72)
              .alignItems(HorizontalAlign.Center)
            }, (participant: SummaryParticipant, index: number) => `${participant.agentId}-${index}`)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Row({ space: Spacing.card.medium }) {
        Button('展开回放')
          .layoutWeight(1)
          .height(42)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.lavenderDark)
          .backgroundColor(MintColors.lavenderBg)
          .borderRadius(BorderRadius.xxl)
          .onClick(() => {
            this.onReplay()
          })

        Button('分享')
          .layoutWeight(1)
          .height(42)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.mintDark)
          .backgroundColor(MintColors.mintBg)
          .borderRadius(BorderRadius.xxl)
          .onClick(() => {
            this.onShare()
          })

        Button(this.record.isFavorite ? '已藏' : '收藏')
          .width(60)
          .height(42)
          .fontSize(Typography.size.body)
          .fontColor(this.record.isFavorite ? MintColors.warning : MintColors.textMuted)
          .backgroundColor(this.record.isFavorite ? 'rgba(232, 184, 109, 0.16)' : MintColors.surface)
          .borderRadius(BorderRadius.xxl)
          .onClick(() => {
            this.onFavorite()
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor(MintColors.cardPrimary)
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 0.5,
      color: MintColors.border,
      radius: BorderRadius.xxl2
    })
    .shadow({
      radius: 24,
      color: 'rgba(184, 169, 217, 0.08)',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  private buildStatCard(label: string, value: string, bgColor: string) {
    Column({ space: Spacing.xs }) {
      Text(value)
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)

      Text(label)
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textMuted)
    }
    .layoutWeight(1)
    .padding(Spacing.md)
    .backgroundColor(bgColor)
    .borderRadius(BorderRadius.xl)
    .alignItems(HorizontalAlign.Start)
  }
}
