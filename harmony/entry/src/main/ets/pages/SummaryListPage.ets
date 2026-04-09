import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { ArenaRunHistoryItem } from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import { AnimationDuration, AnimationCurve } from '../common/styles/Animation'
import { PersonaApi } from '../service/PersonaApi'
import { formatTimeAgo, getParticipantColor } from '../service/SummaryService'

const FALLBACK_SAFE_TOP_VP: number = 52

// 会议历史卡片数据
interface MeetingCardData {
  runId: string
  title: string
  topic: string
  timeAgo: string
  participantNames: string[]
  participantColors: string[]
  consensusPreview: string
  messageCount: number
  mode: string
}

@Entry
@Component
struct SummaryListPage {
  @State private cards: MeetingCardData[] = []
  @State private isLoading: boolean = true
  @State private errorMessage: string = ''
  @State private safeTopVp: number = 0
  @State private safeBottomVp: number = 0
  @State private bodyOpacity: number = 1
  @State private bodyTranslateY: number = 0

  aboutToAppear(): void {
    this.loadSafeInsets()
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_error) {
    }
    this.loadHistory()
  }

  private loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_error) {
    }
  }

  private topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  private playBodyEntrance(): void {
    this.bodyOpacity = 0
    this.bodyTranslateY = 16
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.friction
      }, () => {
        this.bodyOpacity = 1
        this.bodyTranslateY = 0
      })
    }, 20)
  }

  private async loadHistory(): Promise<void> {
    this.isLoading = true
    this.bodyOpacity = 1
    this.bodyTranslateY = 0
    this.errorMessage = ''
    try {
      const response = await PersonaApi.getArenaHistory(100)
      this.cards = response.runs.map((item: ArenaRunHistoryItem) => this.mapToCard(item))
    } catch (error) {
      console.error('[SummaryListPage] loadHistory failed:', error)
      this.errorMessage = '加载失败，请检查网络连接'
    } finally {
      this.isLoading = false
      this.playBodyEntrance()
    }
  }

  private mapToCard(item: ArenaRunHistoryItem): MeetingCardData {
    const title = item.title && item.title.length > 0
      ? item.title
      : (item.summaryTitle && item.summaryTitle.length > 0 ? item.summaryTitle : '会议纪要')
    const consensusPreview = item.consensus && item.consensus.length > 0
      ? item.consensus
      : (item.consensusPreview && item.consensusPreview.length > 0 ? item.consensusPreview : '')
    const participantColors = item.participantNames.map((_name: string, index: number) =>
      getParticipantColor(index)
    )

    return {
      runId: item.runId,
      title: title,
      topic: item.topic,
      timeAgo: item.createdAt ? formatTimeAgo(item.createdAt) : '刚刚',
      participantNames: item.participantNames,
      participantColors: participantColors,
      consensusPreview: consensusPreview,
      messageCount: item.messageCount ?? 0,
      mode: item.mode
    }
  }

  private navigateToDetail(card: MeetingCardData): void {
    router.pushUrl({
      url: 'pages/SummaryDetailPage',
      params: {
        arenaRunId: card.runId
      }
    })
  }

  @Builder
  private buildParticipantTags(participantNames: string[], colors: string[]) {
    Row({ space: 6 }) {
      ForEach(participantNames.slice(0, 4), (name: string, index: number) => {
        Text(name)
          .fontSize(Typography.size.xs)
          .fontColor('#FFFFFF')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(colors[index] ?? MintColors.mint)
          .borderRadius(BorderRadius.pill)
      }, (name: string, index: number) => name + index)
    }
  }

  @Builder
  private buildMeetingCard(card: MeetingCardData) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Column({ space: 4 }) {
          Text(card.title)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(card.topic.length > 0 ? card.topic : '无议题')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(card.timeAgo)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textMuted)
      }
      .width('100%')

      if (card.participantNames.length > 0) {
        this.buildParticipantTags(card.participantNames, card.participantColors)
      }

      Text(card.consensusPreview.length > 0 ? card.consensusPreview : '点击查看完整会议纪要')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
        .lineHeight(22)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: Spacing.md }) {
        Text(`${card.messageCount} 条消息`)
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.textMuted)

        Text(card.mode === 'debate' ? '辩论模式' : '对话模式')
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.lavender)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor(MintColors.surface)
    .borderRadius(BorderRadius.xxl)
    .border({ width: 1, color: MintColors.border, radius: BorderRadius.xxl })
    .onClick(() => this.navigateToDetail(card))
  }

  @Builder
  private buildLoadingState() {
    Column({ space: Spacing.md }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(MintColors.mint)

      Text('加载会议历史...')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildErrorState() {
    Column({ space: Spacing.lg }) {
      Text('⚠️')
        .fontSize(48)

      Text(this.errorMessage)
        .fontSize(Typography.size.body)
        .fontColor(MintColors.error)
        .textAlign(TextAlign.Center)

      Button('重新加载')
        .fontSize(Typography.size.body)
        .fontColor('#FFFFFF')
        .backgroundColor(MintColors.mint)
        .borderRadius(BorderRadius.button)
        .padding({ left: Spacing.xl, right: Spacing.xl, top: Spacing.sm, bottom: Spacing.sm })
        .stateEffect(true)
        .onClick(() => this.loadHistory())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: Spacing.page.horizontal, right: Spacing.page.horizontal })
  }

  @Builder
  private buildEmptyState() {
    Column({ space: Spacing.lg }) {
      Text('📋')
        .fontSize(48)

      Text('暂无会议记录')
        .fontSize(Typography.size.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)

      Text('开始一场对话，开启您的会议纪要之旅')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: Spacing.page.horizontal, right: Spacing.page.horizontal })
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 6 }) {
        Text('会议纪要')
          .fontSize(Typography.size.hero)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Text('历史会议一览')
          .fontSize(Typography.size.body)
          .fontColor(MintColors.textSecondary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: Spacing.page.horizontal,
        right: Spacing.page.horizontal,
        top: this.topInsetVp() + Spacing.md,
        bottom: Spacing.sm
      })

      Column() {
        if (this.isLoading) {
          this.buildLoadingState()
        } else if (this.errorMessage.length > 0) {
          this.buildErrorState()
        } else if (this.cards.length === 0) {
          this.buildEmptyState()
        } else {
          Scroll() {
            Column({ space: Spacing.md }) {
              ForEach(this.cards, (card: MeetingCardData) => {
                this.buildMeetingCard(card)
              }, (card: MeetingCardData) => card.runId)
            }
            .width('100%')
            .padding({
              left: Spacing.page.horizontal,
              right: Spacing.page.horizontal,
              top: Spacing.xs,
              bottom: this.safeBottomVp + Spacing.xl
            })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .opacity(this.bodyOpacity)
      .translate({ y: this.bodyTranslateY })
      .animation({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.friction
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }
}
