import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import {
  ArenaMessage,
  ArenaMode,
  ArenaPhase,
  ArenaRun,
  ArenaSummary,
  ArenaStreamEvent,
  PersonaSpec,
  PresetProfile,
  ProfileBundle,
  ArenaOutputLinks,
  PlannedRound
} from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'

// ============================================
// 常量定义
// ============================================
const DEFAULT_TOPIC: string = '这个选择现在该坚持，还是该及时转向？'
const DEFAULT_MODE: ArenaMode = 'chat'
const MIN_PARTICIPANTS: number = 2
const FALLBACK_SAFE_TOP_VP: number = 52

// ============================================
// 状态机
// ============================================
export type MeetingState = 'idle' | 'config' | 'running' | 'paused' | 'completed' | 'error'

/**
 * 会议完整结果
 */
export interface MeetingResult {
  runId: string
  sessionId: string
  topic: string
  mode: ArenaMode
  participants: PersonaSpec[]
  messages: ArenaMessage[]
  summary: ArenaSummary | null
  links: ArenaOutputLinks | null
  status: 'completed' | 'interrupted'
  createdAt: string
}

/**
 * 草稿气泡
 */
export interface LiveDraft {
  messageId: string
  agentId: string
  displayName: string
  stageLabel: string
  accumulatedText: string
  phase?: ArenaPhase
  round?: number
  timestamp: string
}

// ============================================
// 主组件
// ============================================
@Entry
@Component
struct Arena {
  // ==================== 基础数据（从 Index 传入或本地加载）====================

  // 接收路由参数
  @State profileId: string = ''
  @State selectedAgentIdsParam: string = ''

  // 本地数据
  @State profileBundle: ProfileBundle | null = null
  @State selectedAgentIds: string[] = []
  @State isLoadingBundle: boolean = false
  @State bundleError: string = ''

  // ==================== 会议配置 ====================
  @State topic: string = DEFAULT_TOPIC
  @State discussionMode: ArenaMode = DEFAULT_MODE
  @State roundCount: number = 0  // 0 表示使用默认值

  // ==================== 会议状态机 ====================
  @State meetingState: MeetingState = 'idle'
  @State activeSessionId: string = ''
  @State currentRunId: string = ''

  // ==================== 流式消息 ====================
  @State streamMessages: ArenaMessage[] = []
  @State liveDrafts: LiveDraft[] = []
  @State liveSummaryText: string = ''
  @State phaseLabel: string = ''
  @State currentRound: number = 0
  @State plannedRounds: PlannedRound[] = []

  // ==================== 会议结果 ====================
  @State meetingResult: MeetingResult | null = null
  @State meetingError: string = ''

  // ==================== UI 状态 ====================
  @State chatInputText: string = ''
  @State activeSegment: number = 0  // 0: 设定, 1: 现场
  @State showAdvancedConfig: boolean = false
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State showRolePicker: boolean = false

  // ==================== 生命周期 ====================
  aboutToAppear(): void {
    this.loadSafeInsets()
    // 从路由参数获取数据
    const params = router.getParams() as Record<string, string>
    if (params) {
      this.profileId = params['profileId'] ?? ''
      const agentIds = params['selectedAgentIds'] ?? ''
      if (agentIds) {
        this.selectedAgentIds = agentIds.split(',').filter(id => id.length > 0)
      }
      const topicParam = params['topic']
      if (topicParam && topicParam.length > 0) {
        this.topic = topicParam
      }
      const modeParam = params['discussionMode']
      if (modeParam === 'chat' || modeParam === 'debate') {
        this.discussionMode = modeParam
      }
    }

    // 如果有 profileId，加载 bundle
    if (this.profileId.length > 0) {
      void this.loadProfileBundle()
    }
  }

  // ==================== 安全区域 ====================
  loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_error) {
      this.safeTopVp = FALLBACK_SAFE_TOP_VP
      this.safeBottomVp = 0
    }
  }

  topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  // ==================== 数据加载 ====================

  /** 加载角色 Bundle */
  async loadProfileBundle(): Promise<void> {
    if (!this.profileId) return

    this.isLoadingBundle = true
    this.bundleError = ''

    try {
      this.profileBundle = await PersonaApi.getProfileBundle(this.profileId)
      // 如果没有传入 agentIds，默认选择前两个
      if (this.selectedAgentIds.length === 0 && this.profileBundle.agents.length >= 2) {
        this.selectedAgentIds = [
          this.profileBundle.agents[0].agentId,
          this.profileBundle.agents[1].agentId
        ]
      }
      // 如果有 suggestedTopic，使用它
      if (this.profileBundle.profile.suggestedTopics.length > 0 && this.topic === DEFAULT_TOPIC) {
        this.topic = this.profileBundle.profile.suggestedTopics[0]
      }
    } catch (_error) {
      this.bundleError = '加载角色信息失败'
    } finally {
      this.isLoadingBundle = false
    }
  }

  // ==================== 角色管理 ====================

  /** 获取已选人格列表 */
  getSelectedAgents(): PersonaSpec[] {
    if (!this.profileBundle) return []
    return this.profileBundle.agents.filter(agent => this.selectedAgentIds.includes(agent.agentId))
  }

  /** 检查是否可以选择更多人格 */
  canSelectMoreAgents(): boolean {
    return true
  }

  /** 检查是否可以开始会议 */
  canStartMeeting(): boolean {
    return this.getSelectedAgents().length >= MIN_PARTICIPANTS && this.meetingState === 'idle'
  }

  /** 切换人格选中状态 */
  toggleAgent(agentId: string): void {
    if (this.meetingState === 'running') return

    const index = this.selectedAgentIds.indexOf(agentId)
    if (index >= 0) {
      // 取消选择（如果只剩1个，不能取消）
      if (this.selectedAgentIds.length > 1) {
        const newIds: string[] = []
        for (let i = 0; i < this.selectedAgentIds.length; i++) {
          if (i !== index) {
            newIds.push(this.selectedAgentIds[i])
          }
        }
        this.selectedAgentIds = newIds
      }
    } else {
      // 添加选择
      this.selectedAgentIds = [...this.selectedAgentIds, agentId]
    }
  }

  /** 是否已选中的角色 */
  isAgentSelected(agentId: string): boolean {
    return this.selectedAgentIds.includes(agentId)
  }

  // ==================== 会议控制 ====================

  /** 启动流式会议 */
  async startMeeting(): Promise<void> {
    if (!this.canStartMeeting()) return

    this.meetingState = 'running'
    this.meetingError = ''
    this.streamMessages = []
    this.liveDrafts = []
    this.liveSummaryText = ''
    this.phaseLabel = '准备中...'
    this.activeSegment = 1  // 自动切换到现场
    this.activeSessionId = ''

    const agents = this.getSelectedAgents()
    const topic = this.topic.trim().length > 0 ? this.topic.trim() : DEFAULT_TOPIC

    await PersonaApi.streamArena(
      topic,
      agents,
      this.discussionMode,
      (event) => this.handleStreamEvent(event),
      (error) => this.handleStreamError(error),
      () => this.handleStreamComplete(),
      this.roundCount > 0 ? this.roundCount : undefined
    )
  }

  /** 继续已打断的会议 */
  async continueMeeting(): Promise<void> {
    if (!this.meetingResult || !this.activeSessionId) return

    this.meetingState = 'running'
    this.meetingError = ''
    this.activeSegment = 1

    const agents = this.getSelectedAgents()
    const topic = this.topic.trim().length > 0 ? this.topic.trim() : DEFAULT_TOPIC

    await PersonaApi.streamArena(
      topic,
      agents,
      this.discussionMode,
      (event) => this.handleStreamEvent(event),
      (error) => this.handleStreamError(error),
      () => this.handleStreamComplete(),
      this.roundCount > 0 ? this.roundCount : undefined
    )
  }

  /** 打断当前会议 */
  async interruptMeeting(): Promise<void> {
    if (!this.activeSessionId || this.meetingState !== 'running') return

    try {
      await PersonaApi.interruptArenaSession(this.activeSessionId)
      this.meetingState = 'paused'
      this.phaseLabel = '已打断'
    } catch (error) {
      this.meetingError = '打断失败，请重试'
    }
  }

  /** 重置会议 */
  resetMeeting(): void {
    this.meetingState = 'idle'
    this.streamMessages = []
    this.liveDrafts = []
    this.liveSummaryText = ''
    this.phaseLabel = ''
    this.currentRound = 0
    this.meetingResult = null
    this.meetingError = ''
    this.activeSessionId = ''
    this.currentRunId = ''
    this.activeSegment = 0
  }

  // ==================== 流式事件处理 ====================

  private handleStreamEvent(event: ArenaStreamEvent): void {
    const eventType = event.type

    if (eventType === 'run_started') {
      const runIdTrim = event.runId.trim()
      const sessionTrim = (event.sessionId ?? '').trim()
      this.currentRunId = runIdTrim
      if (sessionTrim.length > 0) {
        this.activeSessionId = sessionTrim
      }
      this.phaseLabel = '会议开始'
      if (event.plannedRounds) {
        this.plannedRounds = event.plannedRounds
      }
    } else if (eventType === 'phase_started') {
      this.phaseLabel = this.formatPhaseLabel(event.phase ?? '')
      if (event.round) {
        this.currentRound = event.round
      }
    } else if (eventType === 'speaker_started') {
      this.addLiveDraft(event)
    } else if (eventType === 'speaker_delta') {
      this.updateLiveDraft(event)
    } else if (eventType === 'speaker_completed') {
      this.finalizeDraft(event)
    } else if (eventType === 'message') {
      if (event.message) {
        this.streamMessages = [...this.streamMessages, event.message]
      }
    } else if (eventType === 'summary_started') {
      this.phaseLabel = '生成总结...'
    } else if (eventType === 'summary_delta') {
      if (event.delta) {
        this.liveSummaryText = this.liveSummaryText + event.delta
      }
    } else if (eventType === 'done') {
      this.handleDone(event)
    } else if (eventType === 'error') {
      this.meetingError = event.error ?? '会议发生错误'
      this.meetingState = 'error'
      this.phaseLabel = '发生错误'
    }
  }

  private addLiveDraft(event: ArenaStreamEvent): void {
    const draft: LiveDraft = {
      messageId: event.messageId ?? `draft-${Date.now()}`,
      agentId: event.agentId ?? '',
      displayName: event.displayName ?? '',
      stageLabel: event.stageLabel ?? '',
      accumulatedText: '',
      phase: event.phase,
      round: event.round,
      timestamp: event.timestamp ?? new Date().toISOString()
    }
    // 使用数组拼接而非 spread
    const newDrafts: LiveDraft[] = []
    for (let i = 0; i < this.liveDrafts.length; i++) {
      newDrafts.push(this.liveDrafts[i])
    }
    newDrafts.push(draft)
    this.liveDrafts = newDrafts
  }

  private updateLiveDraft(event: ArenaStreamEvent): void {
    const messageId = event.messageId
    if (!messageId) return

    const newDrafts: LiveDraft[] = []
    for (let i = 0; i < this.liveDrafts.length; i++) {
      const draft = this.liveDrafts[i]
      if (draft.messageId === messageId) {
        newDrafts.push({
          messageId: draft.messageId,
          agentId: draft.agentId,
          displayName: draft.displayName,
          stageLabel: draft.stageLabel,
          accumulatedText: event.accumulatedText ?? '',
          phase: draft.phase,
          round: draft.round,
          timestamp: draft.timestamp
        })
      } else {
        newDrafts.push(draft)
      }
    }
    this.liveDrafts = newDrafts
  }

  private finalizeDraft(event: ArenaStreamEvent): void {
    const messageId = event.messageId
    if (!messageId) return

    const newMessages: ArenaMessage[] = []
    for (let i = 0; i < this.streamMessages.length; i++) {
      newMessages.push(this.streamMessages[i])
    }

    const newDrafts: LiveDraft[] = []
    for (let i = 0; i < this.liveDrafts.length; i++) {
      const draft = this.liveDrafts[i]
      if (draft.messageId === messageId) {
        // 草稿转为正式消息
        const message: ArenaMessage = {
          id: draft.messageId,
          agentId: draft.agentId,
          displayName: draft.displayName,
          stageLabel: draft.stageLabel,
          content: draft.accumulatedText,
          stance: 'neutral',
          phase: draft.phase,
          round: draft.round,
          timestamp: draft.timestamp
        }
        newMessages.push(message)
      } else {
        newDrafts.push(draft)
      }
    }
    this.streamMessages = newMessages
    this.liveDrafts = newDrafts
  }

  private handleDone(event: ArenaStreamEvent): void {
    if (event.result) {
      const result = event.result as ArenaRun
      this.meetingResult = {
        runId: result.runId,
        sessionId: result.sessionId ?? this.activeSessionId,
        topic: result.topic,
        mode: result.mode,
        participants: result.participants ?? this.getSelectedAgents(),
        messages: this.streamMessages.length > 0 ? this.streamMessages : (result.messages ?? []),
        summary: result.summary ?? null,
        links: event.links ?? null,
        status: result.status ?? 'completed',
        createdAt: result.createdAt ?? new Date().toISOString()
      }
    }
    this.meetingState = 'completed'
    this.phaseLabel = '会议完成'
  }

  private handleStreamError(error: string): void {
    this.meetingError = error
    this.meetingState = 'error'
    this.phaseLabel = '连接断开'
  }

  private handleStreamComplete(): void {
    if (this.meetingState === 'running') {
      this.meetingState = 'completed'
      this.phaseLabel = '会议完成'
    }
  }

  // ==================== 辅助方法 ====================

  /** 格式化阶段标签 */
  private formatPhaseLabel(phase: string): string {
    const labels: Record<string, string> = {
      'opening': '开场陈述',
      'reflection': '互相理解',
      'rebuttal': '正面交锋',
      'synthesis': '综合回应',
      'closing': '收束陈词',
      'manual': '提问'
    }
    return labels[phase] ?? phase
  }

  /** 获取角色名称 */
  getAgentProfileName(agentId: string): string {
    if (this.profileBundle) {
      const agent = this.profileBundle.agents.find(a => a.agentId === agentId)
      if (agent) return agent.displayName
    }
    return agentId
  }

  /** 获取阶段人格的显示标签 */
  getAgentStageLabel(agentId: string): string {
    if (this.profileBundle) {
      const agent = this.profileBundle.agents.find(a => a.agentId === agentId)
      if (agent) return agent.stageLabel
    }
    return ''
  }

  /** 格式化时间 */
  formatTime(iso?: string): string {
    if (!iso || iso.length < 16) return ''
    const pivot = iso.indexOf('T')
    return pivot >= 0 ? iso.substring(pivot + 1, pivot + 6) : ''
  }

  /** 获取状态描述 */
  getStatusText(): string {
    switch (this.meetingState) {
      case 'idle': return '等待发起'
      case 'running': return '会议进行中'
      case 'paused': return '已打断'
      case 'completed': return '会议完成'
      case 'error': return '发生错误'
      default: return ''
    }
  }

  /** 获取状态颜色 */
  getStatusColor(): string {
    switch (this.meetingState) {
      case 'running': return Colors.stance.oppose
      case 'completed': return Colors.primary
      case 'paused': return Colors.warning
      case 'error': return Colors.error
      default: return Colors.textMuted
    }
  }

  // ==================== 导航 ====================

  safeBack(): void {
    try {
      router.back()
    } catch (_error) {
      // 静默处理
    }
  }

  goToPosterPreview(): void {
    if (!this.meetingResult) return
    router.pushUrl({
      url: 'pages/PosterPreviewPage',
      params: {
        arenaRunId: this.meetingResult.runId,
        topic: this.meetingResult.topic,
        participantCount: this.meetingResult.participants.length.toString()
      }
    })
  }

  goToSummaryDetail(): void {
    if (!this.meetingResult) return
    router.pushUrl({
      url: 'pages/SummaryDetailPage',
      params: {
        arenaRunId: this.meetingResult.runId
      }
    })
  }

  // ============================================
  // 子组件构建器
  // ============================================

  // ---------- 顶部状态栏 ----------
  @Builder
  topBar() {
    Row({ space: Spacing.md }) {
      Button() {
        Text('<').fontSize(20).fontColor(Colors.textPrimary)
      }
        .width(40).height(40)
        .backgroundColor(Colors.cardPrimary)
        .borderRadius(20)
        .onClick(() => this.safeBack())

      Column({ space: 2 }) {
        Text(this.profileBundle?.profile.displayName ?? '人格会议')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)

        Row({ space: 6 }) {
          Text('●').fontSize(8).fontColor(this.getStatusColor())
          Text(this.getStatusText()).fontSize(Typography.size.xs).fontColor(Colors.textSecondary)
          if (this.phaseLabel) {
            Text('·').fontSize(8).fontColor(Colors.textTertiary)
            Text(this.phaseLabel).fontSize(Typography.size.xs).fontColor(Colors.primary)
          }
          if (this.currentRound > 0) {
            Text('·').fontSize(8).fontColor(Colors.textTertiary)
            Text(`第${this.currentRound}轮`).fontSize(Typography.size.xs).fontColor(Colors.textSecondary)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${this.selectedAgentIds.length}人格`)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.canStartMeeting() ? Colors.primary : Colors.textMuted)
        .padding({ left: Spacing.md, right: Spacing.md, top: Spacing.sm, bottom: Spacing.sm })
        .backgroundColor(Colors.cardPrimary)
        .borderRadius(BorderRadius.pill)
    }
    .width('100%')
  }

  // ---------- 分段切换器 ----------
  @Builder
  segmentControl() {
    Row({ space: 4 }) {
      Button(this.activeSegment === 0 ? '● 设定' : '设定')
        .height(36)
        .layoutWeight(1)
        .fontSize(Typography.size.body)
        .fontColor(this.activeSegment === 0 ? '#FFFFFF' : Colors.textSecondary)
        .backgroundColor(this.activeSegment === 0 ? Colors.primary : Colors.cardPrimary)
        .borderRadius(BorderRadius.lg)
        .onClick(() => { this.activeSegment = 0 })

      Button(this.activeSegment === 1 ? '● 现场' : '现场')
        .height(36)
        .layoutWeight(1)
        .fontSize(Typography.size.body)
        .fontColor(this.activeSegment === 1 ? '#FFFFFF' : Colors.textSecondary)
        .backgroundColor(this.activeSegment === 1 ? Colors.primary : Colors.cardPrimary)
        .borderRadius(BorderRadius.lg)
        .onClick(() => { this.activeSegment = 1 })
    }
    .width('100%')
  }

  // ---------- 设定区 ----------
  @Builder
  configSection() {
    Column({ space: Spacing.md }) {
      // 议题输入
      Column({ space: Spacing.sm }) {
        Text('辩题 / 议题')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textMuted)
          .width('100%')

        TextArea({ text: this.topic, placeholder: '输入议题，角色会围绕这个话题展开讨论' })
          .width('100%')
          .height(80)
          .fontSize(Typography.size.body)
          .fontColor(Colors.textPrimary)
          .placeholderColor(Colors.textPlaceholder)
          .backgroundColor(Colors.backgroundSecondary)
          .borderRadius(BorderRadius.xl)
          .padding(Spacing.md)
          .enabled(this.meetingState !== 'running')
          .onChange((value: string) => { this.topic = value })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 模式选择
      Column({ space: Spacing.sm }) {
        Text('讨论模式')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textMuted)
          .width('100%')

        Row({ space: 4 }) {
          Button('💬 聊天模式')
            .height(36)
            .layoutWeight(1)
            .fontSize(Typography.size.body)
            .fontColor(this.discussionMode === 'chat' ? '#FFFFFF' : Colors.textSecondary)
            .backgroundColor(this.discussionMode === 'chat' ? Colors.primary : Colors.cardPrimary)
            .borderRadius(BorderRadius.lg)
            .enabled(this.meetingState !== 'running')
            .onClick(() => { this.discussionMode = 'chat' })

          Button('⚔️ 辩论模式')
            .height(36)
            .layoutWeight(1)
            .fontSize(Typography.size.body)
            .fontColor(this.discussionMode === 'debate' ? '#FFFFFF' : Colors.textSecondary)
            .backgroundColor(this.discussionMode === 'debate' ? Colors.stance.oppose : Colors.cardPrimary)
            .borderRadius(BorderRadius.lg)
            .enabled(this.meetingState !== 'running')
            .onClick(() => { this.discussionMode = 'debate' })
        }
      }
      .width('100%')

      // 轮数配置
      Column({ space: Spacing.sm }) {
        Row({ space: Spacing.sm }) {
          Text('对话轮数')
            .fontSize(Typography.size.caption)
            .fontColor(Colors.textMuted)

          Blank()

          Text(this.roundCount > 0 ? `${this.roundCount} 轮` : '默认')
            .fontSize(Typography.size.caption)
            .fontColor(this.roundCount > 0 ? Colors.primary : Colors.textSecondary)
        }
        .width('100%')

        Row({ space: 8 }) {
          ForEach([0, 2, 3, 5, 8], (num: number) => {
            Button(num === 0 ? '默认' : `${num}轮`)
              .height(32)
              .fontSize(Typography.size.xs)
              .fontColor(this.roundCount === num ? '#FFFFFF' : Colors.textSecondary)
              .backgroundColor(this.roundCount === num ? Colors.primary : Colors.cardPrimary)
              .borderRadius(BorderRadius.lg)
              .enabled(this.meetingState !== 'running')
              .onClick(() => { this.roundCount = num })
          }, (num: number) => num.toString())
        }
        .width('100%')
      }
      .width('100%')

      // 人格选择区
      this.agentSelector()

      // 错误提示
      if (this.bundleError.length > 0) {
        Text(this.bundleError)
          .width('100%')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.error)
          .padding(Spacing.md)
          .backgroundColor('rgba(244, 63, 94, 0.08)')
          .borderRadius(BorderRadius.lg)
      }

      if (this.meetingError.length > 0) {
        Text(this.meetingError)
          .width('100%')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.error)
          .padding(Spacing.md)
          .backgroundColor('rgba(244, 63, 94, 0.08)')
          .borderRadius(BorderRadius.lg)
      }
    }
    .width('100%')
  }

  // ---------- 人格选择器 ----------
  @Builder
  agentSelector() {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.sm }) {
        Text('阶段人格')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textMuted)
        Text(`已选 ${this.selectedAgentIds.length} 位人格`)
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textTertiary)
      }
      .width('100%')

      if (this.isLoadingBundle) {
        Row({ space: Spacing.sm }) {
          LoadingProgress().width(20).height(20)
          Text('加载人格信息...').fontSize(Typography.size.caption).fontColor(Colors.textSecondary)
        }
        .width('100%')
        .padding(Spacing.md)
      } else if (!this.profileBundle || this.profileBundle.agents.length === 0) {
        Text('暂无可用的阶段人格')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textTertiary)
          .width('100%')
          .padding(Spacing.md)
      } else {
        // 已选人格 chips
        if (this.selectedAgentIds.length > 0) {
          Scroll() {
            Row({ space: Spacing.sm }) {
              ForEach(this.selectedAgentIds, (agentId: string) => {
                this.buildSelectedAgentChip(agentId)
              }, (agentId: string) => agentId)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }

        // 可选人格列表
        Column({ space: Spacing.sm }) {
          Text('点击选择要参与的人格：')
            .fontSize(Typography.size.xs)
            .fontColor(Colors.textTertiary)
            .width('100%')

          ForEach(this.profileBundle.agents, (agent: PersonaSpec) => {
            this.buildAgentOption(agent)
          }, (agent: PersonaSpec) => agent.agentId)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSelectedAgentChip(agentId: string) {
    Row({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(24).height(24).borderRadius(12).backgroundColor(Colors.primary)
        Text(this.getAgentProfileName(agentId).charAt(0))
          .fontSize(Typography.size.xs).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }

      Column({ space: 1 }) {
        Text(this.getAgentProfileName(agentId))
          .fontSize(Typography.size.xs).fontColor(Colors.textPrimary)
        Text(this.getAgentStageLabel(agentId))
          .fontSize(9).fontColor(Colors.textTertiary).maxLines(1)
      }

      if (this.meetingState !== 'running') {
        Text('×')
          .fontSize(14)
          .fontColor(Colors.textTertiary)
          .onClick(() => this.toggleAgent(agentId))
      }
    }
    .padding({ left: Spacing.sm, right: Spacing.sm, top: 6, bottom: 6 })
    .backgroundColor(this.isAgentSelected(agentId) ? Colors.accentPurple : Colors.cardPrimary)
    .borderRadius(BorderRadius.pill)
  }

  @Builder
  buildAgentOption(agent: PersonaSpec) {
    Row({ space: Spacing.sm }) {
      Checkbox()
        .select(this.isAgentSelected(agent.agentId))
        .selectedColor(Colors.primary)
        .onChange((value: boolean) => {
          if (value) {
            if (!this.isAgentSelected(agent.agentId)) {
              this.toggleAgent(agent.agentId)
            }
          }
        })

      Column({ space: 2 }) {
        Text(agent.displayName)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)
        Text(agent.stageLabel)
          .fontSize(Typography.size.xs)
          .fontColor(Colors.primary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(agent.timeLabel)
          .fontSize(Typography.size.xs)
          .fontColor(Colors.textTertiary)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.meetingState !== 'running' && this.isAgentSelected(agent.agentId)) {
        Button('移除')
          .height(28)
          .fontSize(Typography.size.xs)
          .fontColor(Colors.error)
          .backgroundColor('rgba(244, 63, 94, 0.08)')
          .borderRadius(BorderRadius.pill)
          .onClick(() => this.toggleAgent(agent.agentId))
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor(this.isAgentSelected(agent.agentId) ? Colors.accentPurple : Colors.cardPrimary)
    .borderRadius(BorderRadius.lg)
  }

  // ---------- 现场区 ----------
  @Builder
  liveSection() {
    Column({ space: Spacing.md }) {
      Column() {
        this.messageList()
      }
      .width('100%')
      .layoutWeight(1)

      this.controlButtons()
    }
    .width('100%')
    .height('100%')
  }

  // ---------- 消息列表 ----------
  @Builder
  messageList() {
    Column({ space: Spacing.md }) {
      Row() {
        Text('对话')
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)
        if (this.streamMessages.length > 0) {
          Text(`${this.streamMessages.length} 条`)
            .fontSize(Typography.size.caption)
            .fontColor(Colors.textTertiary)
            .margin({ left: Spacing.sm })
        }
        if (this.meetingState === 'running') {
          Row({ space: 4 }) {
            LoadingProgress().width(14).height(14)
            Text('进行中').fontSize(Typography.size.xs).fontColor(Colors.primary)
          }
          .margin({ left: Spacing.sm })
        }
      }
      .width('100%')

      Scroll() {
        Column({ space: Spacing.md }) {
          // 空状态
          if (this.streamMessages.length === 0 && this.liveDrafts.length === 0 && this.meetingState !== 'running') {
            Column({ space: Spacing.sm }) {
              Text('对话尚未开始')
                .fontSize(Typography.size.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(Colors.textPrimary)
              Text('在「设定」区选择人格后点击「启动讨论」')
                .fontSize(Typography.size.caption)
                .fontColor(Colors.textTertiary)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: Spacing.lg, right: Spacing.lg, top: 44, bottom: 44 })
            .backgroundColor('rgba(99, 102, 241, 0.05)')
            .borderRadius(BorderRadius.xxl)
            .alignItems(HorizontalAlign.Center)
          }

          // 正式消息
          ForEach(this.streamMessages, (message: ArenaMessage) => {
            this.messageBubble(message)
          }, (message: ArenaMessage) => message.id)

          // 草稿气泡
          ForEach(this.liveDrafts, (draft: LiveDraft) => {
            this.draftBubble(draft)
          }, (draft: LiveDraft) => draft.messageId)

          // Live Summary
          if (this.liveSummaryText.length > 0) {
            Column({ space: Spacing.xs }) {
              Text('正在生成总结...')
                .fontSize(Typography.size.caption)
                .fontColor(Colors.primary)
              Text(this.liveSummaryText)
                .fontSize(Typography.size.caption)
                .fontColor(Colors.textSecondary)
                .lineHeight(18)
            }
            .width('100%')
            .padding(Spacing.md)
            .backgroundColor('rgba(99, 102, 241, 0.08)')
            .borderRadius(BorderRadius.lg)
          }

          // 完成总结
          if (this.meetingResult?.summary) {
            this.summarySection()
          }
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .padding(Spacing.lg)
    .backgroundColor('rgba(255, 255, 255, 0.78)')
    .borderRadius(BorderRadius.xxl3)
    .border({ width: 0.5, color: Colors.border, radius: BorderRadius.xxl3 })
  }

  // ---------- 消息气泡 ----------
  @Builder
  messageBubble(message: ArenaMessage) {
    Row() {
      if (message.agentId === 'user-prompt') {
        // 用户消息
        Blank().layoutWeight(1)
        Column({ space: 6 }) {
          Text('我').fontSize(Typography.size.xs).fontColor(Colors.primary).width('100%').textAlign(TextAlign.End)
          Text(message.content).fontSize(Typography.size.body).fontColor(Colors.textPrimary).lineHeight(Typography.lineHeight.relaxed)
          Text(this.formatTime(message.timestamp)).fontSize(10).fontColor(Colors.textTertiary).width('100%').textAlign(TextAlign.End)
        }
        .constraintSize({ maxWidth: '80%' })
        .alignItems(HorizontalAlign.End)
        .padding(Spacing.md)
        .backgroundColor('rgba(78, 205, 196, 0.16)')
        .borderRadius({ topLeft: 18, topRight: 8, bottomRight: 18, bottomLeft: 18 })
      } else {
        // AI 消息
        Stack({ alignContent: Alignment.Center }) {
          Column().width(36).height(36).borderRadius(18).backgroundColor(Colors.primary)
          Text(this.getAgentProfileName(message.agentId).charAt(0))
            .fontSize(Typography.size.body).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }

        Column({ space: 4 }) {
          Row({ space: Spacing.xs }) {
            Text(this.getAgentProfileName(message.agentId))
              .fontSize(Typography.size.xs).fontWeight(FontWeight.Medium).fontColor(Colors.textPrimary)
            if (message.phase) {
              Text('·').fontSize(Typography.size.xs).fontColor(Colors.textTertiary)
              Text(this.formatPhaseLabel(message.phase))
                .fontSize(Typography.size.xs).fontColor(Colors.primary)
            }
          }
          Text(message.content)
            .fontSize(Typography.size.body).fontColor(Colors.textPrimary).lineHeight(Typography.lineHeight.relaxed)
          Text(this.formatTime(message.timestamp)).fontSize(10).fontColor(Colors.textTertiary)
        }
        .constraintSize({ maxWidth: '78%' })
        .alignItems(HorizontalAlign.Start)
        .padding(Spacing.md)
        .backgroundColor(Colors.cardPrimary)
        .borderRadius({ topLeft: 6, topRight: 18, bottomRight: 18, bottomLeft: 18 })

        Blank().layoutWeight(1)
      }
    }
    .width('100%')
  }

  // ---------- 草稿气泡 ----------
  @Builder
  draftBubble(draft: LiveDraft) {
    Row({ space: Spacing.sm }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(36).height(36).borderRadius(18).backgroundColor(Colors.accentLight)
        Text(draft.displayName.charAt(0))
          .fontSize(Typography.size.body).fontWeight(FontWeight.Bold).fontColor(Colors.primary)
      }

      Column({ space: 4 }) {
        Row({ space: Spacing.xs }) {
          Text(draft.displayName).fontSize(Typography.size.xs).fontWeight(FontWeight.Medium).fontColor(Colors.textPrimary)
          Text('·').fontSize(Typography.size.xs).fontColor(Colors.textTertiary)
          Text('输入中...').fontSize(Typography.size.xs).fontColor(Colors.primary)
        }
        Row({ space: 2 }) {
          Text(draft.accumulatedText || '...')
            .fontSize(Typography.size.body).fontColor(Colors.textSecondary).lineHeight(Typography.lineHeight.relaxed)
          Text('▌').fontSize(Typography.size.body).fontColor(Colors.primary)
        }
      }
      .constraintSize({ maxWidth: '78%' })
      .alignItems(HorizontalAlign.Start)
      .padding(Spacing.md)
      .backgroundColor('rgba(99, 102, 241, 0.06)')
      .borderRadius({ topLeft: 6, topRight: 18, bottomRight: 18, bottomLeft: 18 })

      Blank().layoutWeight(1)
    }
    .width('100%')
  }

  // ---------- 会议总结 ----------
  @Builder
  summarySection() {
    Column({ space: Spacing.md }) {
      Row() {
        Text('会议总结').fontSize(Typography.size.body).fontWeight(FontWeight.Medium).fontColor(Colors.textPrimary)
        Blank().layoutWeight(1)
      }

      if (this.meetingResult && this.meetingResult.summary && this.meetingResult.summary.title) {
        Text(this.meetingResult.summary.title).fontSize(Typography.size.bodyLg).fontWeight(FontWeight.Medium).fontColor(Colors.textPrimary)
      }

      if (this.meetingResult && this.meetingResult.summary && this.meetingResult.summary.consensus) {
        Column({ space: Spacing.xs }) {
          Text('共识').fontSize(Typography.size.caption).fontColor(Colors.primary)
          Text(this.meetingResult.summary.consensus).fontSize(Typography.size.caption).fontColor(Colors.textSecondary).lineHeight(18)
        }
        .width('100%').padding(Spacing.md)
        .backgroundColor('rgba(78, 205, 196, 0.08)').borderRadius(BorderRadius.lg)
      }

      if (this.meetingResult && this.meetingResult.summary && this.meetingResult.summary.disagreements && this.meetingResult.summary.disagreements.length > 0) {
        Column({ space: Spacing.xs }) {
          Text('分歧').fontSize(Typography.size.caption).fontColor(Colors.stance.reflective)
          ForEach(this.meetingResult.summary.disagreements, (item: string) => {
            Text(`• ${item}`).fontSize(Typography.size.caption).fontColor(Colors.textPrimary).lineHeight(18)
          }, (item: string) => item)
        }
        .width('100%').padding(Spacing.md)
        .backgroundColor('rgba(139, 92, 246, 0.08)').borderRadius(BorderRadius.lg)
      }

      if (this.meetingResult && this.meetingResult.summary && this.meetingResult.summary.actionableAdvice && this.meetingResult.summary.actionableAdvice.length > 0) {
        Column({ space: Spacing.xs }) {
          Text('行动建议').fontSize(Typography.size.caption).fontColor(Colors.warning)
          ForEach(this.meetingResult.summary.actionableAdvice, (item: string) => {
            Text(`• ${item}`).fontSize(Typography.size.caption).fontColor(Colors.textPrimary).lineHeight(18)
          }, (item: string) => item)
        }
        .width('100%').padding(Spacing.md)
        .backgroundColor('rgba(245, 158, 11, 0.08)').borderRadius(BorderRadius.lg)
      }
    }
    .width('100%').padding(Spacing.lg)
    .backgroundColor(Colors.cardPrimary).borderRadius(BorderRadius.xxl)
  }

  // ---------- 控制按钮 ----------
  @Builder
  controlButtons() {
    Column({ space: Spacing.sm }) {
      if (this.meetingState === 'idle') {
        Button(this.canStartMeeting() ? '🚀 启动讨论' : `已选 ${this.selectedAgentIds.length} 位，还需 ${MIN_PARTICIPANTS - this.selectedAgentIds.length > 0 ? MIN_PARTICIPANTS - this.selectedAgentIds.length : 0} 位`)
          .width('100%').height(48)
          .fontSize(Typography.size.body).fontColor('#FFFFFF')
          .backgroundColor(this.canStartMeeting() ? Colors.primary : Colors.textMuted)
          .borderRadius(BorderRadius.pill)
          .enabled(this.canStartMeeting())
          .onClick(() => { void this.startMeeting() })
      } else if (this.meetingState === 'running') {
        Row({ space: Spacing.sm }) {
          Button('⏹️ 打断')
            .height(44).layoutWeight(1)
            .fontSize(Typography.size.body).fontColor(Colors.error)
            .backgroundColor('rgba(244, 63, 94, 0.08)')
            .borderRadius(BorderRadius.pill)
            .onClick(() => { void this.interruptMeeting() })

          Button('继续')
            .height(44).layoutWeight(1)
            .fontSize(Typography.size.body).fontColor('#FFFFFF')
            .backgroundColor(Colors.primary)
            .borderRadius(BorderRadius.pill)
            .onClick(() => { void this.continueMeeting() })
        }
        .width('100%')
      } else if (this.meetingState === 'paused') {
        Column({ space: Spacing.sm }) {
          Text('⏸️ 讨论已打断').fontSize(Typography.size.body).fontColor(Colors.warning).width('100%').textAlign(TextAlign.Center)

          Row({ space: Spacing.sm }) {
            Button('▶️ 继续讨论')
              .height(44).layoutWeight(1)
              .fontSize(Typography.size.body).fontColor('#FFFFFF')
              .backgroundColor(Colors.primary)
              .borderRadius(BorderRadius.pill)
              .onClick(() => { void this.continueMeeting() })

            Button('重新开始')
              .height(44).layoutWeight(1)
              .fontSize(Typography.size.body).fontColor(Colors.textSecondary)
              .backgroundColor(Colors.cardPrimary)
              .borderRadius(BorderRadius.pill)
              .onClick(() => { this.resetMeeting() })
          }
        }
        .width('100%')
      } else if (this.meetingState === 'completed') {
        Column({ space: Spacing.sm }) {
          Row({ space: Spacing.sm }) {
            Button('📄 查看纪要')
              .height(44).layoutWeight(1)
              .fontSize(Typography.size.body).fontColor('#FFFFFF')
              .backgroundColor(Colors.primary)
              .borderRadius(BorderRadius.pill)
              .onClick(() => { this.goToSummaryDetail() })

            Button('🖼️ 生成海报')
              .height(44).layoutWeight(1)
              .fontSize(Typography.size.body).fontColor(Colors.primary)
              .backgroundColor(Colors.accentPurple)
              .borderRadius(BorderRadius.pill)
              .onClick(() => { this.goToPosterPreview() })
          }

          Button('🔄 再来一轮')
            .height(40).width('100%')
            .fontSize(Typography.size.body).fontColor(Colors.textSecondary)
            .backgroundColor(Colors.cardPrimary)
            .borderRadius(BorderRadius.pill)
            .onClick(() => { this.resetMeeting() })
        }
        .width('100%')
      } else if (this.meetingState === 'error') {
        Button('🔄 重新开始')
          .height(48).width('100%')
          .fontSize(Typography.size.body).fontColor('#FFFFFF')
          .backgroundColor(Colors.primary)
          .borderRadius(BorderRadius.pill)
          .onClick(() => { this.resetMeeting() })
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor(Colors.cardPrimary)
    .borderRadius(BorderRadius.xxl)
  }

  // ============================================
  // 主视图
  // ============================================
  @Builder
  mainView() {
    Column({ space: Spacing.sm }) {
      this.topBar()
      this.segmentControl()

      if (this.activeSegment === 0) {
        this.configSection()
      } else {
        Column() {
          this.liveSection()
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: Spacing.page.horizontal,
      right: Spacing.page.horizontal,
      top: this.topInsetVp() + 12,
      bottom: this.safeBottomVp + Spacing.sm
    })
  }

  // ============================================
  // 页面根组件
  // ============================================
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 背景
      Column() {
        Column().width('100%').height('100%').backgroundColor(Colors.background)
        Column().width(320).height(220).borderRadius(160)
          .backgroundColor('rgba(99, 102, 241, 0.08)').blur(100).position({ x: -120, y: -50 })
        Column().width(280).height(200).borderRadius(140)
          .backgroundColor('rgba(139, 92, 246, 0.06)').blur(80).position({ right: -80, y: 80 })
      }
      .width('100%').height('100%')

      // 主内容
      this.mainView()
    }
    .width('100%').height('100%').backgroundColor(Colors.background)
  }
}
