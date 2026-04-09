import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import pasteboard from '@ohos.pasteboard'
import promptAction from '@ohos.promptAction'
import { ArenaRun, ExportFormatType, SummaryParticipant, SummaryRecord } from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import { AnimationCurve, AnimationDuration, getStaggerDelay } from '../common/styles/Animation'
import { PersonaApi } from '../service/PersonaApi'
import { SummaryService, convertArenaRunToSummaryRecord } from '../service/SummaryService'

export interface SummaryDetailRouteParams {
  summaryId?: string
  arenaRunId?: string
  openSheet?: 'export' | 'share'
  exportFormat?: ExportFormatType
}

const FALLBACK_SAFE_TOP_VP: number = 52

function formatSummaryDate(iso: string): string {
  if (iso.length < 8) {
    return iso
  }
  try {
    const d = new Date(iso)
    if (Number.isNaN(d.getTime())) {
      return iso
    }
    const y = d.getFullYear()
    const m = d.getMonth() + 1
    const day = d.getDate()
    const hh = d.getHours().toString().padStart(2, '0')
    const min = d.getMinutes().toString().padStart(2, '0')
    return `${y}年${m}月${day}日 ${hh}:${min}`
  } catch (_e) {
    return iso
  }
}

@Entry
@Component
struct SummaryDetailPage {
  @State private summaryRecord: SummaryRecord | null = null
  @State private isLoading: boolean = true
  @State private error: string = ''
  @State private safeTopVp: number = 0
  @State private safeBottomVp: number = 0
  @State private heroOpacity: number = 0
  @State private heroTranslateY: number = 22
  @State private toolbarOpacity: number = 0
  @State private toolbarTranslateY: number = 14
  @State private bodyOpacity: number = 0
  @State private bodyTranslateY: number = 18
  @State private loadingPulse: number = 0.65

  private summaryId: string = ''
  private arenaRunId: string = ''
  private pendingSheet: 'none' | 'export' | 'share' = 'none'
  private entryExportFormat: ExportFormatType = 'image'

  aboutToAppear(): void {
    this.loadSafeInsets()
    this.startLoadingPulse()

    const params = router.getParams() as SummaryDetailRouteParams
    if (!params || (!params.summaryId && !params.arenaRunId)) {
      this.error = '缺少纪要标识'
      this.isLoading = false
      return
    }

    this.summaryId = params.summaryId ? params.summaryId : ''
    this.arenaRunId = params.arenaRunId ? params.arenaRunId : ''
    this.pendingSheet = params.openSheet ? params.openSheet : 'none'
    this.entryExportFormat = params.exportFormat ? params.exportFormat : 'image'

    try {
      const ctx = getContext(this) as common.UIAbilityContext
      void SummaryService.init(ctx).then(() => {
        void this.loadSummaryDetail()
      })
    } catch (_error) {
      void this.loadSummaryDetail()
    }
  }

  private startLoadingPulse(): void {
    animateTo({
      duration: 900,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.loadingPulse = 1
    })
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

  private buildRecordFromArenaRun(run: ArenaRun): SummaryRecord {
    const record = convertArenaRunToSummaryRecord(run, undefined)
    record.id = run.runId
    record.arenaRunId = run.runId
    if (run.createdAt && run.createdAt.length > 0) {
      record.createdAt = run.createdAt
      record.updatedAt = run.createdAt
    }
    return record
  }

  private scheduleContentEntrance(): void {
    this.heroOpacity = 0
    this.heroTranslateY = 22
    this.toolbarOpacity = 0
    this.toolbarTranslateY = 14
    this.bodyOpacity = 0
    this.bodyTranslateY = 18

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.smooth
      }, () => {
        this.heroOpacity = 1
        this.heroTranslateY = 0
      })
    }, getStaggerDelay(0, 40))

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.smooth
      }, () => {
        this.toolbarOpacity = 1
        this.toolbarTranslateY = 0
      })
    }, 140)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.smooth
      }, () => {
        this.bodyOpacity = 1
        this.bodyTranslateY = 0
      })
    }, 260)
  }

  private async loadSummaryDetail(): Promise<void> {
    this.isLoading = true
    this.error = ''
    try {
      if (this.arenaRunId.length > 0) {
        const response = await PersonaApi.getArenaRunDetail(this.arenaRunId)
        this.summaryRecord = this.buildRecordFromArenaRun(response.result)
      } else {
        this.summaryRecord = await SummaryService.getSummaryDetail(this.summaryId)
      }

      if (!this.summaryRecord) {
        this.error = '未找到纪要内容'
        return
      }

      await this.runPendingActionIfNeeded()
      setTimeout(() => this.scheduleContentEntrance(), 30)
    } catch (error) {
      console.error('[SummaryDetailPage] loadSummaryDetail failed:', error)
      this.error = '加载失败，请检查网络后重试'
    } finally {
      this.isLoading = false
    }
  }

  private async runPendingActionIfNeeded(): Promise<void> {
    if (this.pendingSheet === 'share') {
      await this.handleCopyContent()
    } else if (this.pendingSheet === 'export') {
      if (this.entryExportFormat === 'video') {
        await this.handleExportVideo()
      } else if (this.entryExportFormat === 'text') {
        await this.handleExportText()
      } else {
        await this.openPosterPreviewFromPending()
      }
    }
    this.pendingSheet = 'none'
  }

  private async openPosterPreviewFromPending(): Promise<void> {
    const id = this.posterRunId()
    if (id.length === 0) {
      await this.copyTextToClipboard(this.shareText(), '已复制纪要文本')
      return
    }
    router.pushUrl({
      url: 'pages/PosterPreviewPage',
      params: {
        arenaRunId: id,
        title: this.summaryRecord ? this.summaryRecord.title : ''
      }
    })
  }

  private shareText(): string {
    if (!this.summaryRecord) {
      return ''
    }
    return SummaryService.generateShareText(this.summaryRecord)
  }

  private posterRunId(): string {
    if (this.arenaRunId.length > 0) {
      return this.arenaRunId
    }
    if (this.summaryRecord && this.summaryRecord.arenaRunId && this.summaryRecord.arenaRunId.length > 0) {
      return this.summaryRecord.arenaRunId
    }
    return ''
  }

  private showToast(message: string): void {
    try {
      void promptAction.openToast({ message: message })
    } catch (error) {
      console.error('[SummaryDetailPage] openToast failed:', error)
    }
  }

  private async copyTextToClipboard(text: string, successMessage: string): Promise<boolean> {
    if (text.trim().length === 0) {
      this.showToast('暂无可复制内容')
      return false
    }

    try {
      const board = pasteboard.getSystemPasteboard()
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      await board.setData(data)
      this.showToast(successMessage)
      return true
    } catch (error) {
      console.error('[SummaryDetailPage] copyTextToClipboard failed:', error)
      this.showToast('复制失败')
      return false
    }
  }

  private openPosterPreview(): void {
    const id = this.posterRunId()
    if (id.length === 0) {
      this.showToast('当前纪要未关联会议 run，无法生成海报')
      return
    }
    router.pushUrl({
      url: 'pages/PosterPreviewPage',
      params: {
        arenaRunId: id,
        title: this.summaryRecord ? this.summaryRecord.title : ''
      }
    })
  }

  private async handleExportVideo(): Promise<void> {
    await this.copyTextToClipboard(this.shareText(), '已复制回放文案到剪贴板')
  }

  private async handleExportText(): Promise<void> {
    await this.copyTextToClipboard(this.shareText(), '已复制全文')
  }

  private async handleCopyContent(): Promise<void> {
    await this.copyTextToClipboard(this.shareText(), '已复制纪要全文')
  }

  private async toggleFavorite(): Promise<void> {
    if (!this.summaryRecord || this.arenaRunId.length > 0) {
      this.showToast('云端会议纪要不支持收藏，可导出文本到本地')
      return
    }
    const next = !this.summaryRecord.isFavorite
    this.summaryRecord.isFavorite = next
    const success = await SummaryService.toggleFavorite(this.summaryId, next)
    if (!success) {
      this.summaryRecord.isFavorite = !next
      this.showToast('收藏更新失败')
    } else {
      this.showToast(next ? '已加入收藏' : '已取消收藏')
    }
  }

  private async deleteSummary(): Promise<void> {
    if (this.arenaRunId.length > 0) {
      this.showToast('云端记录请在后端管理，此处无法删除')
      return
    }
    const success = await SummaryService.deleteSummary(this.summaryId)
    if (success) {
      this.showToast('已删除')
      router.back()
      return
    }
    this.showToast('删除失败')
  }

  private goBack(): void {
    try {
      router.back()
    } catch (_e) {
    }
  }

  private isLocalOnly(): boolean {
    return this.summaryId.length > 0 && this.arenaRunId.length === 0
  }

  @Builder
  buildNavBar() {
    Row({ space: Spacing.md }) {
      Button() {
        Text('‹').fontSize(26).fontColor(MintColors.mintDark).fontWeight(FontWeight.Medium)
      }
      .width(44)
      .height(44)
      .backgroundColor('rgba(255, 255, 255, 0.92)')
      .borderRadius(22)
      .border({ width: 0.5, color: MintColors.border, radius: 22 })
      .onClick(() => this.goBack())

      Column({ space: 2 }) {
        Text('纪要详情').fontSize(Typography.size.bodyLg).fontWeight(FontWeight.Medium).fontColor(MintColors.textPrimary)
        Text('共识 · 分歧 · 行动建议').fontSize(Typography.size.xs).fontColor(MintColors.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('复制全文')
        .height(36)
        .fontSize(Typography.size.xs)
        .fontWeight(FontWeight.Medium)
        .fontColor(MintColors.mintDark)
        .backgroundColor('rgba(78, 205, 196, 0.12)')
        .borderRadius(BorderRadius.pill)
        .onClick(() => {
          void this.handleCopyContent()
        })
    }
    .width('100%')
    .padding({
      left: Spacing.page.horizontal,
      right: Spacing.page.horizontal,
      top: this.topInsetVp() + 8,
      bottom: Spacing.sm
    })
  }

  @Builder
  buildHeroCard(record: SummaryRecord) {
    Column({ space: Spacing.md }) {
      Text(record.title)
        .fontSize(Typography.size.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)
        .width('100%')
        .lineHeight(32)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: Spacing.sm }) {
        Text(formatSummaryDate(record.createdAt))
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textSecondary)
        if (record.messageCount > 0) {
          Text('·')
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textMuted)
          Text(`${record.messageCount} 条对话`)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textMuted)
        }
      }
      .width('100%')

      if (record.participants.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          ForEach(record.participants, (participant: SummaryParticipant, index: number) => {
            Text(`${participant.displayName} · ${participant.stageLabel}`)
              .fontSize(Typography.size.xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(index % 2 === 0 ? '#0F766E' : '#5B21B6')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(index % 2 === 0 ? 'rgba(78, 205, 196, 0.14)' : 'rgba(184, 169, 217, 0.18)')
              .borderRadius(BorderRadius.pill)
              .margin({ right: 8, bottom: 8 })
          }, (p: SummaryParticipant, index: number) => p.agentId + '-' + index)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.card.large)
    .backgroundColor('rgba(255, 255, 255, 0.92)')
    .borderRadius(BorderRadius.xxl3)
    .border({ width: 1, color: 'rgba(255, 255, 255, 0.9)', radius: BorderRadius.xxl3 })
    .shadow({
      radius: 28,
      color: 'rgba(15, 23, 42, 0.08)',
      offsetX: 0,
      offsetY: 10
    })
    .opacity(this.heroOpacity)
    .translate({ y: this.heroTranslateY })
  }

  @Builder
  buildActionToolbar() {
    Column({ space: Spacing.sm }) {
      Button('生成海报 · 全屏预览抓一抓')
        .width('100%')
        .height(48)
        .fontSize(Typography.size.body)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(MintColors.mint)
        .borderRadius(BorderRadius.xxl)
        .onClick(() => this.openPosterPreview())

      Scroll() {
        Row({ space: Spacing.sm }) {
          this.buildChipAction('复制文本', () => {
            void this.handleExportText()
          })
          this.buildChipAction('视频脚本', () => {
            void this.handleExportVideo()
          })
          if (this.isLocalOnly()) {
            this.buildChipAction(this.summaryRecord && this.summaryRecord.isFavorite ? '已收藏' : '收藏', () => {
              void this.toggleFavorite()
            })
            this.buildChipAction('删除', () => {
              void this.deleteSummary()
            }, true)
          }
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .opacity(this.toolbarOpacity)
    .translate({ y: this.toolbarTranslateY })
  }

  @Builder
  buildChipAction(label: string, onTap: () => void, danger?: boolean) {
    Button(label)
      .height(38)
      .padding({ left: Spacing.md, right: Spacing.md })
      .fontSize(Typography.size.caption)
      .fontWeight(FontWeight.Medium)
      .fontColor(danger ? MintColors.error : MintColors.mintDark)
      .backgroundColor(danger ? 'rgba(224, 120, 128, 0.10)' : 'rgba(78, 205, 196, 0.10)')
      .borderRadius(BorderRadius.pill)
      .border({
        width: 0.5,
        color: danger ? 'rgba(224, 120, 128, 0.35)' : MintColors.borderLight,
        radius: BorderRadius.pill
      })
      .onClick(onTap)
  }

  @Builder
  buildDetailCard(titleCn: string, body: string) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Column()
          .width(4)
          .height(18)
          .borderRadius(2)
          .backgroundColor(MintColors.mint)
        Text(titleCn)
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.mintDark)
          .letterSpacing(0.5)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(body.length > 0 ? body : '暂无')
        .fontSize(Typography.size.body)
        .fontColor(body.length > 0 ? MintColors.textPrimary : MintColors.textMuted)
        .lineHeight(Typography.lineHeight.relaxed)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(BorderRadius.xxl2)
    .border({ width: 1, color: MintColors.borderLight, radius: BorderRadius.xxl2 })
    .shadow({
      radius: 16,
      color: 'rgba(15, 23, 42, 0.05)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  buildBulletCard(titleCn: string, items: string[]) {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Column()
          .width(4)
          .height(18)
          .borderRadius(2)
          .backgroundColor(MintColors.lavender)
        Text(titleCn)
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.lavenderDark)
          .letterSpacing(0.5)
      }
      .width('100%')

      if (items.length === 0) {
        Text('暂无')
          .fontSize(Typography.size.body)
          .fontColor(MintColors.textMuted)
          .width('100%')
      } else {
        Column({ space: Spacing.sm }) {
          ForEach(items, (line: string, idx: number) => {
            Row({ space: Spacing.sm }) {
              Text('•')
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textMuted)
              Text(line)
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textPrimary)
                .lineHeight(Typography.lineHeight.relaxed)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (line: string, idx: number) => `${titleCn}-${idx}-${line.length}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(BorderRadius.xxl2)
    .border({ width: 1, color: MintColors.borderLight, radius: BorderRadius.xxl2 })
    .shadow({
      radius: 16,
      color: 'rgba(15, 23, 42, 0.05)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  buildBody(record: SummaryRecord) {
    Column({ space: Spacing.md }) {
      this.buildDetailCard('议题', record.topic)
      this.buildDetailCard('共识', record.consensus)
      this.buildBulletCard('分歧', record.disagreements)
      this.buildBulletCard('行动建议', record.actionableAdvice)
      if (record.narrativeHook.length > 0) {
        this.buildDetailCard('一句总结', record.narrativeHook)
      }
      if (record.moderatorNote && record.moderatorNote.length > 0) {
        this.buildDetailCard('主持人备注', record.moderatorNote)
      }
    }
    .width('100%')
    .opacity(this.bodyOpacity)
    .translate({ y: this.bodyTranslateY })
  }

  @Builder
  buildLoadingState() {
    Column({ space: Spacing.lg }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(MintColors.mint)
        .opacity(this.loadingPulse)
      Text('正在加载纪要…')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column().width('100%').height('100%').backgroundColor(MintColors.background)
        Column()
          .width(260)
          .height(260)
          .borderRadius(130)
          .backgroundColor('rgba(78, 205, 196, 0.09)')
          .blur(90)
          .position({ x: -100, y: -40 })
        Column()
          .width(220)
          .height(220)
          .borderRadius(110)
          .backgroundColor('rgba(184, 169, 217, 0.08)')
          .blur(70)
          .position({ right: -80, y: 120 })
      }
      .width('100%')
      .height('100%')

      Column() {
        this.buildNavBar()

        if (this.isLoading) {
          this.buildLoadingState()
        } else if (this.error.length > 0) {
          Column({ space: Spacing.lg }) {
            Text(this.error)
              .fontSize(Typography.size.body)
              .fontColor(MintColors.error)
              .textAlign(TextAlign.Center)
              .width('100%')
            Button('重试')
              .height(44)
              .padding({ left: Spacing.xl, right: Spacing.xl })
              .fontColor('#FFFFFF')
              .backgroundColor(MintColors.mint)
              .borderRadius(BorderRadius.xxl)
              .onClick(() => {
                void this.loadSummaryDetail()
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: Spacing.page.horizontal, right: Spacing.page.horizontal })
        } else if (this.summaryRecord) {
          Scroll() {
            Column({ space: Spacing.lg }) {
              this.buildHeroCard(this.summaryRecord)
              this.buildActionToolbar()
              this.buildBody(this.summaryRecord)
            }
            .width('100%')
            .padding({
              left: Spacing.page.horizontal,
              right: Spacing.page.horizontal,
              top: Spacing.sm,
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
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }
}
