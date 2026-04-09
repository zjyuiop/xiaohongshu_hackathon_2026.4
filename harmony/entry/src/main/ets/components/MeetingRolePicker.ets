import { PersonaSpec } from '../common/Models'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'

interface FusionPreview {
  id: string
  label: string
  signature: string
  accent: string
  members: string[]
}

@Component
export struct MeetingRolePicker {
  @Prop agents: PersonaSpec[] = []
  @Prop selectedAgentIds: string[] = []
  @State conversationAgentIds: string[] = []
  @State fusedRoles: FusionPreview[] = []
  @State conversationHovering: boolean = false
  @State infoDialogVisible: boolean = false
  @State infoDialogTitle: string = ''
  @State infoDialogBody: string = ''

  onToggleAgent: (agentId: string) => void = () => {}
  onStartDiscussion: (agentIds: string[]) => void = () => {}
  onAddRole: () => void = () => {}

  private readonly roleDragTag: string = 'role-orb'
  private readonly conversationDropTag: string = 'conversation-role-slot'

  private openInfoDialog(title: string, body: string): void {
    this.infoDialogTitle = title
    this.infoDialogBody = body
    this.infoDialogVisible = true
  }

  private closeInfoDialog(): void {
    this.infoDialogVisible = false
  }

  private selectedCount(): number {
    return this.selectedAgentIds.length
  }

  private isSelected(agentId: string): boolean {
    return this.selectedAgentIds.includes(agentId)
  }

  private isInConversation(agentId: string): boolean {
    return this.conversationAgentIds.includes(agentId)
  }

  private selectedOrder(agentId: string): number {
    return this.selectedAgentIds.indexOf(agentId)
  }

  private getSelectedAgents(): PersonaSpec[] {
    const selectedAgents: PersonaSpec[] = []
    this.selectedAgentIds.forEach((agentId: string) => {
      const agent = this.agents.find((item: PersonaSpec) => item.agentId === agentId)
      if (agent) {
        selectedAgents.push(agent)
      }
    })
    return selectedAgents
  }

  private getConversationAgents(): PersonaSpec[] {
    const agents: PersonaSpec[] = []
    this.conversationAgentIds.forEach((agentId: string) => {
      const agent = this.agents.find((item: PersonaSpec) => item.agentId === agentId)
      if (agent) {
        agents.push(agent)
      }
    })
    return agents
  }

  private getAgentInitial(agent: PersonaSpec): string {
    return agent.displayName.length > 0 ? agent.displayName.substring(0, 1) : '?'
  }

  private getAgentAccent(agentId: string): string {
    const order = this.selectedOrder(agentId)
    if (order === 0) {
      return MintColors.mintDark
    }
    if (order === 1) {
      return MintColors.lavenderDark
    }
    if (order === 2) {
      return MintColors.warning
    }
    return '#7BA6F7'
  }

  private getAgentTone(agentId: string): string {
    const order = this.selectedOrder(agentId)
    if (order === 0) {
      return 'rgba(78, 205, 196, 0.10)'
    }
    if (order === 1) {
      return 'rgba(184, 169, 217, 0.12)'
    }
    if (order === 2) {
      return 'rgba(232, 184, 109, 0.14)'
    }
    return 'rgba(123, 166, 247, 0.12)'
  }

  private getSelectionHelpText(): string {
    if (this.selectedCount() === 0) {
      return '先从下方候选角色里点选人物，加入上方角色区。'
    }
    if (this.selectedCount() < 2) {
      return '再加入 1 位角色，就可以开始多人对话。'
    }
    return '把一个角色圆拖到另一个角色圆上，就会直接生成新的融合角色预览；拖到下方对话区则进入讨论阵容。'
  }

  private getConversationHelpText(): string {
    if (this.getConversationAgents().length >= 2) {
      return '对话阵容已就绪，点击按钮即可开始讨论。'
    }
    return '把上方已选角色拖入对话平台，至少放入 2 位角色。'
  }

  private toggleConversationAgent(agentId: string): void {
    if (!this.isSelected(agentId)) {
      return
    }

    if (this.isInConversation(agentId)) {
      this.conversationAgentIds = this.conversationAgentIds.filter((id: string) => id !== agentId)
      return
    }

    this.conversationAgentIds = [...this.conversationAgentIds, agentId]
  }

  private startConversation(): void {
    const ids = this.getConversationAgents().map((agent: PersonaSpec) => agent.agentId)
    if (ids.length < 2) {
      return
    }
    this.onStartDiscussion(ids)
  }

  private encodeDragPayload(agentId: string): string {
    return `agent:${agentId}`
  }

  private decodeDragPayload(extraParams?: string): string {
    if (!extraParams || !extraParams.startsWith('agent:')) {
      return ''
    }
    return extraParams.substring(6)
  }

  private removeAgentFromLocalAreas(agentId: string): void {
    this.conversationAgentIds = this.conversationAgentIds.filter((id: string) => id !== agentId)
  }

  private toggleAgentSelection(agentId: string): void {
    const selected = this.isSelected(agentId)
    this.onToggleAgent(agentId)
    if (selected) {
      this.removeAgentFromLocalAreas(agentId)
    }
  }

  private openAddRolePage(): void {
    this.onAddRole()
  }

  private createFusionRole(sourceId: string, targetId: string): void {
    if (sourceId.length === 0 || targetId.length === 0 || sourceId === targetId) {
      return
    }

    const source = this.agents.find((item: PersonaSpec) => item.agentId === sourceId)
    const target = this.agents.find((item: PersonaSpec) => item.agentId === targetId)
    if (!source || !target || !this.isSelected(sourceId) || !this.isSelected(targetId)) {
      return
    }

    const members = [target, source]
    const signature = members.map((agent: PersonaSpec) => this.getAgentInitial(agent)).join('')
    const label = `${target.stageLabel} × ${source.stageLabel}`
    const preview: FusionPreview = {
      id: `fusion-${Date.now()}`,
      label,
      signature,
      accent: this.getAgentAccent(targetId),
      members: [targetId, sourceId]
    }

    const duplicateIndex = this.fusedRoles.findIndex((item: FusionPreview) => {
      return item.members.length === 2 &&
        item.members.includes(sourceId) &&
        item.members.includes(targetId)
    })
    if (duplicateIndex >= 0) {
      const nextRoles = [...this.fusedRoles]
      nextRoles.splice(duplicateIndex, 1)
      this.fusedRoles = [preview, ...nextRoles].slice(0, 4)
      return
    }

    this.fusedRoles = [preview, ...this.fusedRoles].slice(0, 4)
  }

  private fuseAgentsFromDrop(targetId: string, extraParams?: string): void {
    const sourceId = this.decodeDragPayload(extraParams)
    if (sourceId.length > 0) {
      this.createFusionRole(sourceId, targetId)
    }
  }

  private addToConversationFromDrop(extraParams?: string): void {
    const agentId = this.decodeDragPayload(extraParams)
    if (agentId.length > 0) {
      this.toggleConversationAgent(agentId)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 12 }) {
        this.buildRoleStudio()
        this.buildConversationStudio()
        this.buildCandidateGallery()
      }
      .width('100%')

      if (this.infoDialogVisible) {
        this.buildInfoDialog()
      }
    }
    .width('100%')
  }

  @Builder
  private buildRoleStudio() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('角色选择')
          .layoutWeight(1)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        this.buildInfoChip('说明', () => {
          this.openInfoDialog('角色选择说明', this.getSelectionHelpText())
        })

        Text(`${this.selectedCount()} 位已就位`)
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.mintDark)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(MintColors.mintBg)
          .borderRadius(BorderRadius.pill)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Start }) {
        ForEach(this.getSelectedAgents(), (agent: PersonaSpec) => {
          this.buildSelectedRoleOrb(agent)
        }, (agent: PersonaSpec) => agent.agentId)
        this.buildEmptyRoleOrb()
      }
      .width('100%')

      if (this.fusedRoles.length > 0) {
        Column({ space: 8 }) {
          Row() {
            Text('融合结果')
              .fontSize(Typography.size.caption)
              .fontWeight(FontWeight.Bold)
              .fontColor(MintColors.textPrimary)

            Blank()

            Text('拖拽重合自动生成')
              .fontSize(Typography.size.xs)
              .fontColor(MintColors.textMuted)
          }
          .width('100%')

          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.fusedRoles, (role: FusionPreview) => {
                this.buildFusionBubble(role)
              }, (role: FusionPreview) => role.id)
            }
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('rgba(255, 255, 255, 0.84)')
    .borderRadius(BorderRadius.xxl3)
    .border({
      width: 0.8,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl3
    })
    .shadow({
      radius: 24,
      color: 'rgba(78, 205, 196, 0.08)',
      offsetX: 0,
      offsetY: 10
    })
  }

  @Builder
  private buildConversationStudio() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('对话平台')
          .layoutWeight(1)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        this.buildInfoChip('说明', () => {
          this.openInfoDialog('对话平台说明', this.getConversationHelpText())
        })

        Text(`${this.getConversationAgents().length} 位对谈中`)
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.lavenderDark)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(MintColors.lavenderBg)
          .borderRadius(BorderRadius.pill)
      }
      .width('100%')

      Column({ space: 12 }) {
        if (this.getConversationAgents().length === 0) {
          this.buildConversationEmptyState()
        } else {
          Scroll() {
            Row({ space: Spacing.md }) {
              ForEach(this.getConversationAgents(), (agent: PersonaSpec) => {
                this.buildConversationRole(agent)
              }, (agent: PersonaSpec) => agent.agentId)
            }
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }

        Row({ space: 8 }) {
          this.buildCompactHint('多人对谈')
          this.buildCompactHint('拖动排布')
        }
        .width('100%')

        Button(this.getConversationAgents().length >= 2 ? '开始多人交流辩论' : '至少加入 2 位角色')
          .width('100%')
          .height(48)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.getConversationAgents().length >= 2 ? MintColors.mintDark : '#BFD7D4')
          .borderRadius(BorderRadius.pill)
          .enabled(this.getConversationAgents().length >= 2)
          .onClick(() => {
            this.startConversation()
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor('rgba(78, 205, 196, 0.08)')
      .borderRadius(BorderRadius.xxl3)
      .border({
        width: 1,
        color: 'rgba(78, 205, 196, 0.28)',
        radius: BorderRadius.xxl3
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('rgba(255, 255, 255, 0.86)')
    .borderRadius(BorderRadius.xxl3)
    .border({
      width: this.conversationHovering ? 1.2 : 0.8,
      color: this.conversationHovering ? MintColors.mintDark : MintColors.borderLight,
      radius: BorderRadius.xxl3
    })
    .allowDrop(null)
    .onDragEnter((_event: DragEvent, extraParams?: string) => {
      if (this.decodeDragPayload(extraParams).length > 0) {
        this.conversationHovering = true
      }
    })
    .onDragLeave(() => {
      this.conversationHovering = false
    })
    .onDrop((_event: DragEvent, extraParams?: string) => {
      this.addToConversationFromDrop(extraParams)
      this.conversationHovering = false
    })
  }

  @Builder
  private buildCandidateGallery() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('候选角色')
          .layoutWeight(1)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.textPrimary)

        Text(`${this.agents.length} 位候选`)
          .fontSize(Typography.size.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(MintColors.lavenderDark)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('rgba(184, 169, 217, 0.12)')
          .borderRadius(BorderRadius.pill)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Start }) {
        ForEach(this.agents, (agent: PersonaSpec) => {
          this.buildCandidateCard(agent)
        }, (agent: PersonaSpec) => agent.agentId)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildSelectedRoleOrb(agent: PersonaSpec) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(80)
          .height(80)
          .borderRadius(40)
          .backgroundColor(this.getAgentTone(agent.agentId))
          .border({
            width: 1.5,
            color: this.getAgentAccent(agent.agentId),
            radius: 40
          })

        Text(this.getAgentInitial(agent))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getAgentAccent(agent.agentId))
      }
      .width(80)
      .height(80)
      .allowDrop(null)
      .onDrop((_event: DragEvent, extraParams?: string) => {
        this.fuseAgentsFromDrop(agent.agentId, extraParams)
      })

      Text(agent.stageLabel)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      Row({ space: 6 }) {
        this.buildMiniAction(this.isInConversation(agent.agentId) ? '已在对话' : '加入对话', this.isInConversation(agent.agentId), () => {
          this.toggleConversationAgent(agent.agentId)
        })
      }
    }
    .width('30%')
    .margin({ right: '3%', bottom: 12 })
    .draggable(true)
    .onDragStart((_event: DragEvent) => {
      return {
        extraInfo: this.encodeDragPayload(agent.agentId)
      }
    })
  }

  @Builder
  private buildEmptyRoleOrb() {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(80)
          .height(80)
          .borderRadius(40)
          .backgroundColor('rgba(255, 255, 255, 0.72)')
          .border({
            width: 1.5,
            color: MintColors.border,
            radius: 40,
            style: BorderStyle.Dashed
          })

        Text('+')
          .fontSize(28)
          .fontWeight(FontWeight.Medium)
          .fontColor(MintColors.textMuted)
      }
      .width(80)
      .height(80)
      .onClick(() => {
        this.openAddRolePage()
      })

      Text('添加角色')
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(MintColors.textPrimary)
    }
    .width('30%')
    .margin({ right: '3%', bottom: 12 })
  }

  @Builder
  private buildFusionBubble(role: FusionPreview) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(70)
          .height(70)
          .borderRadius(35)
          .backgroundColor('rgba(255, 255, 255, 0.94)')
          .border({
            width: 2,
            color: role.accent,
            radius: 35
          })

        Text(role.signature)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(role.accent)
      }
      .width(70)
      .height(70)

      Text(role.label)
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textSecondary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(82)
        .textAlign(TextAlign.Center)
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('rgba(184, 169, 217, 0.08)')
    .borderRadius(BorderRadius.xxl2)
  }

  @Builder
  private buildConversationEmptyState() {
    Column({ space: 10 }) {
      Row({ space: Spacing.md }) {
        ForEach([0, 1, 2], (slot: number, index: number) => {
          Column()
            .width(68)
            .height(68)
            .borderRadius(34)
            .backgroundColor('rgba(255, 255, 255, 0.72)')
            .border({
              width: 1.5,
              color: index === 1 ? MintColors.mintDark : MintColors.border,
              radius: 34,
              style: BorderStyle.Dashed
            })
        }, (slot: number, index: number) => `${slot}-${index}`)
      }

      Text('拖动角色到这里，快速组成讨论阵容')
        .fontSize(Typography.size.caption)
        .fontColor(MintColors.textSecondary)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: Spacing.sm, bottom: Spacing.sm })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildConversationRole(agent: PersonaSpec) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(78)
          .height(78)
          .borderRadius(39)
          .backgroundColor('#FFFFFF')
          .border({
            width: 2,
            color: this.getAgentAccent(agent.agentId),
            radius: 39
          })

        Text(this.getAgentInitial(agent))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getAgentAccent(agent.agentId))
      }
      .width(78)
      .height(78)

      Text(agent.stageLabel)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')

      Button('移出')
        .height(26)
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textSecondary)
        .backgroundColor('#FFFFFF')
        .borderRadius(BorderRadius.pill)
        .onClick(() => {
          this.toggleConversationAgent(agent.agentId)
        })
    }
    .width(100)
  }

  @Builder
  private buildInfoChip(label: string, onClick: () => void) {
    Text(label)
      .fontSize(Typography.size.xs)
      .fontWeight(FontWeight.Medium)
      .fontColor(MintColors.textSecondary)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('rgba(255, 255, 255, 0.88)')
      .borderRadius(BorderRadius.pill)
      .onClick(() => {
        onClick()
      })
  }

  @Builder
  private buildCompactHint(label: string) {
    Row({ space: 6 }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(MintColors.mintDark)

      Text(label)
        .fontSize(Typography.size.xs)
        .fontColor(MintColors.textSecondary)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('rgba(255, 255, 255, 0.76)')
    .borderRadius(BorderRadius.xxl2)
  }

  @Builder
  private buildInfoDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(15, 23, 42, 0.26)')
        .onClick(() => {
          this.closeInfoDialog()
        })

      Column({ space: 12 }) {
        Row() {
          Text(this.infoDialogTitle)
            .layoutWeight(1)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(MintColors.textPrimary)

          Text('关闭')
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textSecondary)
            .onClick(() => {
              this.closeInfoDialog()
            })
        }
        .width('100%')

        Text(this.infoDialogBody)
          .width('100%')
          .fontSize(Typography.size.body)
          .fontColor(MintColors.textSecondary)
          .lineHeight(Typography.lineHeight.relaxed)

        Button('我知道了')
          .width('100%')
          .height(42)
          .fontSize(Typography.size.body)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(MintColors.mintDark)
          .borderRadius(BorderRadius.pill)
          .onClick(() => {
            this.closeInfoDialog()
          })
      }
      .width('84%')
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .backgroundColor('rgba(255, 255, 255, 0.98)')
      .borderRadius(BorderRadius.xxl3)
      .shadow({
        radius: 28,
        color: 'rgba(15, 23, 42, 0.16)',
        offsetX: 0,
        offsetY: 12
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildCandidateCard(agent: PersonaSpec) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor(this.isSelected(agent.agentId) ? this.getAgentTone(agent.agentId) : 'rgba(255, 255, 255, 0.84)')
          .border({
            width: 1.5,
            color: this.isSelected(agent.agentId) ? this.getAgentAccent(agent.agentId) : MintColors.border,
            radius: 36
          })

        Text(this.isSelected(agent.agentId) ? this.getAgentInitial(agent) : '+')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isSelected(agent.agentId) ? this.getAgentAccent(agent.agentId) : MintColors.textMuted)
      }
      .width(72)
      .height(72)
      .onClick(() => {
        this.toggleAgentSelection(agent.agentId)
      })

      Text(agent.stageLabel)
        .fontSize(Typography.size.caption)
        .fontWeight(FontWeight.Bold)
        .fontColor(MintColors.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      Button(this.isSelected(agent.agentId) ? '已添加' : '添加')
        .width('100%')
        .height(28)
        .fontSize(Typography.size.xs)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isSelected(agent.agentId) ? '#FFFFFF' : this.getAgentAccent(agent.agentId))
        .backgroundColor(this.isSelected(agent.agentId) ? this.getAgentAccent(agent.agentId) : '#FFFFFF')
        .borderRadius(BorderRadius.pill)
        .onClick(() => {
          this.toggleAgentSelection(agent.agentId)
        })
    }
    .width('30%')
    .padding({ left: 8, right: 8, top: 12, bottom: 12 })
    .margin({ right: '3%', bottom: 12 })
    .backgroundColor(this.isSelected(agent.agentId) ? 'rgba(78, 205, 196, 0.06)' : 'rgba(255, 255, 255, 0.76)')
    .borderRadius(BorderRadius.xxl2)
  }

  @Builder
  private buildMiniAction(label: string, active: boolean, onClick: () => void) {
    Button(label)
      .height(26)
      .fontSize(10)
      .fontWeight(FontWeight.Medium)
      .fontColor(active ? '#FFFFFF' : MintColors.textSecondary)
      .backgroundColor(active ? MintColors.mintDark : '#FFFFFF')
      .borderRadius(BorderRadius.pill)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        onClick()
      })
  }
}
