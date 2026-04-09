import { ExportFormatType, ImageSizeType } from '../common/Models'
import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'

interface ExportFormatOption {
  type: ExportFormatType
  order: string
  title: string
  description: string
  tint: string
  tone: string
}

interface ImageSizeOption {
  type: ImageSizeType
  label: string
  description: string
}

@Component
export struct ExportSheet {
  @Prop isVisible: boolean = false
  @Prop initialFormat: ExportFormatType = 'image'
  @Prop initialImageSize: ImageSizeType = '1x1'
  @Prop subjectTitle: string = ''
  @State selectedFormat: ExportFormatType = 'image'
  @State selectedImageSize: ImageSizeType = '1x1'
  @State isExporting: boolean = false

  onClose: () => void = () => {}
  onExportImage: (sizeType: ImageSizeType) => void = () => {}
  onExportVideo: () => void = () => {}
  onExportText: () => void = () => {}

  private readonly formatOptions: ExportFormatOption[] = [
    {
      type: 'image',
      order: '01',
      title: '纪要卡片',
      description: '适合分享到社交平台、聊天窗口或汇报封面。',
      tint: '#6366F1',
      tone: 'rgba(99, 102, 241, 0.10)'
    },
    {
      type: 'video',
      order: '02',
      title: '会议视频',
      description: '把会议共识、亮点和角色观点整理成视频回顾入口。',
      tint: '#0EA5E9',
      tone: 'rgba(14, 165, 233, 0.10)'
    },
    {
      type: 'text',
      order: '03',
      title: '文本摘要',
      description: '导出便于复制、继续编辑或沉淀到文档里的文本内容。',
      tint: '#10B981',
      tone: 'rgba(16, 185, 129, 0.10)'
    }
  ]

  private readonly imageSizeOptions: ImageSizeOption[] = [
    { type: '1x1', label: '1:1', description: '方形卡片' },
    { type: '16x9', label: '16:9', description: '横版封面' },
    { type: '9x16', label: '9:16', description: '竖版故事' }
  ]

  aboutToAppear(): void {
    this.selectedFormat = this.initialFormat
    this.selectedImageSize = this.initialImageSize
  }

  private isFormatSelected(type: ExportFormatType): boolean {
    return this.selectedFormat === type
  }

  private isSizeSelected(type: ImageSizeType): boolean {
    return this.selectedImageSize === type
  }

  private primaryActionLabel(): string {
    if (this.isExporting) {
      return '正在准备内容...'
    }
    if (this.selectedFormat === 'image') {
      return '生成纪要卡片'
    }
    if (this.selectedFormat === 'video') {
      return '生成会议视频'
    }
    return '导出文本摘要'
  }

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(15, 23, 42, 0.30)')
          .onClick(() => {
            if (!this.isExporting) {
              this.onClose()
            }
          })

        Column({ space: Spacing.lg }) {
          Column()
            .width(40)
            .height(4)
            .borderRadius(2)
            .backgroundColor(Colors.textMuted)
            .margin({ top: Spacing.sm })

          Column({ space: 6 }) {
            Text('EXPORT STUDIO')
              .fontSize(Typography.size.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.primary)
              .letterSpacing(1.6)

            Text('导出会议素材')
              .fontSize(Typography.size.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.textPrimary)

            Text('把当前纪要整理成适合传播的卡片、视频或文本，让内容不只停留在列表里。')
              .fontSize(Typography.size.body)
              .fontColor(Colors.textSecondary)
              .lineHeight(Typography.lineHeight.relaxed)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.subjectTitle.length > 0) {
            Column({ space: 6 }) {
              Text('当前纪要')
                .fontSize(Typography.size.xs)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.textMuted)

              Text(this.subjectTitle)
                .fontSize(Typography.size.bodyLg)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.textPrimary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .width('100%')
            .padding(Spacing.md)
            .backgroundColor('rgba(248, 250, 252, 0.92)')
            .borderRadius(BorderRadius.xl)
          }

          Column({ space: Spacing.md }) {
            ForEach(this.formatOptions, (option: ExportFormatOption) => {
              this.buildFormatOption(option)
            }, (option: ExportFormatOption) => option.type)
          }
          .width('100%')

          if (this.selectedFormat === 'image') {
            Column({ space: Spacing.sm }) {
              Text('图片比例')
                .fontSize(Typography.size.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.textSecondary)
                .alignSelf(ItemAlign.Start)

              Row({ space: Spacing.card.medium }) {
                ForEach(this.imageSizeOptions, (option: ImageSizeOption) => {
                  this.buildSizeOption(option)
                }, (option: ImageSizeOption) => option.type)
              }
              .width('100%')
            }
            .width('100%')
          }

          Button(this.primaryActionLabel())
            .width('100%')
            .height(50)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor(Colors.primary)
            .borderRadius(BorderRadius.xxl)
            .enabled(!this.isExporting)
            .onClick(() => {
              this.handleExport()
            })

          Button('取消')
            .width('100%')
            .height(44)
            .fontSize(Typography.size.body)
            .fontColor(Colors.textSecondary)
            .backgroundColor('rgba(255, 255, 255, 0.72)')
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              if (!this.isExporting) {
                this.onClose()
              }
            })
            .margin({ bottom: Spacing.sm })
        }
        .width('100%')
        .padding({
          left: Spacing.page.horizontal,
          right: Spacing.page.horizontal,
          bottom: Spacing.page.vertical + 20
        })
        .backgroundColor(Colors.background)
        .borderRadius({
          topLeft: BorderRadius.xxl2,
          topRight: BorderRadius.xxl2,
          bottomLeft: 0,
          bottomRight: 0
        })
        .shadow({
          radius: 24,
          color: 'rgba(15, 23, 42, 0.12)',
          offsetX: 0,
          offsetY: -6
        })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private buildFormatOption(option: ExportFormatOption) {
    Row({ space: Spacing.md }) {
      Column({ space: 4 }) {
        Text(option.order)
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(option.tint)

        Text(option.title)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)

        Text(option.description)
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textMuted)
          .lineHeight(Typography.lineHeight.normal)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.isFormatSelected(option.type) ? '已选' : '选择')
        .fontSize(Typography.size.xs)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isFormatSelected(option.type) ? option.tint : Colors.textMuted)
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor(this.isFormatSelected(option.type) ? option.tone : 'rgba(255, 255, 255, 0.74)')
    .borderRadius(BorderRadius.xl)
    .border({
      width: this.isFormatSelected(option.type) ? 1.5 : 1,
      color: this.isFormatSelected(option.type) ? option.tint : Colors.borderLight,
      radius: BorderRadius.xl
    })
    .onClick(() => {
      this.selectedFormat = option.type
    })
  }

  @Builder
  private buildSizeOption(option: ImageSizeOption) {
    Column({ space: Spacing.xs }) {
      Text(option.label)
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isSizeSelected(option.type) ? Colors.primary : Colors.textSecondary)

      Text(option.description)
        .fontSize(Typography.size.xs)
        .fontColor(Colors.textMuted)
    }
    .layoutWeight(1)
    .padding(Spacing.md)
    .backgroundColor(this.isSizeSelected(option.type) ? 'rgba(99, 102, 241, 0.10)' : 'rgba(255, 255, 255, 0.72)')
    .borderRadius(BorderRadius.lg)
    .border({
      width: this.isSizeSelected(option.type) ? 1.5 : 1,
      color: this.isSizeSelected(option.type) ? Colors.primary : Colors.borderLight,
      radius: BorderRadius.lg
    })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.selectedImageSize = option.type
    })
  }

  private handleExport(): void {
    this.isExporting = true
    setTimeout(() => {
      if (this.selectedFormat === 'image') {
        this.onExportImage(this.selectedImageSize)
      } else if (this.selectedFormat === 'video') {
        this.onExportVideo()
      } else {
        this.onExportText()
      }

      this.isExporting = false
      this.onClose()
    }, 300)
  }
}

@Component
export struct ExportSuccessToast {
  @Prop isVisible: boolean = false
  @Prop message: string = '导出成功'

  build() {
    if (this.isVisible) {
      Column({ space: Spacing.md }) {
        Text('完成')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Text(this.message)
          .fontSize(Typography.size.body)
          .fontColor('#FFFFFF')
      }
      .width(180)
      .padding(Spacing.xl)
      .backgroundColor('rgba(15, 23, 42, 0.82)')
      .borderRadius(BorderRadius.xxl)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }
}
