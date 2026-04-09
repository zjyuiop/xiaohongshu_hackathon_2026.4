import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { PersonaSpec } from '../common/Models'
import {
  AnimationDuration,
  AnimationCurve
} from '../common/styles/Animation'

@Component
export struct ArenaTab {
  @Prop agents: PersonaSpec[] = []
  @Prop selectedAgentIds: string[] = []
  @Prop topic: string = ''
  @Prop isLoading: boolean = false
  @State private pressedStart: boolean = false
  @State private contentOpacity: number = 0
  @State private contentTranslateY: number = 30
  @State private weaveAreaOpacity: number = 0
  @State private weaveAreaScale: number = 0.94

  onToggleAgent: (agentId: string) => void = () => {}
  onTopicChange: (topic: string) => void = () => {}
  onStartDiscussion: () => void = () => {}

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.contentOpacity = 1
        this.contentTranslateY = 0
      })
    }, 60)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.weaveAreaOpacity = 1
        this.weaveAreaScale = 1
      })
    }, 150)
  }

  get selectedCount(): number {
    return this.selectedAgentIds.length
  }

  private canSelect(): boolean {
    return this.selectedCount < 3
  }

  private canStart(): boolean {
    return this.selectedCount >= 2 && !this.isLoading
  }

  private isSelected(agentId: string): boolean {
    return this.selectedAgentIds.includes(agentId)
  }

  private getAgentById(agentId: string): PersonaSpec | undefined {
    return this.agents.find((agent: PersonaSpec) => agent.agentId === agentId)
  }

  private getSelectedAgents(): PersonaSpec[] {
    return this.agents.filter((agent: PersonaSpec) => this.selectedAgentIds.includes(agent.agentId))
  }

  private getAgentName(agentId: string): string {
    const agent = this.getAgentById(agentId)
    return agent ? agent.displayName.substring(0, 1) : '?'
  }

  private getTopicHint(): string {
    const length = this.topic.trim().length
    if (length === 0) {
      return '抛出一个真实问题，会更容易得到有张力的讨论结果'
    }
    if (length < 12) {
      return '可以再具体一点，比如加入场景、关系或犹豫点'
    }
    return '这个议题已经足够清晰，可以开始编织讨论'
  }

  private getStartButtonLabel(): string {
    if (this.isLoading) {
      return '思维编织中...'
    }
    if (this.selectedCount < 2) {
      return '至少选择 2 个切片'
    }
    return '开启跨时空会谈'
  }

  build() {
    Column({ space: Spacing.card.xlarge }) {
      Column({ space: Spacing.sm }) {
        Row({ space: Spacing.sm }) {
          Column()
            .width(24)
            .height(3)
            .borderRadius(1.5)
            .backgroundColor('#6366F1')

          Text('思维共振')
            .fontSize(Typography.size.xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textPrimary)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text('保留现有的灵感气质，把选角、议题和启动动作做得更清晰')
          .fontSize(Typography.size.bodyLg)
          .fontColor(Colors.textTertiary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: Spacing.lg })

      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width(136)
          .height(136)
          .borderRadius(68)
          .backgroundColor('rgba(99, 102, 241, 0.08)')
          .blur(34)
          .position({ x: -36, y: -24 })

        Column()
          .width(112)
          .height(112)
          .borderRadius(56)
          .backgroundColor('rgba(16, 185, 129, 0.06)')
          .blur(30)
          .position({ right: -18, y: 24 })

        Column({ space: Spacing.card.large }) {
          Row() {
            Column({ space: 6 }) {
              Row({ space: 6 }) {
                Text('人格编织')
                  .fontSize(Typography.size.subtitle)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.textPrimary)

                Text(`${this.selectedCount}/3`)
                  .fontSize(Typography.size.xs)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Colors.primary)
                  .padding({
                    left: Spacing.sm,
                    right: Spacing.sm,
                    top: 3,
                    bottom: 3
                  })
                  .backgroundColor(Colors.accentPurple)
                  .borderRadius(BorderRadius.pill)
              }

              Text('先挑选 2 到 3 个阶段切片，再把它们带入讨论')
                .fontSize(Typography.size.caption)
                .fontColor(Colors.textMuted)
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Text('可切换')
              .fontSize(Typography.size.xs)
              .fontColor(Colors.textMuted)
              .padding({
                left: Spacing.sm,
                right: Spacing.sm,
                top: 4,
                bottom: 4
              })
              .backgroundColor('rgba(255, 255, 255, 0.75)')
              .borderRadius(BorderRadius.pill)
          }
          .width('100%')

          Column({ space: Spacing.card.medium }) {
            Row({ space: Spacing.sm }) {
              ForEach(this.selectedAgentIds, (agentId: string) => {
                this.buildFilledSlot(agentId)
              }, (agentId: string) => agentId)

              if (this.canSelect()) {
                this.buildEmptySlot()
              }

              Row({ space: 4 }) {
                Text('→')
                  .fontSize(18)
                  .fontColor(Colors.textMuted)
              }
              .margin({ left: Spacing.xs, right: Spacing.xs })

              this.buildResultSlot()
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)

            if (this.selectedCount > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.getSelectedAgents(), (agent: PersonaSpec) => {
                  this.buildSelectedBadge(agent)
                }, (agent: PersonaSpec) => agent.agentId)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(Spacing.card.medium)
          .backgroundColor('rgba(99, 102, 241, 0.04)')
          .borderRadius(BorderRadius.xxl)

          Column({ space: Spacing.sm }) {
            ForEach(this.agents, (agent: PersonaSpec, index: number) => {
              this.buildAgentCard(agent, index)
            }, (agent: PersonaSpec) => agent.agentId)
          }
          .width('100%')

          Row({ space: 6 }) {
            Column()
              .width(4)
              .height(4)
              .borderRadius(2)
              .backgroundColor(Colors.textMuted)

            Text('切片越有差异，讨论越容易出现真正有价值的观点碰撞')
              .fontSize(Typography.size.caption)
              .fontColor(Colors.textMuted)
          }
          .width('100%')
        }
        .width('100%')
        .padding(Spacing.huge)
      }
      .width('100%')
      .backgroundColor(Colors.cardPrimary)
      .borderRadius(BorderRadius.huge)
      .border({
        width: 1,
        color: 'rgba(99, 102, 241, 0.10)',
        radius: BorderRadius.huge
      })
      .backdropBlur(20)
      .opacity(this.weaveAreaOpacity)
      .scale({
        x: this.weaveAreaScale,
        y: this.weaveAreaScale
      })
      .animation({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      })

      Column({ space: Spacing.card.large }) {
        Row() {
          Column({ space: 6 }) {
            Row({ space: Spacing.xs }) {
              Column()
                .width(3)
                .height(18)
                .borderRadius(1.5)
                .backgroundColor('#10B981')

              Text('抛出议题')
                .fontSize(Typography.size.subtitle)
                .fontWeight(FontWeight.Bold)
                .fontColor(Colors.textSecondary)
            }
            .width('100%')

            Text(this.getTopicHint())
              .fontSize(Typography.size.caption)
              .fontColor(Colors.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(`${this.topic.trim().length} 字`)
            .fontSize(Typography.size.xs)
            .fontColor(Colors.textMuted)
            .padding({
              left: Spacing.sm,
              right: Spacing.sm,
              top: 4,
              bottom: 4
            })
            .backgroundColor('rgba(241, 245, 249, 0.78)')
            .borderRadius(BorderRadius.pill)
        }
        .width('100%')

        TextArea({
          text: this.topic,
          placeholder: '例如：在面临极度不确定的未来时，该如何做出决策？'
        })
          .width('100%')
          .height(104)
          .fontSize(Typography.size.bodyLg)
          .fontColor(Colors.textPrimary)
          .placeholderColor(Colors.textPlaceholder)
          .placeholderFont({
            size: Typography.size.bodyLg,
            weight: FontWeight.Normal
          })
          .backgroundColor(Colors.background)
          .borderRadius(BorderRadius.xxl)
          .border({
            width: 1,
            color: Colors.borderLight,
            radius: BorderRadius.xxl
          })
          .padding(Spacing.card.large)
          .onChange((value: string) => {
            this.onTopicChange(value)
          })

        Button(this.getStartButtonLabel())
          .width('100%')
          .height(52)
          .fontSize(Typography.size.bodyLg)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.selectedCount >= 2 ? '#6366F1' : Colors.textMuted)
          .borderRadius(BorderRadius.huge)
          .enabled(this.canStart())
          .shadow({
            radius: this.selectedCount >= 2 ? 22 : 10,
            color: this.selectedCount >= 2 ? 'rgba(99, 102, 241, 0.22)' : 'rgba(0, 0, 0, 0.05)',
            offsetX: 0,
            offsetY: this.selectedCount >= 2 ? 8 : 4
          })
          .scale({
            x: this.pressedStart ? 0.985 : 1,
            y: this.pressedStart ? 0.985 : 1
          })
          .animation({
            duration: AnimationDuration.fast,
            curve: AnimationCurve.emphasized
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.pressedStart = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.pressedStart = false
            }
          })
          .onClick(() => {
            if (this.canStart()) {
              this.onStartDiscussion()
            }
          })
      }
      .width('100%')
      .padding({
        left: 0,
        right: 0,
        bottom: Spacing.giant
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.contentOpacity)
    .translate({ x: 0, y: this.contentTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized
    })
  }

  @Builder
  buildSelectedBadge(agent: PersonaSpec) {
    Row({ space: 6 }) {
      Column()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(Colors.primary)

      Text(agent.stageLabel)
        .fontSize(Typography.size.xs)
        .fontColor(Colors.textSecondary)

      Text(agent.timeLabel)
        .fontSize(Typography.size.xs)
        .fontColor(Colors.textMuted)
    }
    .padding({
      left: Spacing.sm,
      right: Spacing.sm,
      top: 6,
      bottom: 6
    })
    .backgroundColor('rgba(255, 255, 255, 0.70)')
    .borderRadius(BorderRadius.pill)
    .margin({ right: Spacing.xs, bottom: Spacing.xs })
  }

  @Builder
  buildAgentCard(agent: PersonaSpec, index: number) {
    Row({ space: Spacing.md }) {
      Column()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(this.isSelected(agent.agentId) ? Colors.primary : Colors.border)
        .margin({ top: 4 })

      Column({ space: 6 }) {
        Row({ space: Spacing.xs }) {
          Text(agent.stageLabel)
            .fontSize(Typography.size.bodyLg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textPrimary)

          Text(agent.timeLabel)
            .fontSize(Typography.size.xs)
            .fontColor(Colors.textMuted)
            .padding({
              left: Spacing.sm,
              right: Spacing.sm,
              top: 3,
              bottom: 3
            })
            .backgroundColor('rgba(241, 245, 249, 0.85)')
            .borderRadius(BorderRadius.pill)
        }
        .width('100%')

        Text(agent.voiceStyle)
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (agent.traits.length > 0) {
          Row({ space: 6 }) {
            Text(agent.traits[0])
              .fontSize(Typography.size.xs)
              .fontColor(Colors.primary)
              .padding({
                left: Spacing.sm,
                right: Spacing.sm,
                top: 4,
                bottom: 4
              })
              .backgroundColor('rgba(99, 102, 241, 0.08)')
              .borderRadius(BorderRadius.pill)

            if (agent.values.length > 0) {
              Text(agent.values[0])
                .fontSize(Typography.size.xs)
                .fontColor(Colors.textSecondary)
                .padding({
                  left: Spacing.sm,
                  right: Spacing.sm,
                  top: 4,
                  bottom: 4
                })
                .backgroundColor('rgba(255, 255, 255, 0.80)')
                .borderRadius(BorderRadius.pill)
            }
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.isSelected(agent.agentId) ? '移出' : '加入')
        .fontSize(Typography.size.xs)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isSelected(agent.agentId) ? '#FFFFFF' : Colors.primary)
        .padding({
          left: Spacing.md,
          right: Spacing.md,
          top: Spacing.sm,
          bottom: Spacing.sm
        })
        .backgroundColor(this.isSelected(agent.agentId) ? Colors.primary : 'rgba(99, 102, 241, 0.08)')
        .borderRadius(BorderRadius.pill)
    }
    .width('100%')
    .padding(Spacing.card.medium)
    .backgroundColor(this.isSelected(agent.agentId) ? 'rgba(255, 255, 255, 0.92)' : 'rgba(255, 255, 255, 0.65)')
    .borderRadius(BorderRadius.xxl)
    .border({
      width: this.isSelected(agent.agentId) ? 1.5 : 1,
      color: this.isSelected(agent.agentId) ? 'rgba(99, 102, 241, 0.20)' : Colors.borderLight,
      radius: BorderRadius.xxl
    })
    .shadow({
      radius: this.isSelected(agent.agentId) ? 18 : 8,
      color: this.isSelected(agent.agentId) ? 'rgba(99, 102, 241, 0.12)' : 'rgba(15, 23, 42, 0.04)',
      offsetX: 0,
      offsetY: this.isSelected(agent.agentId) ? 6 : 2
    })
    .onClick(() => {
      this.onToggleAgent(agent.agentId)
    })
    .transition(TransitionEffect.OPACITY.animation({
      duration: AnimationDuration.normal + index * 20,
      curve: AnimationCurve.emphasized
    }))
  }

  @Builder
  buildFilledSlot(agentId: string) {
    Column({ space: 2 }) {
      Text(this.getAgentName(agentId))
        .fontSize(Typography.size.subtitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.primary)
    }
    .width(52)
    .height(52)
    .borderRadius(26)
    .backgroundColor('#FFFFFF')
    .border({
      width: 2,
      color: '#6366F1',
      radius: 26
    })
    .shadow({
      radius: 12,
      color: 'rgba(99, 102, 241, 0.14)',
      offsetX: 0,
      offsetY: 4
    })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildEmptySlot() {
    Column() {
      Text('+')
        .fontSize(22)
        .fontColor(Colors.textMuted)
    }
    .width(52)
    .height(52)
    .borderRadius(26)
    .backgroundColor('rgba(241, 245, 249, 0.80)')
    .border({
      width: 1.5,
      color: Colors.textMuted,
      radius: 26,
      style: BorderStyle.Dashed
    })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildResultSlot() {
    Column({ space: 3 }) {
      Text('AI')
        .fontSize(Typography.size.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.primary)

      Text('融合')
        .fontSize(Typography.size.xs)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.primary)
    }
    .width(64)
    .height(64)
    .borderRadius(20)
    .backgroundColor(Colors.accentPurple)
    .border({
      width: 1.5,
      color: 'rgba(99, 102, 241, 0.28)',
      radius: 20
    })
    .shadow({
      radius: 16,
      color: 'rgba(99, 102, 241, 0.14)',
      offsetX: 0,
      offsetY: 6
    })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
