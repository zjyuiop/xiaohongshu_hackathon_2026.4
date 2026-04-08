import { router } from '@kit.ArkUI'
import { ArenaMessage, PersonaSpec, PresetProfile, RouteParams, SelectedAgentsBundle, EMPTY_PROFILE } from '../common/Models'
import { PersonaApi } from '../service/PersonaApi'

@Entry
@Component
struct Arena {
  @State profile: PresetProfile = EMPTY_PROFILE
  @State selectedAgents: PersonaSpec[] = []
  @State topic: string = '现在该不该离开这份长期消耗我的工作？'
  @State messages: ArenaMessage[] = []
  @State summaryTitle: string = ''
  @State consensus: string = ''
  @State disagreements: string[] = []
  @State actionableAdvice: string[] = []
  @State narrativeHook: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams
    const profileId = params.profileId ? params.profileId : 'graduate'
    const selectedAgentIds = params.selectedAgentIds ? params.selectedAgentIds.split(',') : []

    PersonaApi.getSelectedAgents(profileId, selectedAgentIds).then((bundle: SelectedAgentsBundle) => {
      this.profile = bundle.profile
      this.selectedAgents = bundle.selectedAgents
    })
  }

  runDiscussion(): void {
    PersonaApi.runArena(this.topic, this.selectedAgents).then((result) => {
      this.messages = result.messages
      this.summaryTitle = result.summary.title
      this.consensus = result.summary.consensus
      this.disagreements = result.summary.disagreements
      this.actionableAdvice = result.summary.actionableAdvice
      this.narrativeHook = result.summary.narrativeHook
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 12 }) {
          Button('返回角色详情子页')
            .fontColor('#0D7A72')
            .backgroundColor('#00000000')
            .padding(0)
            .onClick(() => {
              router.back()
            })

          Text('ARENA / 阶段人格议会')
            .fontSize(12)
            .fontColor('#0D7A72')
            .letterSpacing(2)

          Text(`${this.profile.displayName} 的阶段人格议会`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#201913')

          TextInput({ text: this.topic, placeholder: '输入讨论议题' })
            .backgroundColor('#FFF9F1')
            .borderRadius(18)
            .onChange((value: string) => {
              this.topic = value
            })

          Button('开始讨论')
            .width('100%')
            .height(42)
            .backgroundColor('#201913')
            .fontColor('#FFF8F1')
            .borderRadius(99)
            .onClick(() => {
              this.runDiscussion()
            })
        }
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .width('100%')
        .backgroundColor('#F7F0E5')
        .borderRadius(24)

        Column({ space: 10 }) {
          Text('参会角色')
            .fontSize(14)
            .fontColor('#6D6256')

          ForEach(this.selectedAgents, (agent: PersonaSpec) => {
            Column({ space: 6 }) {
              Text(agent.stageLabel)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#201913')
              Text(`${agent.timeLabel} · ${agent.voiceStyle}`)
                .fontSize(13)
                .fontColor('#6D6256')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .backgroundColor('#FFF9F1')
            .borderRadius(18)
          }, (agent: PersonaSpec) => agent.agentId)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Text('对话流')
            .fontSize(14)
            .fontColor('#6D6256')

          if (this.messages.length > 0) {
            ForEach(this.messages, (message: ArenaMessage) => {
              Column({ space: 8 }) {
                Text(`${message.stageLabel} · ${message.displayName}`)
                  .fontSize(13)
                  .fontColor('#0D7A72')
                Text(message.content)
                  .fontSize(14)
                  .fontColor('#201913')
                  .lineHeight(22)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor('#FFF9F1')
              .borderRadius(20)
            }, (message: ArenaMessage) => message.id)
          } else {
            Text('点击“开始讨论”后，这里会生成阶段人格之间的对话。')
              .fontSize(14)
              .fontColor('#6D6256')
              .padding(18)
              .backgroundColor('#FFF9F1')
              .borderRadius(20)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.summaryTitle.length > 0) {
          Column({ space: 10 }) {
            Text(this.summaryTitle)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#201913')

            Text(this.consensus)
              .fontSize(14)
              .fontColor('#5B5249')
              .lineHeight(22)

            Text('主要分歧')
              .fontSize(14)
              .fontColor('#6D6256')
            ForEach(this.disagreements, (item: string) => {
              Text(`• ${item}`)
                .fontSize(13)
                .fontColor('#201913')
            }, (item: string) => item)

            Text('行动建议')
              .fontSize(14)
              .fontColor('#6D6256')
            ForEach(this.actionableAdvice, (item: string) => {
              Text(`• ${item}`)
                .fontSize(13)
                .fontColor('#201913')
            }, (item: string) => item)

            Text(this.narrativeHook)
              .fontSize(13)
              .fontColor('#7A3C35')
              .lineHeight(20)
              .padding(14)
              .backgroundColor('#F2E6D5')
              .borderRadius(18)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .backgroundColor('#FFF9F1')
          .borderRadius(22)
        }
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
