import { ArenaMessage, ArenaMode, PersonaSpec, PresetProfile, ProfileBundle, SourceDocumentSummary, TimelineNode, EMPTY_PROFILE } from '../common/Models'
import { PersonaApi } from '../service/PersonaApi'

@Entry
@Component
struct Index {
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
  @State rolePanel: number = 0
  @State showImportForm: boolean = false
  @State importName: string = ''
  @State importBio: string = ''
  @State connectionLabel: string = 'CONNECTING'
  @State sourceDocumentTitle: string = ''
  @State sourceDocumentAuthor: string = ''
  @State sourceDocumentMeta: string = ''

  aboutToAppear(): void {
    void this.hydratePresets()
  }

  allProfiles(): PresetProfile[] {
    return [...this.profiles, ...this.customProfiles]
  }

  selectedAgents(): PersonaSpec[] {
    return this.agents.filter((agent: PersonaSpec) => this.selectedAgentIds.includes(agent.agentId))
  }

  hasActiveProfile(profileId: string): boolean {
    return this.selectedProfile.id === profileId
  }

  agentAt(index: number): PersonaSpec | null {
    if (index < 0 || index >= this.agents.length) {
      return null
    }
    return this.agents[index]
  }

  isNodeSelected(index: number): boolean {
    const agent = this.agentAt(index)
    return agent ? this.selectedAgentIds.includes(agent.agentId) : false
  }

  isDiscussionMode(mode: ArenaMode): boolean {
    return this.discussionMode === mode
  }

  isActiveTab(index: number): boolean {
    return this.activeTab === index
  }

  isRolePanel(index: number): boolean {
    return this.rolePanel === index
  }

  hasSelectedProfile(): boolean {
    return this.selectedProfile.id.length > 0
  }

  hasSourceDocumentInfo(): boolean {
    return this.sourceDocumentTitle.length > 0
  }

  hasSummaryContent(): boolean {
    return this.summaryTitle.length > 0
  }

  switchRolePanel(index: number): void {
    this.rolePanel = index
  }

  currentPageLabel(): string {
    if (this.activeTab === 0) {
      return this.isRolePanel(0) ? '人物选择' : '阶段人格'
    }
    if (this.activeTab === 1) {
      return '议会'
    }
    return '纪要'
  }

  currentPageDescription(): string {
    if (this.activeTab === 0) {
      if (!this.hasSelectedProfile()) {
        return '先选择人物，再进入阶段人格面板完成议会编组。'
      }
      return this.isRolePanel(0)
        ? `当前人物：${this.selectedProfile.displayName}，先看摘要与议题，再进入阶段人格。`
        : `为 ${this.selectedProfile.displayName} 选择 2 到 3 个阶段人格进入议会。`
    }
    if (this.activeTab === 1) {
      return this.hasSelectedProfile()
        ? `${this.selectedProfile.displayName} 的阶段议会已经就绪，输入议题后即可开始。`
        : '先在角色页完成编组，再来这里发起讨论。'
    }
    return this.hasSummaryContent()
      ? '议会已经生成纪要，可在这里快速回看共识、分歧与行动建议。'
      : '纪要页承接议会结果，在移动端只保留最关键的输出。'
  }

  normalizeError(error: Object): string {
    const maybeMessage = error as Record<string, string>
    if (maybeMessage.message) {
      return maybeMessage.message
    }
    return '请求失败，请检查后端或网络设置'
  }

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

  applySourceDocument(sourceDocument?: SourceDocumentSummary | null): void {
    this.sourceDocumentTitle = sourceDocument && sourceDocument.title ? sourceDocument.title : ''
    this.sourceDocumentAuthor = sourceDocument && sourceDocument.author ? sourceDocument.author : ''

    if (sourceDocument && sourceDocument.sectionCount > 0) {
      this.sourceDocumentMeta = `${sourceDocument.sectionCount} sections`
      return
    }

    this.sourceDocumentMeta = ''
  }

  applyBundle(bundle: ProfileBundle): void {
    this.selectedProfile = bundle.profile
    this.nodes = bundle.nodes
    this.agents = bundle.agents
    this.selectedAgentIds = bundle.agents.slice(0, 2).map((agent: PersonaSpec) => agent.agentId)
    this.applySourceDocument(bundle.sourceDocument)
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

    if (this.selectedAgentIds.length >= 3) {
      this.selectedAgentIds = [...this.selectedAgentIds.slice(1), agentId]
      return
    }

    this.selectedAgentIds = [...this.selectedAgentIds, agentId]
  }

  switchTab(index: number): void {
    this.activeTab = index
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
      this.showImportForm = false
      this.importName = ''
      this.importBio = ''
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
    } catch (error) {
      this.error = this.normalizeError(error as Object)
      this.refreshConnectionLabel()
    } finally {
      this.loading = ''
    }
  }

  stageColor(stageType: string): string {
    if (stageType === 'early') {
      return '#00E5FF'
    }
    if (stageType === 'turning-point') {
      return '#48E3C2'
    }
    if (stageType === 'crisis') {
      return '#FF5A76'
    }
    if (stageType === 'rebuild') {
      return '#9C5CFF'
    }
    if (stageType === 'peak') {
      return '#FFD166'
    }
    return '#8A90A4'
  }

  stanceColor(stance: string): string {
    if (stance === 'support') {
      return '#00E5FF'
    }
    if (stance === 'oppose') {
      return '#FF5A76'
    }
    if (stance === 'reflective') {
      return '#9C5CFF'
    }
    return '#8A90A4'
  }

  @Builder
  buildHeroSection() {
    Column({ space: 10 }) {
      Text('TIME PERSONA / HARMONY')
        .fontSize(12)
        .fontColor('#00E5FF')
        .letterSpacing(2.4)

      Text('时序人格局')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F6F8FF')

      Text(this.selectedProfile.id.length > 0
        ? `${this.selectedProfile.displayName} · 三段移动工作台`
        : '用底部三按钮切换角色、议会与纪要，保留 web 版三栏工作台的职责拆分。')
        .fontSize(14)
        .fontColor('#98A2B3')
        .lineHeight(22)

      Row({ space: 8 }) {
        Text(this.connectionLabel)
          .fontSize(11)
          .fontColor('#DDE6FF')
          .maxLines(1)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#141B25')
          .borderRadius(99)

        Text('MOBILE WORKBENCH')
          .fontSize(11)
          .fontColor('#9C5CFF')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#191327')
          .borderRadius(99)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor('#CC11131A')
    .borderRadius(28)
  }

  @Builder
  buildErrorCard() {
    if (this.error.length > 0) {
      Text(this.error)
        .width('100%')
        .fontSize(13)
        .fontColor('#FF8EA1')
        .lineHeight(20)
        .padding(16)
        .backgroundColor('#24121A')
        .borderRadius(20)
    }
  }

  @Builder
  buildLoadingCard() {
    if (this.loading.length > 0) {
      Text(this.loading)
        .width('100%')
        .fontSize(13)
        .fontColor('#8BE9FF')
        .lineHeight(20)
        .padding(16)
        .backgroundColor('#101A22')
        .borderRadius(20)
    }
  }

  @Builder
  buildRoleCard(profile: PresetProfile) {
    Button() {
      Column({ space: 10 }) {
        Row() {
          Text(profile.category.toUpperCase())
            .fontSize(11)
            .fontColor(this.hasActiveProfile(profile.id) ? '#00E5FF' : '#7B8497')
          Blank()
          Text(profile.coverSeed)
            .fontSize(11)
            .fontColor('#667085')
        }
        .width('100%')

        Text(profile.displayName)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6F8FF')

        Text(profile.subtitle)
          .fontSize(13)
          .fontColor('#C6A4FF')

        Text(profile.biography)
          .fontSize(13)
          .fontColor('#AAB3C5')
          .lineHeight(20)
          .maxLines(4)

        if (profile.highlights.length > 0) {
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            ForEach(profile.highlights.slice(0, 4), (item: string) => {
              Text(item)
                .fontSize(11)
                .fontColor('#D6DCE7')
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor('#171B24')
                .borderRadius(99)
                .margin({ right: 8, bottom: 8 })
            }, (item: string) => item)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.hasActiveProfile(profile.id) ? '#151C25' : '#10131A')
      .borderRadius(24)
    }
    .width('100%')
    .backgroundColor('#00000000')
    .borderRadius(24)
    .onClick(() => {
      void this.selectProfile(profile)
    })
  }

  @Builder
  buildTimelineNode(node: TimelineNode, index: number) {
    Button() {
      Column({ space: 10 }) {
        Row() {
          Text(`${index + 1}`)
            .fontSize(11)
            .fontColor('#F6F8FF')
            .width(26)
            .height(26)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.stageColor(node.stageType))
            .borderRadius(13)

          Text(node.timeLabel + (node.ageLabel ? ` · ${node.ageLabel}` : ''))
            .fontSize(12)
            .fontColor('#98A2B3')
            .margin({ left: 10 })

          Blank()

          Text(this.isNodeSelected(index) ? 'IN' : 'ADD')
            .fontSize(11)
            .fontColor(this.isNodeSelected(index) ? '#00E5FF' : '#667085')
        }
        .width('100%')

        Text(node.stageLabel)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6F8FF')

        Text(node.keyEvent)
          .fontSize(13)
          .fontColor('#D7DEEA')
          .lineHeight(20)

        Text(node.summary)
          .fontSize(12)
          .fontColor('#98A2B3')
          .lineHeight(20)
          .maxLines(3)

        if (this.agentAt(index)) {
          Text(this.isNodeSelected(index) ? '点击移出议会' : '点击接入议会')
            .fontSize(12)
            .fontColor(this.isNodeSelected(index) ? '#00E5FF' : '#C6A4FF')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(18)
      .backgroundColor(this.isNodeSelected(index) ? '#151E28' : '#10131A')
      .borderRadius(22)
    }
    .width('100%')
    .backgroundColor('#00000000')
    .onClick(() => {
      const nodeAgent = this.agentAt(index)
      if (nodeAgent) {
        this.toggleAgent(nodeAgent.agentId)
      }
    })
  }

  @Builder
  buildRoleTab() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row() {
          Text('ROLE / SOURCE')
            .fontSize(12)
            .fontColor('#00E5FF')
            .letterSpacing(2)

          Blank()

          Button(this.showImportForm ? '收起导入' : '导入传记')
            .height(36)
            .backgroundColor('#171B24')
            .fontColor('#F6F8FF')
            .borderRadius(99)
            .onClick(() => {
              this.showImportForm = !this.showImportForm
            })
        }
        .width('100%')

        if (this.showImportForm) {
          Column({ space: 10 }) {
            Text('自定义人物导入')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F6F8FF')

            Text('这里直接走后端的 parse -> build 链路，生成时间线节点与阶段人格。')
              .fontSize(13)
              .fontColor('#98A2B3')
              .lineHeight(20)

            TextInput({ text: this.importName, placeholder: '人物名称' })
              .backgroundColor('#0A0D12')
              .borderRadius(16)
              .fontColor('#F6F8FF')
              .placeholderColor('#667085')
              .onChange((value: string) => {
                this.importName = value
              })

            TextArea({ text: this.importBio, placeholder: '粘贴人物背景、传记或经历摘要' })
              .backgroundColor('#0A0D12')
              .borderRadius(16)
              .fontColor('#F6F8FF')
              .placeholderColor('#667085')
              .height(180)
              .onChange((value: string) => {
                this.importBio = value
              })

            Button('解析传记并生成阶段人格')
              .width('100%')
              .height(46)
              .backgroundColor('#171F2A')
              .fontColor('#00E5FF')
              .borderRadius(99)
              .onClick(() => {
                void this.importCustomProfile()
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .backgroundColor('#CC11131A')
          .borderRadius(24)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      ForEach(this.allProfiles(), (profile: PresetProfile) => {
        this.buildRoleCard(profile)
      }, (profile: PresetProfile) => profile.id)

      if (this.selectedProfile.id.length > 0) {
        Column({ space: 14 }) {
          Text('TIMELINE / SELECT AGENTS')
            .fontSize(12)
            .fontColor('#00E5FF')
            .letterSpacing(2)

          Text(this.selectedProfile.displayName)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F6F8FF')

          Text(this.selectedProfile.biography)
            .fontSize(13)
            .fontColor('#AAB3C5')
            .lineHeight(21)

          if (this.selectedProfile.suggestedTopics.length > 0) {
            Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
              ForEach(this.selectedProfile.suggestedTopics.slice(0, 4), (item: string) => {
                Button(item)
                  .height(34)
                  .backgroundColor('#171B24')
                  .fontColor('#C6A4FF')
                  .borderRadius(99)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => {
                    this.topic = item
                    this.activeTab = 1
                  })
              }, (item: string) => item)
            }
            .width('100%')
          }

          Row() {
            Text(`已接入 ${this.selectedAgentIds.length} / 3`)
              .fontSize(13)
              .fontColor('#98A2B3')
            Blank()
            Button('进入议会')
              .height(38)
              .backgroundColor('#00E5FF')
              .fontColor('#041017')
              .borderRadius(99)
              .enabled(this.selectedAgentIds.length >= 2)
              .opacity(this.selectedAgentIds.length >= 2 ? 1 : 0.45)
              .onClick(() => {
                this.activeTab = 1
              })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#CC11131A')
        .borderRadius(24)

        ForEach(this.nodes, (node: TimelineNode, index: number) => {
          this.buildTimelineNode(node, index)
        }, (node: TimelineNode) => node.nodeId)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildModeButton(label: string, mode: ArenaMode) {
    Button(label)
      .height(34)
      .backgroundColor(this.isDiscussionMode(mode) ? '#00E5FF' : '#171B24')
      .fontColor(this.isDiscussionMode(mode) ? '#041017' : '#D6DCE7')
      .borderRadius(99)
      .onClick(() => {
        this.discussionMode = mode
      })
  }

  @Builder
  buildArenaTab() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Text('ARENA / COUNCIL')
          .fontSize(12)
          .fontColor('#00E5FF')
          .letterSpacing(2)

        Text(this.selectedProfile.id.length > 0 ? `${this.selectedProfile.displayName} 的阶段议会` : '先去角色页选择人物')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6F8FF')

        Text('默认人物直接读取 /api/profiles/:id，自定义人物走 parse + build，再把 2 到 3 个 agent 带进 arena。')
          .fontSize(13)
          .fontColor('#98A2B3')
          .lineHeight(20)

        Row({ space: 8 }) {
          this.buildModeButton('CHAT', 'chat')
          this.buildModeButton('DEBATE', 'debate')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor('#CC11131A')
      .borderRadius(24)

      Column({ space: 12 }) {
        Text('已接入人格')
          .fontSize(14)
          .fontColor('#98A2B3')

        if (this.selectedAgents().length > 0) {
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            ForEach(this.selectedAgents(), (agent: PersonaSpec) => {
              Column({ space: 4 }) {
                Text(agent.stageLabel)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#F6F8FF')

                Text(agent.timeLabel)
                  .fontSize(11)
                  .fontColor('#98A2B3')
              }
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor('#161B24')
              .borderRadius(18)
              .margin({ right: 8, bottom: 8 })
            }, (agent: PersonaSpec) => agent.agentId)
          }
          .width('100%')
        } else {
          Text('去角色页选择至少 2 个阶段人格后，这里会显示参会阵容。')
            .fontSize(13)
            .fontColor('#98A2B3')
            .lineHeight(20)
        }

        TextArea({ text: this.topic, placeholder: '输入议题，例如：现在该不该继续创业？' })
          .backgroundColor('#0A0D12')
          .borderRadius(18)
          .fontColor('#F6F8FF')
          .placeholderColor('#667085')
          .height(150)
          .onChange((value: string) => {
            this.topic = value
          })

        Button('启动议会')
          .width('100%')
          .height(48)
          .backgroundColor('#00E5FF')
          .fontColor('#041017')
          .borderRadius(99)
          .enabled(this.selectedAgents().length >= 2 && this.loading.length === 0)
          .opacity(this.selectedAgents().length >= 2 && this.loading.length === 0 ? 1 : 0.45)
          .onClick(() => {
            void this.runDiscussion()
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor('#CC11131A')
      .borderRadius(24)

      if (this.messages.length > 0) {
        ForEach(this.messages, (message: ArenaMessage) => {
          Column({ space: 10 }) {
            Row() {
              Text(message.stageLabel)
                .fontSize(12)
                .fontColor(this.stanceColor(message.stance))
              Blank()
              Text(message.displayName)
                .fontSize(11)
                .fontColor('#667085')
            }
            .width('100%')

            Text(message.content)
              .fontSize(14)
              .fontColor('#E7EBF4')
              .lineHeight(22)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .backgroundColor('#10131A')
          .borderRadius(22)
        }, (message: ArenaMessage) => message.id)
      } else {
        Column({ space: 10 }) {
          Text('等待启动')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F6F8FF')

          Text('这里承接 web 中间栏的对话流。点击“启动议会”后，会直接渲染 `/api/arena/run` 返回的 messages。')
            .fontSize(13)
            .fontColor('#98A2B3')
            .lineHeight(20)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#CC11131A')
        .borderRadius(24)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSummaryTab() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Text('EXPORT / SUMMARY')
          .fontSize(12)
          .fontColor('#00E5FF')
          .letterSpacing(2)

        Text('会议纪要与来源')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6F8FF')

        Text('这里承接 web 右栏的导出角色。当前先把 summary、推荐动作和源文档信息放进移动端纪要面板。')
          .fontSize(13)
          .fontColor('#98A2B3')
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor('#CC11131A')
      .borderRadius(24)

      if (this.sourceDocumentTitle.length > 0) {
        Column({ space: 8 }) {
          Text('SOURCE DOCUMENT')
            .fontSize(12)
            .fontColor('#9C5CFF')
            .letterSpacing(2)

          Text(this.sourceDocumentTitle)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F6F8FF')

          if (this.sourceDocumentAuthor.length > 0) {
            Text(this.sourceDocumentAuthor)
              .fontSize(13)
              .fontColor('#D6DCE7')
          }

          if (this.sourceDocumentMeta.length > 0) {
            Text(this.sourceDocumentMeta)
              .fontSize(12)
              .fontColor('#98A2B3')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor('#151025')
        .borderRadius(22)
      }

      if (this.summaryTitle.length > 0) {
        Column({ space: 12 }) {
          Text(this.summaryTitle)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F6F8FF')

          Text(this.consensus)
            .fontSize(14)
            .fontColor('#D6DCE7')
            .lineHeight(22)

          Text('主要分歧')
            .fontSize(14)
            .fontColor('#98A2B3')
          ForEach(this.disagreements, (item: string) => {
            Text(`• ${item}`)
              .fontSize(13)
              .fontColor('#E7EBF4')
              .lineHeight(21)
          }, (item: string) => item)

          Text('行动建议')
            .fontSize(14)
            .fontColor('#98A2B3')
          ForEach(this.actionableAdvice, (item: string) => {
            Text(`• ${item}`)
              .fontSize(13)
              .fontColor('#E7EBF4')
              .lineHeight(21)
          }, (item: string) => item)

          Text(`“${this.narrativeHook}”`)
            .fontSize(13)
            .fontColor('#D8C1FF')
            .lineHeight(21)
            .padding(14)
            .backgroundColor('#191327')
            .borderRadius(18)

          Row({ space: 10 }) {
            Button('回到议会')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#00E5FF')
              .fontColor('#041017')
              .borderRadius(99)
              .onClick(() => {
                this.activeTab = 1
              })

            Button('换角色')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#171B24')
              .fontColor('#F6F8FF')
              .borderRadius(99)
              .onClick(() => {
                this.activeTab = 0
              })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#CC11131A')
        .borderRadius(24)
      } else {
        Column({ space: 10 }) {
          Text('暂无纪要')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F6F8FF')

          Text('启动一次议会后，这里会直接显示 `/api/arena/run` 返回的 summary。')
            .fontSize(13)
            .fontColor('#98A2B3')
            .lineHeight(20)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#CC11131A')
        .borderRadius(24)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTabButton(label: string, caption: string, index: number) {
    Button() {
      Column({ space: 4 }) {
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isActiveTab(index) ? '#041017' : '#E7EBF4')

        Text(caption)
          .fontSize(10)
          .fontColor(this.isActiveTab(index) ? '#0B3B47' : '#667085')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(56)
    .backgroundColor(this.isActiveTab(index) ? '#00E5FF' : '#10131A')
    .borderRadius(18)
    .onClick(() => {
      this.switchTab(index)
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 16 }) {
        Scroll() {
          Column({ space: 16 }) {
            this.buildHeroSection()
            this.buildLoadingCard()
            this.buildErrorCard()

            if (this.activeTab === 0) {
              this.buildRoleTab()
            } else if (this.activeTab === 1) {
              this.buildArenaTab()
            } else {
              this.buildSummaryTab()
            }
          }
          .padding({ left: 16, right: 16, top: 16, bottom: 112 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor('#050508')

      Row({ space: 10 }) {
        this.buildTabButton('角色', 'ROLE', 0)
        this.buildTabButton('议会', 'ARENA', 1)
        this.buildTabButton('纪要', 'EXPORT', 2)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 18 })
      .backgroundColor('#F2050508')
    }.width('100%')
    .height('100%')
  }
}
