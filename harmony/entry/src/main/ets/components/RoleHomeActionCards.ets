import { Colors } from '../common/styles/Colors'
import { Typography } from '../common/styles/Typography'
import { BorderRadius } from '../common/styles/BorderRadius'
import { Spacing } from '../common/styles/Spacing'
import { Durations, Curves } from '../common/styles/Effects'
import {
  AnimationDuration,
  AnimationCurve
} from '../common/styles/Animation'
import { Icon } from './CustomIcon'

// 角色首页顶部双入口：创造新识 | 寻访前人（绿色卡片直达二级搜索页，不在本页再放黄色横条卡片）
@Component
export struct RoleHomeActionCards {
  onCreateClick: () => void = () => {}
  onExploreClick: () => void = () => {}
  onImportClick: () => void = () => {}
  @State private pressedLeft: boolean = false
  @State private pressedRight: boolean = false
  @State private leftCardOpacity: number = 0
  @State private rightCardOpacity: number = 0
  @State private leftCardTranslateY: number = 40
  @State private rightCardTranslateY: number = 40
  @State private leftIconRotate: number = 0
  @State private rightIconBounce: number = 1

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.leftCardOpacity = 1
        this.leftCardTranslateY = 0
      })

      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.bounce
      }, () => {
        this.leftIconRotate = 360
      })
    }, 100)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.emphasized
      }, () => {
        this.rightCardOpacity = 1
        this.rightCardTranslateY = 0
      })

      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.bounce
      }, () => {
        this.rightIconBounce = 1
      })
    }, 250)
  }

  build() {
    Column({ space: Spacing.sm }) {
      Row({ space: Spacing.card.medium }) {
        this.buildCreateCard()
        this.buildExploreCard()
      }
      .width('100%')

      // 弱化入口：导入传记（不占主卡片位）
      Row() {
        Text('导入已有的人物传记')
          .fontSize(Typography.size.caption)
          .fontColor(Colors.textMuted)
          .decoration({ type: TextDecorationType.Underline })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: Spacing.xs })
      .onClick(() => {
        this.onImportClick()
      })
    }
    .width('100%')
  }

  @Builder
  buildCreateCard() {
    Column({ space: Spacing.sm }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#EEF2FF')
          .border({
            width: 1,
            color: 'rgba(99, 102, 241, 0.15)',
            radius: 22
          })

        Stack({ alignContent: Alignment.Center }) {
          Icon({
            iconType: 'edit',
            iconSize: 20,
            iconColor: '#6366F1'
          })

          Column() {
            Icon({
              iconType: 'plus',
              iconSize: 8,
              iconColor: '#FFFFFF'
            })
          }
          .width(14)
          .height(14)
          .borderRadius(7)
          .backgroundColor('#6366F1')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .position({ x: 20, y: 0 })
        }
        .width(44)
        .height(44)
        .rotate({
          angle: this.leftIconRotate
        })
      }
      .width(44)
      .height(44)

      Text('创造新识')
        .fontSize(Typography.size.subtitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Start)

      Text('定义一个全新的人格')
        .fontSize(Typography.size.caption)
        .fontColor(Colors.textTertiary)
        .width('100%')
        .textAlign(TextAlign.Start)
        .maxLines(2)
        .lineHeight(18)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.card.large)
    .backgroundColor('#EEF2FF')
    .borderRadius(BorderRadius.huge)
    .border({
      width: 1,
      color: 'rgba(99, 102, 241, 0.2)',
      radius: BorderRadius.huge
    })
    .shadow({
      radius: this.pressedLeft ? 12 : 20,
      color: 'rgba(99, 102, 241, 0.15)',
      offsetX: 0,
      offsetY: this.pressedLeft ? 2 : 6
    })
    .scale({
      x: this.pressedLeft ? 0.97 : 1,
      y: this.pressedLeft ? 0.97 : 1
    })
    .animation({
      duration: Durations.fast,
      curve: Curves.emphasized
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedLeft = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedLeft = false
      }
    })
    .onClick(() => {
      this.onCreateClick()
    })
    .opacity(this.leftCardOpacity)
    .translate({ x: 0, y: this.leftCardTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized
    })
  }

  @Builder
  buildExploreCard() {
    Column({ space: Spacing.sm }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#ECFDF5')
          .border({
            width: 1,
            color: 'rgba(16, 185, 129, 0.2)',
            radius: 22
          })

        Column({ space: 3 }) {
          Icon({
            iconType: 'search',
            iconSize: 20,
            iconColor: '#10B981'
          })
        }
        .alignItems(HorizontalAlign.Center)
        .scale({
          x: this.rightIconBounce,
          y: this.rightIconBounce
        })
      }
      .width(44)
      .height(44)

      Text('寻访前人')
        .fontSize(Typography.size.subtitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Start)

      Text('搜索名人角色，部署 AI 对话')
        .fontSize(Typography.size.caption)
        .fontColor(Colors.textTertiary)
        .width('100%')
        .textAlign(TextAlign.Start)
        .maxLines(2)
        .lineHeight(18)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(Spacing.card.large)
    .backgroundColor('#ECFDF5')
    .borderRadius(BorderRadius.huge)
    .border({
      width: 1,
      color: 'rgba(16, 185, 129, 0.2)',
      radius: BorderRadius.huge
    })
    .shadow({
      radius: this.pressedRight ? 12 : 20,
      color: 'rgba(16, 185, 129, 0.12)',
      offsetX: 0,
      offsetY: this.pressedRight ? 2 : 6
    })
    .scale({
      x: this.pressedRight ? 0.97 : 1,
      y: this.pressedRight ? 0.97 : 1
    })
    .animation({
      duration: Durations.fast,
      curve: Curves.emphasized
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedRight = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedRight = false
      }
    })
    .onClick(() => {
      this.onExploreClick()
    })
    .opacity(this.rightCardOpacity)
    .translate({ x: 0, y: this.rightCardTranslateY })
    .animation({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.emphasized
    })
  }
}
