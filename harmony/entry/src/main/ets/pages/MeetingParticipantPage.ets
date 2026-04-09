import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { PersonaSpec, ProfileBundle, RouteParams } from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { MeetingSessionStore } from '../utils/MeetingSessionStore'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import { AnimationDuration, AnimationCurve } from '../common/styles/Animation'
import { parseMeetingSelection } from '../common/MeetingSelection'

const FALLBACK_SAFE_TOP_VP: number = 52

function buildMeetingRoundOptions(): number[] {
  const a: number[] = []
  for (let i = 5; i <= 25; i++) {
    a.push(i)
  }
  return a
}

const MEETING_ROUND_OPTIONS: number[] = buildMeetingRoundOptions()
const DEFAULT_MEETING_ROUND_COUNT: number = 10

interface ProfileAgentsGroup {
  profileId: string
  displayName: string
  agents: PersonaSpec[]
}

@Entry
@Component
struct MeetingParticipantPage {
  @State agents: PersonaSpec[] = []
  @State profileGroups: ProfileAgentsGroup[] = []
  @State profileIds: string[] = []
  @State selectedAgentIds: string[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State topic: string = ''
  @State meetingRoundCount: number = DEFAULT_MEETING_ROUND_COUNT
  @State profileNameSummary: string = ''

  @State headerOpacity: number = 0
  @State headerTranslateY: number = 14
  @State contentOpacity: number = 0
  @State contentTranslateY: number = 22
  @State topicInputOpacity: number = 0
  @State topicInputTranslateY: number = 26
  @State pressingAgentId: string = ''
  /** 整页自右侧滑入（模拟路由转场） */
  @State pageSlideX: number = 36
  @State pageSlideOpacity: number = 0.92
  /** 列表与底部区块错峰：1=标题行，2+i=第 i 个人格卡片，之后为添加/议题/轮数/开始 */
  @State listStaggerStep: number = 0

  aboutToAppear(): void {
    this.loadSafeInsets()

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.page,
        curve: AnimationCurve.emphasized
      }, () => {
        this.pageSlideX = 0
        this.pageSlideOpacity = 1
      })
    }, 10)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.headerOpacity = 1
        this.headerTranslateY = 0
      })
    }, 60)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.friction
      }, () => {
        if (this.loading) {
          this.contentOpacity = 1
          this.contentTranslateY = 0
        }
      })
    }, 120)

    const rawParams = router.getParams()
    const params: RouteParams = rawParams ? rawParams as RouteParams : {}

    const sel = parseMeetingSelection(params)
    let ids: string[] = sel.profileIds.length > 0 ? sel.profileIds : []
    const single = params.profileId ?? ''
    if (ids.length === 0 && single.length > 0) {
      ids = [single]
    }
    if (ids.length === 0) {
      const sessionIds = MeetingSessionStore.getProfileIds()
      if (sessionIds.length > 0) {
        ids = [...sessionIds]
      } else {
        const one = MeetingSessionStore.getProfileId()
        if (one.length > 0) {
          ids = [one]
        }
      }
    }

    this.profileIds = ids
    MeetingSessionStore.setProfileIds(this.profileIds)

    if (sel.selectedAgentIds.length > 0) {
      this.selectedAgentIds = [...sel.selectedAgentIds]
    } else {
      this.syncSelectionFromSession()
    }

    const routeTopic = params.topic ?? ''
    if (routeTopic.length > 0) {
      try {
        this.topic = decodeURIComponent(routeTopic)
      } catch (_e) {
        this.topic = routeTopic
      }
    } else {
      const sessionTopic = MeetingSessionStore.getTopic()
      if (sessionTopic.length > 0) {
        this.topic = sessionTopic
      }
    }

    this.applyMeetingRoundFromRouteOrSession(params)

    if (this.profileIds.length === 0) {
      this.error = '缺少人物信息，请返回重新选择。'
      this.loading = false
      return
    }

    this.loadAllProfiles()
  }

  onPageShow(): void {
    const pending = MeetingSessionStore.takePendingAddProfileId()
    if (pending.length > 0 && this.profileIds.indexOf(pending) < 0) {
      this.profileIds = [...this.profileIds, pending]
      MeetingSessionStore.setProfileIds(this.profileIds)
      this.loadAllProfiles()
    }
    this.syncSelectionFromSession()
  }

  private normIds(arr: string[]): string {
    const copy: string[] = [...arr]
    copy.sort()
    return copy.join(',')
  }

  private syncSelectionFromSession(): void {
    const sessionIds = MeetingSessionStore.getProfileIds()
    if (sessionIds.length > 0 && this.normIds(sessionIds) !== this.normIds(this.profileIds)) {
      return
    }

    const sessionSelectedAgentIds = MeetingSessionStore.getSelectedAgents()
    if (sessionSelectedAgentIds.length > 0) {
      this.selectedAgentIds = [...sessionSelectedAgentIds]
    }

    const sessionTopic = MeetingSessionStore.getTopic()
    if (sessionTopic.length > 0) {
      this.topic = sessionTopic
    }

    const sessionRounds = MeetingSessionStore.getRoundCount()
    if (sessionRounds >= 5 && sessionRounds <= 25) {
      this.meetingRoundCount = sessionRounds
    }
  }

  private applyMeetingRoundFromRouteOrSession(params: RouteParams): void {
    const raw = params.roundCount
    const fromRoute = typeof raw === 'number' ? Math.floor(raw) : Math.floor(Number(raw))
    if (!Number.isNaN(fromRoute) && fromRoute >= 5 && fromRoute <= 25) {
      this.meetingRoundCount = fromRoute
      return
    }
    const stored = MeetingSessionStore.getRoundCount()
    if (stored >= 5 && stored <= 25) {
      this.meetingRoundCount = stored
    } else {
      this.meetingRoundCount = DEFAULT_MEETING_ROUND_COUNT
    }
  }

  private loadAllProfiles(): void {
    this.loading = true
    this.error = ''
    this.listStaggerStep = 0

    const loadTasks = this.profileIds.map((pid: string) => PersonaApi.getProfileBundle(pid))
    Promise.all(loadTasks)
      .then((bundles: ProfileBundle[]) => {
        const groups: ProfileAgentsGroup[] = bundles.map((b) => {
          const g: ProfileAgentsGroup = {
            profileId: b.profile.id,
            displayName: b.profile.displayName,
            agents: b.agents
          }
          return g
        })
        this.profileGroups = groups

        const seenAgent = new Set<string>()
        const merged: PersonaSpec[] = []
        bundles.forEach((b) => {
          b.agents.forEach((agent: PersonaSpec) => {
            if (!seenAgent.has(agent.agentId)) {
              seenAgent.add(agent.agentId)
              merged.push(agent)
            }
          })
        })
        this.agents = merged

        this.selectedAgentIds = this.selectedAgentIds.filter((agentId: string) =>
          merged.some((agent: PersonaSpec) => agent.agentId === agentId)
        )

        if (this.topic.length === 0 && bundles[0].profile.suggestedTopics.length > 0) {
          const st = bundles[0].profile.suggestedTopics[0]
          if (st && st.length > 0) {
            this.topic = st
          }
        }

        const names = groups.map((g: ProfileAgentsGroup) => g.displayName)
        if (names.length <= 2) {
          this.profileNameSummary = names.join('、')
        } else {
          this.profileNameSummary = `${names[0]} 等 ${names.length} 人`
        }

        this.loading = false
        this.scheduleContentStagger()
      })
      .catch((err: Error) => {
        const errorMsg = err.message || '未知错误'
        this.error = `加载角色失败：${errorMsg}`
        this.loading = false
        this.listStaggerStep = 1
        animateTo({
          duration: AnimationDuration.normal,
          curve: AnimationCurve.emphasized
        }, () => {
          this.contentOpacity = 1
          this.contentTranslateY = 0
          this.topicInputOpacity = 1
          this.topicInputTranslateY = 0
        })
      })
  }

  /** 角色卡片与下方模块依次滑入 */
  private scheduleContentStagger(): void {
    animateTo({
      duration: AnimationDuration.fast,
      curve: AnimationCurve.emphasized
    }, () => {
      this.contentOpacity = 1
      this.contentTranslateY = 0
      this.topicInputOpacity = 1
      this.topicInputTranslateY = 0
    })
    const n = this.agents.length
    const totalSteps = 1 + n + 1 + 3
    this.listStaggerStep = 0
    for (let s = 0; s < totalSteps; s++) {
      const stepIndex = s
      setTimeout(() => {
        animateTo({
          duration: AnimationDuration.normal,
          curve: AnimationCurve.emphasized
        }, () => {
          this.listStaggerStep = stepIndex + 1
        })
      }, 20 + stepIndex * 42)
    }
  }

  private topicStaggerStep(): number {
    return 2 + this.agents.length + 1
  }

  private roundStaggerStep(): number {
    return 2 + this.agents.length + 2
  }

  private startStaggerStep(): number {
    return 2 + this.agents.length + 3
  }

  private staggerTopicVisible(): boolean {
    return this.listStaggerStep >= this.topicStaggerStep()
  }

  private staggerRoundVisible(): boolean {
    return this.listStaggerStep >= this.roundStaggerStep()
  }

  private staggerStartVisible(): boolean {
    return this.listStaggerStep >= this.startStaggerStep()
  }

  private loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_e) {
    }
  }

  private topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  private toggleAgent(agentId: string): void {
    if (this.selectedAgentIds.includes(agentId)) {
      this.selectedAgentIds = this.selectedAgentIds.filter((id: string) => id !== agentId)
    } else {
      this.selectedAgentIds = [...this.selectedAgentIds, agentId]
    }

    MeetingSessionStore.setProfileIds(this.profileIds)
    MeetingSessionStore.setSelectedAgents(this.selectedAgentIds)
  }

  private isSelected(agentId: string): boolean {
    return this.selectedAgentIds.includes(agentId)
  }

  private globalIndexFor(agentId: string): number {
    return this.agents.findIndex((a: PersonaSpec) => a.agentId === agentId)
  }

  private getAgentAccentColor(index: number): string {
    const colors: string[] = [
      MintColors.mint,
      MintColors.lavender,
      MintColors.warning,
      '#7BA6F7',
      MintColors.mintDark
    ]
    return colors[index % colors.length]
  }

  private removeProfile(pid: string): void {
    if (this.profileIds.length <= 1) {
      return
    }
    this.profileIds = this.profileIds.filter((p: string) => p !== pid)
    MeetingSessionStore.setProfileIds(this.profileIds)
    this.loadAllProfiles()
  }

  private addAnotherPerson(): void {
    MeetingSessionStore.setProfileIds(this.profileIds)
    MeetingSessionStore.setTopic(this.topic)
    MeetingSessionStore.setRoundCount(this.meetingRoundCount)
    MeetingSessionStore.setSelectedAgents(this.selectedAgentIds)
    router.pushUrl({
      url: 'pages/MeetingProfilePickerPage'
    })
  }

  private startMeeting(): void {
    if (this.selectedAgentIds.length < 2) {
      return
    }

    MeetingSessionStore.setProfileIds(this.profileIds)
    MeetingSessionStore.setProfileId(this.profileIds[0])
    MeetingSessionStore.setSelectedAgents(this.selectedAgentIds)
    MeetingSessionStore.setTopic(this.topic)
    MeetingSessionStore.setRoundCount(this.meetingRoundCount)

    router.pushUrl({
      url: 'pages/MeetingChatPage',
      params: {
        profileId: this.profileIds[0],
        profileIds: this.profileIds.join(','),
        selectedAgentIds: this.selectedAgentIds.join(','),
        topic: this.topic,
        roundCount: this.meetingRoundCount
      }
    })
  }

  private goBack(): void {
    router.back()
  }

  private openProfileDetailFor(profileId: string): void {
    MeetingSessionStore.setProfileIds(this.profileIds)
    MeetingSessionStore.setSelectedAgents(this.selectedAgentIds)
    MeetingSessionStore.setTopic(this.topic)
    MeetingSessionStore.setRoundCount(this.meetingRoundCount)
    router.pushUrl({
      url: 'pages/ProfileDetail',
      params: {
        profileId: profileId,
        selectedAgentIds: this.selectedAgentIds.join(','),
        returnToMeeting: '1'
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildBackground()

      Column() {
        this.buildTopBar()

        Column() {
          Scroll() {
            Column({ space: Spacing.lg }) {
              this.buildHeader()

              if (this.loading) {
                this.buildLoadingState()
              } else if (this.error) {
                this.buildErrorState()
              } else {
                this.buildContent()
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({
          left: Spacing.page.horizontal,
          right: Spacing.page.horizontal,
          top: this.topInsetVp() + 56,
          bottom: this.safeBottomVp + Spacing.xl
        })
      }
      .width('100%')
      .height('100%')
      .translate({ x: this.pageSlideX })
      .opacity(this.pageSlideOpacity)
      .animation({
        duration: AnimationDuration.page,
        curve: AnimationCurve.emphasized
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildBackground() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(MintColors.background)

      Column()
        .width(280)
        .height(220)
        .borderRadius(140)
        .backgroundColor('rgba(78, 205, 196, 0.06)')
        .blur(90)
        .position({ x: -96, y: -36 })

      Column()
        .width(220)
        .height(180)
        .borderRadius(110)
        .backgroundColor('rgba(184, 169, 217, 0.08)')
        .blur(72)
        .position({ right: -54, y: 200 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildTopBar() {
    Row({ space: 12 }) {
      Button() {
        Text('‹')
          .fontSize(22)
          .fontColor(MintColors.mintDark)
      }
      .width(40)
      .height(40)
      .backgroundColor(MintColors.surfaceGlass)
      .borderRadius(20)
      .stateEffect(true)
      .onClick(() => this.goBack())

      Text('选择参会者')
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)
        .layoutWeight(1)

      Text(this.profileNameSummary.length > 0 ? this.profileNameSummary : ' ')
        .fontSize(Typography.size.caption)
        .fontColor(MintColors.textMuted)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('rgba(255, 255, 255, 0.72)')
        .borderRadius(BorderRadius.pill)
        .constraintSize({ maxWidth: '46%' })
    }
    .width('100%')
    .padding({
      left: Spacing.page.horizontal,
      right: Spacing.page.horizontal,
      top: this.topInsetVp() + 12
    })
    .opacity(this.headerOpacity)
    .translate({ y: this.headerTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized
    })
  }

  @Builder
  buildHeader(): void {
    Column({ space: Spacing.sm }) {
      Text('邀请角色参与讨论')
        .fontSize(Typography.size.hero)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)

      Text('可添加多个人物，每人选择不同人生阶段人格；至少选 2 位人格后再开始会议')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.headerOpacity)
    .translate({ y: this.headerTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized
    })
  }

  @Builder
  buildLoadingState(): void {
    Column({ space: Spacing.md }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(MintColors.mint)

      Text('加载角色中...')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textMuted)

      if (this.profileIds.length > 0) {
        Text(`人物数：${this.profileIds.length}`)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textSecondary)
      }
    }
    .width('100%')
    .padding(Spacing.xl)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.contentOpacity)
    .translate({ y: this.contentTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.friction
    })
  }

  @Builder
  buildErrorState(): void {
    Column({ space: Spacing.lg }) {
      Column({ space: Spacing.sm }) {
        Text('⚠')
          .fontSize(48)
          .fontColor(MintColors.error)

        Text(this.error)
          .fontSize(Typography.size.body)
          .fontColor(MintColors.error)
          .textAlign(TextAlign.Center)
          .lineHeight(Typography.lineHeight.relaxed)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row({ space: Spacing.md }) {
        Button('返回上一页')
          .fontSize(Typography.size.body)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.mintDark)
          .borderRadius(BorderRadius.pill)
          .height(44)
          .width('45%')
          .stateEffect(true)
          .onClick(() => this.goBack())

        Button('重试')
          .fontSize(Typography.size.body)
          .fontColor(MintColors.mintDark)
          .backgroundColor('rgba(78, 205, 196, 0.12)')
          .borderRadius(BorderRadius.pill)
          .height(44)
          .width('45%')
          .stateEffect(true)
          .onClick(() => {
            this.loading = true
            this.error = ''
            this.loadAllProfiles()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(Spacing.xl)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.contentOpacity)
    .translate({ y: this.contentTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.friction
    })
  }

  @Builder
  buildContent(): void {
    Column({ space: Spacing.lg }) {
      this.buildRoleList()

      this.buildTopicSection()

      this.buildRoundCountSection()

      this.buildStartButton()
    }
    .width('100%')
    .opacity(this.contentOpacity)
    .translate({ y: this.contentTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.friction
    })
  }

  @Builder
  buildRoleList(): void {
    Column({ space: Spacing.md }) {
      Row({ space: 8 }) {
        Text('角色列表')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Blank()

        Text(`已选 ${this.selectedAgentIds.length} 位人格 · 共 ${this.agents.length} 个阶段`)
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.mintDark)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(MintColors.mintBg)
          .borderRadius(BorderRadius.pill)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .opacity(this.listStaggerStep >= 1 ? 1 : 0)
      .translate({ y: this.listStaggerStep >= 1 ? 0 : 14 })
      .animation({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.emphasized
      })

      Column({ space: Spacing.md }) {
        ForEach(this.profileGroups, (group: ProfileAgentsGroup) => {
          Column({ space: Spacing.sm }) {
            Row({ space: 8 }) {
              Text(group.displayName)
                .fontSize(Typography.size.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(MintColors.textPrimary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Button('资料')
                .fontSize(Typography.size.caption)
                .fontColor(MintColors.mintDark)
                .backgroundColor('rgba(78, 205, 196, 0.12)')
                .borderRadius(BorderRadius.pill)
                .height(30)
                .padding({ left: 12, right: 12 })
                .stateEffect(true)
                .onClick(() => {
                  this.openProfileDetailFor(group.profileId)
                })

              if (this.profileIds.length > 1) {
                Button('移除')
                  .fontSize(Typography.size.caption)
                  .fontColor(MintColors.error)
                  .backgroundColor('rgba(220, 38, 38, 0.08)')
                  .borderRadius(BorderRadius.pill)
                  .height(30)
                  .padding({ left: 12, right: 12 })
                  .stateEffect(true)
                  .onClick(() => {
                    this.removeProfile(group.profileId)
                  })
              }
            }
            .width('100%')

            ForEach(group.agents, (agent: PersonaSpec) => {
              this.buildRoleItem(agent, this.globalIndexFor(agent.agentId))
            }, (agent: PersonaSpec) => `${group.profileId}_${agent.agentId}`)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (group: ProfileAgentsGroup) => group.profileId)
      }
      .width('100%')

      Button() {
        Row({ space: 8 }) {
          Text('+')
            .fontSize(18)
            .fontColor(MintColors.mintDark)
          Text('添加另一个人物')
            .fontSize(Typography.size.body)
            .fontColor(MintColors.mintDark)
        }
      }
      .type(ButtonType.Normal)
      .width('100%')
      .height(48)
      .backgroundColor('rgba(255, 255, 255, 0.55)')
      .borderRadius(BorderRadius.lg)
      .border({
        width: 1,
        color: MintColors.borderLight,
        radius: BorderRadius.lg
      })
      .stateEffect(true)
      .onClick(() => this.addAnotherPerson())
      .opacity(this.listStaggerStep >= 2 + this.agents.length ? 1 : 0)
      .translate({ y: this.listStaggerStep >= 2 + this.agents.length ? 0 : 16 })
      .animation({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.emphasized
      })
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.84)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 0.8,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl2
    })
  }

  @Builder
  buildRoleItem(agent: PersonaSpec, index: number): void {
    Row({ space: Spacing.md }) {
      Column() {
        Text(agent.displayName.length > 0 ? agent.displayName.charAt(0) : '?')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isSelected(agent.agentId) ? '#FFFFFF' : this.getAgentAccentColor(index))
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(this.isSelected(agent.agentId) ? this.getAgentAccentColor(index) : 'rgba(255, 255, 255, 0.92)')
      .border({
        width: 1.5,
        color: this.getAgentAccentColor(index),
        radius: 22
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(agent.stageLabel)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Text(agent.timeLabel)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textMuted)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.isSelected(agent.agentId)) {
        Column() {
          Text('✓')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor(MintColors.mintDark)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          Text('+')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(MintColors.mintDark)
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('rgba(255, 255, 255, 0.92)')
        .border({
          width: 1,
          color: MintColors.borderLight,
          radius: 14
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: Spacing.sm, bottom: Spacing.sm })
    .borderRadius(BorderRadius.lg)
    .backgroundColor(this.isSelected(agent.agentId) ? 'rgba(78, 205, 196, 0.08)' : 'rgba(255, 255, 255, 0.72)')
    .border({
      width: this.isSelected(agent.agentId) ? 1 : 0.5,
      color: this.isSelected(agent.agentId) ? MintColors.mintDark : MintColors.borderLight,
      radius: BorderRadius.lg
    })
    .scale({
      x: this.pressingAgentId === agent.agentId ? 0.98 : 1,
      y: this.pressingAgentId === agent.agentId ? 0.98 : 1
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressingAgentId = agent.agentId
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressingAgentId = ''
      }
    })
    .opacity(this.listStaggerStep >= 2 + index ? 1 : 0)
    .translate({ y: this.listStaggerStep >= 2 + index ? 0 : 20 })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized
    })
    .onClick(() => {
      this.toggleAgent(agent.agentId)
    })
  }

  @Builder
  buildTopicSection(): void {
    Column({ space: Spacing.md }) {
      Text('设置议题')
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)

      TextInput({ placeholder: '输入你想讨论的议题...', text: this.topic })
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textPrimary)
        .placeholderColor(MintColors.textMuted)
        .backgroundColor('rgba(255, 255, 255, 0.92)')
        .borderRadius(BorderRadius.lg)
        .height(56)
        .padding({ left: 16, right: 16 })
        .border({
          width: 1,
          color: MintColors.borderLight,
          radius: BorderRadius.lg
        })
        .onChange((value: string) => {
          this.topic = value
          MeetingSessionStore.setTopic(value)
        })
    }
    .width('100%')
    .opacity(this.staggerTopicVisible() ? this.topicInputOpacity : 0)
    .translate({
      y: this.staggerTopicVisible() ? this.topicInputTranslateY : 18
    })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.smooth
    })
  }

  @Builder
  buildRoundCountSection(): void {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Text('对话轮数')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)
          .layoutWeight(1)

        Text(`当前 ${this.meetingRoundCount} 轮`)
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.mintDark)
      }
      .width('100%')

      Text('左右滑动选择 5～25 轮，开始会议后按该轮数讨论')
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textMuted)
        .width('100%')

      Scroll() {
        Row({ space: 10 }) {
          ForEach(MEETING_ROUND_OPTIONS, (n: number) => {
            this.buildRoundCountChip(n)
          }, (n: number) => `round_${n}`)
        }
        .padding({ right: 4 })
      }
      .width('100%')
      .height(52)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.90)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 0.8,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl2
    })
    .opacity(this.staggerRoundVisible() ? this.topicInputOpacity : 0)
    .translate({
      y: this.staggerRoundVisible() ? this.topicInputTranslateY : 18
    })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.smooth
    })
  }

  @Builder
  buildRoundCountChip(n: number): void {
    Column() {
      Text(`${n}`)
        .fontSize(Typography.size.body)
        .fontWeight(this.meetingRoundCount === n ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.meetingRoundCount === n ? '#FFFFFF' : MintColors.textPrimary)
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(BorderRadius.lg)
    .backgroundColor(this.meetingRoundCount === n ? MintColors.mintDark : 'rgba(255, 255, 255, 0.92)')
    .border({
      width: 1,
      color: this.meetingRoundCount === n ? MintColors.mintDark : MintColors.borderLight,
      radius: BorderRadius.lg
    })
    .onClick(() => {
      this.meetingRoundCount = n
      MeetingSessionStore.setRoundCount(n)
    })
  }

  @Builder
  buildStartButton(): void {
    Column({ space: Spacing.sm }) {
      Text(`已选 ${this.selectedAgentIds.length} 位角色 · ${this.profileIds.length} 位人物`)
        .fontSize(Typography.size.caption)
        .fontColor(this.selectedAgentIds.length >= 2 ? MintColors.mintDark : MintColors.textMuted)

      Button(this.selectedAgentIds.length >= 2 ? '开始会议' : `还需选择 ${2 - this.selectedAgentIds.length} 位角色`)
        .fontSize(Typography.size.body)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(this.selectedAgentIds.length >= 2 ? MintColors.mintDark : '#BFD7D4')
        .borderRadius(BorderRadius.pill)
        .height(52)
        .width('100%')
        .stateEffect(true)
        .enabled(this.selectedAgentIds.length >= 2)
        .onClick(() => this.startMeeting())
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.90)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 0.8,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl2
    })
    .opacity(this.staggerStartVisible() ? this.topicInputOpacity : 0)
    .translate({
      y: this.staggerStartVisible() ? this.topicInputTranslateY : 18
    })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.smooth
    })
  }
}
