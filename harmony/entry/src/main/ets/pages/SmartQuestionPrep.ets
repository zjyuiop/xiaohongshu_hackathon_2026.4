import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { RouteParams, WorkbenchPickBrief } from '../common/Models'
import { buildMeetingRouteParams, MeetingSelectionState, parseMeetingSelection } from '../common/MeetingSelection'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import { AnimationDuration, AnimationCurve } from '../common/styles/Animation'

const FALLBACK_SAFE_TOP_VP: number = 52

function parseWorkbenchJson(raw?: string): WorkbenchPickBrief[] {
  if (raw === undefined || raw.length === 0) {
    return []
  }
  try {
    const decoded = decodeURIComponent(raw)
    const parsed = JSON.parse(decoded) as Object
    if (Array.isArray(parsed)) {
      return parsed as WorkbenchPickBrief[]
    }
  } catch (_e) {
  }
  return []
}

function primaryLabel(b: WorkbenchPickBrief): string {
  if (b.stageLabel.length > 0) {
    return b.stageLabel
  }
  if (b.profileName.length > 0) {
    return b.profileName
  }
  return b.displayName.length > 0 ? b.displayName : '辩手'
}

function labelAt(briefs: WorkbenchPickBrief[], index: number): string {
  if (briefs.length > index) {
    return primaryLabel(briefs[index])
  }
  return index === 0 ? '角色甲' : '角色乙'
}

function buildScenarioPrompts(briefs: WorkbenchPickBrief[]): string[] {
  const a = labelAt(briefs, 0)
  const b = briefs.length > 1 ? labelAt(briefs, 1) : '另一位辩手'
  const names = briefs.map((x) => primaryLabel(x)).join('、')

  return [
    `若「${a}」与「${b}」同在一场闭门策略会，两人最先会争论什么？`,
    `设定一场跨界对谈的开场：主持人应如何同时接住「${a}」与「${b}」的叙事？`,
    `两人面对「短期业绩 vs 长期信念」冲突时，各自会如何表态？`,
    `想象他们共同评审一个创业项目：分歧最可能出现在哪一环？`,
    `若必须合作完成一项高难度任务，谁更适合牵头？为什么？`,
    `用电影镜头描述：两人在雨夜咖啡馆相遇，第一句话会是什么？`,
    `一场公开辩论，观众最想先听他们交锋的议题是什么？`,
    `与当前人格相关的综合情景：${names} — 若在同一屋檐下过夜讨论，凌晨三点会聊到什么？`
  ]
}

function buildQuestionPrompts(briefs: WorkbenchPickBrief[]): string[] {
  const a = labelAt(briefs, 0)
  const b = briefs.length > 1 ? labelAt(briefs, 1) : '另一位辩手'

  return [
    `用「${a}」的思维，会如何质疑「${b}」最近一次公开表态？`,
    `「${a}」所坚持的底层原则，在「${b}」的语境里是否必然成立？`,
    `批判性审视：若去掉「${a}」的光环，其核心论点还剩什么？`,
    `「${b}」的决策链条里，哪一环最经不起「${a}」式追问？`,
    `两人对「风险」与「机会」的定义有何根本不同？`,
    `若让「${a}」向「${b}」提一个无法回避的问题，会是什么？`,
    `从第三方视角：在「${a}」与「${b}」的叙事中，哪一个更容易被证伪？`,
    `在什么条件下，你会认为「${b}」比「${a}」更接近真相？`
  ]
}

@Entry
@Component
struct SmartQuestionPrep {
  @State briefs: WorkbenchPickBrief[] = []
  @State prepMode: string = 'scenario'
  @State questionText: string = ''
  @State smartChips: string[] = []
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State meetingSelection: MeetingSelectionState = { profileIds: [], selectedAgentIds: [] }
  @State contentOpacity: number = 0
  @State contentTranslateY: number = 18

  aboutToAppear(): void {
    this.loadSafeInsets()
    const rawParams = router.getParams()
    const params: RouteParams = rawParams ? rawParams as RouteParams : {}
    this.meetingSelection = parseMeetingSelection(params)
    this.briefs = parseWorkbenchJson(params.workbenchJson)
    this.refreshChips()
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.contentOpacity = 1
        this.contentTranslateY = 0
      })
    }, 56)
  }

  loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_e) {
    }
  }

  topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  refreshChips(): void {
    if (this.briefs.length === 0) {
      this.smartChips = []
      return
    }
    if (this.prepMode === 'scenario') {
      this.smartChips = buildScenarioPrompts(this.briefs)
    } else {
      this.smartChips = buildQuestionPrompts(this.briefs)
    }
  }

  setMode(mode: string): void {
    this.prepMode = mode
    this.refreshChips()
  }

  applyChip(text: string): void {
    this.questionText = text
  }

  goMeeting(): void {
    if (this.meetingSelection.selectedAgentIds.length === 0) {
      return
    }
    const raw = this.questionText.trim()
    const topicToSend =
      raw.length > 0 ? raw : '就当前人格组合，请围绕议题正面交锋，允许反驳与争执。'
    router.pushUrl({
      url: 'pages/MeetingChatPage',
      params: buildMeetingRouteParams(this.meetingSelection, {
        topic: encodeURIComponent(topicToSend)
      })
    })
  }

  build() {
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
        .stateEffect(true)
        .onClick(() => {
          router.back()
        })

        Text('议题智问')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: Spacing.page.horizontal,
        right: Spacing.page.horizontal,
        top: this.topInsetVp() + 8,
        bottom: Spacing.sm
      })

      Scroll() {
        Column({ space: Spacing.lg }) {
          Text('根据融合台工作台人格，选择生成方式；可在「问题框」自行输入，或点选下方智问。')
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textMuted)
            .width('100%')
            .lineHeight(18)

          Row({ space: Spacing.sm }) {
            Button('场景式')
              .layoutWeight(1)
              .height(44)
              .fontSize(Typography.size.body)
              .fontColor(this.prepMode === 'scenario' ? '#FFFFFF' : MintColors.mintDark)
              .backgroundColor(this.prepMode === 'scenario' ? MintColors.mint : MintColors.surfaceGlass)
              .borderRadius(BorderRadius.xxl)
              .border({
                width: this.prepMode === 'scenario' ? 0 : 0.5,
                color: MintColors.border,
                radius: BorderRadius.xxl
              })
              .stateEffect(true)
              .onClick(() => {
                this.setMode('scenario')
              })

            Button('提问式')
              .layoutWeight(1)
              .height(44)
              .fontSize(Typography.size.body)
              .fontColor(this.prepMode === 'question' ? '#FFFFFF' : MintColors.mintDark)
              .backgroundColor(this.prepMode === 'question' ? MintColors.mint : MintColors.surfaceGlass)
              .borderRadius(BorderRadius.xxl)
              .border({
                width: this.prepMode === 'question' ? 0 : 0.5,
                color: MintColors.border,
                radius: BorderRadius.xxl
              })
              .stateEffect(true)
              .onClick(() => {
                this.setMode('question')
              })
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('问题框')
              .fontSize(Typography.size.xs)
              .fontColor(MintColors.textMuted)
              .width('100%')

            TextArea({
              text: this.questionText,
              placeholder: '在此输入你想让辩手讨论的问题，也可点下方「智问」一键填入。'
            })
              .width('100%')
              .height(120)
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textPrimary)
              .placeholderColor(MintColors.textPlaceholder)
              .backgroundColor(MintColors.backgroundSecondary)
              .borderRadius(BorderRadius.xxl)
              .padding(Spacing.lg)
              .onChange((value: string) => {
                this.questionText = value
              })
          }
          .width('100%')

          Column({ space: Spacing.sm }) {
            Row({ space: 6 }) {
              Text('智问')
                .fontSize(Typography.size.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(MintColors.textPrimary)
              Text('：')
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textMuted)
              Text(this.prepMode === 'scenario' ? '故事情景' : '批判性问题')
                .fontSize(Typography.size.caption)
                .fontColor(MintColors.mintDark)
            }
            .width('100%')

            if (this.briefs.length === 0) {
              Text('未收到人格数据，请返回融合台重新确定。')
                .fontSize(Typography.size.caption)
                .fontColor(MintColors.error)
                .width('100%')
            } else if (this.smartChips.length === 0) {
              Text('暂无智问，请切换模式。')
                .fontSize(Typography.size.caption)
                .fontColor(MintColors.textMuted)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.smartChips, (line: string, idx: number) => {
                  Text(line)
                    .fontSize(Typography.size.xs)
                    .fontColor(MintColors.mintDark)
                    .padding({
                      left: Spacing.sm,
                      right: Spacing.sm,
                      top: 8,
                      bottom: 8
                    })
                    .margin({ right: Spacing.xs, bottom: Spacing.xs })
                    .backgroundColor(MintColors.mintBg)
                    .borderRadius(BorderRadius.pill)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '48%' })
                    .onClick(() => {
                      this.applyChip(line)
                    })
                }, (line: string, idx: number) => `chip-${idx}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(Spacing.lg)
          .backgroundColor(MintColors.cardPrimary)
          .borderRadius(BorderRadius.xxl3)
          .border({
            width: 0.5,
            color: MintColors.borderLight,
            radius: BorderRadius.xxl3
          })

          if (this.meetingSelection.selectedAgentIds.length > 0) {
            Button('进入圆盘辩论场')
              .width('100%')
              .height(48)
              .fontSize(Typography.size.body)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .backgroundColor(MintColors.mint)
              .borderRadius(BorderRadius.xxl)
              .stateEffect(true)
              .onClick(() => {
                this.goMeeting()
              })
          } else {
            Text('当前工作台为人格预览或融合标签，无法直接进入辩论场；仍可在此整理议题。')
              .fontSize(Typography.size.xs)
              .fontColor(MintColors.textMuted)
              .width('100%')
          }
        }
        .width('100%')
        .padding({
          left: Spacing.page.horizontal,
          right: Spacing.page.horizontal,
          top: Spacing.sm,
          bottom: this.safeBottomVp + Spacing.xl
        })
        .opacity(this.contentOpacity)
        .translate({ y: this.contentTranslateY })
        .animation({
          duration: AnimationDuration.slow,
          curve: AnimationCurve.emphasized
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }
}
