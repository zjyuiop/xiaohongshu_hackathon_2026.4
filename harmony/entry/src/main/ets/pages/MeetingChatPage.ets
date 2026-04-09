import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import {
  ARENA_USER_TOPIC_AGENT_ID,
  ArenaMessage,
  ArenaStreamEvent,
  ArenaSummary,
  PersonaSpec,
  RouteParams
} from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { MeetingSessionStore } from '../utils/MeetingSessionStore'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import { AnimationDuration, AnimationCurve } from '../common/styles/Animation'
import { parseMeetingSelection } from '../common/MeetingSelection'
import promptAction from '@ohos.promptAction'

const FALLBACK_SAFE_TOP_VP: number = 52
const DEFAULT_TOPIC: string = '现在该不该离开这份长期消耗我的工作？'

/** 为 false 时隐藏底部「插话/续聊」输入条 */
const SHOW_MEETING_COMPOSER: boolean = false
/** 为 false 时隐藏会议进行中状态条上的红色「打断」按钮 */
const SHOW_MEETING_INTERRUPT_BUTTON: boolean = false

type MeetingStage = 'init' | 'checking' | 'loading' | 'running' | 'done' | 'interrupted' | 'error'

@Entry
@Component
struct MeetingChatPage {
  @State profileId: string = ''
  @State profileIds: string[] = []
  @State topic: string = DEFAULT_TOPIC
  @State selectedAgents: PersonaSpec[] = []
  @State selectedAgentIds: string[] = []
  @State roundCount: number = 0  // 0 表示使用默认轮数

  @State messages: ArenaMessage[] = []
  @State liveDraftText: string = ''  // 当前发言中的草稿文本
  @State liveSpeakerId: string = ''  // 当前正在发言的人格 ID
  @State summary: ArenaSummary | null = null
  @State stage: MeetingStage = 'init'
  @State errorMessage: string = ''
  @State connectionStatus: string = '连接中...'
  @State progressText: string = ''

  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0

  @State headerOpacity: number = 0
  @State headerScale: number = 0.96
  @State headerTranslateY: number = 14
  @State agendaOpacity: number = 0
  @State agendaTranslateY: number = 16
  @State contentOpacity: number = 0
  @State contentTranslateY: number = 16
  @State summaryOpacity: number = 0
  @State summaryTranslateY: number = 20
  @State summaryScale: number = 0.96
  @State fallbackNotice: string = ''

  @State activeSessionId: string = ''  // 用于中断功能的会话 ID
  @State canInterrupt: boolean = false  // 当前是否可以中断

  @State liveSummaryText: string = ''  // 实时累积的总结文本
  @State lastRunId: string = ''  // run_started / 流内 runId，用于结果兜底拉取

  @State userInputDraft: string = ''
  @State composerBusy: boolean = false
  @State localUserBubbleSeq: number = 0

  @State pageSlideX: number = 36
  @State pageSlideOpacity: number = 0.92
  /** 会议进行中：1=状态条，2=对话区 */
  @State runningSectionStep: number = 0

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
    this.animateEntry()

    const rawParams = router.getParams()
    const params: RouteParams = rawParams ? rawParams as RouteParams : {}
    this.profileId = params.profileId ?? ''

    const sel = parseMeetingSelection(params)
    if (sel.profileIds.length > 0) {
      this.profileIds = sel.profileIds
    }
    if (sel.selectedAgentIds.length > 0) {
      this.selectedAgentIds = sel.selectedAgentIds
    }

    const rawTopic = params.topic ?? ''
    if (rawTopic.length > 0) {
      try {
        this.topic = decodeURIComponent(rawTopic)
      } catch (_e) {
        this.topic = rawTopic
      }
    } else {
      this.topic = DEFAULT_TOPIC
    }

    this.applyRoundCountFromRoute(params)

    if (this.profileIds.length === 0 && this.profileId.length > 0) {
      this.profileIds = [this.profileId]
    }
    if (this.profileIds.length === 0) {
      const sessionIds = MeetingSessionStore.getProfileIds()
      if (sessionIds.length > 0) {
        this.profileIds = [...sessionIds]
      }
    }
    if (this.profileId.length === 0 && this.profileIds.length > 0) {
      this.profileId = this.profileIds[0]
    }
    if (this.profileId.length === 0) {
      const sessionProfileId = MeetingSessionStore.getProfileId()
      if (sessionProfileId.length > 0) {
        this.profileId = sessionProfileId
        if (this.profileIds.length === 0) {
          this.profileIds = [sessionProfileId]
        }
      }
    }

    if (this.selectedAgentIds.length === 0) {
      this.selectedAgentIds = MeetingSessionStore.getSelectedAgents()
    }

    if (this.topic === DEFAULT_TOPIC) {
      const sessionTopic = MeetingSessionStore.getTopic()
      if (sessionTopic.length > 0) {
        this.topic = sessionTopic
      }
    }

    const effectiveProfiles: string[] = this.profileIds.length > 0 ? this.profileIds :
      (this.profileId.length > 0 ? [this.profileId] : [])
    if (effectiveProfiles.length === 0 || this.selectedAgentIds.length < 2) {
      this.stage = 'error'
      this.errorMessage = '参数不完整，请至少选择 2 位参会者后再开始会议。'
      return
    }

    this.initializeAndStart()
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

  private animateEntry(): void {
    setTimeout(() => {
      animateTo({ duration: AnimationDuration.normal, curve: AnimationCurve.emphasized }, () => {
        this.headerOpacity = 1
        this.headerScale = 1
        this.headerTranslateY = 0
      })
    }, 50)

    setTimeout(() => {
      animateTo({ duration: AnimationDuration.slow, curve: AnimationCurve.friction }, () => {
        this.agendaOpacity = 1
        this.agendaTranslateY = 0
      })
    }, 130)
  }

  /** 生成过程中也要展示已收到的消息，避免 contentOpacity 一直为 0 */
  private ensureContentVisible(): void {
    if (this.contentOpacity < 1) {
      this.contentOpacity = 1
      this.contentTranslateY = 0
    }
  }

  /** 会议结束仍无内容时，按文档用 GET /api/arena/runs/:runId 回读 */
  private hydrateFromRunIfNeeded(): void {
    if (this.messages.length > 0 && this.summary !== null) {
      return
    }
    if (this.lastRunId.length === 0) {
      return
    }
    PersonaApi.getArenaRunDetail(this.lastRunId)
      .then((detail) => {
        const run = detail.result
        if (this.messages.length === 0 && run.messages && run.messages.length > 0) {
          this.messages = [...run.messages]
          this.ensureContentVisible()
        }
        if (this.summary === null && run.summary) {
          this.summary = run.summary
        }
      })
      .catch(() => {
      })
  }

  private async initializeAndStart(): Promise<void> {
    this.stage = 'checking'
    this.connectionStatus = '正在连接服务器...'
    this.progressText = '检查后端连接状态'

    try {
      const health = await PersonaApi.checkHealth()
      if (!health) {
        this.connectionStatus = '后端连接失败'
        this.stage = 'error'
        this.errorMessage = '无法连接到后端服务器，请检查网络或后端服务状态。'
        return
      }

      this.connectionStatus = `已连接: ${PersonaApi.getConnectionLabel()}`
      this.progressText = '正在加载参会人格...'
      this.stage = 'loading'

      const bundle = await PersonaApi.getSelectedAgentsForMeeting(
        this.profileIds.length > 0 ? this.profileIds : [this.profileId],
        this.selectedAgentIds
      )
      this.selectedAgents = bundle.selectedAgents

      if (this.selectedAgents.length < 2) {
        this.stage = 'error'
        this.errorMessage = `只找到 ${this.selectedAgents.length} 位人格，需要至少 2 位。请返回重新选择。`
        return
      }

      this.progressText = '人格加载完成，开始生成会议...'
      this.stage = 'running'
      this.scheduleRunningSectionStagger()

      this.messages = []
      this.liveDraftText = ''
      this.liveSpeakerId = ''

      this.progressText = '正在连接流式对话...'
      this.lastRunId = ''
      this.activeSessionId = ''
      this.canInterrupt = false
      this.contentOpacity = 1
      this.contentTranslateY = 0

      try {
        await PersonaApi.streamArena(
          this.topic,
          this.selectedAgents,
          'chat',
          (event: ArenaStreamEvent) => this.handleStreamEvent(event),
          (error: string) => this.handleStreamError(error),
          () => this.handleStreamComplete(),
          this.roundCount > 0 ? this.roundCount : undefined
        )
      } catch (_streamError) {
        await this.runMeetingFallback()
      }
    } catch (error) {
      this.connectionStatus = '生成失败'
      this.stage = 'error'
      const errorText = error instanceof Error ? error.message : '未知错误'
      this.errorMessage = `会议生成失败：${errorText}`
    }
  }

  private handleStreamEvent(event: ArenaStreamEvent): void {
    const eventType = event.type

    if (eventType === 'run_started') {
      const runIdTrim = event.runId.trim()
      const sessionTrim = (event.sessionId ?? '').trim()
      if (runIdTrim.length > 0) {
        this.lastRunId = runIdTrim
      }
      // 仅使用服务端下发的 sessionId；runId 与 session 语义不同，冒充会导致 /sessions/:id/interrupt 报 Parameter error
      if (sessionTrim.length > 0) {
        this.activeSessionId = sessionTrim
        this.canInterrupt = true
      } else {
        this.canInterrupt = false
      }
      this.progressText = '会议开始...'
    } else if (eventType === 'phase_started') {
      const phaseLabels: Record<string, string> = {
        'opening': '开场阶段...',
        'reflection': '反思阶段...',
        'rebuttal': '反驳阶段...',
        'synthesis': '综合阶段...',
        'closing': '收尾阶段...',
        'manual': '手动模式...'
      }
      this.progressText = phaseLabels[event.phase ?? ''] ?? '生成中...'
    } else if (eventType === 'speaker_started') {
      this.liveSpeakerId = event.agentId ?? ''
      this.liveDraftText = ''
      const aid = event.agentId ?? ''
      if (aid.length > 0) {
        const ag = this.selectedAgents.find((a: PersonaSpec) => a.agentId === aid)
        this.progressText = ag ? `${ag.stageLabel} · 正在流式输出` : '人格正在发言…'
      } else {
        this.progressText = '人格正在发言…'
      }
    } else if (eventType === 'speaker_delta') {
      if (event.channel === 'thinking') {
        return
      }
      if (event.delta && event.delta.length > 0) {
        this.liveDraftText = this.liveDraftText + event.delta
        this.ensureContentVisible()
      } else if (event.accumulatedText && event.accumulatedText.length > 0) {
        this.liveDraftText = event.accumulatedText
        this.ensureContentVisible()
      }
    } else if (eventType === 'speaker_completed') {
      if (event.message) {
        this.messages = [...this.messages, event.message]
        this.ensureContentVisible()
      }
      this.liveDraftText = ''
      this.liveSpeakerId = ''
    } else if (eventType === 'message') {
      if (event.message) {
        this.messages = [...this.messages, event.message]
        this.ensureContentVisible()
      }
    } else if (eventType === 'summary_delta') {
      if (event.delta && event.delta.length > 0) {
        this.liveSummaryText = this.liveSummaryText + event.delta
        this.ensureContentVisible()
      } else if (event.accumulatedText && event.accumulatedText.length > 0) {
        this.liveSummaryText = event.accumulatedText
        this.ensureContentVisible()
      }
    } else if (eventType === 'summary') {
      if (event.summary) {
        this.summary = event.summary
        this.ensureContentVisible()
      } else if (this.liveSummaryText.length > 0) {
        this.summary = {
          title: '会议总结',
          consensus: this.liveSummaryText,
          disagreements: [],
          actionableAdvice: [],
          narrativeHook: ''
        }
        this.ensureContentVisible()
      }
    } else if (eventType === 'done') {
      if (event.runId && event.runId.length > 0) {
        this.lastRunId = event.runId
      }
      if (event.result) {
        const resSid = event.result.sessionId?.trim()
        if (resSid !== undefined && resSid.length > 0) {
          this.activeSessionId = resSid
        }
        if (event.result.messages && event.result.messages.length > 0) {
          this.messages = [...event.result.messages]
        }
        if (event.result.summary) {
          this.summary = event.result.summary
        }
      }
      this.liveDraftText = ''
      this.liveSpeakerId = ''
      this.stage = 'done'
      this.canInterrupt = false
      this.connectionStatus = '会议生成完成'
      this.hydrateFromRunIfNeeded()
      this.revealResult()
    } else if (eventType === 'error') {
      this.connectionStatus = '生成失败'
      this.stage = 'error'
      this.errorMessage = event.error ?? '会议发生错误'
    }
  }

  /** 打断当前会议 */
  async interruptMeeting(): Promise<void> {
    if (!this.activeSessionId || !this.canInterrupt) return

    try {
      await PersonaApi.interruptArenaSession(this.activeSessionId)
      this.stage = 'interrupted'
      this.canInterrupt = false
      this.connectionStatus = '已打断'
      this.progressText = '会议已被中断'
    } catch (error) {
      const errorText = error instanceof Error ? error.message : '未知错误'
      this.errorMessage = `打断失败：${errorText}`
    }
  }

  private handleStreamError(error: string): void {
    if (this.selectedAgents.length >= 2 && this.messages.length === 0 && this.stage === 'running') {
      this.fallbackNotice = '流式连接异常，已自动切换为普通会议模式。'
      void this.runMeetingFallback().catch((fallbackError: Error) => {
        this.connectionStatus = '生成失败'
        this.stage = 'error'
        const errorText = fallbackError instanceof Error ? fallbackError.message : `${fallbackError}`
        this.errorMessage = `流式传输错误：${error}；普通模式也失败：${errorText}`
      })
      return
    }
    this.connectionStatus = '生成失败'
    this.stage = 'error'
    this.errorMessage = `流式传输错误：${error}`
  }

  private handleStreamComplete(): void {
    if (this.stage === 'running') {
      this.stage = 'done'
      this.connectionStatus = '会议生成完成'
      this.hydrateFromRunIfNeeded()
      this.revealResult()
    }
  }

  private revealResult(): void {
    setTimeout(() => {
      animateTo({ duration: AnimationDuration.slow, curve: AnimationCurve.smooth }, () => {
        this.contentOpacity = 1
        this.contentTranslateY = 0
      })
    }, 80)

    setTimeout(() => {
      animateTo({ duration: AnimationDuration.slow, curve: AnimationCurve.smooth }, () => {
        this.summaryOpacity = 1
        this.summaryScale = 1
      })
    }, 220)
  }

  private async runMeetingFallback(): Promise<void> {
    this.connectionStatus = '普通模式生成中'
    this.progressText = '流式连接不稳定，正在切换普通会议模式...'
    this.fallbackNotice = '流式连接不稳定，已自动切换为普通会议模式。'

    try {
      const result = await PersonaApi.runArena(
        this.topic,
        this.selectedAgents,
        'chat',
        this.roundCount > 0 ? this.roundCount : undefined
      )

      this.messages = result.messages ?? []
      this.summary = result.summary ?? null
      this.liveDraftText = ''
      this.liveSpeakerId = ''
      this.liveSummaryText = ''
      this.stage = 'done'
      this.canInterrupt = false
      this.connectionStatus = '会议生成完成'
      this.progressText = '会议已完成'
      this.revealResult()
    } catch (fallbackError) {
      const errorText = fallbackError instanceof Error ? fallbackError.message : '未知错误'
      this.connectionStatus = '生成失败'
      this.stage = 'error'
      this.errorMessage = `会议生成失败：${errorText}`
    }
  }

  private liveSpeakerLabel(): string {
    if (this.liveSpeakerId.length === 0) {
      return ''
    }
    const agent = this.selectedAgents.find((a: PersonaSpec) => a.agentId === this.liveSpeakerId)
    return agent ? agent.displayName : this.liveSpeakerId
  }

  private getAgentAccentColor(agentId: string): string {
    const index = this.selectedAgents.findIndex((a: PersonaSpec) => a.agentId === agentId)
    const colors: string[] = [
      MintColors.mint,
      MintColors.lavender,
      MintColors.warning,
      '#7BA6F7',
      MintColors.mintDark
    ]
    return colors[Math.max(0, index) % colors.length]
  }

  private getMessageBubbleBackground(agentId: string): string {
    const index = this.selectedAgents.findIndex((a: PersonaSpec) => a.agentId === agentId)
    const alt = Math.max(0, index) % 2 === 0
    return alt ? 'rgba(255, 255, 255, 0.96)' : 'rgba(78, 205, 196, 0.11)'
  }

  private applyRoundCountFromRoute(params: RouteParams): void {
    const raw = params.roundCount
    const n = typeof raw === 'number' ? Math.floor(raw) : Math.floor(Number(raw))
    if (Number.isNaN(n) || n < 5 || n > 25) {
      return
    }
    this.roundCount = n
  }

  private scheduleRunningSectionStagger(): void {
    this.runningSectionStep = 0
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.emphasized
      }, () => {
        this.runningSectionStep = 1
      })
    }, 20)
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.friction
      }, () => {
        this.runningSectionStep = 2
      })
    }, 72)
  }

  private runningStatusVisible(): boolean {
    return this.stage !== 'running' || this.runningSectionStep >= 1
  }

  private conversationStaggerVisible(isStreamingMode: boolean): boolean {
    if (!isStreamingMode || this.stage !== 'running') {
      return true
    }
    return this.runningSectionStep >= 2
  }

  private goBack(): void {
    router.back()
  }

  private isUserMessage(msg: ArenaMessage): boolean {
    return msg.kind === 'user' || msg.agentId === ARENA_USER_TOPIC_AGENT_ID
  }

  private shouldShowComposer(): boolean {
    return SHOW_MEETING_COMPOSER &&
      this.selectedAgents.length >= 2 &&
      (this.stage === 'running' || this.stage === 'done' || this.stage === 'interrupted') &&
      this.lastRunId.length > 0
  }

  private composerReserveBottomVp(): number {
    return this.shouldShowComposer() ? 108 : 0
  }

  private appendLocalUserBubble(text: string): void {
    this.localUserBubbleSeq = this.localUserBubbleSeq + 1
    const msg: ArenaMessage = {
      id: `local-user-${this.localUserBubbleSeq}`,
      kind: 'user',
      agentId: ARENA_USER_TOPIC_AGENT_ID,
      displayName: '我',
      stageLabel: '参会者',
      content: text,
      stance: 'neutral'
    }
    this.messages = [...this.messages, msg]
    this.ensureContentVisible()
  }

  private async sendUserIntervention(): Promise<void> {
    const text = this.userInputDraft.trim()
    if (this.composerBusy) {
      return
    }
    if (text.length === 0) {
      try {
        promptAction.openToast({ message: '请先输入要插话的内容' })
      } catch (_e) {
      }
      return
    }
    if (this.lastRunId.length === 0) {
      this.errorMessage = '请等待会议开始后再插话。'
      return
    }
    if (this.selectedAgents.length < 2) {
      return
    }

    const continueFrom = this.lastRunId
    const sessionForContinue = this.activeSessionId.length > 0 ? this.activeSessionId : undefined

    this.composerBusy = true
    this.errorMessage = ''

    try {
      if (this.stage === 'running' && this.canInterrupt && this.activeSessionId.length > 0) {
        try {
          await PersonaApi.interruptArenaSession(this.activeSessionId)
          this.stage = 'interrupted'
          this.canInterrupt = false
          this.connectionStatus = '已打断'
          this.progressText = '已打断，正在按你的插话续聊…'
        } catch (interruptErr) {
          const errorText = interruptErr instanceof Error ? interruptErr.message : '未知错误'
          this.errorMessage = `打断失败：${errorText}`
          this.composerBusy = false
          return
        }
      }

      this.userInputDraft = ''
      this.appendLocalUserBubble(text)

      this.liveDraftText = ''
      this.liveSpeakerId = ''
      this.liveSummaryText = ''
      this.summary = null
      this.stage = 'running'
      this.connectionStatus = `已连接: ${PersonaApi.getConnectionLabel()}`
      this.progressText = '正在根据你的插话继续会议…'
      this.summaryOpacity = 0
      this.summaryScale = 0.96
      this.scheduleRunningSectionStagger()

      try {
        await PersonaApi.streamArena(
          this.topic,
          this.selectedAgents,
          'chat',
          (event: ArenaStreamEvent) => this.handleStreamEvent(event),
          (error: string) => this.handleStreamError(error),
          () => this.handleStreamComplete(),
          this.roundCount > 0 ? this.roundCount : undefined,
          {
            guidance: text,
            continueFromRunId: continueFrom,
            sessionId: sessionForContinue
          }
        )
      } catch (streamErr) {
        const errText = streamErr instanceof Error ? streamErr.message : '未知错误'
        this.connectionStatus = '续聊流式失败'
        this.stage = 'done'
        this.errorMessage = `续聊流式连接失败：${errText}`
      }
    } catch (outer) {
      const errorText = outer instanceof Error ? outer.message : '未知错误'
      this.connectionStatus = '续聊失败'
      this.stage = this.messages.length > 0 ? 'done' : 'error'
      this.errorMessage = `续聊失败：${errorText}`
    } finally {
      this.composerBusy = false
    }
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

              this.buildAgenda()

              if (this.stage === 'checking' || this.stage === 'loading') {
                this.buildLoadingState()
              }

              if (this.stage === 'running') {
                this.buildRunningStatusBar()
                this.buildConversationArea(true)
              }

              if (this.stage === 'interrupted') {
                this.buildInterruptedState()
              }

              if (this.stage === 'error') {
                this.buildErrorDisplay()
              }

              if (this.stage === 'done' || this.stage === 'interrupted') {
                if (this.messages.length > 0) {
                  this.buildConversationArea(false)
                }
              }

              if (this.summary) {
                this.buildSummaryCard()
              }

              if (this.stage === 'done' && this.messages.length === 0 && this.summary === null) {
                this.buildEmptyOutcomeHint()
              }
            }
            .width('100%')
            .padding({
              left: Spacing.page.horizontal,
              right: Spacing.page.horizontal,
              top: this.topInsetVp() + 56,
              bottom: this.safeBottomVp + Spacing.xl + this.composerReserveBottomVp()
            })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)

          if (this.shouldShowComposer()) {
            Column({ space: 6 }) {
              if (this.errorMessage.length > 0) {
                Text(this.errorMessage)
                  .fontSize(Typography.size.caption)
                  .fontColor(MintColors.error)
                  .width('100%')
                  .lineHeight(18)
              }

              Text('插话 / 续聊 · 你作为参会者加入讨论')
                .fontSize(Typography.size.xs)
                .fontColor(MintColors.textMuted)
                .width('100%')

              Row({ space: 10 }) {
                TextArea({
                  text: this.userInputDraft,
                  placeholder: '随时输入观点，发送后人格会围绕你的插话继续讨论…'
                })
                  .layoutWeight(1)
                  .height(52)
                  .fontSize(Typography.size.body)
                  .fontColor(MintColors.textPrimary)
                  .placeholderColor(MintColors.textPlaceholder)
                  .backgroundColor('rgba(78, 205, 196, 0.08)')
                  .borderRadius(BorderRadius.xl)
                  .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.sm, bottom: Spacing.sm })
                  .enabled(!this.composerBusy)
                  .onChange((value: string) => {
                    this.userInputDraft = value
                  })

                Button('发送')
                  .height(52)
                  .fontSize(Typography.size.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(MintColors.mint)
                  .borderRadius(BorderRadius.pill)
                  .padding({ left: 18, right: 18 })
                  .stateEffect(true)
                  .enabled(!this.composerBusy)
                  .onClick(() => {
                    void this.sendUserIntervention()
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding({
              left: Spacing.page.horizontal,
              right: Spacing.page.horizontal,
              top: Spacing.sm,
              bottom: this.safeBottomVp + Spacing.sm
            })
            .backgroundColor('rgba(255, 255, 255, 0.94)')
            .borderWidth({ top: 1 })
            .borderColor({ top: 'rgba(78, 205, 196, 0.22)' })
            .shadow({
              radius: 12,
              color: 'rgba(45, 59, 71, 0.06)',
              offsetX: 0,
              offsetY: -2
            })
            .zIndex(50)
          }
        }
        .layoutWeight(1)
        .width('100%')
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
        .backgroundColor('rgba(78, 205, 196, 0.08)')
        .blur(90)
        .position({ x: -96, y: -36 })

      Column()
        .width(220)
        .height(180)
        .borderRadius(110)
        .backgroundColor('rgba(184, 169, 217, 0.10)')
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

      Column({ space: 2 }) {
        Text(this.stage === 'done' ? '会议已结束' : (this.stage === 'error' ? '生成失败' : '会议进行中'))
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textMuted)

        Text(this.summary?.title ?? '人格会议')
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${this.selectedAgents.length} 位`)
        .fontSize(Typography.size.xs)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.mintDark)
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor('rgba(78, 205, 196, 0.12)')
        .borderRadius(BorderRadius.pill)
    }
    .width('100%')
    .padding({
      left: Spacing.page.horizontal,
      right: Spacing.page.horizontal,
      top: this.topInsetVp() + 12
    })
    .opacity(this.headerOpacity)
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized
    })
  }

  @Builder
  buildHeader(): void {
    Column({ space: Spacing.md }) {
      Text('人格会议')
        .fontSize(Typography.size.hero)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)

      Text(this.stage === 'done' ? '以下为本次会议的完整对话与结论' :
        (this.stage === 'running' ? '下方为实时对话，发言随流式输出逐字呈现' : '人格观点正在汇聚成一场完整讨论'))
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)

      if (this.fallbackNotice.length > 0) {
        Text(this.fallbackNotice)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.warning)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('rgba(245, 166, 35, 0.12)')
          .borderRadius(BorderRadius.lg)
      }
    }
    .width('100%')
    .opacity(this.headerOpacity)
    .scale({ x: this.headerScale, y: this.headerScale })
    .translate({ y: this.headerTranslateY })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized
    })
  }

  @Builder
  buildAgenda(): void {
    Column({ space: Spacing.sm }) {
      Text('议题')
        .fontSize(Typography.size.caption)
        .fontColor(MintColors.textMuted)

      Text(this.topic)
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Medium)
        .fontColor(MintColors.textPrimary)
        .lineHeight(Typography.lineHeight.relaxed)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.md)
    .backgroundColor(MintColors.backgroundSecondary)
    .borderRadius(BorderRadius.lg)
    .opacity(this.agendaOpacity)
    .translate({ y: this.agendaTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.friction
    })
  }

  @Builder
  buildLoadingState(): void {
    Column({ space: Spacing.lg }) {
      Column({ space: Spacing.sm }) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(MintColors.mint)

        Text(this.progressText)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)

        Text(this.connectionStatus)
          .fontSize(Typography.size.caption)
          .fontColor(MintColors.textMuted)
          .textAlign(TextAlign.Center)

        if (this.fallbackNotice.length > 0) {
          Text(this.fallbackNotice)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.warning)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row({ space: Spacing.md }) {
        ForEach(this.selectedAgents, (agent: PersonaSpec, index: number) => {
          Column({ space: 6 }) {
            Column() {
              Text(agent.displayName.length > 0 ? agent.displayName.charAt(0) : '?')
                .fontSize(Typography.size.body)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor(this.getAgentAccentColor(agent.agentId))
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Text(agent.stageLabel)
              .fontSize(Typography.size.caption)
              .fontColor(MintColors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          .width(70)
        }, (agent: PersonaSpec) => agent.agentId)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text('连接成功后将进入下方实时对话区')
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textMuted)
    }
    .width('100%')
    .padding(Spacing.card.large)
    .backgroundColor('rgba(255, 255, 255, 0.86)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: 'rgba(78, 205, 196, 0.32)',
      radius: BorderRadius.xxl2
    })
    .alignItems(HorizontalAlign.Center)
  }

  /** 会议进行中：顶部轻量状态条（不再用大卡片挡住对话区） */
  @Builder
  buildRunningStatusBar(): void {
    Row({ space: Spacing.md }) {
      LoadingProgress()
        .width(22)
        .height(22)
        .color(MintColors.mint)

      Column({ space: 4 }) {
        Text(this.progressText)
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textPrimary)
          .width('100%')

        Text(this.connectionStatus)
          .fontSize(Typography.size.xs)
          .fontColor(MintColors.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (SHOW_MEETING_INTERRUPT_BUTTON && this.canInterrupt) {
        Button('打断')
          .height(34)
          .fontSize(Typography.size.caption)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.error)
          .borderRadius(BorderRadius.pill)
          .padding({ left: 14, right: 14 })
          .stateEffect(true)
          .onClick(() => {
            void this.interruptMeeting()
          })
      }
    }
    .width('100%')
    .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.sm, bottom: Spacing.sm })
    .backgroundColor('rgba(255, 255, 255, 0.88)')
    .borderRadius(BorderRadius.lg)
    .border({
      width: 1,
      color: 'rgba(78, 205, 196, 0.28)',
      radius: BorderRadius.lg
    })
    .opacity(this.runningStatusVisible() ? 1 : 0)
    .translate({ y: this.runningStatusVisible() ? 0 : 12 })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.emphasized
    })
  }

  /**
   * 对话区：已完成消息 +（可选）当前流式气泡 + 流式总结预览
   * isStreamingMode=true：会议进行中，展示实时输入气泡
   */
  @Builder
  buildConversationArea(isStreamingMode: boolean): void {
    Column({ space: Spacing.lg }) {
      Row({ space: 8 }) {
        Text(isStreamingMode ? '实时对话' : '对话流')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Blank()

        Text(`${this.messages.length} 条`)
          .fontSize(Typography.size.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.lavenderDark)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('rgba(184, 169, 217, 0.12)')
          .borderRadius(BorderRadius.pill)
      }
      .width('100%')

      Column({ space: Spacing.md }) {
        if (isStreamingMode && this.messages.length === 0 &&
          this.liveSpeakerId.length === 0 && this.liveDraftText.length === 0) {
          Column({ space: Spacing.sm }) {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(MintColors.mint)
            Text('已连接流式通道，等待首位发言…')
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textSecondary)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(Spacing.lg)
          .alignItems(HorizontalAlign.Center)
        }

        ForEach(this.messages, (msg: ArenaMessage, index: number) => {
          this.buildMessageBubble(msg, index)
        }, (msg: ArenaMessage) => msg.id)

        if (isStreamingMode && (this.liveSpeakerId.length > 0 || this.liveDraftText.length > 0)) {
          this.buildStreamingMessageBubble()
        }

        if (isStreamingMode && this.liveSummaryText.length > 0 && this.summary === null) {
          Column({ space: Spacing.sm }) {
            Text('总结生成中…')
              .fontSize(Typography.size.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.lavenderDark)

            Text(this.liveSummaryText)
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textPrimary)
              .lineHeight(Typography.lineHeight.relaxed)
              .width('100%')
          }
          .width('100%')
          .padding(Spacing.md)
          .backgroundColor('rgba(184, 169, 217, 0.12)')
          .borderRadius(BorderRadius.lg)
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.90)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl2
    })
    .opacity(this.conversationStaggerVisible(isStreamingMode) ? this.contentOpacity : 0)
    .translate({
      y: this.conversationStaggerVisible(isStreamingMode) ? this.contentTranslateY : 16
    })
    .animation({
      duration: AnimationDuration.page,
      curve: AnimationCurve.smooth
    })
  }

  /** 当前正在输出的一条（流式 delta），与已完成气泡同布局，虚线边框表示进行中 */
  @Builder
  buildStreamingMessageBubble(): void {
    Row({ space: 10 }) {
      Column() {
        Text(this.liveSpeakerLabel().length > 0 ? this.liveSpeakerLabel().charAt(0) : '…')
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.liveSpeakerId.length > 0 ? this.getAgentAccentColor(this.liveSpeakerId) :
        MintColors.mint)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.liveSpeakerLabel().length > 0 ? this.liveSpeakerLabel() : '发言中')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)
            .layoutWeight(1)
            .maxLines(2)

          Text('输出中')
            .fontSize(10)
            .fontColor(MintColors.mintDark)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(MintColors.mintBg)
            .borderRadius(BorderRadius.pill)
        }
        .width('100%')

        Column() {
          if (this.liveDraftText.length > 0) {
            Text(this.liveDraftText)
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textPrimary)
              .lineHeight(Typography.lineHeight.relaxed)
              .width('100%')
          } else {
            Row({ space: 4 }) {
              Text('●')
                .fontSize(12)
                .fontColor(MintColors.mintDark)
              Text('●')
                .fontSize(12)
                .fontColor(MintColors.mintDark)
              Text('●')
                .fontSize(12)
                .fontColor(MintColors.mintDark)
              Text(' 正在组织语言…')
                .fontSize(Typography.size.caption)
                .fontColor(MintColors.textMuted)
            }
            .padding({ top: 4, bottom: 4 })
          }
        }
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor('rgba(78, 205, 196, 0.14)')
        .borderRadius(18)
        .border({
          width: 1.2,
          color: MintColors.mint,
          style: BorderStyle.Dashed,
          radius: 18
        })
        .shadow({
          radius: 10,
          color: 'rgba(78, 205, 196, 0.12)',
          offsetX: 0,
          offsetY: 3
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildEmptyOutcomeHint(): void {
    Column({ space: Spacing.sm }) {
      Text('暂无对话与总结')
        .fontSize(Typography.size.bodyLg)
        .fontWeight(FontWeight.Medium)
        .fontColor(MintColors.textPrimary)

      Text('若刚结束仍为空，可能是网络中断或流式解析异常。请点「重试」或返回后重新开始会议。')
        .fontSize(Typography.size.body)
        .fontColor(MintColors.textSecondary)
        .lineHeight(Typography.lineHeight.relaxed)
    }
    .width('100%')
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.88)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl2
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildErrorDisplay(): void {
    Column({ space: Spacing.lg }) {
      Column({ space: Spacing.sm }) {
        Text('⚠')
          .fontSize(48)
          .fontColor(MintColors.error)

        Text(this.errorMessage)
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
            this.stage = 'init'
            this.errorMessage = ''
            this.initializeAndStart()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(Spacing.xl)
    .backgroundColor('rgba(255, 255, 255, 0.90)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: 'rgba(239, 68, 68, 0.32)',
      radius: BorderRadius.xxl2
    })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildInterruptedState(): void {
    Column({ space: Spacing.lg }) {
      Column({ space: Spacing.sm }) {
        Text('⏸')
          .fontSize(48)
          .fontColor(MintColors.warning)

        Text('会议已中断')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Text(`已完成 ${this.messages.length} 条发言`)
          .fontSize(Typography.size.body)
          .fontColor(MintColors.textSecondary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row({ space: Spacing.md }) {
        Button('返回')
          .fontSize(Typography.size.body)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.textMuted)
          .borderRadius(BorderRadius.pill)
          .height(44)
          .width('45%')
          .stateEffect(true)
          .onClick(() => this.goBack())

        Button('继续生成')
          .fontSize(Typography.size.body)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.mint)
          .borderRadius(BorderRadius.pill)
          .height(44)
          .width('45%')
          .stateEffect(true)
          .onClick(() => {
            this.stage = 'init'
            this.initializeAndStart()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(Spacing.xl)
    .backgroundColor('rgba(255, 255, 255, 0.90)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: 'rgba(255, 193, 7, 0.5)',
      radius: BorderRadius.xxl2
    })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildUserMessageBubble(msg: ArenaMessage, index: number): void {
    Row({ space: 10 }) {
      Blank()
        .layoutWeight(1)

      Column({ space: 6 }) {
        if (index === 0 || !this.isUserMessage(this.messages[index - 1])) {
          Column({ space: 2 }) {
            Text(`${msg.displayName} · ${msg.stageLabel}`)
              .fontSize(Typography.size.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)
              .maxLines(2)
              .width('100%')
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .alignItems(HorizontalAlign.End)
        }

        Column() {
          Text(msg.content)
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
            .lineHeight(Typography.lineHeight.relaxed)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor('rgba(78, 205, 196, 0.26)')
        .borderRadius(18)
        .border({
          width: 1,
          color: 'rgba(78, 205, 196, 0.45)',
          radius: 18
        })
        .shadow({
          radius: 8,
          color: 'rgba(45, 59, 71, 0.06)',
          offsetX: 0,
          offsetY: 2
        })
      }
      .constraintSize({ maxWidth: '78%' })
      .alignItems(HorizontalAlign.End)

      Column() {
        Text(msg.displayName.length > 0 ? msg.displayName.charAt(0) : '我')
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(MintColors.mintDark)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: (index === 0 || !this.isUserMessage(this.messages[index - 1])) ? 2 : 0 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildMessageBubble(msg: ArenaMessage, index: number): void {
    if (this.isUserMessage(msg)) {
      this.buildUserMessageBubble(msg, index)
    } else {
      Row({ space: 10 }) {
      Column() {
        Text(msg.displayName.length > 0 ? msg.displayName.charAt(0) : '?')
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.getAgentAccentColor(msg.agentId))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: (index === 0 || this.messages[index - 1].agentId !== msg.agentId) ? 2 : 0 })

      Column({ space: 6 }) {
        if (index === 0 || this.messages[index - 1].agentId !== msg.agentId) {
          Column({ space: 2 }) {
            Text(msg.displayName)
              .fontSize(Typography.size.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)
              .maxLines(2)

            Text(msg.stageLabel)
              .fontSize(10)
              .fontColor(MintColors.textMuted)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Column() {
          Text(msg.content)
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
            .lineHeight(Typography.lineHeight.relaxed)
            .width('100%')
        }
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.getMessageBubbleBackground(msg.agentId))
        .borderRadius(18)
        .border({
          width: 1,
          color: 'rgba(78, 205, 196, 0.22)',
          radius: 18
        })
        .shadow({
          radius: 8,
          color: 'rgba(45, 59, 71, 0.06)',
          offsetX: 0,
          offsetY: 2
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  buildSummaryCard(): void {
    Column({ space: Spacing.md }) {
      Row() {
        Column({ space: 4 }) {
          Text('会议结论')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.mintDark)

          if (this.summary?.title) {
            Text(this.summary.title)
              .fontSize(Typography.size.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.summary?.narrativeHook) {
          Text('金句')
            .fontSize(Typography.size.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.lavenderDark)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('rgba(184, 169, 217, 0.12)')
            .borderRadius(BorderRadius.pill)
        }
      }
      .width('100%')

      if (this.summary?.consensus) {
        Column({ space: 6 }) {
          Text('共识')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.mintDark)

          Text(this.summary.consensus)
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
            .lineHeight(Typography.lineHeight.relaxed)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(Spacing.md)
        .backgroundColor(MintColors.mintBg)
        .borderRadius(BorderRadius.lg)
      }

      if (this.summary?.narrativeHook) {
        Column({ space: 6 }) {
          Text('金句')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.lavenderDark)

          Text(`"${this.summary.narrativeHook}"`)
            .fontSize(Typography.size.body)
            .fontColor(MintColors.textPrimary)
            .fontStyle(FontStyle.Italic)
            .lineHeight(Typography.lineHeight.relaxed)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(Spacing.md)
        .backgroundColor('rgba(184, 169, 217, 0.10)')
        .borderRadius(BorderRadius.lg)
      }

      if (this.summary?.actionableAdvice && this.summary.actionableAdvice.length > 0) {
        Column({ space: 6 }) {
          Text('行动建议')
            .fontSize(Typography.size.caption)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          ForEach(this.summary.actionableAdvice, (advice: string, idx: number) => {
            Row({ space: 8 }) {
              Text(`${idx + 1}.`)
                .fontSize(Typography.size.caption)
                .fontWeight(FontWeight.Bold)
                .fontColor(MintColors.mintDark)

              Text(advice)
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textPrimary)
            }
            .width('100%')
          }, (advice: string) => advice)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(Spacing.md)
        .backgroundColor('rgba(255, 255, 255, 0.80)')
        .borderRadius(BorderRadius.lg)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.92)')
    .borderRadius(BorderRadius.xxl2)
    .border({
      width: 1,
      color: 'rgba(255, 255, 255, 0.94)',
      radius: BorderRadius.xxl2
    })
    .shadow({
      radius: 26,
      color: 'rgba(78, 205, 196, 0.10)',
      offsetX: 0,
      offsetY: 10
    })
    .opacity(this.summaryOpacity)
    .translate({ y: this.summaryTranslateY })
    .scale({ x: this.summaryScale, y: this.summaryScale })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.friction
    })
  }
}
