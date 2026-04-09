import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { PersonaSpec, PresetProfile, ProfileBundle, RouteParams, TimelineNode, EMPTY_PROFILE } from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { MeetingSessionStore } from '../utils/MeetingSessionStore'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'

const FALLBACK_SAFE_TOP_VP: number = 52
const TIMELINE_TEASER_MAX_CHARS: number = 44

@Entry
@Component
struct ProfileDetail {
  @State profile: PresetProfile = EMPTY_PROFILE
  @State nodes: TimelineNode[] = []
  @State agents: PersonaSpec[] = []
  @State selectedPersonaIds: string[] = []
  @State meetingAgentIds: string[] = []
  @State expandedNodeIds: string[] = []
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State returnToMeeting: boolean = false

  aboutToAppear(): void {
    this.loadSafeInsets()
    const rawParams = router.getParams()
    const params: RouteParams = rawParams ? rawParams as RouteParams : {}
    const profileId = params.profileId ?? MeetingSessionStore.getProfileId() ?? ''
    const routeSelectedAgentIds = params.selectedAgentIds
      ? params.selectedAgentIds.split(',').filter((agentId: string) => agentId.length > 0)
      : []
    this.returnToMeeting = params.returnToMeeting === '1'
    const sessionProfileId = MeetingSessionStore.getProfileId()
    const sessionSelectedAgentIds = this.returnToMeeting && sessionProfileId === profileId
      ? MeetingSessionStore.getSelectedAgents()
      : []
    const initialSelectedAgentIds = routeSelectedAgentIds.length > 0 ? routeSelectedAgentIds : sessionSelectedAgentIds

    if (!profileId.length) {
      return
    }

    PersonaApi.getProfileBundle(profileId).then((bundle: ProfileBundle) => {
      const initialAgentIds = initialSelectedAgentIds.filter((agentId: string) =>
        bundle.agents.some((agent: PersonaSpec) => agent.agentId === agentId)
      )

      this.profile = bundle.profile
      this.nodes = bundle.nodes
      this.agents = bundle.agents
      this.selectedPersonaIds = [...initialAgentIds]
      this.meetingAgentIds = [...initialAgentIds]
      this.expandedNodeIds = []
    }).catch(() => {})
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

  isTimelineNodeExpanded(nodeId: string): boolean {
    return this.expandedNodeIds.includes(nodeId)
  }

  toggleTimelineNode(nodeId: string): void {
    if (this.expandedNodeIds.includes(nodeId)) {
      this.expandedNodeIds = this.expandedNodeIds.filter((id: string) => id !== nodeId)
      return
    }

    this.expandedNodeIds = [...this.expandedNodeIds, nodeId]
  }

  isPersonaSelected(agentId: string): boolean {
    return this.selectedPersonaIds.includes(agentId)
  }

  isAgentInMeeting(agentId: string): boolean {
    return this.meetingAgentIds.includes(agentId)
  }

  togglePersonaSelection(agentId: string): void {
    if (this.selectedPersonaIds.includes(agentId)) {
      this.selectedPersonaIds = this.selectedPersonaIds.filter((item: string) => item !== agentId)
      return
    }

    this.selectedPersonaIds = [...this.selectedPersonaIds, agentId]
  }

  hasSelectedPersonas(): boolean {
    return this.selectedPersonaIds.length > 0
  }

  getMeetingAgentIdsForStart(): string[] {
    if (this.meetingAgentIds.length > 0) {
      return [...this.meetingAgentIds]
    }
    return [...this.selectedPersonaIds]
  }

  canStartFromDetail(): boolean {
    return this.getMeetingAgentIdsForStart().length >= 2
  }

  addSelectedPersonasToMeeting(): void {
    if (!this.hasSelectedPersonas()) {
      return
    }

    const preservedAgentIds = this.meetingAgentIds.filter((agentId: string) => !this.selectedPersonaIds.includes(agentId))
    const nextMeetingAgentIds = [...preservedAgentIds, ...this.selectedPersonaIds]
    this.meetingAgentIds = nextMeetingAgentIds

    if (this.returnToMeeting) {
      const existing = MeetingSessionStore.getProfileIds()
      if (existing.length === 0) {
        MeetingSessionStore.setProfileIds([this.profile.id])
      } else if (existing.indexOf(this.profile.id) < 0) {
        MeetingSessionStore.setProfileIds([...existing, this.profile.id])
      } else {
        MeetingSessionStore.setProfileIds(existing)
      }
      MeetingSessionStore.setProfileId(this.profile.id)
      MeetingSessionStore.setSelectedAgents(nextMeetingAgentIds)
      router.back()
    }
  }

  startMeeting(): void {
    const meetingAgentIds = this.getMeetingAgentIdsForStart()
    if (meetingAgentIds.length < 2) {
      return
    }

    router.pushUrl({
      url: 'pages/MeetingParticipantPage',
      params: {
        profileId: this.profile.id,
        profileIds: this.profile.id,
        selectedAgentIds: meetingAgentIds.join(',')
      }
    })
  }

  timelineCollapsedTeaser(node: TimelineNode): string {
    const summary = node.summary.trim()
    const fallback = node.keyEvent.trim()
    let core: string = summary.length > 0 ? summary : fallback

    if (core.length > TIMELINE_TEASER_MAX_CHARS) {
      core = core.substring(0, TIMELINE_TEASER_MAX_CHARS) + '...'
    }

    const age = node.ageLabel ? node.ageLabel.trim() : ''
    if (age.length > 0 && core.length > 0) {
      return `${age} · ${core}`
    }

    return core
  }

  getStageColor(stageType: string): string {
    const colors: Record<string, string> = {
      'early': MintColors.stage.early,
      'turning-point': MintColors.stage.turningPoint,
      'crisis': MintColors.stage.crisis,
      'rebuild': MintColors.stage.rebuild,
      'peak': MintColors.stage.peak
    }
    return colors[stageType] || MintColors.stage.default
  }

  private getAgentForNode(node: TimelineNode, index: number): PersonaSpec | undefined {
    const exactMatch = this.agents.find((agent: PersonaSpec) =>
      agent.stageLabel === node.stageLabel &&
      agent.timeLabel === node.timeLabel
    )
    if (exactMatch) {
      return exactMatch
    }

    const stageMatch = this.agents.find((agent: PersonaSpec) => agent.stageLabel === node.stageLabel)
    if (stageMatch) {
      return stageMatch
    }

    const eventMatch = this.agents.find((agent: PersonaSpec) => agent.keyEvent === node.keyEvent)
    if (eventMatch) {
      return eventMatch
    }

    return this.agents[index]
  }

  private getAgentIdForNode(node: TimelineNode, index: number): string {
    const agent = this.getAgentForNode(node, index)
    return agent ? agent.agentId : ''
  }

  getPersonaButtonLabel(node: TimelineNode, index: number): string {
    const agentId = this.getAgentIdForNode(node, index)
    if (!agentId.length) {
      return '+ 选择人格'
    }

    if (this.isPersonaSelected(agentId)) {
      return '✓ 已选人格'
    }

    if (this.isAgentInMeeting(agentId)) {
      return '已在会议中'
    }

    return '+ 选择人格'
  }

  getPersonaButtonFontColor(node: TimelineNode, index: number): string {
    const agentId = this.getAgentIdForNode(node, index)
    if (!agentId.length) {
      return MintColors.textMuted
    }

    if (this.isPersonaSelected(agentId)) {
      return '#FFFFFF'
    }

    if (this.isAgentInMeeting(agentId)) {
      return MintColors.lavenderDark
    }

    return MintColors.mintDark
  }

  getPersonaButtonBackgroundColor(node: TimelineNode, index: number): string {
    const agentId = this.getAgentIdForNode(node, index)
    if (!agentId.length) {
      return MintColors.backgroundSecondary
    }

    if (this.isPersonaSelected(agentId)) {
      return MintColors.mint
    }

    if (this.isAgentInMeeting(agentId)) {
      return MintColors.lavenderPale
    }

    return MintColors.surfaceGlass
  }

  getPersonaButtonBorderColor(node: TimelineNode, index: number): string {
    const agentId = this.getAgentIdForNode(node, index)
    if (!agentId.length) {
      return MintColors.border
    }

    if (this.isPersonaSelected(agentId)) {
      return MintColors.mint
    }

    if (this.isAgentInMeeting(agentId)) {
      return MintColors.lavenderLight
    }

    return MintColors.border
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(MintColors.background)

        Column()
          .width(300)
          .height(200)
          .borderRadius(150)
          .backgroundColor('rgba(78, 205, 196, 0.06)')
          .blur(80)
          .position({ x: -100, y: -60 })

        Column()
          .width(260)
          .height(170)
          .borderRadius(130)
          .backgroundColor('rgba(184, 169, 217, 0.06)')
          .blur(60)
          .position({ right: -80, y: -40 })
      }
      .width('100%')
      .height('100%')

      Scroll() {
        Column({ space: Spacing.lg }) {
          Column({ space: Spacing.md }) {
            Text(this.profile.displayName)
              .fontSize(Typography.size.hero)
              .fontWeight(Typography.weight.bold)
              .fontColor(MintColors.textPrimary)

            Text(this.profile.biography)
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textSecondary)
              .lineHeight(Typography.lineHeight.relaxed)

            Divider()
              .color(MintColors.divider)
              .margin({ top: Spacing.sm, bottom: Spacing.sm })

            Row() {
              Column({ space: 2 }) {
                Text(`${this.selectedPersonaIds.length}`)
                  .fontSize(Typography.size.xl)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(MintColors.mint)

                Text('已选人格')
                  .fontSize(Typography.size.xs)
                  .fontColor(MintColors.textMuted)

                Text(`已带入会议 ${this.meetingAgentIds.length}`)
                  .fontSize(Typography.size.xs)
                  .fontColor(MintColors.textMuted)
              }

              Blank()

              Column({ space: Spacing.sm }) {
                Button('添加进会议')
                  .width(132)
                  .height(40)
                  .fontSize(Typography.size.body)
                  .fontColor(this.hasSelectedPersonas() ? '#FFFFFF' : MintColors.textMuted)
                  .backgroundColor(this.hasSelectedPersonas() ? MintColors.mint : MintColors.backgroundSecondary)
                  .borderRadius(BorderRadius.xxl)
                  .enabled(this.hasSelectedPersonas())
                  .onClick(() => {
                    this.addSelectedPersonasToMeeting()
                  })

                Button('开始会议')
                  .width(132)
                  .height(40)
                  .fontSize(Typography.size.body)
                  .fontColor(this.canStartFromDetail() ? '#FFFFFF' : MintColors.textMuted)
                  .backgroundColor(this.canStartFromDetail() ? MintColors.lavenderDark : MintColors.backgroundSecondary)
                  .borderRadius(BorderRadius.xxl)
                  .enabled(this.canStartFromDetail())
                  .onClick(() => {
                    this.startMeeting()
                  })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
          }
          .width('100%')
          .padding(Spacing.lg)
          .backgroundColor(MintColors.cardPrimary)
          .borderRadius(BorderRadius.xxl)
          .border({
            width: 0.5,
            color: MintColors.border,
            radius: BorderRadius.xxl
          })
          .shadow({
            radius: 20,
            color: 'rgba(78, 205, 196, 0.08)',
            offsetX: 0,
            offsetY: 6
          })

          Row() {
            Text('人生时间线')
              .fontSize(Typography.size.bodyLg)
              .fontWeight(FontWeight.Medium)
              .fontColor(MintColors.textPrimary)
          }
          .width('100%')
          .padding({ top: Spacing.sm })

          ForEach(this.nodes, (node: TimelineNode, index: number) => {
            this.buildTimelineNode(node, index)
          }, (node: TimelineNode) => node.nodeId)
        }
        .padding({
          left: Spacing.page.horizontal,
          right: Spacing.page.horizontal,
          top: this.topInsetVp() + 60,
          bottom: this.safeBottomVp + Spacing.xl
        })
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Button() {
        Text('<')
          .fontSize(20)
          .fontColor(MintColors.mintDark)
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
      .onClick(() => {
        router.back()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }

  @Builder
  buildTimelineNode(node: TimelineNode, index: number) {
    Column({ space: Spacing.md }) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor(this.getStageColor(node.stageType))

          Text(`${index + 1}`)
            .fontSize(Typography.size.sm)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
        }
        .width(28)
        .height(28)

        Text(node.stageLabel)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)
          .margin({ left: Spacing.sm })
          .layoutWeight(1)

        Text(node.timeLabel)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textMuted)
          .margin({ right: Spacing.xs })

        Text(this.isTimelineNodeExpanded(node.nodeId) ? '▼' : '▶')
          .fontSize(11)
          .fontColor(MintColors.textMuted)
          .width(20)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .onClick(() => {
        this.toggleTimelineNode(node.nodeId)
      })

      if (!this.isTimelineNodeExpanded(node.nodeId) && this.timelineCollapsedTeaser(node).length > 0) {
        Text(this.timelineCollapsedTeaser(node))
          .fontSize(Typography.size.sm)
          .fontColor(MintColors.textMuted)
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      if (this.isTimelineNodeExpanded(node.nodeId)) {
        Column({ space: Spacing.md }) {
          Text(node.summary)
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textSecondary)
            .lineHeight(Typography.lineHeight.relaxed)

          Row({ space: Spacing.xs }) {
            Text('关键事件：')
              .fontSize(Typography.size.sm)
              .fontColor(MintColors.textMuted)
              .flexShrink(0)

            Text(node.keyEvent)
              .fontSize(Typography.size.sm)
              .fontColor(MintColors.textPrimary)
              .layoutWeight(1)
              .lineHeight(22)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            ForEach(node.traits, (trait: string) => {
              Text(trait)
                .fontSize(Typography.size.xs)
                .fontColor(MintColors.mintDark)
                .padding({
                  left: Spacing.sm,
                  right: Spacing.sm,
                  top: 3,
                  bottom: 3
                })
                .backgroundColor(MintColors.mintBg)
                .borderRadius(BorderRadius.chip)
                .margin({ right: Spacing.xs, bottom: Spacing.xs })
            }, (trait: string) => trait)
          }
          .width('100%')

          if (node.values.length > 0) {
            Row({ space: Spacing.xs }) {
              Text('价值观：')
                .fontSize(Typography.size.sm)
                .fontColor(MintColors.textMuted)
                .flexShrink(0)

              Text(node.values.join(' / '))
                .fontSize(Typography.size.sm)
                .fontColor(MintColors.textPrimary)
                .layoutWeight(1)
                .lineHeight(22)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }

          if (node.sourceEvidence.length > 0) {
            Column({ space: Spacing.xs }) {
              Text('证据引用：')
                .fontSize(Typography.size.sm)
                .fontColor(MintColors.textMuted)

              Text(`"${node.sourceEvidence[0].quote}"`)
                .fontSize(Typography.size.body)
                .fontColor(MintColors.lavenderDark)
                .lineHeight(Typography.lineHeight.relaxed)
                .fontStyle(FontStyle.Italic)
            }
            .width('100%')
            .padding(Spacing.md)
            .backgroundColor(MintColors.lavenderPale)
            .borderRadius(BorderRadius.lg)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
      }

      Button(this.getPersonaButtonLabel(node, index))
        .width('100%')
        .height(42)
        .fontSize(Typography.size.body)
        .fontColor(this.getPersonaButtonFontColor(node, index))
        .backgroundColor(this.getPersonaButtonBackgroundColor(node, index))
        .borderRadius(BorderRadius.xxl)
        .border({
          width: 1,
          color: this.getPersonaButtonBorderColor(node, index),
          radius: BorderRadius.xxl
        })
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
        .onClick(() => {
          const agentId = this.getAgentIdForNode(node, index)
          if (agentId.length > 0) {
            this.togglePersonaSelection(agentId)
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor(MintColors.cardPrimary)
    .borderRadius(BorderRadius.xxl)
    .border({
      width: 0.5,
      color: MintColors.border,
      radius: BorderRadius.xxl
    })
    .transition(TransitionEffect.OPACITY.animation({
      duration: 300,
      curve: Curve.EaseOut
    }))
  }
}
