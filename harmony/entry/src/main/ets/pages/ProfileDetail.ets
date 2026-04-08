import { router } from '@kit.ArkUI'
import { PersonaSpec, PresetProfile, ProfileBundle, RouteParams, TimelineNode, EMPTY_PROFILE } from '../common/Models'
import { PersonaApi } from '../service/PersonaApi'

@Entry
@Component
struct ProfileDetail {
  @State profile: PresetProfile = EMPTY_PROFILE
  @State nodes: TimelineNode[] = []
  @State agents: PersonaSpec[] = []
  @State selectedAgentIds: string[] = []

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams
    const profileId = params.profileId ? params.profileId : 'graduate'

    PersonaApi.getProfileBundle(profileId).then((bundle: ProfileBundle) => {
      this.profile = bundle.profile
      this.nodes = bundle.nodes
      this.agents = bundle.agents
      this.selectedAgentIds = bundle.agents.slice(0, 2).map((agent: PersonaSpec) => agent.agentId)
    })
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

  goArena(): void {
    router.pushUrl({
      url: 'pages/Arena',
      params: {
        profileId: this.profile.id,
        selectedAgentIds: this.selectedAgentIds.join(',')
      }
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 12 }) {
          Button('返回角色库')
            .fontColor('#0D7A72')
            .backgroundColor('#00000000')
            .padding(0)
            .onClick(() => {
              router.back()
            })

          Text('角色详情子页')
            .fontSize(12)
            .fontColor('#0D7A72')
            .letterSpacing(2)

          Text(this.profile.displayName)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#201913')

          Text(this.profile.biography)
            .fontSize(15)
            .fontColor('#5B5249')
            .lineHeight(24)

          Row() {
            Text(`已选节点 ${this.selectedAgentIds.length} / 3`)
              .fontSize(13)
              .fontColor('#6D6256')
            Blank()
            Button('带入议会')
              .height(40)
              .backgroundColor('#201913')
              .fontColor('#FFF8F1')
              .borderRadius(99)
              .onClick(() => {
                this.goArena()
              })
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .width('100%')
        .backgroundColor('#F7F0E5')
        .borderRadius(24)

        ForEach(this.nodes, (node: TimelineNode, index: number) => {
          Column({ space: 10 }) {
            Row() {
              Text(`${index + 1}`)
                .fontSize(12)
                .fontColor('#FFF8F1')
                .width(28)
                .height(28)
                .textAlign(TextAlign.Center)
                .backgroundColor('#201913')
                .borderRadius(14)
              Text(`${node.timeLabel} / ${node.ageLabel}`)
                .fontSize(12)
                .fontColor('#0D7A72')
                .margin({ left: 10 })
            }
            .width('100%')

            Text(node.stageLabel)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#201913')

            Text(node.summary)
              .fontSize(14)
              .fontColor('#5B5249')
              .lineHeight(22)

            Text(`关键事件：${node.keyEvent}`)
              .fontSize(13)
              .fontColor('#6D6256')

            Text(`特质：${node.traits.join(' / ')}`)
              .fontSize(13)
              .fontColor('#6D6256')

            Text(`价值观：${node.values.join(' / ')}`)
              .fontSize(13)
              .fontColor('#6D6256')

            Text(`证据：${node.sourceEvidence[0].quote}`)
              .fontSize(13)
              .fontColor('#7A3C35')
              .lineHeight(20)

            Button(this.selectedAgentIds.includes(this.agents[index].agentId) ? '移出议会' : '加入议会')
              .width('100%')
              .height(40)
              .backgroundColor(this.selectedAgentIds.includes(this.agents[index].agentId) ? '#D9EEE9' : '#F2E6D5')
              .fontColor(this.selectedAgentIds.includes(this.agents[index].agentId) ? '#0D7A72' : '#7A3C35')
              .borderRadius(99)
              .onClick(() => {
                this.toggleAgent(this.agents[index].agentId)
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .backgroundColor('#FFF9F1')
          .borderRadius(22)
        }, (node: TimelineNode) => node.nodeId)
      }
      .padding(16)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .scrollBar(BarState.Off)
    .backgroundColor('#EDE0C9')
    .width('100%')
    .height('100%')
  }
}
