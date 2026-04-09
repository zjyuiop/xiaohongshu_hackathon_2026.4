/**
 * 添加人物：从预设列表选择另一个人物加入同一场会议（风格与参会者页一致）
 */
import { router } from '@kit.ArkUI'
import { PersonaApi } from '../service/PersonaApi'
import { PresetProfile } from '../common/Models'
import { MeetingSessionStore } from '../utils/MeetingSessionStore'
import { MintColors } from '../common/styles/MintColors'
import { AnimationDuration, AnimationCurve } from '../common/styles/Animation'

@Entry
@Component
struct MeetingProfilePickerPage {
  @State presets: PresetProfile[] = []
  @State loading: boolean = true
  @State errorMessage: string = ''
  @State bodyOpacity: number = 1
  @State bodyTranslateY: number = 0
  @State pressingPresetId: string = ''

  aboutToAppear(): void {
    this.loadPresets()
  }

  private playListEntrance(): void {
    this.bodyOpacity = 0
    this.bodyTranslateY = 14
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.bodyOpacity = 1
        this.bodyTranslateY = 0
      })
    }, 24)
  }

  private async loadPresets(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      const list = await PersonaApi.getPresets()
      this.presets = list
    } catch (e) {
      this.errorMessage = '加载人物列表失败'
      this.presets = []
    } finally {
      this.loading = false
      if (this.errorMessage.length > 0 || this.presets.length === 0) {
        this.bodyOpacity = 1
        this.bodyTranslateY = 0
      } else {
        this.playListEntrance()
      }
    }
  }

  private isAlreadyAdded(presetId: string): boolean {
    const existing = MeetingSessionStore.getProfileIds()
    return existing.indexOf(presetId) >= 0
  }

  private selectPreset(preset: PresetProfile): void {
    if (this.isAlreadyAdded(preset.id)) {
      return
    }
    MeetingSessionStore.setPendingAddProfileId(preset.id)
    router.back()
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('←')
            .fontSize(20)
            .fontColor(MintColors.textPrimary)
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .stateEffect(true)
        .onClick(() => {
          router.back()
        })

        Text('添加人物')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('')
          .width(40)
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 8 })

      Column() {
        Text('选择要加入讨论的人物')
          .fontSize(14)
          .fontColor(MintColors.textSecondary)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 12 })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(MintColors.mint)
            Text('加载中…')
              .fontSize(14)
              .fontColor(MintColors.textSecondary)
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#DC2626')
            .padding(20)
        } else {
          List({ space: 10 }) {
            ForEach(this.presets, (p: PresetProfile) => {
              ListItem() {
                this.buildPresetRow(p)
              }
            }, (p: PresetProfile) => p.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: 24 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .opacity(this.bodyOpacity)
      .translate({ y: this.bodyTranslateY })
      .animation({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }

  @Builder
  buildPresetRow(preset: PresetProfile) {
    Row() {
      Text(preset.displayName.length > 0 ? preset.displayName.charAt(0) : '?')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .borderRadius(22)
        .textAlign(TextAlign.Center)
        .backgroundColor(MintColors.mint)

      Column() {
        Text(preset.displayName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (preset.subtitle.length > 0) {
          Text(preset.subtitle)
            .fontSize(13)
            .fontColor(MintColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      if (this.isAlreadyAdded(preset.id)) {
        Text('已添加')
          .fontSize(13)
          .fontColor(MintColors.textSecondary)
      } else {
        Text('添加')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.mint)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.isAlreadyAdded(preset.id) ? '#F3F4F6' : MintColors.cardPrimary)
    .borderRadius(16)
    .border({
      width: 1,
      color: MintColors.borderLight
    })
    .opacity(this.isAlreadyAdded(preset.id) ? 0.75 : 1)
    .scale({
      x: this.pressingPresetId === preset.id ? 0.98 : 1,
      y: this.pressingPresetId === preset.id ? 0.98 : 1
    })
    .animation({
      duration: AnimationDuration.fast,
      curve: AnimationCurve.sharp
    })
    .onTouch((event: TouchEvent) => {
      if (this.isAlreadyAdded(preset.id)) {
        return
      }
      if (event.type === TouchType.Down) {
        this.pressingPresetId = preset.id
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressingPresetId = ''
      }
    })
    .onClick(() => {
      this.selectPreset(preset)
    })
  }
}
