import { Colors } from '../common/styles/Colors'

const DEFAULT_FALLBACK_COLORS: string[] = ['#F1F5F9', '#E2E8F0', '#CBD5E1']

@Component
export struct PersonaAvatar {
  @Prop personaId: string = ''
  @Prop displayName: string = ''
  @Prop coverSeed: string = ''
  @Prop avatarSize: number = 56
  @Prop highlighted: boolean = false
  @Prop fallbackColors: string[] = DEFAULT_FALLBACK_COLORS

  private normalizeKey(value: string): string {
    return value.trim()
      .toLowerCase()
      .replace(/[^a-z0-9-_]/g, '-')
      .replace(/\s+/g, '-')
      .replace(/_/g, '-')
      .replace(/-+/g, '-')
  }

  private matchesAlias(key: string, aliases: string[]): boolean {
    for (let i = 0; i < aliases.length; i++) {
      if (key === aliases[i]) {
        return true
      }
    }
    return false
  }

  private resolveAvatarResource(): Resource | null {
    const candidateKeys: string[] = [
      this.normalizeKey(this.personaId),
      this.normalizeKey(this.coverSeed),
      this.normalizeKey(this.displayName)
    ]

    for (let i = 0; i < candidateKeys.length; i++) {
      const resource = this.matchAvatarResource(candidateKeys[i])
      if (resource !== null) {
        return resource
      }
    }

    return null
  }

  private matchAvatarResource(key: string): Resource | null {
    if (this.matchesAlias(key, ['jobs', 'steve-jobs', 'jobs-black-turtleneck'])) {
      return $r('app.media.avatar_jobs')
    }
    if (this.matchesAlias(key, ['qin', 'qin-shihuang', 'qin-empire-bronze'])) {
      return $r('app.media.avatar_qin')
    }
    if (this.matchesAlias(key, ['graduate', 'graduate-city-night'])) {
      return $r('app.media.avatar_graduate')
    }
    if (this.matchesAlias(key, ['warren-buffett', 'buffett'])) {
      return $r('app.media.avatar_buffett')
    }
    if (this.matchesAlias(key, ['jack-ma', 'jackma'])) {
      return $r('app.media.avatar_jackma')
    }
    if (this.matchesAlias(key, ['elon-musk', 'musk'])) {
      return $r('app.media.avatar_musk')
    }
    if (this.matchesAlias(key, ['confucius'])) {
      return $r('app.media.avatar_confucius')
    }
    if (this.matchesAlias(key, ['zhang-yiming'])) {
      return $r('app.media.avatar_zhang_yiming')
    }
    if (this.matchesAlias(key, ['puyi', 'aixinjueluo-puyi'])) {
      return $r('app.media.avatar_puyi')
    }
    return null
  }

  private innerSize(): number {
    return Math.max(this.avatarSize - 10, 28)
  }

  private frameRadius(): number {
    return Math.max(this.avatarSize * 0.28, 14)
  }

  private topColor(): string {
    return this.fallbackColors.length > 0 ? this.fallbackColors[0] : DEFAULT_FALLBACK_COLORS[0]
  }

  private middleColor(): string {
    if (this.fallbackColors.length > 2) {
      return this.fallbackColors[1]
    }
    return this.topColor()
  }

  private bottomColor(): string {
    if (this.fallbackColors.length > 1) {
      return this.fallbackColors[this.fallbackColors.length - 1]
    }
    return this.topColor()
  }

  private getAvatarChar(): string {
    return this.displayName.length > 0 ? this.displayName.charAt(0) : '?'
  }

  private hasAvatarResource(): boolean {
    return this.resolveAvatarResource() !== null
  }

  private mustResolveAvatarResource(): Resource {
    const resource: Resource | null = this.resolveAvatarResource()
    return resource !== null ? resource : $r('app.media.avatar_graduate')
  }

  @Builder
  private buildFallbackAvatar() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.innerSize())
        .height(this.innerSize())
        .borderRadius(this.innerSize() / 2)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [this.topColor(), 0],
            [this.middleColor(), 0.55],
            [this.bottomColor(), 1]
          ]
        })

      Text(this.getAvatarChar())
        .fontSize(this.innerSize() * 0.38)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.highlighted ? '#FFFFFF' : Colors.primary)
    }
  }

  @Builder
  private buildImageAvatar() {
    Image(this.mustResolveAvatarResource())
      .width(this.innerSize())
      .height(this.innerSize())
      .borderRadius(this.innerSize() / 2)
      .objectFit(ImageFit.Cover)
      .shadow({
        radius: this.highlighted ? 12 : 8,
        color: this.highlighted ? 'rgba(99, 102, 241, 0.12)' : 'rgba(15, 23, 42, 0.05)',
        offsetX: 0,
        offsetY: 3
      })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(this.frameRadius())
        .backgroundColor(this.highlighted ? 'rgba(255, 255, 255, 0.96)' : 'rgba(255, 255, 255, 0.90)')
        .border({
          width: 1,
          color: this.highlighted ? 'rgba(99, 102, 241, 0.14)' : 'rgba(255, 255, 255, 0.95)',
          radius: this.frameRadius()
        })
        .shadow({
          radius: this.highlighted ? 14 : 10,
          color: this.highlighted ? 'rgba(99, 102, 241, 0.10)' : 'rgba(15, 23, 42, 0.05)',
          offsetX: 0,
          offsetY: 4
        })

      if (this.hasAvatarResource()) {
        this.buildImageAvatar()
      } else {
        this.buildFallbackAvatar()
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
  }
}
