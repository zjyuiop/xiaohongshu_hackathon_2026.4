import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { PersonaSpec, PresetProfile, ProfileBundle, WorkbenchPickBrief } from '../common/Models'
import { buildMeetingRouteParams, MeetingSelectionState } from '../common/MeetingSelection'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'

const SLOT_COUNT: number = 3
const FALLBACK_SAFE_TOP_VP: number = 52
const PAN_DROP_DOWN_VP: number = 56
const PAN_DROP_UP_VP: number = -56

interface FusionPick {
  agentId: string
  displayName: string
  stageLabel: string
  personId: string
  profileName: string
  profileId: string
}

function newEmptyPick(): FusionPick {
  return {
    agentId: '',
    displayName: '',
    stageLabel: '',
    personId: '',
    profileName: '',
    profileId: ''
  }
}

@Entry
@Component
struct FusionWorkbench {
  @State upperSlots: FusionPick[] = []
  @State lowerSlots: FusionPick[] = []
  @State workbench: FusionPick[] = []
  @State pendingFromSlot: FusionPick | null = null
  @State pendingSlotKey: string = ''
  @State showPicker: boolean = false
  @State pickerPresets: PresetProfile[] = []
  @State pickerExpandedProfileId: string = ''
  @State pickerExpandedBundle: ProfileBundle | null = null
  @State pickerLoadingProfileId: string = ''
  @State pickerNotice: string = ''
  @State pickIsUpper: boolean = true
  @State pickSlotIndex: number = 0
  @State pickMode: string = 'slot'
  @State fusionLeft: FusionPick = newEmptyPick()
  @State fusionRight: FusionPick = newEmptyPick()
  @State fusionOutput: FusionPick = newEmptyPick()
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State panningKey: string = ''
  @State panOffsetY: number = 0
  @State fuseHint: string = ''

  aboutToAppear(): void {
    this.loadSafeInsets()
    this.initSlots()
    void this.loadPickerPresets()
  }

  initSlots(): void {
    if (this.upperSlots.length !== SLOT_COUNT) {
      let u: FusionPick[] = []
      for (let i = 0; i < SLOT_COUNT; i++) {
        u.push(newEmptyPick())
      }
      this.upperSlots = u
    }
    if (this.lowerSlots.length !== SLOT_COUNT) {
      let l: FusionPick[] = []
      for (let i = 0; i < SLOT_COUNT; i++) {
        l.push(newEmptyPick())
      }
      this.lowerSlots = l
    }
  }

  loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_error) {
    }
  }

  topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  isEmptyPick(p: FusionPick): boolean {
    return p.agentId.length === 0
  }

  slotKey(isUpper: boolean, index: number): string {
    return (isUpper ? 'u' : 'l') + `${index}`
  }

  async loadPickerPresets(): Promise<void> {
    try {
      this.pickerPresets = await PersonaApi.getPresets()
    } catch (_error) {
      this.pickerNotice = '加载角色列表失败'
    }
  }

  openSlotPicker(isUpper: boolean, index: number): void {
    this.initSlots()
    this.pickMode = 'slot'
    this.pickIsUpper = isUpper
    this.pickSlotIndex = index
    this.pickerNotice = ''
    this.showPicker = true
    if (this.pickerPresets.length === 0) {
      void this.loadPickerPresets()
    }
  }

  openFusionOperandPicker(isLeft: boolean): void {
    this.pickMode = isLeft ? 'fuseL' : 'fuseR'
    this.pickerNotice = ''
    this.showPicker = true
    if (this.pickerPresets.length === 0) {
      void this.loadPickerPresets()
    }
  }

  closePicker(): void {
    this.showPicker = false
    this.pickerExpandedProfileId = ''
    this.pickerExpandedBundle = null
    this.pickerLoadingProfileId = ''
    this.pickerNotice = ''
    this.pickMode = 'slot'
  }

  async expandPickerProfile(profile: PresetProfile): Promise<void> {
    this.pickerNotice = ''
    if (this.pickerExpandedProfileId === profile.id) {
      if (this.pickerLoadingProfileId === profile.id) {
        return
      }
      this.pickerExpandedProfileId = ''
      this.pickerExpandedBundle = null
      return
    }
    this.pickerExpandedProfileId = profile.id
    this.pickerExpandedBundle = null
    this.pickerLoadingProfileId = profile.id
    try {
      const bundle = await PersonaApi.getProfileBundle(profile.id)
      if (this.pickerExpandedProfileId !== profile.id) {
        return
      }
      this.pickerExpandedBundle = bundle
      if (bundle.agents.length === 1) {
        this.applyPickerAgent(bundle, bundle.agents[0])
      }
    } catch (_error) {
      if (this.pickerExpandedProfileId === profile.id) {
        this.pickerNotice = '该角色暂时无法加载'
        this.pickerExpandedProfileId = ''
        this.pickerExpandedBundle = null
      }
    } finally {
      if (this.pickerLoadingProfileId === profile.id) {
        this.pickerLoadingProfileId = ''
      }
    }
  }

  recomputeFusionOutput(): void {
    if (this.isEmptyPick(this.fusionLeft) || this.isEmptyPick(this.fusionRight)) {
      this.fusionOutput = newEmptyPick()
      return
    }
    const left = this.fusionLeft
    const right = this.fusionRight
    const lLabel = left.stageLabel.length > 0 ? left.stageLabel : left.displayName
    const rLabel = right.stageLabel.length > 0 ? right.stageLabel : right.displayName
    this.fusionOutput = {
      agentId: `fused-${Date.now()}`,
      displayName: '融合人格',
      stageLabel: `${lLabel} + ${rLabel}`,
      personId: 'fused-local',
      profileName: '新人格',
      profileId: ''
    }
  }

  applyPickerAgent(bundle: ProfileBundle, agent: PersonaSpec): void {
    const pick: FusionPick = {
      agentId: agent.agentId,
      displayName: agent.displayName,
      stageLabel: agent.stageLabel,
      personId: agent.personId,
      profileName: bundle.profile.displayName,
      profileId: bundle.profile.id
    }
    if (this.pickMode === 'fuseL') {
      this.fusionLeft = pick
      this.recomputeFusionOutput()
    } else if (this.pickMode === 'fuseR') {
      this.fusionRight = pick
      this.recomputeFusionOutput()
    } else {
      if (this.pickIsUpper) {
        const next = this.upperSlots.slice()
        next[this.pickSlotIndex] = pick
        this.upperSlots = next
      } else {
        const next = this.lowerSlots.slice()
        next[this.pickSlotIndex] = pick
        this.lowerSlots = next
      }
    }
    this.closePicker()
  }

  pickerTitle(): string {
    if (this.pickMode === 'fuseL') {
      return '选择左侧融合素材'
    }
    if (this.pickMode === 'fuseR') {
      return '选择右侧融合素材'
    }
    return '选择人格到圆位'
  }

  presetInitial(profile: PresetProfile): string {
    const name = profile.displayName.trim()
    return name.length > 0 ? name.charAt(0) : '?'
  }

  tapFilledSlot(key: string, pick: FusionPick): void {
    if (this.isEmptyPick(pick)) {
      return
    }
    this.pendingFromSlot = pick
    this.pendingSlotKey = key
    this.fuseHint = '已选中人格：拖入下方「工作台」或点击工作台空白处放置。'
  }

  tryDropOnWorkbench(): void {
    if (this.pendingFromSlot === null) {
      return
    }
    if (this.workbench.length >= 5) {
      this.fuseHint = '工作台已满，请先点「确定」或清空。'
      return
    }
    this.workbench = [...this.workbench, this.pendingFromSlot]
    this.clearSlotByKey(this.pendingSlotKey)
    this.pendingFromSlot = null
    this.pendingSlotKey = ''
    this.fuseHint = '已放入工作台。可继续从圆位或融合结果拖入。'
  }

  clearSlotByKey(key: string): void {
    const empty = newEmptyPick()
    if (key.startsWith('u')) {
      const idx = Number.parseInt(key.substring(1), 10)
      const next = this.upperSlots.slice()
      next[idx] = empty
      this.upperSlots = next
    } else if (key.startsWith('l')) {
      const idx = Number.parseInt(key.substring(1), 10)
      const next = this.lowerSlots.slice()
      next[idx] = empty
      this.lowerSlots = next
    } else if (key === 'fuseOut') {
      this.fusionOutput = newEmptyPick()
      if (!this.isEmptyPick(this.fusionLeft) && !this.isEmptyPick(this.fusionRight)) {
        this.recomputeFusionOutput()
      }
    }
  }

  clearFusionOperands(): void {
    this.fusionLeft = newEmptyPick()
    this.fusionRight = newEmptyPick()
    this.fusionOutput = newEmptyPick()
    this.fuseHint = '已清空融合素材。'
  }

  confirmWorkbench(): void {
    if (this.workbench.length === 0) {
      this.fuseHint = '工作台为空，请先拖入人格后再点确定。'
      return
    }

    const briefs: WorkbenchPickBrief[] = []
    const profileIds: string[] = []
    const selectedAgentIds: string[] = []

    for (let i = 0; i < this.workbench.length; i++) {
      const p = this.workbench[i]
      if (this.isEmptyPick(p)) {
        continue
      }
      briefs.push({
        profileName: p.profileName.length > 0 ? p.profileName : p.displayName,
        stageLabel: p.stageLabel,
        agentId: p.agentId,
        displayName: p.displayName
      })
      if (p.personId === 'fused-local' || p.agentId.indexOf('fused-') === 0) {
        continue
      }
      if (p.agentId.length === 0) {
        continue
      }
      selectedAgentIds.push(p.agentId)
      const pid = p.profileId.length > 0 ? p.profileId : p.personId
      if (pid.length > 0 && profileIds.indexOf(pid) < 0) {
        profileIds.push(pid)
      }
    }

    if (briefs.length === 0) {
      this.fuseHint = '工作台无有效人格，请先拖入人格后再点确定。'
      return
    }

    const selection: MeetingSelectionState = {
      profileIds: profileIds,
      selectedAgentIds: selectedAgentIds
    }

    router.pushUrl({
      url: 'pages/SmartQuestionPrep',
      params: buildMeetingRouteParams(selection, {
        workbenchJson: encodeURIComponent(JSON.stringify(briefs))
      })
    })
  }

  clearWorkbench(): void {
    this.workbench = []
    this.pendingFromSlot = null
    this.pendingSlotKey = ''
    this.fuseHint = '工作台已清空。'
  }

  openExploreLibrary(): void {
    router.pushUrl({ url: 'pages/ExplorePersonas' })
  }

  tryPanDropToWorkbench(isUpperRow: boolean, key: string, pick: FusionPick): void {
    const y = this.panOffsetY
    const towardBench =
      (isUpperRow && y > PAN_DROP_DOWN_VP) ||
      (!isUpperRow && y < PAN_DROP_UP_VP)
    if (towardBench) {
      this.pendingFromSlot = pick
      this.pendingSlotKey = key
      this.tryDropOnWorkbench()
    }
    this.panOffsetY = 0
    this.panningKey = ''
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (!this.showPicker) {
        Scroll() {
          Column() {
            Row({ space: Spacing.sm }) {
              Button() {
                Text('<')
                  .fontSize(20)
                  .fontColor(MintColors.mintDark)
              }
              .width(38)
              .height(38)
              .backgroundColor(MintColors.surfaceGlass)
              .borderRadius(19)
              .onClick(() => {
                router.back()
              })

              Text('人格融合台')
                .fontSize(Typography.size.bodyLg)
                .fontWeight(FontWeight.Medium)
                .fontColor(MintColors.textPrimary)
                .layoutWeight(1)

              Button('角色库')
                .height(36)
                .fontSize(Typography.size.caption)
                .fontColor(MintColors.mintDark)
                .backgroundColor(MintColors.mintBg)
                .borderRadius(BorderRadius.xxl)
                .onClick(() => {
                  this.openExploreLibrary()
                })
            }
            .width('100%')
            .padding({
              left: Spacing.page.horizontal,
              right: Spacing.page.horizontal,
              top: this.topInsetVp() + 8,
              bottom: Spacing.sm
            })

            Text('上/下圆位点 + 添加人格；融合条选左右素材自动生成新人格，可拖入工作台；下排圆位向上拖入工作台。')
              .fontSize(Typography.size.xs)
              .fontColor(MintColors.textMuted)
              .padding({
                left: Spacing.page.horizontal,
                right: Spacing.page.horizontal,
                bottom: Spacing.sm
              })

            this.buildSlotRow(true)
            this.buildFusionBar()
            this.buildWorkbenchCard()
            Column() {
              this.buildSlotRow(false)
            }
            .width('100%')
            .zIndex(10)
          }
          .width('100%')
          .padding({ bottom: this.safeBottomVp + Spacing.xl })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor(MintColors.background)
      }

      if (this.showPicker) {
        this.buildPickerOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }

  @Builder
  buildFusionBar() {
    Column({ space: Spacing.sm }) {
      Text('融合配方')
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textMuted)
        .width('100%')

      Row({ space: Spacing.xs }) {
        this.buildFusionOperand(true)
        Text('+')
          .fontSize(18)
          .fontColor(MintColors.textMuted)
        this.buildFusionOperand(false)
        Text('=')
          .fontSize(18)
          .fontColor(MintColors.textMuted)
        this.buildFusionOutputCircle()
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)
      .padding(Spacing.md)
      .backgroundColor(MintColors.surfaceGlass)
      .borderRadius(BorderRadius.xxl)
      .margin({
        left: Spacing.page.horizontal,
        right: Spacing.page.horizontal,
        bottom: Spacing.sm
      })

      Row({ space: Spacing.sm }) {
        Button('重新合成')
          .height(34)
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.mintDark)
          .backgroundColor(MintColors.mintBg)
          .borderRadius(BorderRadius.lg)
          .enabled(!this.isEmptyPick(this.fusionLeft) && !this.isEmptyPick(this.fusionRight))
          .onClick(() => {
            this.recomputeFusionOutput()
            this.fuseHint = '已根据左右素材更新融合结果，可拖入工作台。'
          })

        Button('清空融合素材')
          .height(34)
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.error)
          .backgroundColor('rgba(224, 120, 128, 0.08)')
          .borderRadius(BorderRadius.lg)
          .onClick(() => {
            this.clearFusionOperands()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: Spacing.sm })
    }
    .width('100%')
  }

  @Builder
  buildFusionOperand(isLeft: boolean) {
    Column({ space: 4 }) {
      if (isLeft ? this.isEmptyPick(this.fusionLeft) : this.isEmptyPick(this.fusionRight)) {
        Column() {
          Text('+')
            .fontSize(22)
            .fontColor(MintColors.textMuted)
        }
        .width(52)
        .height(52)
        .borderRadius(26)
        .border({
          width: 2,
          color: MintColors.border,
          radius: 26,
          style: BorderStyle.Dashed
        })
        .backgroundColor('#FFFFFF')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.openFusionOperandPicker(isLeft)
        })
      } else {
        Column({ space: 2 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(52)
              .height(52)
              .borderRadius(26)
              .backgroundColor(MintColors.lavenderDark)

            Text((isLeft ? this.fusionLeft.profileName : this.fusionRight.profileName).charAt(0))
              .fontSize(Typography.size.body)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .onClick(() => {
            this.openFusionOperandPicker(isLeft)
          })

          Text((isLeft ? this.fusionLeft.stageLabel : this.fusionRight.stageLabel))
            .fontSize(10)
            .fontColor(MintColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(56)
            .textAlign(TextAlign.Center)
        }
        .width(60)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width(64)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildFusionOutputCircle() {
    Column({ space: 4 }) {
      if (this.isEmptyPick(this.fusionOutput)) {
        Column() {
          Text('#')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textMuted)
        }
        .width(52)
        .height(52)
        .borderRadius(26)
        .border({
          width: 2,
          color: MintColors.borderLight,
          radius: 26
        })
        .backgroundColor('#FFFFFF')
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 2 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(52)
              .height(52)
              .borderRadius(26)
              .backgroundColor(MintColors.mint)

            Text(this.fusionOutput.profileName.length > 0 ? this.fusionOutput.profileName.charAt(0) : '#')
              .fontSize(Typography.size.body)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .translate({
            x: 0,
            y: this.panningKey === 'fuseOut' ? this.panOffsetY : 0
          })
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionStart(() => {
                this.panningKey = 'fuseOut'
                this.panOffsetY = 0
              })
              .onActionUpdate((event: GestureEvent) => {
                this.panOffsetY = event.offsetY
              })
              .onActionEnd(() => {
                if (this.panningKey === 'fuseOut' && this.panOffsetY > PAN_DROP_DOWN_VP) {
                  this.pendingFromSlot = this.fusionOutput
                  this.pendingSlotKey = 'fuseOut'
                  this.tryDropOnWorkbench()
                }
                this.panOffsetY = 0
                this.panningKey = ''
              })
          )

          Text(this.fusionOutput.stageLabel)
            .fontSize(10)
            .fontColor(MintColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(64)
            .textAlign(TextAlign.Center)
        }
        .width(68)
        .onClick(() => {
          if (!this.isEmptyPick(this.fusionOutput)) {
            this.tapFilledSlot('fuseOut', this.fusionOutput)
          }
        })
      }
    }
    .width(72)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildWorkbenchCard() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column({ space: Spacing.sm }) {
          Text('工作台')
            .fontSize(Typography.size.xl)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)
            .width('100%')

          Column({ space: Spacing.xs }) {
            if (this.workbench.length === 0) {
              Text(this.pendingFromSlot !== null ? '点击此处放置选中的人格' : '将圆位或融合结果拖入此区域')
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textMuted)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 24, bottom: 48 })
            } else {
              ForEach(this.workbench, (p: FusionPick) => {
                Text(`${p.profileName} · ${p.stageLabel}`)
                  .fontSize(Typography.size.caption)
                  .fontColor(MintColors.textPrimary)
                  .width('100%')
                  .padding(Spacing.sm)
                  .backgroundColor('rgba(255, 255, 255, 0.65)')
                  .borderRadius(BorderRadius.lg)
              }, (p: FusionPick, idx: number) => `${p.agentId}-${idx}`)
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 120 })
          .justifyContent(this.workbench.length === 0 ? FlexAlign.Center : FlexAlign.Start)
          .onClick(() => {
            this.tryDropOnWorkbench()
          })

          Row({ space: Spacing.sm }) {
            Button('清空工作台')
              .layoutWeight(1)
              .height(36)
              .fontSize(Typography.size.xs)
              .fontColor(MintColors.error)
              .backgroundColor('rgba(224, 120, 128, 0.1)')
              .borderRadius(BorderRadius.lg)
              .onClick(() => {
                this.clearWorkbench()
              })
          }
          .width('100%')
          .padding({ right: 96, bottom: 4 })
        }
        .width('100%')
        .constraintSize({ minHeight: 220 })
        .padding(Spacing.lg)
        .alignItems(HorizontalAlign.Start)

        Button('确定')
          .height(40)
          .padding({ left: 20, right: 20 })
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.mint)
          .borderRadius(BorderRadius.xxl)
          .margin({ right: Spacing.md, bottom: Spacing.md })
          .onClick(() => {
            this.confirmWorkbench()
          })
      }
      .width('100%')

      if (this.fuseHint.length > 0) {
        Text(this.fuseHint)
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.mintDark)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({
            left: Spacing.md,
            right: Spacing.md,
            bottom: Spacing.sm
          })
      }
    }
    .width('100%')
    .margin({
      left: Spacing.page.horizontal,
      right: Spacing.page.horizontal,
      top: Spacing.sm,
      bottom: Spacing.md
    })
    .backgroundColor('rgba(78, 205, 196, 0.12)')
    .borderRadius(BorderRadius.xxl3)
    .border({
      width: this.pendingFromSlot !== null ? 2 : 1,
      color: this.pendingFromSlot !== null ? MintColors.mint : MintColors.borderLight,
      radius: BorderRadius.xxl3
    })
    .clip(true)
  }

  @Builder
  buildSlotRow(isUpper: boolean) {
    Row({ space: Spacing.md }) {
      ForEach(isUpper ? this.upperSlots : this.lowerSlots, (pick: FusionPick, index: number) => {
        this.buildOneSlot(isUpper, index, pick)
      }, (_pick: FusionPick, index: number) => (isUpper ? 'u' : 'l') + `${index}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({
      left: Spacing.page.horizontal,
      right: Spacing.page.horizontal,
      top: Spacing.md,
      bottom: Spacing.md
    })
  }

  @Builder
  buildOneSlot(isUpper: boolean, index: number, pick: FusionPick) {
    Column({ space: 6 }) {
      if (this.isEmptyPick(pick)) {
        Button({ type: ButtonType.Normal }) {
          Text('+')
            .fontSize(28)
            .fontColor(MintColors.textMuted)
        }
        .width(64)
        .height(64)
        .padding(0)
        .borderRadius(32)
        .border({
          width: 2,
          color: MintColors.border,
          radius: 32,
          style: BorderStyle.Dashed
        })
        .backgroundColor(MintColors.surfaceGlass)
        .stateEffect(true)
        .onClick(() => {
          this.openSlotPicker(isUpper, index)
        })
      } else {
        Column({ space: 4 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(64)
              .height(64)
              .borderRadius(32)
              .backgroundColor(MintColors.mint)

            Text(pick.profileName.length > 0 ? pick.profileName.charAt(0) : '?')
              .fontSize(Typography.size.subtitle)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .translate({
            x: 0,
            y: this.panningKey === this.slotKey(isUpper, index) ? this.panOffsetY : 0
          })
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionStart(() => {
                this.panningKey = this.slotKey(isUpper, index)
                this.panOffsetY = 0
              })
              .onActionUpdate((event: GestureEvent) => {
                this.panOffsetY = event.offsetY
              })
              .onActionEnd(() => {
                const key = this.slotKey(isUpper, index)
                if (this.panningKey === key) {
                  this.tryPanDropToWorkbench(isUpper, key, pick)
                }
              })
          )

          Text(pick.stageLabel)
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(72)
            .textAlign(TextAlign.Center)
        }
        .width(80)
        .onClick(() => {
          this.tapFilledSlot(this.slotKey(isUpper, index), pick)
        })
      }
    }
    .width(80)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildPickerOverlay() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0, 0, 0, 0.48)')
        .onClick(() => {
          this.closePicker()
        })

      Column({ space: Spacing.md }) {
        Row() {
          Text(this.pickerTitle())
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)
            .layoutWeight(1)

          Button('关闭')
            .height(36)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.mintDark)
            .backgroundColor(MintColors.mintBg)
            .borderRadius(BorderRadius.xxl)
            .onClick(() => {
              this.closePicker()
            })
        }
        .width('100%')

        if (this.pickerNotice.length > 0) {
          Text(this.pickerNotice)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.error)
        }

        Scroll() {
          Column({ space: Spacing.sm }) {
            ForEach(this.pickerPresets, (profile: PresetProfile) => {
              Column({ space: Spacing.xs }) {
                Row({ space: Spacing.sm }) {
                  Stack({ alignContent: Alignment.Center }) {
                    Column()
                      .width(40)
                      .height(40)
                      .borderRadius(20)
                      .backgroundColor(MintColors.mint)

                    Text(this.presetInitial(profile))
                      .fontSize(Typography.size.body)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }

                  Column({ space: 4 }) {
                    Text(profile.displayName)
                      .fontSize(Typography.size.body)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(MintColors.textPrimary)

                    Text(profile.subtitle)
                      .fontSize(Typography.size.xs)
                      .fontColor(MintColors.textMuted)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(this.pickerExpandedProfileId === profile.id ? '▾' : '▸')
                    .fontSize(14)
                    .fontColor(MintColors.textMuted)
                }
                .width('100%')
                .padding(Spacing.md)
                .backgroundColor(MintColors.surfaceGlass)
                .borderRadius(BorderRadius.xxl)
                .onClick(() => {
                  void this.expandPickerProfile(profile)
                })

                if (this.pickerExpandedProfileId === profile.id) {
                  if (this.pickerLoadingProfileId === profile.id) {
                    Text('加载人格中…')
                      .fontSize(Typography.size.caption)
                      .fontColor(MintColors.textMuted)
                      .padding({ left: Spacing.md, bottom: Spacing.sm })
                  } else if (
                    this.pickerExpandedBundle !== null &&
                    this.pickerExpandedBundle.profile.id === profile.id
                  ) {
                    if (this.pickerExpandedBundle.agents.length === 0) {
                      Text('该角色暂无可选阶段')
                        .fontSize(Typography.size.caption)
                        .fontColor(MintColors.textMuted)
                        .padding({ left: Spacing.md, right: Spacing.md, bottom: Spacing.sm })
                    } else {
                      Column({ space: 6 }) {
                        ForEach(this.pickerExpandedBundle.agents, (agent: PersonaSpec, aidx: number) => {
                          Button({ type: ButtonType.Normal }) {
                            Row({ space: Spacing.sm }) {
                              Text(`${agent.stageLabel} · ${agent.timeLabel}`)
                                .fontSize(Typography.size.caption)
                                .fontColor(MintColors.mintDark)
                                .layoutWeight(1)
                                .maxLines(2)
                                .textAlign(TextAlign.Start)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                            }
                            .width('100%')
                            .padding({ left: Spacing.sm, right: Spacing.sm })
                          }
                          .width('100%')
                          .height(48)
                          .padding({ left: Spacing.xs, right: Spacing.xs })
                          .backgroundColor(MintColors.mintBg)
                          .borderRadius(BorderRadius.lg)
                          .stateEffect(true)
                          .onClick(() => {
                            const b = this.pickerExpandedBundle
                            if (b !== null && b.profile.id === profile.id) {
                              this.applyPickerAgent(b, agent)
                            }
                          })
                        }, (agent: PersonaSpec, aidx: number) => `${profile.id}-${agent.agentId}-${aidx}`)
                      }
                      .width('100%')
                      .padding({ left: Spacing.md, right: Spacing.md, bottom: Spacing.sm })
                    }
                  }
                }
              }
              .width('100%')
            }, (profile: PresetProfile) => profile.id)
          }
          .width('100%')
        }
        .width('100%')
        .height(360)
      }
      .width('100%')
      .padding({
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.lg,
        bottom: this.safeBottomVp + Spacing.lg
      })
      .backgroundColor(MintColors.cardPrimary)
      .borderRadius(BorderRadius.xxl3)
    }
    .width('100%')
    .height('100%')
    .zIndex(2000)
  }
}
