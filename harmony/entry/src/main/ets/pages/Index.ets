import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import pasteboard from '@ohos.pasteboard'
import promptAction from '@ohos.promptAction'
import {
  ArenaMessage,
  ArenaMode,
  ArenaRunHistoryItem,
  PersonaSpec,
  PresetProfile,
  ProfileBundle,
  SourceDocumentSummary,
  TimelineNode,
  EMPTY_PROFILE
} from '../common/Models'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import { PersonaApi } from '../service/PersonaApi'
import { formatTimeAgo, getAvatarTextColor, getParticipantColor } from '../service/SummaryService'
import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import {
  HeroSection,
  LoadingOverlay,
  ErrorToast,
  RoleCard,
  TabBar,
  RecordsTab,
  RecordItem,
  RoleHomeActionCards,
  ImportForm
} from '../components'

@Entry
@Component
struct Index {
  // 状态管理
  @State profiles: PresetProfile[] = []
  @State customProfiles: PresetProfile[] = []
  @State cachedCustomBundles: ProfileBundle[] = []
  @State selectedProfile: PresetProfile = EMPTY_PROFILE
  @State nodes: TimelineNode[] = []
  @State agents: PersonaSpec[] = []
  @State selectedAgentIds: string[] = []
  @State topic: string = '现在该不该离开这份长期消耗我的工作？'
  @State discussionMode: ArenaMode = 'chat'
  @State messages: ArenaMessage[] = []
  @State summaryTitle: string = ''
  @State consensus: string = ''
  @State disagreements: string[] = []
  @State actionableAdvice: string[] = []
  @State narrativeHook: string = ''
  @State loading: string = ''
  @State error: string = ''
  @State activeTab: number = 0
  @State rolePaneOpacity: number = 1
  @State rolePaneY: number = 0
  @State arenaTitleOpacity: number = 0
  @State arenaTitleY: number = 18
  @State arenaBodyOpacity: number = 0
  @State arenaBodyY: number = 22
  @State recordsPaneOpacity: number = 0
  @State recordsPaneY: number = 16
  @State rolePanel: number = 0
  @State showImportForm: boolean = false
  @State importFormExpanded: boolean = false
  @State importEntryMode: string = 'import'
  @State importName: string = ''
  @State importBio: string = ''
  @State connectionLabel: string = '连接中'
  @State sourceDocument: SourceDocumentSummary | null = null
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State records: RecordItem[] = []

  // 计算属性
  allProfiles(): PresetProfile[] {
    return [...this.profiles, ...this.customProfiles]
  }

  selectedAgents(): PersonaSpec[] {
    return this.agents.filter((agent: PersonaSpec) => this.selectedAgentIds.includes(agent.agentId))
  }

  hasSelectedProfile(): boolean {
    return this.selectedProfile.id.length > 0
  }

  hasSummaryContent(): boolean {
    return this.summaryTitle.length > 0
  }

  // 生命周期
  aboutToAppear(): void {
    void this.hydratePresets()
    this.loadSafeInsets()
    void this.loadMeetingRecords()
  }

  onPageShow(): void {
    void this.loadMeetingRecords()
  }

  loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_e) {
      // 忽略错误，使用默认值
    }
  }

  // 业务方法
  refreshConnectionLabel(): void {
    this.connectionLabel = PersonaApi.getConnectionLabel()
  }

  resetArena(): void {
    this.messages = []
    this.summaryTitle = ''
    this.consensus = ''
    this.disagreements = []
    this.actionableAdvice = []
    this.narrativeHook = ''
  }

  applyBundle(bundle: ProfileBundle): void {
    this.selectedProfile = bundle.profile
    this.nodes = bundle.nodes
    this.agents = bundle.agents
    this.selectedAgentIds = bundle.agents.slice(0, 2).map((agent: PersonaSpec) => agent.agentId)
    this.sourceDocument = bundle.sourceDocument || null
    this.resetArena()

    if (bundle.profile.suggestedTopics.length > 0) {
      this.topic = bundle.profile.suggestedTopics[0]
    }
  }

  cacheCustomBundle(bundle: ProfileBundle): void {
    const nextCache = this.cachedCustomBundles.filter((item: ProfileBundle) => item.profile.id !== bundle.profile.id)
    this.cachedCustomBundles = [...nextCache, bundle]

    const nextProfiles = this.customProfiles.filter((item: PresetProfile) => item.id !== bundle.profile.id)
    this.customProfiles = [...nextProfiles, bundle.profile]
  }

  findCachedCustomBundle(profileId: string): ProfileBundle | null {
    const found = this.cachedCustomBundles.find((bundle: ProfileBundle) => bundle.profile.id === profileId)
    return found ? found : null
  }

  normalizeError(error: Object): string {
    const maybeMessage = error as Record<string, string>
    if (maybeMessage.message) {
      return maybeMessage.message
    }
    return '请求失败，请检查后端或网络设置'
  }

  async hydratePresets(): Promise<void> {
    this.loading = '正在连接后端并加载角色库...'
    this.error = ''

    try {
      const profiles = await PersonaApi.getPresets()
      this.profiles = profiles
      this.refreshConnectionLabel()

      if (profiles.length > 0) {
        await this.selectProfile(profiles[0])
      }
    } catch (error) {
      this.error = this.normalizeError(error as Object)
      this.refreshConnectionLabel()
    } finally {
      this.loading = ''
    }
  }

  async selectProfile(profile: PresetProfile): Promise<void> {
    const cachedCustomBundle = this.findCachedCustomBundle(profile.id)
    if (cachedCustomBundle) {
      this.applyBundle(cachedCustomBundle)
      this.refreshConnectionLabel()
      return
    }

    this.loading = `正在加载 ${profile.displayName} 的时间线与人格体...`
    this.error = ''

    try {
      const bundle = await PersonaApi.getProfileBundle(profile.id)
      this.applyBundle(bundle)
      this.refreshConnectionLabel()
    } catch (error) {
      this.error = this.normalizeError(error as Object)
      this.refreshConnectionLabel()
    } finally {
      this.loading = ''
    }
  }

  toggleAgent(agentId: string): void {
    if (this.selectedAgentIds.includes(agentId)) {
      this.selectedAgentIds = this.selectedAgentIds.filter((item: string) => item !== agentId)
      return
    }

    this.selectedAgentIds = [...this.selectedAgentIds, agentId]
  }

  switchTab(index: number): void {
    if (index === 1) {
      this.arenaTitleOpacity = 0
      this.arenaTitleY = 18
      this.arenaBodyOpacity = 0
      this.arenaBodyY = 22
    } else if (index === 2) {
      this.recordsPaneOpacity = 0
      this.recordsPaneY = 16
    } else if (index === 0) {
      this.rolePaneOpacity = 0
      this.rolePaneY = 14
    }

    animateTo({
      duration: 220,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.activeTab = index
      if (index === 2) {
        void this.loadMeetingRecords()
      }
    })

    if (index === 1) {
      setTimeout(() => {
        animateTo({
          duration: 380,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.arenaTitleOpacity = 1
          this.arenaTitleY = 0
        })
      }, 48)
      setTimeout(() => {
        animateTo({
          duration: 440,
          curve: Curve.Friction
        }, () => {
          this.arenaBodyOpacity = 1
          this.arenaBodyY = 0
        })
      }, 120)
    } else if (index === 2) {
      setTimeout(() => {
        animateTo({
          duration: 400,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.recordsPaneOpacity = 1
          this.recordsPaneY = 0
        })
      }, 40)
    } else if (index === 0) {
      setTimeout(() => {
        animateTo({
          duration: 360,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.rolePaneOpacity = 1
          this.rolePaneY = 0
        })
      }, 0)
    }
  }

  mapHistoryItemToRecord(item: ArenaRunHistoryItem): RecordItem {
    const names = item.participantNames
    const avatarColors = names.map((_n: string, idx: number) => getParticipantColor(idx))
    const avatarTextColors = names.map((_n: string, idx: number) => getAvatarTextColor(idx))
    const title = item.title && item.title.length > 0
      ? item.title
      : (item.summaryTitle && item.summaryTitle.length > 0 ? item.summaryTitle : '会议纪要')
    const content = item.consensusPreview && item.consensusPreview.length > 0
      ? item.consensusPreview
      : (item.consensus && item.consensus.length > 0 ? item.consensus : '')
    const participantLine = names.length > 0 ? names.join(' · ') : '暂无参会者'
    return {
      id: item.runId,
      title: title,
      topic: item.topic,
      participants: names,
      participantLine: participantLine,
      avatarColors: avatarColors,
      avatarTextColors: avatarTextColors,
      content: content,
      timeAgo: item.createdAt ? formatTimeAgo(item.createdAt) : '刚刚',
      accentColor: avatarColors.length > 0 ? avatarColors[0] : Colors.primary,
      messageCount: item.messageCount !== undefined ? item.messageCount : 0,
      highlightCount: 0,
      durationLabel: item.mode === 'debate' ? '辩论' : '对谈',
      isFavorite: false
    }
  }

  async loadMeetingRecords(): Promise<void> {
    try {
      const history = await PersonaApi.getArenaHistory(50)
      this.records = history.runs.map((run: ArenaRunHistoryItem) => this.mapHistoryItemToRecord(run))
      this.refreshConnectionLabel()
    } catch (_error) {
      this.refreshConnectionLabel()
    }
  }

  async handleGenerateShareCard(record: RecordItem): Promise<void> {
    if (record.id.length === 0) {
      this.error = '缺少会议 runId，无法生成卡片'
      return
    }
    this.loading = ''
    this.refreshConnectionLabel()
    router.pushUrl({
      url: 'pages/PosterPreviewPage',
      params: {
        arenaRunId: record.id,
        title: record.title
      }
    })
  }

  openImportSheet(mode: string): void {
    this.importEntryMode = mode
    this.showImportForm = true
    this.importFormExpanded = true
  }

  closeImportSheet(): void {
    this.showImportForm = false
    this.importFormExpanded = false
    this.importName = ''
    this.importBio = ''
  }

  async openTimelineFromCard(profile: PresetProfile): Promise<void> {
    await this.selectProfile(profile)
    this.goProfileDetail()
  }

  async importCustomProfile(): Promise<void> {
    if (!this.importName.trim() || this.importBio.trim().length < 10) {
      this.error = '请输入人物名称，并填写至少 10 个字的传记内容'
      return
    }

    this.loading = `正在解析 ${this.importName} 的时间线并构建人格体...`
    this.error = ''

    try {
      const bundle = await PersonaApi.importCustomProfile(this.importName.trim(), this.importBio.trim())
      this.cacheCustomBundle(bundle)
      this.applyBundle(bundle)
      this.closeImportSheet()
      this.activeTab = 0
      this.refreshConnectionLabel()
    } catch (error) {
      this.error = this.normalizeError(error as Object)
      this.refreshConnectionLabel()
    } finally {
      this.loading = ''
    }
  }

  async runDiscussion(): Promise<void> {
    const participants = this.selectedAgents()
    if (participants.length < 2) {
      this.error = '至少选择 2 个阶段人格进入议会'
      return
    }

    this.loading = '阶段人格正在会议中，请稍候...'
    this.error = ''

    try {
      const result = await PersonaApi.runArena(this.topic, participants, this.discussionMode)
      this.messages = result.messages
      this.summaryTitle = result.summary.title
      this.consensus = result.summary.consensus
      this.disagreements = result.summary.disagreements
      this.actionableAdvice = result.summary.actionableAdvice
      this.narrativeHook = result.summary.narrativeHook
      this.refreshConnectionLabel()
      void this.loadMeetingRecords()
    } catch (error) {
      this.error = this.normalizeError(error as Object)
      this.refreshConnectionLabel()
    } finally {
      this.loading = ''
    }
  }

  goProfileDetail(): void {
    router.pushUrl({
      url: 'pages/ProfileDetail',
      params: {
        profileId: this.selectedProfile.id,
        selectedAgentIds: this.selectedAgentIds.join(',')
      }
    })
  }

  handleRetry(): void {
    void this.hydratePresets()
  }

  // Tab 内容构建器
  @Builder
  buildRoleTab() {
    Column({ space: Spacing.card.large }) {
      RoleHomeActionCards({
        onCreateClick: () => {
          router.pushUrl({ url: 'pages/CreateRole' })
        },
        onImportClick: () => {
          this.openImportSheet('import')
        },
        onExploreClick: () => {
          router.pushUrl({ url: 'pages/ExplorePersonas' })
        }
      })

      if (this.showImportForm) {
        ImportForm({
          isExpanded: this.importFormExpanded,
          name: this.importName,
          bio: this.importBio,
          isLoading: this.loading.length > 0,
          importMode: this.importEntryMode,
          showCloseButton: true,
          onNameChange: (value: string) => {
            this.importName = value
          },
          onBioChange: (value: string) => {
            this.importBio = value
          },
          onSubmit: () => {
            void this.importCustomProfile()
          },
          onToggle: () => {
            this.importFormExpanded = !this.importFormExpanded
          },
          onClose: () => {
            this.closeImportSheet()
          }
        })
      }

      Column({ space: Spacing.md }) {
        Row() {
          Text(`已收集的切片 (${this.allProfiles().length})`)
            .fontSize(Typography.size.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textMuted)
            .letterSpacing(0.5)
        }
        .width('100%')

        Column({ space: Spacing.card.medium }) {
          ForEach(this.allProfiles(), (profile: PresetProfile, index: number) => {
            RoleCard({
              profile: profile,
              isActive: this.selectedProfile.id === profile.id,
              index: index,
              onCardClick: (p: PresetProfile) => {
                void this.selectProfile(p)
              },
              onViewTimeline: () => {
                void this.openTimelineFromCard(profile)
              }
            })
          }, (profile: PresetProfile) => profile.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.rolePaneOpacity)
    .translate({ y: this.rolePaneY })
    .animation({
      duration: 360,
      curve: Curve.FastOutSlowIn
    })
  }

  @Builder
  buildArenaTab() {
    Column({ space: Spacing.card.large }) {
      Column({ space: Spacing.sm }) {
        Text('人格会议')
          .fontSize(Typography.size.xxl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)

        Text('选择人物的不同人生阶段人格，让他们围绕议题展开讨论，汇聚多元观点。')
          .fontSize(Typography.size.bodyLg)
          .fontColor(Colors.textTertiary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .opacity(this.arenaTitleOpacity)
      .translate({ y: this.arenaTitleY })
      .animation({
        duration: 400,
        curve: Curve.FastOutSlowIn
      })

      Column({ space: Spacing.md }) {
        if (this.selectedProfile.id.length > 0) {
          Column({ space: Spacing.md }) {
            Text(`当前人物：${this.selectedProfile.displayName}`)
              .fontSize(Typography.size.bodyLg)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.textPrimary)

            Text(`可选人格阶段：${this.agents.length} 个`)
              .fontSize(Typography.size.body)
              .fontColor(Colors.textSecondary)
          }
          .width('100%')
          .padding(Spacing.card.large)
          .backgroundColor(Colors.cardPrimary)
          .borderRadius(BorderRadius.huge)
        }

        Button('开始人格会议')
          .width('100%')
          .height(46)
          .fontSize(Typography.size.bodyLg)
          .fontColor('#FFFFFF')
          .backgroundColor(Colors.primary)
          .borderRadius(BorderRadius.huge)
          .stateEffect(true)
          .enabled(this.selectedProfile.id.length > 0)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/MeetingParticipantPage',
              params: {
                profileId: this.selectedProfile.id,
                profileIds: this.selectedProfile.id,
                selectedAgentIds: this.selectedAgentIds.join(','),
                topic: this.topic
              }
            })
          })

        Button('进入角色详情')
          .width('100%')
          .height(40)
          .fontSize(Typography.size.body)
          .fontColor(Colors.primary)
          .backgroundColor(Colors.accentPurple)
          .borderRadius(BorderRadius.huge)
          .stateEffect(true)
          .enabled(this.selectedProfile.id.length > 0)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/ProfileDetail',
              params: {
                profileId: this.selectedProfile.id,
                selectedAgentIds: this.selectedAgentIds.join(',')
              }
            })
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .opacity(this.arenaBodyOpacity)
      .translate({ y: this.arenaBodyY })
      .animation({
        duration: 440,
        curve: Curve.Friction
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRecordsTab() {
    Column() {
      RecordsTab({
        records: this.records,
        onRecordClick: (record: RecordItem) => {
          router.pushUrl({
            url: 'pages/SummaryDetailPage',
            params: { arenaRunId: record.id }
          })
        },
        onGenerateCard: (record: RecordItem) => {
          void this.handleGenerateShareCard(record)
        },
        onGenerateVideo: (_record: RecordItem) => {
          try {
            void promptAction.openToast({ message: '会议视频入口开发中，可先使用「生成卡片」或详情页导出' })
          } catch (_e) {
          }
        },
        onShareRecord: (record: RecordItem) => {
          router.pushUrl({
            url: 'pages/SummaryDetailPage',
            params: { arenaRunId: record.id, openSheet: 'share' }
          })
        },
        onViewAll: () => {
          router.pushUrl({ url: 'pages/SummaryListPage' })
        }
      })
    }
    .width('100%')
    .opacity(this.recordsPaneOpacity)
    .translate({ y: this.recordsPaneY })
    .animation({
      duration: 400,
      curve: Curve.FastOutSlowIn
    })
  }

  // 主构建方法
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 背景装饰 - 多层次渐变背景
      Stack() {
        // 底层：基础渐变
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#F8FAFC')

        // 左上角主色光晕
        Column()
          .width(280)
          .height(280)
          .borderRadius(140)
          .backgroundColor('#EEF2FF')
          .blur(80)
          .position({ x: -120, y: -80 })

        // 左上角装饰圆
        Column()
          .width(120)
          .height(120)
          .borderRadius(60)
          .backgroundColor('rgba(99, 102, 241, 0.12)')
          .blur(40)
          .position({ x: -30, y: 20 })

        // 右上角靛蓝光晕
        Column()
          .width(320)
          .height(320)
          .borderRadius(160)
          .backgroundColor('rgba(139, 92, 246, 0.08)')
          .blur(100)
          .position({ right: -120, y: 40 })

        // 右上角装饰圆
        Column()
          .width(100)
          .height(100)
          .borderRadius(50)
          .backgroundColor('rgba(165, 180, 252, 0.2)')
          .blur(30)
          .position({ right: 20, y: 100 })

        // 底部玫瑰色光晕
        Column()
          .width(360)
          .height(360)
          .borderRadius(180)
          .backgroundColor('rgba(254, 205, 211, 0.15)')
          .blur(120)
          .position({ left: -60, bottom: -100 })

        // 底部第二个光晕
        Column()
          .width(200)
          .height(200)
          .borderRadius(100)
          .backgroundColor('rgba(16, 185, 129, 0.06)')
          .blur(60)
          .position({ right: 40, bottom: 80 })

        // 右上角小装饰
        Column()
          .width(60)
          .height(60)
          .borderRadius(30)
          .backgroundColor('rgba(245, 158, 11, 0.1)')
          .blur(20)
          .position({ right: 60, y: 200 })
      }
      .width('100%')
      .height('100%')

      // 主内容区域
      Column({ space: Spacing.md }) {
        Scroll() {
          Column({ space: Spacing.md }) {
            // 头部
            HeroSection({
              selectedProfileName: this.selectedProfile.displayName,
              connectionLabel: this.connectionLabel
            })

            // 加载状态
            LoadingOverlay({
              message: this.loading
            })

            // 错误提示
            ErrorToast({
              message: this.error,
              onRetry: () => {
                this.handleRetry()
              }
            })

            // Tab 内容
            if (this.activeTab === 0) {
              this.buildRoleTab()
            } else if (this.activeTab === 1) {
              this.buildArenaTab()
            } else {
              this.buildRecordsTab()
            }
          }
          .padding({
            left: Spacing.page.horizontal,
            right: Spacing.page.horizontal,
            top: this.safeTopVp,
            bottom: 80 + this.safeBottomVp
          })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      // 底部导航
      TabBar({
        activeIndex: this.activeTab,
        safeBottomVp: this.safeBottomVp,
        onTabChange: (index: number) => {
          this.switchTab(index)
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.background)
  }
}
