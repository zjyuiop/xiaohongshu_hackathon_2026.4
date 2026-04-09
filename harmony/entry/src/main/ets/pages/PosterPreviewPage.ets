import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { unifiedDataChannel } from '@kit.ArkData'
import { harmonyShare, systemShare } from '@kit.ShareKit'
import { window } from '@kit.ArkUI'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import pasteboard from '@ohos.pasteboard'
import promptAction from '@ohos.promptAction'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'

/**
 * 华为 Share Kit 隔空传送接入说明（官方文档路径：开发者联盟 → 最佳实践 → bpta-application-gesture-share）
 *
 * 核心能力：
 *  - harmonyShare.on('gesturesShare', ...) 注册监听「握拳抓取」手势
 *  - 用户在海报上握拳时，系统自动回调应用 → 应用调用 sharableTarget.share(shareData)
 *  - 传输的是「数据」而非「截屏」，是真正的应用内原生跨设备分享
 *
 * 注意事项：
 *  - 从触发手势到调用 share 需在 3 秒内完成，否则分享失败
 *  - 每次分享仅支持「链接」或「文件」中的一种，不支持混合
 *  - 图片需为本地文件 URI（file://），网络图片需先下载到沙箱
 *
 * Share Kit 模块路径：@kit.ShareKit
 * harmonyShare：设备间分享（隔空传送）
 * systemShare：应用间分享（系统分享面板）
 */

const FALLBACK_SAFE_TOP_VP: number = 52
/** 全屏海报最大捏合缩放倍数 */
const POSTER_ZOOM_MAX: number = 5
/** 分享数据总量上限（华为 Share Kit 限制） */
const SHARE_DATA_LIMIT: number = 200 * 1024

export interface PosterPreviewRouteParams {
  arenaRunId: string
  title?: string
}

@Entry
@Component
struct PosterPreviewPage {
  @State private posterUrl: string = ''
  @State private posterPrompt: string = ''
  @State private isLoading: boolean = true
  @State private error: string = ''
  @State private safeTopVp: number = 0
  @State private safeBottomVp: number = 0
  /** 点击卡片后进入全屏，便于单独截海报、配合系统抓一抓 */
  @State private showFullscreenPoster: boolean = false
  @State private posterZoomScale: number = 1
  private pinchBaseScale: number = 1
  @State private panOffsetX: number = 0
  @State private panOffsetY: number = 0
  private panStartX: number = 0
  private panStartY: number = 0

  private arenaRunId: string = ''
  private posterTitle: string = '会议海报'
  /** 隔空传送监听回调（用于取消监听） */
  private gestureShareCallback: ((target: harmonyShare.SharableTarget) => void) | undefined = undefined
  /** 当前窗口 ID（Share Kit 需要） */
  private windowId: number = 0
  /** 本地海报文件路径（隔空传送需要本地文件 URI） */
  private localPosterPath: string = ''
  /** 分享模式：true=文件模式，false=链接模式 */
  private shareAsFile: boolean = false

  aboutToAppear(): void {
    this.loadSafeInsets()
    const params = router.getParams() as PosterPreviewRouteParams
    if (params && params.arenaRunId) {
      this.arenaRunId = params.arenaRunId
      this.posterTitle = params.title && params.title.length > 0 ? params.title : '会议海报'
      void this.generatePoster()
    } else {
      this.error = '缺少会议 ID 参数'
      this.isLoading = false
    }
    // 注册隔空传送监听（Share Kit · 握拳抓取手势）
    this.registerGestureShare()
  }

  aboutToDisappear(): void {
    // 取消隔空传送监听，释放资源
    this.unregisterGestureShare()
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

  private async generatePoster(): Promise<void> {
    this.isLoading = true
    this.error = ''
    try {
      const response = await PersonaApi.generateArenaPoster({
        runId: this.arenaRunId,
        stylePreset: 'editorial',
        aspectRatio: '3:4',
        language: 'zh-CN'
      })
      const url = response.poster.imageUrl
        ? response.poster.imageUrl
        : (response.poster.sourceUrl ? response.poster.sourceUrl : '')
      if (url.length === 0) {
        this.error = '后端未返回海报图片地址'
        this.isLoading = false
        return
      }
      this.posterUrl = url
      this.posterPrompt = response.poster.promptUrl ? response.poster.promptUrl : ''
      this.isLoading = false
      // 海报加载成功后，尝试下载到本地（隔空传送需要本地文件）
      void this.downloadPosterForShare(url)
    } catch (err) {
      console.error('[PosterPreviewPage] generatePoster failed:', err)
      this.error = '海报生成失败，请检查网络后重试'
      this.isLoading = false
    }
  }

  /**
   * 将网络海报下载到应用沙箱，作为隔空传送的本地文件源
   */
  private async downloadPosterForShare(imageUrl: string): Promise<void> {
    if (!imageUrl || imageUrl.length === 0) {
      return
    }
    try {
      // 优先使用 HTTP 下载二进制，再写入沙箱
      const httpClient = await http.createHttp()
      const result = await httpClient.request(imageUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      })
      httpClient.destroy()
      if (result.responseCode === 200 && result.result instanceof ArrayBuffer) {
        const ctx = getContext(this) as common.UIAbilityContext
        const cacheDir = ctx.cacheDir
        const fileName = `poster_${Date.now()}.jpg`
        const filePath = `${cacheDir}/${fileName}`
        const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
        fileIo.writeSync(file.fd, new Uint8Array(result.result))
        fileIo.closeSync(file.fd)
        this.localPosterPath = `file://${filePath}`
        this.shareAsFile = true
        console.info(`[PosterPreviewPage] 海报已缓存到本地: ${this.localPosterPath}`)
      } else {
        // 下载失败，降级为链接分享
        this.shareAsFile = false
      }
    } catch (err) {
      console.error('[PosterPreviewPage] downloadPosterForShare failed:', err)
      this.shareAsFile = false
    }
  }

  /**
   * 注册隔空传送监听（Share Kit · 握拳抓取手势）
   * 用户在应用内任何位置握拳时，系统会回调此方法
   */
  private registerGestureShare(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      window.getLastWindow(ctx).then((win) => {
        this.windowId = win.getWindowProperties().id
        this.gestureShareCallback = (target: harmonyShare.SharableTarget) => {
          this.onGestureShare(target)
        }
        harmonyShare.on('gesturesShare', { windowId: this.windowId }, this.gestureShareCallback)
        console.info('[PosterPreviewPage] 隔空传送监听已注册')
      }).catch((err: BusinessError) => {
        console.error('[PosterPreviewPage] getLastWindow failed:', err)
      })
    } catch (err) {
      console.error('[PosterPreviewPage] registerGestureShare failed:', err)
    }
  }

  /**
   * 取消隔空传送监听，释放资源
   */
  private unregisterGestureShare(): void {
    if (this.gestureShareCallback !== undefined && this.windowId > 0) {
      try {
        harmonyShare.off('gesturesShare', { windowId: this.windowId })
        this.gestureShareCallback = undefined
        console.info('[PosterPreviewPage] 隔空传送监听已取消')
      } catch (err) {
        console.error('[PosterPreviewPage] unregisterGestureShare failed:', err)
      }
    }
  }

  /**
   * 隔空传送回调（用户握拳抓取时触发）
   * 在 3 秒内调用 target.share() 完成数据提供
   */
  private onGestureShare(target: harmonyShare.SharableTarget): void {
    console.info('[PosterPreviewPage] 收到隔空传送请求')
    // 如果本地文件已准备好，优先以文件模式分享
    if (this.shareAsFile && this.localPosterPath.length > 0) {
      this.sharePosterAsFile(target)
      return
    }
    // 如果有网络 URL，降级为链接分享
    if (this.posterUrl.length > 0) {
      this.sharePosterAsLink(target)
      return
    }
    // 海报还未生成，尝试重新生成
    if (this.arenaRunId.length > 0 && !this.isLoading) {
      console.info('[PosterPreviewPage] 海报未就绪，尝试重新生成后分享')
      void this.generatePosterAndShare(target)
      return
    }
    // 无法分享，提示用户
    console.warn('[PosterPreviewPage] 无可用海报数据，跳过分享')
    promptAction.showToast({ message: '请先等待海报生成完成' })
  }

  /**
   * 重新生成海报并分享（握拳时海报未就绪的降级处理）
   */
  private async generatePosterAndShare(target: harmonyShare.SharableTarget): Promise<void> {
    try {
      const response = await PersonaApi.generateArenaPoster({
        runId: this.arenaRunId,
        stylePreset: 'editorial',
        aspectRatio: '3:4',
        language: 'zh-CN'
      })
      const url = response.poster.imageUrl
        ? response.poster.imageUrl
        : (response.poster.sourceUrl ? response.poster.sourceUrl : '')
      if (url.length > 0) {
        this.posterUrl = url
        // 尝试下载后分享
        await this.downloadPosterForShare(url)
        if (this.shareAsFile && this.localPosterPath.length > 0) {
          this.sharePosterAsFile(target)
        } else {
          this.sharePosterAsLink(target)
        }
      } else {
        promptAction.showToast({ message: '海报生成失败，无法分享' })
      }
    } catch (err) {
      console.error('[PosterPreviewPage] generatePosterAndShare failed:', err)
      promptAction.showToast({ message: '海报生成失败，无法分享' })
    }
  }

  /**
   * 以本地文件方式分享海报（隔空传送 · 文件模式）
   */
  private sharePosterAsFile(target: harmonyShare.SharableTarget): void {
    try {
      // 通过 uniformTypeDescriptor 获取图片的 UTD 类型
      const imageUtd = uniformTypeDescriptor.UniformDataType.IMAGE
      const shareData = new systemShare.SharedData({
        utd: imageUtd,
        uri: this.localPosterPath,
        title: this.posterTitle,
        description: '会议海报'
      })
      target.share(shareData)
      console.info('[PosterPreviewPage] 文件分享成功')
    } catch (err) {
      console.error('[PosterPreviewPage] sharePosterAsFile failed:', err)
    }
  }

  /**
   * 以链接方式分享海报（隔空传送 · 链接模式，降级方案）
   */
  private sharePosterAsLink(target: harmonyShare.SharableTarget): void {
    try {
      const linkUtd = uniformTypeDescriptor.UniformDataType.HYPERLINK
      const shareData = new systemShare.SharedData({
        utd: linkUtd,
        content: this.posterUrl,
        title: this.posterTitle,
        description: '查看会议海报'
      })
      target.share(shareData)
      console.info('[PosterPreviewPage] 链接分享成功')
    } catch (err) {
      console.error('[PosterPreviewPage] sharePosterAsLink failed:', err)
    }
  }

  private async copyPosterUrl(): Promise<void> {
    if (this.posterUrl.length === 0) {
      return
    }
    try {
      const board = pasteboard.getSystemPasteboard()
      const clipData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.posterUrl)
      await board.setData(clipData)
      void promptAction.openToast({ message: '图片链接已复制到剪贴板' })
    } catch (_err) {
    }
  }

  private goBack(): void {
    try {
      router.back()
    } catch (_err) {
    }
  }

  private openFullscreenPoster(): void {
    if (this.posterUrl.length === 0) {
      return
    }
    this.showFullscreenPoster = true
    this.resetPosterViewTransform()
  }

  private closeFullscreenPoster(): void {
    this.showFullscreenPoster = false
    this.resetPosterViewTransform()
  }

  private resetPosterViewTransform(): void {
    this.posterZoomScale = 1
    this.pinchBaseScale = 1
    this.panOffsetX = 0
    this.panOffsetY = 0
  }

  private clampZoom(value: number): number {
    if (value < 1) {
      return 1
    }
    if (value > POSTER_ZOOM_MAX) {
      return POSTER_ZOOM_MAX
    }
    return value
  }

  /**
   * 拖拽起拖时写入 UDMF，供同生态内跨应用 / 跨设备接收（官方拖拽通路）。
   * 网络图片优先尝试 Image 记录；失败则降级为 PlainText（海报 URL）。
   */
  private applyPosterDragData(event: DragEvent): void {
    if (this.posterUrl.length === 0) {
      return
    }
    try {
      const asImage = new unifiedDataChannel.Image()
      asImage.imageUri = this.posterUrl
      const asImageUnified = new unifiedDataChannel.UnifiedData(asImage)
      event.setData(asImageUnified)
    } catch (_e) {
      try {
        const plain = new unifiedDataChannel.PlainText()
        plain.textContent = this.posterUrl
        event.setData(new unifiedDataChannel.UnifiedData(plain))
      } catch (err) {
        console.error('[PosterPreviewPage] UDMF drag data failed:', err)
      }
    }
  }

  private onPosterDragStart(event: DragEvent): DragItemInfo {
    this.applyPosterDragData(event)
    return {
      extraInfo: 'time-persona-poster'
    }
  }

  @Builder
  buildFullscreenPosterLayer() {
    Column({ space: 0 }) {
      Row({ space: Spacing.md }) {
        Button('关闭')
          .height(40)
          .fontSize(Typography.size.body)
          .fontColor('#FFFFFF')
          .backgroundColor('rgba(255, 255, 255, 0.18)')
          .borderRadius(BorderRadius.xxl)
          .onClick(() => this.closeFullscreenPoster())

        Column({ space: 4 }) {
          Text('全屏海报')
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
          Text('双指缩放；长按约 0.5 秒后滑动可拖出至其他设备（UDMF）')
            .fontSize(Typography.size.xs)
            .fontColor('rgba(255, 255, 255, 0.72)')
            .lineHeight(18)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        left: Spacing.page.horizontal,
        right: Spacing.page.horizontal,
        top: this.topInsetVp() + 8,
        bottom: Spacing.md
      })

      Stack({ alignContent: Alignment.Center }) {
        Image(this.posterUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(true)
          .onDragStart((event: DragEvent) => this.onPosterDragStart(event))
          .translate({ x: this.panOffsetX, y: this.panOffsetY })
          .scale({ x: this.posterZoomScale, y: this.posterZoomScale })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.pinchBaseScale = this.posterZoomScale
                })
                .onActionUpdate((event: GestureEvent) => {
                  const next = this.pinchBaseScale * event.scale
                  this.posterZoomScale = this.clampZoom(next)
                })
                .onActionEnd(() => {
                  this.pinchBaseScale = this.posterZoomScale
                  if (this.posterZoomScale <= 1.02) {
                    this.panOffsetX = 0
                    this.panOffsetY = 0
                  }
                }),
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.panStartX = this.panOffsetX
                  this.panStartY = this.panOffsetY
                })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.posterZoomScale > 1.01) {
                    this.panOffsetX = this.panStartX + event.offsetX
                    this.panOffsetY = this.panStartY + event.offsetY
                  }
                })
            )
          )
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: Spacing.sm, right: Spacing.sm, bottom: this.safeBottomVp + 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .zIndex(2000)
  }

  @Builder
  buildTopBar() {
    Row({ space: Spacing.md }) {
      Button() {
        Text('<').fontSize(22).fontColor(MintColors.mintDark)
      }
      .width(40).height(40)
      .backgroundColor('rgba(255, 255, 255, 0.92)')
      .borderRadius(20)
      .border({ width: 0.5, color: MintColors.border, radius: 20 })
      .onClick(() => this.goBack())

      Column({ space: 2 }) {
        Text('海报预览').fontSize(Typography.size.bodyLg).fontWeight(FontWeight.Medium).fontColor(MintColors.textPrimary)
        Text(this.isLoading ? '生成中…' : (this.error.length > 0 ? '生成失败' : '已接入隔空传送 · 握拳即分享')).fontSize(Typography.size.xs).fontColor(MintColors.textSecondary)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      if (!this.isLoading && this.error.length === 0) {
        Button('复制链接')
          .height(36)
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.mintDark)
          .backgroundColor('rgba(78, 205, 196, 0.12)')
          .borderRadius(BorderRadius.pill)
          .onClick(() => this.copyPosterUrl())
      }
    }.width('100%')
  }

  @Builder
  buildGuidePanel() {
    Column({ space: Spacing.md }) {
      Text('隔空传送（华为 Share Kit · 应用原生）')
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)
        .width('100%')

      Text('已接入华为 Share Kit：用户在任何位置「握拳抓取」时，系统回调应用提供数据，全程由系统完成跨设备传输，非截屏分享。需双端同华为账号、同局域网（以官方文档为准）。')
        .fontSize(Typography.size.caption)
        .fontColor(MintColors.textSecondary)
        .lineHeight(20)
        .width('100%')

      Column({ space: Spacing.sm }) {
        Row({ space: Spacing.sm }) {
          Column() {
            Text('1').fontSize(Typography.size.xs).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }
          .width(22).height(22).borderRadius(11)
          .backgroundColor(MintColors.mint)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

          Text('在任意界面「握拳抓取」，系统自动回调本应用提供海报数据，传输到目标设备')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
        }.width('100%').alignItems(VerticalAlign.Center)

        Row({ space: Spacing.sm }) {
          Column() {
            Text('2').fontSize(Typography.size.xs).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }
          .width(22).height(22).borderRadius(11)
          .backgroundColor(MintColors.mint)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

          Text('从握拳到完成传输需在 3 秒内，由系统自动完成（Share Kit 限制）')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
        }.width('100%').alignItems(VerticalAlign.Center)

        Row({ space: Spacing.sm }) {
          Column() {
            Text('3').fontSize(Typography.size.xs).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }
          .width(22).height(22).borderRadius(11)
          .backgroundColor(MintColors.mint)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

          Text('备用：长按海报拖出（UDMF 拖拽），或全屏后截图分享（非应用原生）')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
        }.width('100%').alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(Spacing.md)
      .backgroundColor('rgba(78, 205, 196, 0.06)')
      .borderRadius(BorderRadius.lg)

      Row({ space: Spacing.sm }) {
        Button('重新生成')
          .layoutWeight(1).height(42)
          .fontSize(Typography.size.body)
          .fontColor(MintColors.mintDark)
          .backgroundColor('rgba(78, 205, 196, 0.10)')
          .borderRadius(BorderRadius.xxl)
          .onClick(() => void this.generatePoster())

        Button('复制链接')
          .layoutWeight(1).height(42)
          .fontSize(Typography.size.body)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.mint)
          .borderRadius(BorderRadius.xxl)
          .enabled(this.posterUrl.length > 0)
          .onClick(() => this.copyPosterUrl())
      }.width('100%')
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor('#FFFFFF')
    .borderRadius(BorderRadius.xxl3)
    .border({ width: 1, color: MintColors.borderLight, radius: BorderRadius.xxl3 })
    .shadow({ radius: 20, color: 'rgba(15, 23, 42, 0.08)', offsetX: 0, offsetY: 6 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column().width('100%').height('100%').backgroundColor('#F1F5F9')
        Column().width(240).height(240).borderRadius(120).backgroundColor('rgba(78, 205, 196, 0.08)').blur(80).position({ x: -80, y: -60 })
        Column().width(200).height(200).borderRadius(100).backgroundColor('rgba(184, 169, 217, 0.08)').blur(60).position({ right: -60, bottom: 120 })
      }.width('100%').height('100%')

      Column({ space: Spacing.md }) {
        this.buildTopBar()

        Scroll() {
          Column({ space: Spacing.lg }) {
            if (this.isLoading) {
              Column({ space: Spacing.md }) {
                LoadingProgress().width(48).height(48).color(MintColors.mint)
                Text('正在生成海报…')
                  .fontSize(Typography.size.body)
                  .fontColor(MintColors.textSecondary)
              }
              .width('100%')
              .padding({ top: 80, bottom: 80 })
              .alignItems(HorizontalAlign.Center)
            } else if (this.error.length > 0) {
              Column({ space: Spacing.md }) {
                Text('生成失败')
                  .fontSize(Typography.size.xl)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(MintColors.error)
                Text(this.error)
                  .fontSize(Typography.size.body)
                  .fontColor(MintColors.textSecondary)
                  .textAlign(TextAlign.Center)
                Button('重试')
                  .height(44)
                  .fontSize(Typography.size.body)
                  .fontColor('#FFFFFF')
                  .backgroundColor(MintColors.mint)
                  .borderRadius(BorderRadius.xxl)
                  .onClick(() => void this.generatePoster())
              }
              .width('100%')
              .padding({ top: 60, bottom: 60 })
              .alignItems(HorizontalAlign.Center)
            } else {
              Column({ space: Spacing.md }) {
                Row({ space: Spacing.sm }) {
                  Text(this.posterTitle)
                    .fontSize(Typography.size.bodyLg)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(MintColors.textPrimary)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Start)

                  Text('点击放大')
                    .fontSize(Typography.size.xs)
                    .fontColor(MintColors.mintDark)
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .backgroundColor('rgba(78, 205, 196, 0.12)')
                    .borderRadius(BorderRadius.pill)
                }
                .width('100%')

                if (this.posterUrl.length > 0) {
                  Stack({ alignContent: Alignment.Center }) {
                    Image(this.posterUrl)
                      .width('100%')
                      .constraintSize({ minHeight: 220 })
                      .objectFit(ImageFit.Contain)
                      .draggable(true)
                      .onDragStart((event: DragEvent) => this.onPosterDragStart(event))
                      .borderRadius(BorderRadius.xxl)
                      .backgroundColor('#FFFFFF')
                      .shadow({ radius: 24, color: 'rgba(15, 23, 42, 0.12)', offsetX: 0, offsetY: 8 })
                  }
                  .width('100%')
                  .onClick(() => this.openFullscreenPoster())
                } else {
                  Column({ space: Spacing.md }) {
                    Text('图片加载失败')
                      .fontSize(Typography.size.body)
                      .fontColor(MintColors.error)
                    Button('重试')
                      .height(40)
                      .fontColor('#FFFFFF')
                      .backgroundColor(MintColors.mint)
                      .borderRadius(BorderRadius.xxl)
                      .onClick(() => void this.generatePoster())
                  }
                  .width('100%')
                  .padding(Spacing.xl)
                  .alignItems(HorizontalAlign.Center)
                }
              }
              .width('100%')
              .padding(Spacing.lg)
              .backgroundColor('#FFFFFF')
              .borderRadius(BorderRadius.xxl3)
              .border({ width: 1, color: MintColors.border, radius: BorderRadius.xxl3 })
              .shadow({ radius: 28, color: 'rgba(15, 23, 42, 0.10)', offsetX: 0, offsetY: 10 })

              this.buildGuidePanel()
            }
          }
          .width('100%')
          .padding({ left: Spacing.page.horizontal, right: Spacing.page.horizontal, top: Spacing.sm, bottom: this.safeBottomVp + 24 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .padding({ left: Spacing.page.horizontal, right: Spacing.page.horizontal, top: this.topInsetVp() + 12 })

      if (this.showFullscreenPoster) {
        this.buildFullscreenPosterLayer()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FAFC')
  }
}
