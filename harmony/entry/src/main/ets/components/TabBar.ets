export interface TabBarProps {
  activeIndex: number
  safeBottomVp?: number
}

@Component
export struct TabBar {
  @Prop public activeIndex: number = 0
  @Prop public safeBottomVp: number = 0
  @State private pressedIndex: number = -1
  @State private barOpacity: number = 0
  @State private barTranslateY: number = 20
  @State private indicatorOffset: number = 0
  public onTabChange: (index: number) => void = () => {}

  private readonly tabLabels: string[] = ['角色', '会议', '纪要']
  private readonly tabActiveFg: string = '#6366F1'
  private readonly tabActiveBg: string = '#EEF2FF'
  private readonly tabInactiveFg: string = '#94A3B8'

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({
        duration: 320,
        curve: Curve.FastOutSlowIn
      }, () => {
        this.barOpacity = 1
        this.barTranslateY = 0
      })
    }, 100)
  }

  private getTabFg(index: number): string {
    return this.activeIndex === index ? this.tabActiveFg : this.tabInactiveFg
  }

  private getTabSymbol(index: number): Resource {
    if (index === 0) {
      return this.activeIndex === index ? $r('sys.symbol.person_fill') : $r('sys.symbol.person')
    }
    if (index === 1) {
      return this.activeIndex === index ? $r('sys.symbol.message_fill') : $r('sys.symbol.message')
    }
    return this.activeIndex === index ? $r('sys.symbol.bookmark_notepad_fill') : $r('sys.symbol.bookmark_notepad')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Row({ space: 0 }) {
            ForEach(this.tabLabels, (_label: string, index: number) => {
              Column()
                .layoutWeight(1)
                .height(40)
                .margin({ left: 2, right: 2 })
                .borderRadius(20)
                .backgroundColor(this.tabActiveBg)
                .shadow({
                  radius: 14,
                  color: 'rgba(99, 102, 241, 0.12)',
                  offsetX: 0,
                  offsetY: 4
                })
                .opacity(this.activeIndex === index ? 1 : 0)
                .scale({
                  x: this.activeIndex === index ? (this.pressedIndex === index ? 0.96 : 1) : 0.82,
                  y: this.activeIndex === index ? (this.pressedIndex === index ? 0.96 : 1) : 0.82
                })
                .animation({
                  duration: this.pressedIndex === index ? 120 : 260,
                  curve: this.pressedIndex === index ? Curve.Sharp : Curve.FastOutSlowIn
                })
            }, (label: string) => label)
          }
          .width('100%')
          .padding({
            left: 8,
            right: 8
          })

          Row({ space: 0 }) {
            ForEach(this.tabLabels, (label: string, index: number) => {
              this.buildTabItem(label, index)
            }, (label: string) => label)
          }
          .width('100%')
          .height(56)
          .padding({
            left: 8,
            right: 8,
            top: 6,
            bottom: 6
          })
          .justifyContent(FlexAlign.SpaceEvenly)
        }
        .width('100%')
        .height(56)
        .backgroundColor('rgba(255, 255, 255, 0.94)')
        .borderRadius(28)
        .border({
          width: 1,
          color: 'rgba(255, 255, 255, 0.88)',
          radius: 28
        })
        .backdropBlur(24)
        .shadow({
          radius: 24,
          color: 'rgba(15, 23, 42, 0.10)',
          offsetX: 0,
          offsetY: 8
        })
      }
      .width('100%')

      Column()
        .width('82%')
        .height(1)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            ['rgba(99, 102, 241, 0)', 0],
            ['rgba(99, 102, 241, 0.22)', 0.5],
            ['rgba(99, 102, 241, 0)', 1]
          ]
        })
        .position({ y: 1 })
    }
    .width('100%')
    .padding({
      left: 24,
      right: 24,
      bottom: 10 + this.safeBottomVp
    })
    .opacity(this.barOpacity)
    .translate({ x: 0, y: this.barTranslateY })
    .scale({
      x: this.barOpacity * 0.05 + 0.95,
      y: this.barOpacity * 0.05 + 0.95
    })
  }

  @Builder
  buildTabItem(label: string, index: number) {
    Column({ space: 2 }) {
      this.buildIcon(index)

      Text(label)
        .fontSize(10)
        .fontWeight(this.activeIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.getTabFg(index))

      Column()
        .width(this.activeIndex === index ? 12 : 4)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.activeIndex === index ? this.tabActiveFg : 'rgba(0, 0, 0, 0)')
        .opacity(this.activeIndex === index ? 1 : 0)
        .scale({
          x: this.activeIndex === index ? 1 : 0.5,
          y: 1
        })
        .animation({
          duration: 220,
          curve: Curve.FastOutSlowIn
        })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({
      left: 8,
      right: 8,
      top: 6,
      bottom: 6
    })
    .borderRadius(16)
    .backgroundColor('rgba(0, 0, 0, 0)')
    .shadow({
      radius: 0,
      color: 'rgba(0, 0, 0, 0)',
      offsetX: 0,
      offsetY: 0
    })
    .scale({
      x: this.pressedIndex === index ? 0.92 : 1,
      y: this.pressedIndex === index ? 0.92 : 1
    })
    .translate({
      x: 0,
      y: this.activeIndex === index ? -2 : 0
    })
    .animation({
      duration: this.pressedIndex === index ? 120 : 240,
        curve: this.pressedIndex === index ? Curve.Sharp : Curve.FastOutSlowIn
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        animateTo({
          duration: 100,
          curve: Curve.Sharp
        }, () => {
          this.pressedIndex = index
        })
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        animateTo({
          duration: 200,
            curve: Curve.FastOutSlowIn
        }, () => {
          this.pressedIndex = -1
        })
      }
    })
    .onClick(() => {
      if (this.activeIndex !== index) {
        animateTo({
          duration: 200,
          curve: Curve.FastOutSlowIn
        }, () => {
          this.onTabChange(index)
        })
      }
    })
  }

  @Builder
  buildIcon(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.activeIndex === index ? 24 : 18)
        .height(this.activeIndex === index ? 24 : 18)
        .borderRadius(12)
        .backgroundColor(this.activeIndex === index ? 'rgba(255, 255, 255, 0.72)' : 'rgba(0, 0, 0, 0)')
        .animation({
          duration: 200,
          curve: Curve.FastOutSlowIn
        })

      Column({ space: 1 }) {
        SymbolGlyph(this.getTabSymbol(index))
          .fontSize(this.activeIndex === index ? 18 : 17)
          .fontColor([this.getTabFg(index)])
          .fontWeight(this.activeIndex === index ? FontWeight.Medium : FontWeight.Normal)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(18)
      .height(18)
      .alignItems(HorizontalAlign.Center)
      .scale({
        x: this.activeIndex === index ? 1.12 : 1,
        y: this.activeIndex === index ? 1.12 : 1
      })
      .animation({
        duration: 220,
          curve: Curve.FastOutSlowIn
      })
    }
  }
}
