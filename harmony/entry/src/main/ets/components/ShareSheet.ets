import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { ShareData } from '../common/Models'

export interface ShareTarget {
  id: string
  name: string
  monogram: string
  subtitle: string
  type: 'social' | 'device' | 'system'
  available: boolean
  tone: string
  tint: string
}

export interface ShareSheetProps {
  isVisible: boolean
  shareData: ShareData
  onClose: () => void
  onShareToSocial: (targetId: string) => void
  onHapShare: () => void
  onDeviceShare: (deviceId: string) => void
  onSystemShare: () => void
  onCopyLink: () => void
}

@Component
export struct ShareSheet {
  @Prop isVisible: boolean = false
  @Prop shareData: ShareData = {
    title: '',
    description: '',
    content: '',
    tags: []
  }

  onClose: () => void = () => {}
  onShareToSocial: (targetId: string) => void = () => {}
  onHapShare: () => void = () => {}
  onDeviceShare: (deviceId: string) => void = () => {}
  onSystemShare: () => void = () => {}
  onCopyLink: () => void = () => {}

  private readonly socialTargets: ShareTarget[] = [
    {
      id: 'wechat',
      name: '微信',
      monogram: '微',
      subtitle: '发给联系人',
      type: 'social',
      available: true,
      tone: 'rgba(16, 185, 129, 0.10)',
      tint: '#10B981'
    },
    {
      id: 'xiaohongshu',
      name: '小红书',
      monogram: '书',
      subtitle: '适合卡片分享',
      type: 'social',
      available: true,
      tone: 'rgba(244, 63, 94, 0.10)',
      tint: '#F43F5E'
    },
    {
      id: 'weibo',
      name: '微博',
      monogram: '博',
      subtitle: '公开传播',
      type: 'social',
      available: true,
      tone: 'rgba(249, 115, 22, 0.10)',
      tint: '#F97316'
    },
    {
      id: 'system',
      name: '系统分享',
      monogram: '享',
      subtitle: '调用系统面板',
      type: 'system',
      available: true,
      tone: 'rgba(99, 102, 241, 0.10)',
      tint: '#6366F1'
    },
    {
      id: 'copy',
      name: '复制内容',
      monogram: '复',
      subtitle: '复制摘要文本',
      type: 'system',
      available: true,
      tone: 'rgba(148, 163, 184, 0.14)',
      tint: '#475569'
    }
  ]

  private readonly deviceTargets: ShareTarget[] = [
    {
      id: 'tablet',
      name: '平板',
      monogram: '板',
      subtitle: '流转到平板',
      type: 'device',
      available: true,
      tone: 'rgba(14, 165, 233, 0.10)',
      tint: '#0EA5E9'
    },
    {
      id: 'smarttv',
      name: '智慧屏',
      monogram: '屏',
      subtitle: '大屏展示',
      type: 'device',
      available: true,
      tone: 'rgba(168, 85, 247, 0.10)',
      tint: '#A855F7'
    }
  ]

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(15, 23, 42, 0.34)')
          .onClick(() => {
            this.onClose()
          })

        Column({ space: Spacing.lg }) {
          Column()
            .width(40)
            .height(4)
            .borderRadius(2)
            .backgroundColor(Colors.textMuted)
            .margin({ top: Spacing.sm })

          Column({ space: 6 }) {
            Text('SHARE / FLOW')
              .fontSize(Typography.size.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.primary)
              .letterSpacing(1.6)

            Text('分享会议纪要')
              .fontSize(Typography.size.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(Colors.textPrimary)

            Text('可以直接转给朋友，也可以通过附近分享或设备流转，把纪要递到身边的人。')
              .fontSize(Typography.size.body)
              .fontColor(Colors.textSecondary)
              .lineHeight(Typography.lineHeight.relaxed)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          SharePreviewCard({
            title: this.shareData.title,
            description: this.shareData.description.length > 0 ? this.shareData.description : this.shareData.content,
            tags: this.shareData.tags
          })

          this.buildNearFieldSection()
          this.buildSocialSection()
          this.buildDeviceShareSection()

          Button('取消')
            .width('100%')
            .height(46)
            .fontSize(Typography.size.body)
            .fontColor(Colors.textSecondary)
            .backgroundColor('rgba(255, 255, 255, 0.74)')
            .borderRadius(BorderRadius.xxl)
            .margin({ bottom: Spacing.sm })
            .onClick(() => {
              this.onClose()
            })
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
  private buildNearFieldSection() {
    Column({ space: Spacing.md }) {
      Row() {
        Column({ space: 4 }) {
          Text('HUAWEI SHARE')
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F97316')
            .letterSpacing(1.2)

          Text('近场分享')
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textPrimary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('近场更快')
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor('#C2410C')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('rgba(249, 115, 22, 0.12)')
          .borderRadius(BorderRadius.pill)
      }
      .width('100%')

      Text('适合把会议纪要、卡片或视频快速递给身边的华为设备。')
        .fontSize(Typography.size.caption)
        .fontColor(Colors.textSecondary)
        .lineHeight(Typography.lineHeight.normal)
        .width('100%')

      Row({ space: Spacing.md }) {
        this.buildNearFieldButton('碰一碰', '把纪要发给对方设备', true)
        this.buildNearFieldButton('抓一抓', '近场发起分享', false)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor('rgba(249, 115, 22, 0.08)')
    .borderRadius(BorderRadius.xxl)
    .border({
      width: 1,
      color: 'rgba(249, 115, 22, 0.18)',
      radius: BorderRadius.xxl
    })
  }

  @Builder
  private buildNearFieldButton(title: string, description: string, active: boolean) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? '#C2410C' : Colors.textSecondary)

      Text(description)
        .fontSize(Typography.size.xs)
        .fontColor(Colors.textMuted)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .padding({ top: Spacing.md, bottom: Spacing.md, left: Spacing.sm, right: Spacing.sm })
    .backgroundColor(active ? 'rgba(255, 255, 255, 0.76)' : 'rgba(255, 255, 255, 0.44)')
    .borderRadius(BorderRadius.xl)
    .opacity(active ? 1 : 0.7)
    .onClick(() => {
      if (active) {
        this.onHapShare()
      }
    })
  }

  @Builder
  private buildSocialSection() {
    Column({ space: Spacing.md }) {
      Row() {
        Text('常用分享')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)

        Blank()

        Text('卡片 / 文本 / 系统面板')
          .fontSize(Typography.size.xs)
          .fontColor(Colors.textMuted)
      }
      .width('100%')

      Scroll() {
        Row({ space: Spacing.md }) {
          ForEach(this.socialTargets, (target: ShareTarget) => {
            this.buildShareTarget(target)
          }, (target: ShareTarget) => target.id)
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
  }

  @Builder
  private buildShareTarget(target: ShareTarget) {
    Column({ space: 10 }) {
      Column() {
        Text(target.monogram)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(target.tint)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(target.tone)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(target.name)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)

        Text(target.subtitle)
          .fontSize(Typography.size.xs)
          .fontColor(Colors.textMuted)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width(132)
    .padding(Spacing.md)
    .backgroundColor('rgba(255, 255, 255, 0.74)')
    .borderRadius(BorderRadius.xl)
    .border({
      width: 1,
      color: Colors.borderLight,
      radius: BorderRadius.xl
    })
    .opacity(target.available ? 1 : 0.5)
    .enabled(target.available)
    .onClick(() => {
      if (!target.available) {
        return
      }
      if (target.type === 'social') {
        this.onShareToSocial(target.id)
      } else if (target.type === 'system' && target.id === 'copy') {
        this.onCopyLink()
      } else if (target.type === 'system') {
        this.onSystemShare()
      }
    })
  }

  @Builder
  private buildDeviceShareSection() {
    Column({ space: Spacing.md }) {
      Row() {
        Text('设备流转')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)

        Blank()

        Text('流转到平板或大屏')
          .fontSize(Typography.size.xs)
          .fontColor(Colors.textMuted)
      }
      .width('100%')

      Row({ space: Spacing.md }) {
        ForEach(this.deviceTargets, (device: ShareTarget) => {
          this.buildDeviceTarget(device)
        }, (device: ShareTarget) => device.id)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildDeviceTarget(target: ShareTarget) {
    Column({ space: 8 }) {
      Column() {
        Text(target.monogram)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(target.tint)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(target.tone)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(target.name)
        .fontSize(Typography.size.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.textPrimary)

      Text(target.subtitle)
        .fontSize(Typography.size.xs)
        .fontColor(Colors.textMuted)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .padding(Spacing.md)
    .backgroundColor('rgba(255, 255, 255, 0.74)')
    .borderRadius(BorderRadius.xl)
    .border({
      width: 1,
      color: Colors.borderLight,
      radius: BorderRadius.xl
    })
    .enabled(target.available)
    .onClick(() => {
      if (target.available) {
        this.onDeviceShare(target.id)
      }
    })
  }
}

@Component
export struct SharePreviewCard {
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop tags: string[] = []

  build() {
    Column({ space: Spacing.md }) {
      Text(this.title.length > 0 ? this.title : '当前还没有可分享的纪要')
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(Typography.size.body)
          .fontColor(Colors.textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(Typography.lineHeight.relaxed)
      }

      if (this.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags.slice(0, 4), (tag: string) => {
            Text(`#${tag}`)
              .fontSize(Typography.size.xs)
              .fontColor(Colors.primary)
              .padding({ left: Spacing.sm, right: Spacing.sm, top: 4, bottom: 4 })
              .backgroundColor('rgba(99, 102, 241, 0.10)')
              .borderRadius(BorderRadius.pill)
              .margin({ right: Spacing.sm, bottom: Spacing.sm })
          }, (tag: string) => tag)
        }
        .width('100%')
      }

      Row({ space: Spacing.xs }) {
        Column()
          .width(4)
          .height(4)
          .borderRadius(2)
          .backgroundColor(Colors.primary)

        Text('阶段人格会议纪要')
          .fontSize(Typography.size.xs)
          .fontColor(Colors.textMuted)
      }
      .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor('rgba(255, 255, 255, 0.74)')
    .borderRadius(BorderRadius.xl)
    .border({
      width: 1,
      color: Colors.borderLight,
      radius: BorderRadius.xl
    })
  }
}
