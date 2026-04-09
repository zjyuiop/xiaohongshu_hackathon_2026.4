import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { AnimationDuration, AnimationCurve, getStaggerDelay } from '../common/styles/Animation'

export interface RecordItem {
  id: string
  title: string
  topic: string
  participants: string[]
  participantLine: string
  avatarColors: string[]
  avatarTextColors: string[]
  content: string
  timeAgo: string
  accentColor: string
  messageCount: number
  highlightCount: number
  durationLabel: string
  isFavorite: boolean
}

export interface RecordsTabProps {
  records: RecordItem[]
  onRecordClick: (record: RecordItem) => void
  onGenerateCard?: (record: RecordItem) => void
  onGenerateVideo?: (record: RecordItem) => void
  onShareRecord?: (record: RecordItem) => void
  onViewAll?: () => void
}

interface WorkspaceAction {
  id: string
  order: string
  title: string
  description: string
  actionLabel: string
  tint: string
  tone: string
}

const RECORD_CARD_BG: string = '#FFFFFF'
const RECORD_PREVIEW_BG: string = '#F5F7FB'
const HERO_CARD_BG: string = 'rgba(255, 255, 255, 0.84)'
const HERO_BORDER: string = 'rgba(255, 255, 255, 0.92)'

@Component
export struct RecordsTab {
  @Prop records: RecordItem[] = []
  onRecordClick: (record: RecordItem) => void = () => {}
  onGenerateCard: (record: RecordItem) => void = () => {}
  onGenerateVideo: (record: RecordItem) => void = () => {}
  onShareRecord: (record: RecordItem) => void = () => {}
  onViewAll: () => void = () => {}

  @State private heroOpacity: number = 0
  @State private heroTranslateY: number = 24
  @State private heroGlowOffset: number = 0
  @State private heroGlowScale: number = 0.96
  @State private heroHaloOpacity: number = 0.55
  @State private latestOpacity: number = 0
  @State private latestTranslateY: number = 20
  @State private latestScale: number = 0.97
  @State private historyOpacity: number = 0
  @State private historyTranslateY: number = 16
  @State private actionCardOpacities: number[] = [0, 0, 0]
  @State private actionCardTranslateX: number[] = [20, 20, 20]
  @State private actionPressedId: string = ''
  @State private historyCardOpacities: number[] = []
  @State private historyCardTranslateY: number[] = []
  @State private historyPressedId: string = ''

  private readonly workspaceActions: WorkspaceAction[] = [
    {
      id: 'card',
      order: '01',
      title: '生成卡片',
      description: '把共识、亮点和参与角色整理成适合分享的视觉卡片。',
      actionLabel: '去导出',
      tint: MintColors.mintDark,
      tone: 'rgba(78, 205, 196, 0.10)'
    },
    {
      id: 'video',
      order: '02',
      title: '会议视频',
      description: '将纪要整理为适合回顾和传播的视频入口。',
      actionLabel: '去生成',
      tint: MintColors.lavenderDark,
      tone: 'rgba(184, 169, 217, 0.12)'
    },
    {
      id: 'share',
      order: '03',
      title: '快速分享',
      description: '直接发给同事、朋友或其它设备，快速扩散讨论结果。',
      actionLabel: '去分享',
      tint: '#F97316',
      tone: 'rgba(249, 115, 22, 0.10)'
    }
  ]

  aboutToAppear(): void {
    this.prepareHistoryMotion()

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.smooth
      }, () => {
        this.heroOpacity = 1
        this.heroTranslateY = 0
      })
    }, 60)

    setTimeout(() => {
      this.startAmbientMotion()
    }, 260)

    for (let i = 0; i < 3; i++) {
      setTimeout(() => {
        animateTo({
          duration: AnimationDuration.normal,
          curve: AnimationCurve.smooth
        }, () => {
          this.actionCardOpacities[i] = 1
          this.actionCardTranslateX[i] = 0
        })
      }, 200 + getStaggerDelay(i, 80))
    }

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.smooth
      }, () => {
        this.latestOpacity = 1
        this.latestTranslateY = 0
        this.latestScale = 1
      })
    }, 250)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.smooth
      }, () => {
        this.historyOpacity = 1
        this.historyTranslateY = 0
      })
    }, 400)

    this.animateHistoryCards()
  }

  private prepareHistoryMotion(): void {
    const count = this.historyRecords().length
    const opacities: number[] = []
    const offsets: number[] = []
    for (let i = 0; i < count; i++) {
      opacities.push(0)
      offsets.push(22)
    }
    this.historyCardOpacities = opacities
    this.historyCardTranslateY = offsets
  }

  private animateHistoryCards(): void {
    const historyCount = this.historyRecords().length
    for (let i = 0; i < historyCount; i++) {
      setTimeout(() => {
        animateTo({
          duration: AnimationDuration.normal,
          curve: AnimationCurve.smooth
        }, () => {
          this.historyCardOpacities[i] = 1
          this.historyCardTranslateY[i] = 0
        })
      }, 460 + getStaggerDelay(i, 90))
    }
  }

  private startAmbientMotion(): void {
    animateTo({
      duration: 3200,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.heroGlowOffset = -12
      this.heroGlowScale = 1.05
      this.heroHaloOpacity = 0.82
    })
  }

  private latestRecord(): RecordItem | null {
    if (this.records.length === 0) {
      return null
    }
    return this.records[0]
  }

  private historyRecords(): RecordItem[] {
    if (this.records.length <= 1) {
      return []
    }
    return this.records.slice(1)
  }

  private hasRecord(): boolean {
    return this.records.length > 0
  }

  private getAvatarFg(record: RecordItem, index: number): string {
    if (index < record.avatarTextColors.length) {
      return record.avatarTextColors[index]
    }
    return '#FFFFFF'
  }

  private summaryCountLabel(): string {
    if (this.records.length === 0) {
      return '等待生成'
    }
    return `${this.records.length} 份纪要`
  }

  private latestStatusLabel(): string {
    const latest = this.latestRecord()
    return latest ? `最近更新 · ${latest.timeAgo}` : '完成一场会议后会自动沉淀'
  }

  private actionEnabled(): boolean {
    return this.latestRecord() !== null
  }

  private actionHint(enabled: boolean): string {
    return enabled ? '点击打开' : '先完成一场会议'
  }

  private runWorkspaceAction(actionId: string): void {
    const latest = this.latestRecord()
    if (!latest) {
      return
    }

    if (actionId === 'card') {
      this.onGenerateCard(latest)
      return
    }

    if (actionId === 'video') {
      this.onGenerateVideo(latest)
      return
    }

    this.onShareRecord(latest)
  }

  private actionCardScale(actionId: string): number {
    return this.actionPressedId === actionId ? 0.97 : 1
  }

  private historyCardOpacity(index: number): number {
    return index < this.historyCardOpacities.length ? this.historyCardOpacities[index] : 1
  }

  private historyCardTranslate(index: number): number {
    return index < this.historyCardTranslateY.length ? this.historyCardTranslateY[index] : 0
  }

  build() {
    Column({ space: Spacing.card.large }) {
      this.buildWorkspaceHero()

      if (this.hasRecord()) {
        this.buildLatestSummary(this.records[0])
      } else {
        this.buildEmptyState()
      }

      this.buildHistorySection()

      Blank()
        .height(Spacing.giant)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildWorkspaceHero() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(220)
        .height(220)
        .borderRadius(110)
        .backgroundColor('rgba(78, 205, 196, 0.10)')
        .blur(88)
        .position({ x: -78, y: -46 })
        .translate({ y: this.heroGlowOffset })
        .scale({ x: this.heroGlowScale, y: this.heroGlowScale })
        .opacity(this.heroHaloOpacity)
        .animation({
          duration: 3200,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })

      Column()
        .width(160)
        .height(160)
        .borderRadius(80)
        .backgroundColor('rgba(184, 169, 217, 0.10)')
        .blur(66)
        .position({ right: -28, y: 72 })
        .translate({ y: -this.heroGlowOffset * 0.65 })
        .scale({ x: 2.01 - this.heroGlowScale, y: 2.01 - this.heroGlowScale })
        .opacity(1.35 - this.heroHaloOpacity * 0.45)
        .animation({
          duration: 3600,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })

      Column({ space: Spacing.lg }) {
        Row() {
          Column({ space: 6 }) {
            Text('MEETING MEMO STUDIO')
              .fontSize(Typography.size.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.mintDark)
              .letterSpacing(1.6)

            Text('会议纪要工作台')
              .fontSize(Typography.size.hero)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.summaryCountLabel())
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.mintDark)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('rgba(78, 205, 196, 0.10)')
            .borderRadius(BorderRadius.pill)
        }
        .width('100%')

        Text('这里会自动沉淀会议共识、分歧与行动建议，并提供卡片导出、视频回顾和分享入口。')
          .fontSize(Typography.size.bodyLg)
          .fontColor(MintColors.textSecondary)
          .lineHeight(Typography.lineHeight.relaxed)
          .width('100%')

        Row({ space: Spacing.sm }) {
          this.buildHeroChip('会后自动总结')
          this.buildHeroChip(this.latestStatusLabel())
        }
        .width('100%')

        Scroll() {
          Row({ space: Spacing.md }) {
            ForEach(this.workspaceActions, (action: WorkspaceAction, index: number) => {
              this.buildActionCard(action, index)
            }, (action: WorkspaceAction) => action.id)
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(Spacing.card.large)
    }
    .width('100%')
    .backgroundColor(HERO_CARD_BG)
    .borderRadius(BorderRadius.xxl3)
    .border({
      width: 1,
      color: HERO_BORDER,
      radius: BorderRadius.xxl3
    })
    .shadow({
      radius: 28,
      color: 'rgba(15, 23, 42, 0.09)',
      offsetX: 0,
      offsetY: 10
    })
    .clip(true)
    .opacity(this.heroOpacity)
    .translate({ y: this.heroTranslateY })
    .scale({ x: this.heroOpacity * 0.03 + 0.97, y: this.heroOpacity * 0.03 + 0.97 })
  }

  @Builder
  private buildHeroChip(label: string) {
    Row({ space: 6 }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(MintColors.mint)

      Text(label)
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor('rgba(255, 255, 255, 0.65)')
    .borderRadius(BorderRadius.pill)
    .border({
      width: 1,
      color: 'rgba(255, 255, 255, 0.75)',
      radius: BorderRadius.pill
    })
  }

  @Builder
  private buildActionCard(action: WorkspaceAction, index: number) {
    Column({ space: Spacing.md }) {
      Row() {
        Text(action.order)
          .fontSize(Typography.size.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(action.tint)

        Blank()

        Text(this.actionEnabled() ? action.actionLabel : '等待纪要')
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.actionEnabled() ? action.tint : MintColors.textMuted)
      }
      .width('100%')

      Column({ space: 6 }) {
        Text(action.title)
          .fontSize(Typography.size.subtitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Start)

        Text(action.description)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textSecondary)
          .lineHeight(Typography.lineHeight.normal)
          .width('100%')
        }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 6 }) {
        Column()
          .width(18)
          .height(2)
          .borderRadius(1)
          .backgroundColor(action.tint)

        Text(this.actionHint(this.actionEnabled()))
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.textMuted)
      }
      .width('100%')
    }
    .width(192)
    .padding(Spacing.lg)
    .backgroundColor(action.tone)
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: 'rgba(255, 255, 255, 0.65)',
      radius: BorderRadius.xxl2
    })
    .enabled(this.actionEnabled())
    .opacity(index < this.actionCardOpacities.length ? this.actionCardOpacities[index] : 1)
    .translate({ x: index < this.actionCardTranslateX.length ? this.actionCardTranslateX[index] : 0 })
    .scale({ x: this.actionCardScale(action.id), y: this.actionCardScale(action.id) })
    .animation({
      duration: this.actionPressedId === action.id ? 120 : 220,
      curve: this.actionPressedId === action.id ? Curve.Sharp : Curve.FastOutSlowIn
    })
    .onTouch((event: TouchEvent) => {
      if (!this.actionEnabled()) {
        return
      }
      if (event.type === TouchType.Down) {
        this.actionPressedId = action.id
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.actionPressedId = ''
      }
    })
    .onClick(() => {
      this.runWorkspaceAction(action.id)
    })
  }

  @Builder
  private buildLatestSummary(record: RecordItem) {
    Column({ space: Spacing.lg }) {
      Row() {
        Column({ space: 6 }) {
          Text('最新一场会议')
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.mintDark)
            .letterSpacing(1.2)

          Text('这份纪要已经可以直接导出或分享')
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (record.isFavorite) {
          Text('已收藏')
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B45309')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('rgba(245, 158, 11, 0.14)')
            .borderRadius(BorderRadius.pill)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 12 }) {
        Row() {
          Column({ space: 6 }) {
            Text(record.title)
              .fontSize(Typography.size.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Start)

            Text(record.topic)
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textMuted)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(record.timeAgo)
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Medium)
            .fontColor(MintColors.textMuted)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('rgba(241, 245, 249, 0.92)')
            .borderRadius(BorderRadius.pill)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(record.content)
          .fontSize(Typography.size.body)
          .fontColor(MintColors.textSecondary)
          .lineHeight(Typography.lineHeight.relaxed)
          .width('100%')
          .padding(Spacing.md)
          .backgroundColor(RECORD_PREVIEW_BG)
          .borderRadius(BorderRadius.lg)

        Row({ space: Spacing.md }) {
          Row() {
            ForEach(record.participants.slice(0, 3), (_name: string, avatarIndex: number) => {
              this.buildAvatarCell(record, avatarIndex, 32, 16)
            }, (_name: string, avatarIndex: number) => `${record.id}-latest-${avatarIndex}`)
          }
          .alignItems(VerticalAlign.Center)

          Text(record.participantLine)
            .layoutWeight(1)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Flex({ wrap: FlexWrap.Wrap }) {
          this.buildMetricChip(`${record.messageCount} 条消息`)
          this.buildMetricChip(`${record.highlightCount} 个亮点`)
          this.buildMetricChip(record.durationLabel)
        }
        .width('100%')

        Row({ space: Spacing.sm }) {
          Button('生成卡片')
            .layoutWeight(1)
            .height(44)
            .fontSize(Typography.size.body)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(MintColors.mint)
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              this.onGenerateCard(record)
            })

          Button('会议视频')
            .layoutWeight(1)
            .height(44)
            .fontSize(Typography.size.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(MintColors.lavenderDark)
            .backgroundColor('rgba(184, 169, 217, 0.12)')
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              this.onGenerateVideo(record)
            })

          Button('去分享')
            .layoutWeight(1)
            .height(44)
            .fontSize(Typography.size.body)
            .fontWeight(FontWeight.Medium)
            .fontColor('#C2410C')
            .backgroundColor('rgba(249, 115, 22, 0.12)')
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              this.onShareRecord(record)
            })
        }
        .width('100%')

        Row({ space: Spacing.sm }) {
          Button('查看详情')
            .layoutWeight(1)
            .height(42)
            .fontSize(Typography.size.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(MintColors.mintDark)
            .backgroundColor('rgba(78, 205, 196, 0.10)')
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              this.onRecordClick(record)
            })

          Button('全部纪要')
            .layoutWeight(1)
            .height(42)
            .fontSize(Typography.size.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(MintColors.textSecondary)
            .backgroundColor('rgba(255, 255, 255, 0.86)')
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              this.onViewAll()
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(Spacing.card.large)
      .backgroundColor(RECORD_CARD_BG)
      .borderRadius(BorderRadius.xxl3)
      .shadow({
        radius: 24,
        color: 'rgba(15, 23, 42, 0.10)',
        offsetX: 0,
        offsetY: 8
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.latestOpacity)
    .translate({ y: this.latestTranslateY })
    .scale({ x: this.latestScale, y: this.latestScale })
  }

  @Builder
  private buildMetricChip(label: string) {
    Text(label)
      .fontSize(Typography.size.xs)
      .fontWeight(FontWeight.Medium)
      .fontColor(MintColors.textSecondary)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('rgba(241, 245, 249, 0.92)')
      .borderRadius(BorderRadius.pill)
      .margin({ right: Spacing.sm, bottom: Spacing.sm })
  }

  @Builder
  private buildEmptyState() {
    Column({ space: Spacing.lg }) {
      Column({ space: 10 }) {
        Text('还没有会议纪要')
          .fontSize(Typography.size.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Text('完成一场会议后，这里会自动沉淀内容，并开放卡片导出、视频回顾和分享入口。')
          .fontSize(Typography.size.body)
          .fontColor(MintColors.textSecondary)
          .lineHeight(Typography.lineHeight.relaxed)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Column({ space: Spacing.sm }) {
        this.buildEmptyStep('1', '先完成一场会议讨论')
        this.buildEmptyStep('2', '系统自动整理共识与亮点')
        this.buildEmptyStep('3', '导出卡片、视频或直接分享')
      }
      .width('100%')
    }
    .width('100%')
    .padding(Spacing.card.large)
    .backgroundColor(RECORD_CARD_BG)
    .borderRadius(BorderRadius.xxl3)
    .border({
      width: 1,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl3
    })
    .alignItems(HorizontalAlign.Center)
    .opacity(this.latestOpacity)
    .translate({ y: this.latestTranslateY })
  }

  @Builder
  private buildEmptyStep(index: string, label: string) {
    Row({ space: Spacing.md }) {
      Column() {
        Text(index)
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.mintDark)
      }
      .width(26)
      .height(26)
      .borderRadius(13)
      .backgroundColor('rgba(78, 205, 196, 0.10)')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(label)
        .layoutWeight(1)
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor('rgba(248, 250, 252, 0.92)')
    .borderRadius(BorderRadius.xl)
  }

  @Builder
  private buildHistorySection() {
    Column({ space: Spacing.md }) {
      Row({ space: Spacing.sm }) {
        Column({ space: 6 }) {
          Text('纪要历史')
            .fontSize(Typography.size.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text(this.historyRecords().length > 0 ? '更早的会议纪要会继续沉淀在这里。' : '新的纪要生成后会出现在这里。')
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textMuted)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('查看全部')
          .height(34)
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.mintDark)
          .backgroundColor('rgba(78, 205, 196, 0.10)')
          .borderRadius(BorderRadius.pill)
          .onClick(() => {
            this.onViewAll()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.historyRecords().length === 0) {
        Column({ space: 6 }) {
          Text('最新一条纪要已经置顶显示。')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)

          Text('继续发起新的会议后，这里会积累更多可回看的纪要。')
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textMuted)
        }
        .width('100%')
        .padding(Spacing.lg)
        .backgroundColor('rgba(255, 255, 255, 0.72)')
        .borderRadius(BorderRadius.xxl2)
      } else {
        Column({ space: Spacing.md }) {
          ForEach(this.historyRecords(), (record: RecordItem, index: number) => {
            this.buildHistoryCard(record, index)
          }, (record: RecordItem) => record.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.historyOpacity)
    .translate({ y: this.historyTranslateY })
  }

  @Builder
  private buildHistoryCard(record: RecordItem, index: number) {
    Row() {
      Column()
        .width(6)
        .alignSelf(ItemAlign.Stretch)
        .backgroundColor(record.accentColor)

      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text(record.title)
              .fontSize(Typography.size.subtitle)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Start)

            Text(record.topic)
              .fontSize(Typography.size.caption)
              .fontColor(MintColors.textMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(record.timeAgo)
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textMuted)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('rgba(241, 245, 249, 0.92)')
            .borderRadius(BorderRadius.pill)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row({ space: 10 }) {
          Row() {
            ForEach(record.participants.slice(0, 3), (_name: string, avatarIndex: number) => {
              this.buildAvatarCell(record, avatarIndex, 28, 14)
            }, (_name: string, avatarIndex: number) => `${record.id}-history-${avatarIndex}`)
          }
          .alignItems(VerticalAlign.Center)

          Text(record.participantLine)
            .layoutWeight(1)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(record.content)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textSecondary)
          .lineHeight(20)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(RECORD_PREVIEW_BG)
          .borderRadius(BorderRadius.md)

        Row({ space: Spacing.md }) {
          Text(`${record.messageCount} 条消息`)
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textMuted)

          Text(`${record.highlightCount} 个亮点`)
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textMuted)

          Text(record.durationLabel)
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textMuted)

          Blank()

          Text('查看详情')
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.mintDark)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 16, top: 16, bottom: 16 })
    }
    .width('100%')
    .backgroundColor(RECORD_CARD_BG)
    .borderRadius(BorderRadius.xxl2)
    .clip(true)
    .shadow({
      radius: index === 0 ? 20 : 16,
      color: index === 0 ? 'rgba(15, 23, 42, 0.09)' : 'rgba(15, 23, 42, 0.06)',
      offsetX: 0,
      offsetY: 6
    })
    .opacity(this.historyCardOpacity(index))
    .translate({ y: this.historyCardTranslate(index) })
    .scale({
      x: this.historyPressedId === record.id ? 0.985 : 1,
      y: this.historyPressedId === record.id ? 0.985 : 1
    })
    .animation({
      duration: this.historyPressedId === record.id ? 120 : 220,
      curve: this.historyPressedId === record.id ? Curve.Sharp : Curve.FastOutSlowIn
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.historyPressedId = record.id
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.historyPressedId = ''
      }
    })
    .onClick(() => {
      this.onRecordClick(record)
    })
  }

  @Builder
  private buildAvatarCell(record: RecordItem, index: number, size: number, radius: number) {
    Column() {
      Text(record.participants[index].length > 0 ? record.participants[index].charAt(0) : '?')
        .fontSize(size >= 32 ? 12 : 11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getAvatarFg(record, index))
    }
    .width(size)
    .height(size)
    .borderRadius(radius)
    .backgroundColor(record.avatarColors[index] || '#F1F5F9')
    .border({
      width: 2,
      color: RECORD_CARD_BG,
      radius: radius
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .margin({ left: index === 0 ? 0 : -10 })
    .zIndex(record.participants.length - index)
  }
}
