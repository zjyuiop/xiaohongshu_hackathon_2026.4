import { common } from '@kit.AbilityKit'
import fileIo from '@ohos.file.fs'
import picker from '@ohos.file.picker'
import fileUri from '@ohos.file.fileuri'
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { AnimationDuration, AnimationCurve } from '../common/styles/Animation'
import { Icon, IconType } from '../components/CustomIcon'
import { ProfileImportResponse, ProfileImportType } from '../common/Models'
import { PersonaApi } from '../service/PersonaApi'

const FALLBACK_SAFE_TOP_VP: number = 52
const IMPORT_CACHE_DIR_NAME: string = 'profile-imports'
const SUPPORTED_IMPORT_SUFFIX_FILTERS: string[] = ['.txt', '.md', '.markdown', '.csv', '.log', '.json', '.html', '.htm', '.xml', '.epub']
const SUPPORTED_IMPORT_FORMATS_TEXT: string = '.txt / .md / .csv / .json / .html / .xml / .epub'

interface TabItem {
  title: string
  iconType: IconType
}

interface SelectedImportFile {
  uri: string
  fileName: string
}

interface UploadFileResult {
  filePath: string
  cleanupPath?: string
}

@Entry
@Component
export struct CreateRole {
  @State private currentTab: number = 0
  @State private roleName: string = ''
  @State private biography: string = ''
  @State private isLoading: boolean = false
  @State private pageEntered: boolean = false
  @State private safeTopVp: number = 0
  @State private safeBottomVp: number = 0

  @State private contentOpacity: number = 0
  @State private contentTranslateY: number = 30
  @State private wechatImportFileUri: string = ''
  @State private wechatImportFileName: string = ''
  @State private chatImportFileUri: string = ''
  @State private chatImportFileName: string = ''

  aboutToAppear(): void {
    this.loadSafeInsets()
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.pageEntered = true
        this.contentOpacity = 1
        this.contentTranslateY = 0
      })
    }, 100)
  }

  loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_e) {
      // 忽略错误
    }
  }

  topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  goBack(): void {
    animateTo({
      duration: AnimationDuration.fast,
      curve: AnimationCurve.decelerated
    }, () => {
      router.back()
    })
  }

  switchTab(index: number): void {
    animateTo({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized
    }, () => {
      this.currentTab = index
    })
  }

  async createRole(): Promise<void> {
    if (!this.roleName.trim()) {
      promptAction.showToast({ message: '请输入人物名称' })
      return
    }

    if (!this.biography.trim() || this.biography.length < 10) {
      promptAction.showToast({ message: '请输入至少10个字符的人物描述' })
      return
    }

    this.isLoading = true

    try {
      const roleName = this.roleName.trim()
      const biography = this.biography.trim()
      promptAction.showToast({ message: '\u6b63\u5728\u89e3\u6790\u4eba\u7269\u6750\u6599\uff0c\u53ef\u80fd\u9700\u8981\u4e00\u6bb5\u65f6\u95f4' })
      const response = await PersonaApi.importProfile({
        importType: 'manual',
        fileName: `${this.sanitizeFileName(roleName)}.txt`,
        mimeType: 'text/plain',
        title: `${roleName} profile notes`,
        displayNameHint: roleName,
        fileData: this.buildManualImportContent(roleName, biography)
      })
      this.handleImportSuccess(response)
    } catch (error) {
      promptAction.showToast({ message: this.formatImportError(error as Error) })
    } finally {
      this.isLoading = false
    }
    return

    PersonaApi.importCustomProfile(this.roleName.trim(), this.biography.trim())
      .then((bundle) => {
        promptAction.showToast({ message: '角色创建成功！' })
        router.pushUrl({
          url: 'pages/ProfileDetail',
          params: {
            profileId: bundle.profile.id
          }
        })
      })
      .catch((error: Error) => {
        promptAction.showToast({ message: `创建失败: ${error.message}` })
      })
      .finally(() => {
        this.isLoading = false
      })
  }

  uploadWeChat(): void {
    void this.selectImportFile('wechat')
    return
    promptAction.showToast({ message: '请选择微信聊天记录文件（仅支持 .txt 格式）' })
  }

  startAIDialogue(): void {
    void this.selectImportFile('chat')
    return
    promptAction.showToast({ message: 'AI对话功能开发中...' })
  }

  getNameInitial(): string {
    return this.roleName.length > 0 ? this.roleName.charAt(0) : '?'
  }

  private buildManualImportContent(roleName: string, biography: string): string {
    return `Name: ${roleName}\n\nBiography:\n${biography}\n`
  }

  private getCurrentImportType(): ProfileImportType {
    if (this.currentTab === 1) {
      return 'wechat'
    }
    if (this.currentTab === 2) {
      return 'chat'
    }
    return 'manual'
  }

  private getOptionalDisplayNameHint(): string | undefined {
    const value = this.roleName.trim()
    return value.length > 0 ? value : undefined
  }

  private getSelectedImportFile(importType: ProfileImportType): SelectedImportFile {
    if (importType === 'wechat') {
      return {
        uri: this.wechatImportFileUri,
        fileName: this.wechatImportFileName
      }
    }

    if (importType === 'chat') {
      return {
        uri: this.chatImportFileUri,
        fileName: this.chatImportFileName
      }
    }

    return {
      uri: '',
      fileName: ''
    }
  }

  private setSelectedImportFile(importType: ProfileImportType, file: SelectedImportFile): void {
    if (importType === 'wechat') {
      this.wechatImportFileUri = file.uri
      this.wechatImportFileName = file.fileName
      return
    }

    if (importType === 'chat') {
      this.chatImportFileUri = file.uri
      this.chatImportFileName = file.fileName
    }
  }

  private canTriggerPrimaryAction(): boolean {
    if (this.isLoading) {
      return false
    }

    if (this.getCurrentImportType() === 'manual') {
      return this.roleName.trim().length > 0 && this.biography.trim().length >= 10
    }

    return true
  }

  private getPrimaryActionLabel(): string {
    if (this.isLoading) {
      return this.getCurrentImportType() === 'manual'
        ? '\u89e3\u6790\u4e2d...'
        : '\u5bfc\u5165\u4e2d...'
    }

    if (this.getCurrentImportType() === 'manual') {
      return '\u521b\u5efa\u5e76\u5bfc\u5165'
    }

    const selectedFile = this.getSelectedImportFile(this.getCurrentImportType())
    return selectedFile.fileName.length > 0
      ? '\u5f00\u59cb\u5bfc\u5165'
      : '\u9009\u62e9\u6587\u4ef6\u5e76\u5bfc\u5165'
  }

  private getSelectButtonLabel(importType: ProfileImportType): string {
    const selectedFile = this.getSelectedImportFile(importType)
    if (selectedFile.fileName.length > 0) {
      return '\u91cd\u65b0\u9009\u62e9\u6587\u4ef6'
    }
    return importType === 'wechat'
      ? '\u9009\u62e9\u804a\u5929\u8bb0\u5f55\u6587\u4ef6'
      : '\u9009\u62e9\u5bf9\u8bdd\u8bb0\u5f55\u6587\u4ef6'
  }

  private getSelectedFileSummary(importType: ProfileImportType): string {
    const selectedFile = this.getSelectedImportFile(importType)
    if (selectedFile.fileName.length > 0) {
      return `\u5df2\u9009\u62e9\uff1a${selectedFile.fileName}`
    }
    return `\u652f\u6301\u683c\u5f0f\uff1a${SUPPORTED_IMPORT_FORMATS_TEXT}`
  }

  private stripFileExtension(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.')
    if (dotIndex <= 0) {
      return fileName
    }
    return fileName.substring(0, dotIndex)
  }

  private sanitizeFileName(value: string): string {
    const sanitized = value
      .replace(/[\\/:*?"<>|\s]+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '')
    return sanitized.length > 0 ? sanitized : 'profile-import'
  }

  private guessMimeType(fileName: string): string {
    const normalized = fileName.toLowerCase()
    if (normalized.endsWith('.md') || normalized.endsWith('.markdown')) {
      return 'text/markdown'
    }
    if (normalized.endsWith('.csv')) {
      return 'text/csv'
    }
    if (normalized.endsWith('.json')) {
      return 'application/json'
    }
    if (normalized.endsWith('.html') || normalized.endsWith('.htm')) {
      return 'text/html'
    }
    if (normalized.endsWith('.xml')) {
      return 'application/xml'
    }
    if (normalized.endsWith('.epub')) {
      return 'application/epub+zip'
    }
    return 'text/plain'
  }

  private extractFileName(source: string): string {
    try {
      const uriValue = new fileUri.FileUri(source)
      if (uriValue.name && uriValue.name.length > 0) {
        return uriValue.name
      }
    } catch (_error) {
    }

    const cleanSource = source.split('?')[0]
    const fileName = cleanSource.substring(cleanSource.lastIndexOf('/') + 1)
    if (!fileName.length) {
      return 'profile-import.txt'
    }

    try {
      return decodeURIComponent(fileName)
    } catch (_error) {
      return fileName
    }
  }

  private buildUploadSourceCandidates(source: string): string[] {
    let candidates: string[] = []
    if (source.length > 0) {
      candidates.push(source)
    }

    try {
      const uriValue = new fileUri.FileUri(source)
      if (uriValue.path && uriValue.path.length > 0 && !candidates.includes(uriValue.path)) {
        candidates.push(uriValue.path)
      }
    } catch (_error) {
    }

    return candidates
  }

  private buildImportTitle(fileName: string): string {
    const title = this.stripFileExtension(fileName).trim()
    return title.length > 0 ? title : 'Imported profile'
  }

  private formatPickerError(error: Error): string {
    const message = error.message ? error.message : ''
    if (!message.length || message.toLowerCase().includes('cancel')) {
      return '\u672a\u9009\u62e9\u6587\u4ef6'
    }
    return `\u9009\u62e9\u6587\u4ef6\u5931\u8d25: ${message}`
  }

  private formatImportError(error: Error): string {
    const message = error.message ? error.message : ''
    const normalized = message.toLowerCase()
    if (normalized.includes('504') || normalized.includes('gateway time-out') || normalized.includes('gateway timeout')) {
      return '\u5bfc\u5165\u8017\u65f6\u8f83\u957f\uff0c\u670d\u52a1\u5668\u6682\u65f6\u8d85\u65f6\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5'
    }
    if (!message.length) {
      return '\u5bfc\u5165\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5'
    }
    return `\u5bfc\u5165\u5931\u8d25: ${message}`
  }

  private handleImportSuccess(response: ProfileImportResponse): void {
    const displayName = response.bundle.profile.displayName.trim()
    const title = response.import.title.trim()
    const successLabel = displayName.length > 0 ? displayName : title

    promptAction.showToast({
      message: successLabel.length > 0
        ? `\u5bfc\u5165\u6210\u529f\uff1a${successLabel}`
        : '\u5bfc\u5165\u6210\u529f'
    })

    router.pushUrl({
      url: 'pages/ProfileDetail',
      params: {
        profileId: response.bundle.profile.id
      }
    })
  }

  private getAbilityContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private async selectImportFile(importType: ProfileImportType): Promise<boolean> {
    try {
      const documentPicker = new picker.DocumentViewPicker(this.getAbilityContext())
      const options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.fileSuffixFilters = SUPPORTED_IMPORT_SUFFIX_FILTERS
      const selectedUris = await documentPicker.select(options)
      if (!selectedUris || selectedUris.length === 0) {
        return false
      }

      const selectedUri = selectedUris[0]
      this.setSelectedImportFile(importType, {
        uri: selectedUri,
        fileName: this.extractFileName(selectedUri)
      })
      return true
    } catch (error) {
      promptAction.showToast({ message: this.formatPickerError(error as Error) })
      return false
    }
  }

  private async prepareUploadFile(file: SelectedImportFile): Promise<UploadFileResult> {
    const cacheRoot = `${this.getAbilityContext().cacheDir}/${IMPORT_CACHE_DIR_NAME}`
    if (!fileIo.accessSync(cacheRoot)) {
      fileIo.mkdirSync(cacheRoot, true)
    }

    const localPath = `${cacheRoot}/${Date.now()}-${this.sanitizeFileName(file.fileName)}`
    const sourceCandidates = this.buildUploadSourceCandidates(file.uri)

    for (const sourcePath of sourceCandidates) {
      try {
        await fileIo.copyFile(sourcePath, localPath)
        return {
          filePath: localPath,
          cleanupPath: localPath
        }
      } catch (_error) {
      }
    }

    const directFilePath = sourceCandidates.find((candidate: string) => candidate.startsWith('/'))
    if (directFilePath) {
      return {
        filePath: directFilePath
      }
    }

    return {
      filePath: file.uri
    }
  }

  private safeCleanup(path?: string): void {
    if (!path) {
      return
    }

    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path)
      }
    } catch (_error) {
    }
  }

  private async importFromSelectedFile(importType: ProfileImportType): Promise<void> {
    let selectedFile = this.getSelectedImportFile(importType)
    if (!selectedFile.uri) {
      const picked = await this.selectImportFile(importType)
      if (!picked) {
        return
      }
      selectedFile = this.getSelectedImportFile(importType)
    }

    if (!selectedFile.uri) {
      promptAction.showToast({ message: '\u8bf7\u5148\u9009\u62e9\u8981\u5bfc\u5165\u7684\u6587\u4ef6' })
      return
    }

    this.isLoading = true
    let cleanupPath: string | undefined = undefined

    try {
      promptAction.showToast({ message: '\u5bfc\u5165\u4e2d\uff0c\u53ef\u80fd\u9700\u8981\u8f83\u957f\u65f6\u95f4\uff0c\u8bf7\u8010\u5fc3\u7b49\u5f85' })
      const prepared = await this.prepareUploadFile(selectedFile)
      cleanupPath = prepared.cleanupPath

      const response = await PersonaApi.importProfile({
        importType,
        filePath: prepared.filePath,
        fileName: selectedFile.fileName,
        mimeType: this.guessMimeType(selectedFile.fileName),
        title: this.buildImportTitle(selectedFile.fileName),
        displayNameHint: this.getOptionalDisplayNameHint()
      })
      this.handleImportSuccess(response)
    } catch (error) {
      promptAction.showToast({ message: this.formatImportError(error as Error) })
    } finally {
      this.safeCleanup(cleanupPath)
      this.isLoading = false
    }
  }

  private async handlePrimaryAction(): Promise<void> {
    if (this.getCurrentImportType() === 'manual') {
      await this.createRole()
      return
    }

    await this.importFromSelectedFile(this.getCurrentImportType())
  }

  getTabIconColor(index: number, isActive: boolean): string {
    if (!isActive) {
      return MintColors.textMuted
    }
    if (index === 1) {
      return MintColors.lavender
    }
    if (index === 2) {
      return MintColors.mintDark
    }
    return MintColors.mint
  }

  getIllustrationBgColor(): string {
    if (this.currentTab === 1) {
      return MintColors.lavenderPale
    }
    return MintColors.mintBg
  }

  getIllustrationOrbColor(): string {
    if (this.currentTab === 1) {
      return MintColors.lavenderBg
    }
    if (this.currentTab === 2) {
      return MintColors.lavenderPale
    }
    return MintColors.mintPale
  }

  getIllustrationIconColor(): string {
    return this.getTabIconColor(this.currentTab, true)
  }

  getIllustrationAccentIcon(offset: number): IconType {
    const tabItems = this.getTabItems()
    return tabItems[(this.currentTab + offset) % tabItems.length].iconType
  }

  @Builder
  buildHeroIllustration() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(130)
          .height(130)
          .fill(this.getIllustrationBgColor())

        Circle()
          .width(90)
          .height(90)
          .fill(this.getIllustrationOrbColor())

        Column() {
          Icon({
            iconType: this.getTabItems()[this.currentTab].iconType,
            iconSize: 34,
            iconColor: this.getIllustrationIconColor()
          })
        }
        .width(58)
        .height(58)
        .backgroundColor('rgba(255, 255, 255, 0.68)')
        .borderRadius(29)
        .border({
          width: 0.5,
          color: 'rgba(255, 255, 255, 0.88)',
          radius: 29
        })
        .backdropBlur(18)
        .shadow({
          radius: 18,
          color: 'rgba(78, 205, 196, 0.12)',
          offsetX: 0,
          offsetY: 6
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Icon({
            iconType: this.getIllustrationAccentIcon(1),
            iconSize: 16,
            iconColor: MintColors.lavenderDark
          })
        }
        .width(28)
        .height(28)
        .backgroundColor('rgba(255, 255, 255, 0.72)')
        .borderRadius(14)
        .shadow({
          radius: 10,
          color: 'rgba(184, 169, 217, 0.14)',
          offsetX: 0,
          offsetY: 4
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 86, y: 18 })

        Column() {
          Icon({
            iconType: this.getIllustrationAccentIcon(2),
            iconSize: 14,
            iconColor: MintColors.mintDark
          })
        }
        .width(24)
        .height(24)
        .backgroundColor('rgba(255, 255, 255, 0.72)')
        .borderRadius(12)
        .shadow({
          radius: 10,
          color: 'rgba(78, 205, 196, 0.10)',
          offsetX: 0,
          offsetY: 4
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 18, y: 78 })
      }
      .margin({ top: Spacing.lg })

      Text('创建专属角色')
        .fontSize(Typography.size.xxl)
        .fontWeight(Typography.weight.bold)
        .fontColor(MintColors.textPrimary)
        .margin({ top: Spacing.md })

      Text('通过文字描绘、聊天记录或 AI 对话，让角色设定更完整也更有质感。')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textMuted)
        .textAlign(TextAlign.Center)
        .margin({ top: Spacing.xs })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildEnhancedTabIcon(item: TabItem, index: number, isActive: boolean) {
    Icon({
      iconType: item.iconType,
      iconSize: 18,
      iconColor: this.getTabIconColor(index, isActive)
    })
      .margin({ bottom: 4 })
  }

  @Builder
  buildWeChatUploadCard() {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.md }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(100)
            .height(100)
            .fill(MintColors.lavenderPale)

          Column() {
            Icon({
              iconType: 'chat',
              iconSize: 38,
              iconColor: MintColors.lavender
            })
          }
          .width(56)
          .height(56)
          .backgroundColor('rgba(255, 255, 255, 0.68)')
          .borderRadius(28)
          .border({
            width: 0.5,
            color: 'rgba(255, 255, 255, 0.88)',
            radius: 28
          })
          .shadow({
            radius: 14,
            color: 'rgba(184, 169, 217, 0.14)',
            offsetX: 0,
            offsetY: 4
          })
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: Spacing.sm }) {
          Text('上传微信聊天记录')
            .fontSize(Typography.size.subtitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text('系统会分析对话内容，提取人物特征，帮助你快速生成更真实的角色画像。')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }
      .width('100%')
      .padding({ top: Spacing.xl, bottom: Spacing.xl })
      .backgroundColor(MintColors.cardPrimary)
      .borderRadius(BorderRadius.xxl)
      .border({
        width: 0.5,
        color: MintColors.border,
        radius: BorderRadius.xxl
      })

      Button('选择聊天记录文件')
        .width('100%')
        .height(50)
        .fontSize(Typography.size.bodyLg)
        .fontColor(MintColors.lavender)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(MintColors.lavenderBg)
        .borderRadius(BorderRadius.xxl)
        .border({
          width: 0.5,
          color: MintColors.border,
          radius: BorderRadius.xxl
        })
        .onClick(() => this.uploadWeChat())

      Row() {
        Text('支持格式：')
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textMuted)

        Text('.txt')
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.lavender)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: Spacing.xs })
    }
  }

  @Builder
  buildAIDialogueCard() {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.md }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(100)
            .height(100)
            .fill(MintColors.mintBg)

          Column() {
            Icon({
              iconType: 'ai',
              iconSize: 38,
              iconColor: MintColors.mintDark
            })
          }
          .width(56)
          .height(56)
          .backgroundColor('rgba(255, 255, 255, 0.68)')
          .borderRadius(28)
          .border({
            width: 0.5,
            color: 'rgba(255, 255, 255, 0.88)',
            radius: 28
          })
          .shadow({
            radius: 14,
            color: 'rgba(78, 205, 196, 0.14)',
            offsetX: 0,
            offsetY: 4
          })
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: Spacing.sm }) {
          Text('AI 智能对话创建')
            .fontSize(Typography.size.subtitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text('通过 AI 对话逐步补全背景、性格和表达方式，让角色设定更自然也更完整。')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }
      .width('100%')
      .padding({ top: Spacing.xl, bottom: Spacing.xl })
      .backgroundColor(MintColors.cardPrimary)
      .borderRadius(BorderRadius.xxl)
      .border({
        width: 0.5,
        color: MintColors.border,
        radius: BorderRadius.xxl
      })

      Button('开始 AI 对话')
        .width('100%')
        .height(50)
        .fontSize(Typography.size.bodyLg)
        .fontColor(MintColors.mintDark)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(MintColors.mintBg)
        .borderRadius(BorderRadius.xxl)
        .border({
          width: 0.5,
          color: MintColors.border,
          radius: BorderRadius.xxl
        })
        .onClick(() => this.startAIDialogue())
    }
  }

  getTabItems(): TabItem[] {
    return [
      { title: '手动输入', iconType: 'edit' },
      { title: '微信记录', iconType: 'chat' },
      { title: 'AI对话', iconType: 'ai' }
    ]
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 背景
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(MintColors.background)

        // 右上薄荷光晕
        Column()
          .width(260)
          .height(180)
          .borderRadius(130)
          .backgroundColor('rgba(78, 205, 196, 0.1)')
          .blur(70)
          .position({ x: '55%', y: -60 })

        // 左下淡紫光晕
        Column()
          .width(220)
          .height(160)
          .borderRadius(110)
          .backgroundColor('rgba(184, 169, 217, 0.1)')
          .blur(60)
          .position({ x: -60, y: '65%' })

        // 底部装饰线
        Column()
          .width('100%')
          .height(2)
          .linearGradient({
            direction: GradientDirection.Left,
            colors: [
              [MintColors.lavenderPale, 0.0],
              [MintColors.mintPale, 0.5],
              [MintColors.lavenderPale, 1.0]
            ]
          })
          .position({ y: '100%' })
      }
      .width('100%')
      .height('100%')

      Scroll() {
        Column({ space: Spacing.md }) {
          this.buildHeroIllustration()
          this.buildTabSelector()
          this.buildContentArea()
          this.buildPrimaryActionButton()
        }
        .padding({
          left: Spacing.page.horizontal,
          right: Spacing.page.horizontal,
          top: this.topInsetVp() + 60,
          bottom: Spacing.page.bottom + 100 + this.safeBottomVp
        })
      }
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Button() {
        Icon({
          iconType: 'arrowLeft',
          iconSize: 16,
          iconColor: MintColors.mintDark
        })
      }
      .width(38)
      .height(38)
      .backgroundColor(MintColors.surfaceGlass)
      .borderRadius(19)
      .shadow({
        radius: 10,
        color: 'rgba(78, 205, 196, 0.1)',
        offsetX: 0,
        offsetY: 3
      })
      .position({ x: Spacing.page.horizontal, y: this.topInsetVp() + 12 })
      .onClick(() => this.goBack())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
    .opacity(this.contentOpacity)
    .translate({ x: 0, y: this.contentTranslateY })
  }

  @Builder
  buildIllustration() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(130)
          .height(130)
          .fill(MintColors.mintBg)

        Circle()
          .width(90)
          .height(90)
          .fill(MintColors.lavenderPale)

        // 装饰星星
        Column() {
          Column()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(MintColors.mint)
        }
        .position({ x: 46, y: 12 })

        Column() {
          Column()
            .width(5)
            .height(5)
            .borderRadius(2.5)
            .backgroundColor(MintColors.lavender)
        }
        .position({ x: 16, y: 55 })

        Column() {
          Column()
            .width(5)
            .height(5)
            .borderRadius(2.5)
            .backgroundColor(MintColors.mintDark)
        }
        .position({ x: 90, y: 65 })

        Column() {
          Column()
            .width(4)
            .height(4)
            .borderRadius(2)
            .backgroundColor(MintColors.lavenderDark)
        }
        .position({ x: 54, y: 92 })
      }
      .margin({ top: Spacing.lg })

      Text('创建专属角色')
        .fontSize(Typography.size.xxl)
        .fontWeight(Typography.weight.bold)
        .fontColor(MintColors.textPrimary)
        .margin({ top: Spacing.md })

      Text('通过文字描绘、AI对话或聊天记录')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textMuted)
        .margin({ top: Spacing.xs })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildTabSelector() {
    Row() {
      ForEach(this.getTabItems(), (item: TabItem, index: number) => {
        Column() {
          this.buildEnhancedTabIcon(item, index, this.currentTab === index)

          Text(item.title)
            .fontSize(Typography.size.caption)
            .fontColor(this.currentTab === index ? MintColors.mintDark : MintColors.textMuted)
        }
        .padding({
          left: Spacing.md,
          right: Spacing.md,
          top: Spacing.sm,
          bottom: Spacing.sm
        })
        .backgroundColor(this.currentTab === index ? MintColors.mintBg : 'transparent')
        .borderRadius(BorderRadius.xxl)
        .onClick(() => this.switchTab(index))
        .animation({
          duration: AnimationDuration.fast,
          curve: AnimationCurve.emphasized
        })
      }, (item: TabItem) => item.title)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .backgroundColor(MintColors.surfaceGlass)
    .borderRadius(BorderRadius.xxl)
    .padding({ top: Spacing.xs, bottom: Spacing.xs })
  }

  @Builder
  buildTabIcon(iconType: string, isActive: boolean) {
    if (iconType === 'edit') {
      Column() {
        Column()
          .width(16)
          .height(2)
          .backgroundColor(isActive ? MintColors.mint : MintColors.textMuted)
          .borderRadius(1)
        Column()
          .width(2)
          .height(14)
          .backgroundColor(isActive ? MintColors.mint : MintColors.textMuted)
          .borderRadius(1)
          .position({ x: 6, y: -8 })
      }
      .width(20)
      .height(20)
      .margin({ bottom: 4 })
      .rotate({ angle: -45 })
    } else if (iconType === 'chat') {
      Column() {
        Column()
          .width(18)
          .height(12)
          .backgroundColor(isActive ? MintColors.lavender : MintColors.textMuted)
          .borderRadius(3)
        Column()
          .width(0)
          .height(0)
          .borderWidth({
            top: 4,
            left: 3,
            right: 5
          })
          .borderColor({
            top: isActive ? MintColors.lavender : MintColors.textMuted,
            left: isActive ? MintColors.lavender : MintColors.textMuted,
            right: Color.Transparent
          })
          .position({ x: -3, y: 8 })
      }
      .width(20)
      .height(20)
      .margin({ bottom: 4 })
    } else if (iconType === 'ai') {
      Column() {
        Column()
          .width(14)
          .height(10)
          .backgroundColor(isActive ? MintColors.mintDark : MintColors.textMuted)
          .borderRadius(3)
        Column()
          .width(10)
          .height(6)
          .backgroundColor(isActive ? MintColors.mintDark : MintColors.textMuted)
          .borderRadius(3)
          .position({ y: -2 })
      }
      .width(20)
      .height(20)
      .margin({ bottom: 4 })
    }
  }

  @Builder
  buildContentArea() {
    Column({ space: Spacing.md }) {
      if (this.currentTab === 0) {
        this.buildManualForm()
      } else if (this.currentTab === 1) {
        this.buildImportUploadCard('wechat')
      } else {
        this.buildImportUploadCard('chat')
      }
    }
  }

  @Builder
  buildManualForm() {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.xs }) {
        Text('人物名称')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)

        TextInput({ placeholder: '请输入角色名称', text: this.roleName })
          .width('100%')
          .height(50)
          .fontSize(Typography.size.bodyLg)
          .fontColor(MintColors.textPrimary)
          .placeholderFont({ size: Typography.size.body })
          .placeholderColor(MintColors.textPlaceholder)
          .backgroundColor(MintColors.surface)
          .borderRadius(BorderRadius.xxl)
          .border({ width: 0.5, color: MintColors.border })
          .padding({ left: Spacing.md, right: Spacing.md })
          .onChange((value: string) => {
            this.roleName = value
          })
      }

      Column({ space: Spacing.xs }) {
        Row() {
          Text('人物传记')
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Medium)
            .fontColor(MintColors.textPrimary)

          Blank()

          Text(`${this.biography.length}/500`)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textMuted)
        }
        .width('100%')

        TextArea({ placeholder: '请描述角色的背景、性格、特点...', text: this.biography })
          .width('100%')
          .height(140)
          .fontSize(Typography.size.bodyLg)
          .fontColor(MintColors.textPrimary)
          .placeholderFont({ size: Typography.size.body })
          .placeholderColor(MintColors.textPlaceholder)
          .backgroundColor(MintColors.surface)
          .borderRadius(BorderRadius.xxl)
          .border({ width: 0.5, color: MintColors.border })
          .padding(Spacing.md)
          .maxLength(500)
          .onChange((value: string) => {
            this.biography = value
          })
      }
    }
  }

  @Builder
  buildImportUploadCard(importType: ProfileImportType) {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.md }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(100)
            .height(100)
            .fill(importType === 'wechat' ? MintColors.lavenderPale : MintColors.mintBg)

          Column() {
            Icon({
              iconType: importType === 'wechat' ? 'chat' : 'ai',
              iconSize: 38,
              iconColor: importType === 'wechat' ? MintColors.lavender : MintColors.mintDark
            })
          }
          .width(56)
          .height(56)
          .backgroundColor('rgba(255, 255, 255, 0.68)')
          .borderRadius(28)
          .border({
            width: 0.5,
            color: 'rgba(255, 255, 255, 0.88)',
            radius: 28
          })
          .shadow({
            radius: 14,
            color: importType === 'wechat' ? 'rgba(184, 169, 217, 0.14)' : 'rgba(78, 205, 196, 0.14)',
            offsetX: 0,
            offsetY: 4
          })
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: Spacing.sm }) {
          Text(importType === 'wechat' ? '\u4e0a\u4f20\u5fae\u4fe1\u804a\u5929\u8bb0\u5f55' : 'AI \u5bf9\u8bdd\u8bb0\u5f55\u5bfc\u5165')
            .fontSize(Typography.size.subtitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text(
            importType === 'wechat'
              ? '\u7cfb\u7edf\u4f1a\u5206\u6790\u5bfc\u51fa\u7684\u804a\u5929\u8bb0\u5f55\uff0c\u63d0\u53d6\u4eba\u7269\u7279\u5f81\uff0c\u5e2e\u4f60\u66f4\u5feb\u751f\u6210\u89d2\u8272\u6863\u6848\u3002'
              : '\u4e0a\u4f20\u4f60\u4e0e AI \u7684\u5bf9\u8bdd\u8bb0\u5f55\u540e\uff0c\u7cfb\u7edf\u4f1a\u8865\u5168\u80cc\u666f\u3001\u6027\u683c\u548c\u8868\u8fbe\u65b9\u5f0f\uff0c\u8ba9\u89d2\u8272\u8bbe\u5b9a\u66f4\u81ea\u7136\u3002'
          )
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }
      .width('100%')
      .padding({ top: Spacing.xl, bottom: Spacing.xl })
      .backgroundColor(MintColors.cardPrimary)
      .borderRadius(BorderRadius.xxl)
      .border({
        width: 0.5,
        color: MintColors.border,
        radius: BorderRadius.xxl
      })

      Button(this.getSelectButtonLabel(importType))
        .width('100%')
        .height(50)
        .fontSize(Typography.size.bodyLg)
        .fontColor(importType === 'wechat' ? MintColors.lavender : MintColors.mintDark)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(importType === 'wechat' ? MintColors.lavenderBg : MintColors.mintBg)
        .borderRadius(BorderRadius.xxl)
        .border({
          width: 0.5,
          color: MintColors.border,
          radius: BorderRadius.xxl
        })
        .enabled(!this.isLoading)
        .onClick(() => {
          if (importType === 'wechat') {
            this.uploadWeChat()
          } else {
            this.startAIDialogue()
          }
        })

      Text(this.getSelectedFileSummary(importType))
        .width('100%')
        .fontSize(Typography.size.caption)
        .fontColor(MintColors.textMuted)
        .textAlign(TextAlign.Center)
        .margin({ top: Spacing.xs })
    }
  }

  @Builder
  buildWeChatUpload() {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.md }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(100)
            .height(100)
            .fill(MintColors.lavenderPale)

          Column() {
            Column()
              .width(36)
              .height(28)
              .backgroundColor(MintColors.lavender)
              .borderRadius(8)
            Column()
              .width(0)
              .height(0)
              .borderWidth({
                top: 8,
                left: 6,
                right: 10
              })
              .borderColor({
                top: MintColors.lavender,
                left: MintColors.lavender,
                right: Color.Transparent
              })
              .position({ x: -6, y: 22 })
          }
          .width(50)
          .height(50)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: Spacing.sm }) {
          Text('上传微信聊天记录')
            .fontSize(Typography.size.subtitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text('系统将分析聊天内容，提取对方特征，生成角色画像')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }
      .width('100%')
      .padding({ top: Spacing.xl, bottom: Spacing.xl })
      .backgroundColor(MintColors.cardPrimary)
      .borderRadius(BorderRadius.xxl)
      .border({
        width: 0.5,
        color: MintColors.border,
        radius: BorderRadius.xxl
      })

      Button('选择聊天记录文件')
        .width('100%')
        .height(50)
        .fontSize(Typography.size.bodyLg)
        .fontColor(MintColors.lavender)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(MintColors.lavenderBg)
        .borderRadius(BorderRadius.xxl)
        .border({
          width: 0.5,
          color: MintColors.border,
          radius: BorderRadius.xxl
        })
        .onClick(() => this.uploadWeChat())

      Row() {
        Text('支持格式：')
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textMuted)

        Text('.txt')
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.lavender)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: Spacing.xs })
    }
  }

  @Builder
  buildAIDialogue() {
    Column({ space: Spacing.md }) {
      Column({ space: Spacing.md }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(100)
            .height(100)
            .fill(MintColors.mintBg)

          Column() {
            Column()
              .width(32)
              .height(22)
              .backgroundColor(MintColors.mint)
              .borderRadius(6)
            Column()
              .width(18)
              .height(14)
              .backgroundColor(MintColors.mint)
              .borderRadius(7)
              .position({ y: -4 })
          }
          .width(50)
          .height(50)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: Spacing.sm }) {
          Text('AI智能对话创建')
            .fontSize(Typography.size.subtitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text('通过与AI对话交流，逐步塑造角色形象，系统将根据对话内容生成角色')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: Spacing.lg, right: Spacing.lg })
      }
      .width('100%')
      .padding({ top: Spacing.xl, bottom: Spacing.xl })
      .backgroundColor(MintColors.cardPrimary)
      .borderRadius(BorderRadius.xxl)
      .border({
        width: 0.5,
        color: MintColors.border,
        radius: BorderRadius.xxl
      })

      Button('开始AI对话')
        .width('100%')
        .height(50)
        .fontSize(Typography.size.bodyLg)
        .fontColor(MintColors.mintDark)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(MintColors.mintBg)
        .borderRadius(BorderRadius.xxl)
        .border({
          width: 0.5,
          color: MintColors.border,
          radius: BorderRadius.xxl
        })
        .onClick(() => this.startAIDialogue())
    }
  }

  @Builder
  buildPrimaryActionButton() {
    Button() {
      Row() {
        if (this.isLoading) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color('#FFFFFF')
          Text(this.getPrimaryActionLabel())
            .fontSize(Typography.size.bodyLg)
            .fontColor('#FFFFFF')
            .margin({ left: Spacing.sm })
        } else {
          Text(this.getPrimaryActionLabel())
            .fontSize(Typography.size.bodyLg)
            .fontColor('#FFFFFF')
        }
      }
    }
    .width('100%')
    .height(52)
    .backgroundColor(this.canTriggerPrimaryAction() ? MintColors.mint : MintColors.backgroundSecondary)
    .borderRadius(BorderRadius.xxl)
    .shadow({
      radius: 16,
      color: 'rgba(78, 205, 196, 0.2)',
      offsetX: 0,
      offsetY: 6
    })
    .enabled(this.canTriggerPrimaryAction())
    .onClick(() => {
      void this.handlePrimaryAction()
    })
  }

  @Builder
  buildCreateButton() {
    Button() {
      Row() {
        if (this.isLoading) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color('#FFFFFF')
          Text('创建中...')
            .fontSize(Typography.size.bodyLg)
            .fontColor('#FFFFFF')
            .margin({ left: Spacing.sm })
        } else {
          Text('创建角色')
            .fontSize(Typography.size.bodyLg)
            .fontColor('#FFFFFF')
        }
      }
    }
    .width('100%')
    .height(52)
    .backgroundColor(this.canTriggerPrimaryAction() ? MintColors.mint : MintColors.backgroundSecondary)
    .borderRadius(BorderRadius.xxl)
    .shadow({
      radius: 16,
      color: 'rgba(78, 205, 196, 0.2)',
      offsetX: 0,
      offsetY: 6
    })
    .enabled(this.canTriggerPrimaryAction())
    .onClick(() => {
      void this.handlePrimaryAction()
    })
  }
}
