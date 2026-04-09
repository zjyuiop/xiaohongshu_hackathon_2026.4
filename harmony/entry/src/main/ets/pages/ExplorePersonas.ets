import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { MintColors } from '../common/styles/MintColors'
import { Typography } from '../common/styles/Typography'
import { Spacing } from '../common/styles/Spacing'
import { BorderRadius } from '../common/styles/BorderRadius'
import {
  AnimationCurve,
  AnimationDuration,
  getStaggerDelay
} from '../common/styles/Animation'
import { fetchSafeAreaInsets } from '../common/WindowSafeArea'
import {
  SearchCategory,
  CategoryInfo,
  PersonaSearchResult,
  SearchHistoryItem,
  PresetProfile
} from '../common/Models'
import {
  Icon,
  getCategoryIconType
} from '../components/CustomIcon'
import { PersonaAvatar } from '../components/PersonaAvatar'
import { PersonaApi } from '../service/PersonaApi'

const FALLBACK_SAFE_TOP_VP: number = 52
const RESULT_REVEAL_BATCH: number = 8

const CATEGORIES: CategoryInfo[] = [
  { id: 'all', name: '全部', icon: '', description: '查看全部人物' },
  { id: 'business', name: '商业', icon: '', description: '企业家和商业领袖' },
  { id: 'finance', name: '金融', icon: '', description: '投资者和市场人物' },
  { id: 'tech', name: '科技', icon: '', description: '科技创业者和产品人物' },
  { id: 'politics', name: '政治', icon: '', description: '政治人物和历史统治者' },
  { id: 'culture', name: '文化', icon: '', description: '作家、艺术家和文化人物' },
  { id: 'sports', name: '体育', icon: '', description: '运动员和体育明星' },
  { id: 'entertainment', name: '娱乐', icon: '', description: '演员、歌手和娱乐人物' },
  { id: 'education', name: '教育', icon: '', description: '教育者和学者' },
  { id: 'philosophy', name: '哲学', icon: '', description: '思想家和哲学人物' }
]

const EMPTY_SEARCH_RESULTS: PersonaSearchResult[] = []
const PROFILE_CATEGORY_OVERRIDES: Record<string, SearchCategory> = {
  'bernard-baruch': 'finance',
  'warren-buffett': 'finance',
  'peter-lynch': 'finance',
  'steve-jobs': 'tech',
  'elon-musk': 'tech',
  'jack-ma': 'business',
  'zhang-yiming': 'tech',
  'puyi': 'politics',
  'confucius': 'philosophy',
  'qin': 'politics',
  'qin-shihuang': 'politics',
  'graduate': 'education'
}
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  'business': ['business', 'founder', 'ceo', 'company', 'commercial', '创业', '企业', '商业', '管理'],
  'finance': ['finance', 'invest', 'investor', 'investment', 'market', 'capital', 'value', 'trading', '股票', '投资', '金融', '资本', '市场'],
  'tech': ['tech', 'technology', 'product', 'apple', 'tesla', 'spacex', 'algorithm', 'startup', '科技', '技术', '产品', '互联网', '工程'],
  'politics': ['politics', 'political', 'government', 'emperor', 'king', 'dynasty', 'leader', '政治', '皇帝', '君主', '朝代', '统治'],
  'culture': ['culture', 'writer', 'artist', 'poet', 'author', 'culture', '文化', '艺术', '作家', '诗人'],
  'sports': ['sports', 'athlete', 'football', 'basketball', 'olympic', '体育', '运动员', '比赛'],
  'entertainment': ['entertainment', 'actor', 'actress', 'singer', 'movie', 'film', 'fictional', '娱乐', '演员', '歌手', '影视'],
  'education': ['education', 'teacher', 'scholar', 'professor', 'learning', '教育', '学者', '老师', '教授'],
  'philosophy': ['philosophy', 'philosopher', 'thinker', '儒家', '哲学', '思想']
}
const SEARCH_MATCH_LABEL: string = '名称匹配'

@Entry
@Component
struct ExplorePersonas {
  @State searchText: string = ''
  @State selectedCategory: SearchCategory = 'all'
  @State allResults: PersonaSearchResult[] = []
  @State searchResults: PersonaSearchResult[] = []
  @State isSearching: boolean = false
  @State isLoadingPresets: boolean = false
  @State loadError: string = ''
  @State searchHistory: SearchHistoryItem[] = []
  @State showHistory: boolean = false
  @State safeTopVp: number = 0
  @State safeBottomVp: number = 0
  @State heroOpacity: number = 0
  @State heroTranslateY: number = 28
  @State searchPanelOpacity: number = 0
  @State searchPanelTranslateY: number = 22
  @State categoryBarOpacity: number = 0
  @State categoryBarTranslateY: number = 18
  @State resultsOpacity: number = 0
  @State resultsTranslateY: number = 28
  @State visibleCardCount: number = 0

  private latestSearchToken: number = 0
  private latestRevealToken: number = 0

  aboutToAppear(): void {
    this.loadSafeInsets()
    this.resetSearchResults()
    this.playEntranceAnimation()
    void this.hydratePresets()
  }

  loadSafeInsets(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      fetchSafeAreaInsets(ctx).then((insets) => {
        this.safeTopVp = insets.topVp
        this.safeBottomVp = insets.bottomVp
      })
    } catch (_e) {
      // 蹇界暐閿欒
    }
  }

  resetSearchResults(): void {
    this.allResults = EMPTY_SEARCH_RESULTS
    this.searchResults = EMPTY_SEARCH_RESULTS
    this.visibleCardCount = 0
    this.loadError = ''
  }

  topInsetVp(): number {
    return this.safeTopVp > 0 ? this.safeTopVp : FALLBACK_SAFE_TOP_VP
  }

  playEntranceAnimation(): void {
    this.resultsOpacity = 0
    this.resultsTranslateY = 28
    this.visibleCardCount = 0

    animateTo({
      duration: AnimationDuration.slow,
      curve: AnimationCurve.smooth
    }, () => {
      this.heroOpacity = 1
      this.heroTranslateY = 0
    })

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.smooth
      }, () => {
        this.searchPanelOpacity = 1
        this.searchPanelTranslateY = 0
      })
    }, 80)

    setTimeout(() => {
      animateTo({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.smooth
      }, () => {
        this.categoryBarOpacity = 1
        this.categoryBarTranslateY = 0
      })
    }, 140)

    setTimeout(() => {
      const revealToken = ++this.latestRevealToken
      animateTo({
        duration: AnimationDuration.slow,
        curve: AnimationCurve.smooth
      }, () => {
        this.resultsOpacity = 1
        this.resultsTranslateY = 0
      })
      this.revealResults(revealToken)
    }, 220)
  }

  createBaseResults(): PersonaSearchResult[] {
    if (this.selectedCategory === 'all') {
      return this.allResults.slice()
    }
    return this.allResults.filter((person) => person.category === this.selectedCategory)
  }

  normalizeKey(value: string): string {
    return value.trim().toLowerCase()
  }

  containsKeyword(text: string, keywords: string[]): boolean {
    for (let i = 0; i < keywords.length; i++) {
      if (text.includes(keywords[i])) {
        return true
      }
    }
    return false
  }

  dedupeStrings(values: string[], limit: number): string[] {
    const uniqueValues: string[] = []
    const seen = new Set<string>()

    for (let i = 0; i < values.length && uniqueValues.length < limit; i++) {
      const trimmed = values[i].trim()
      if (!trimmed.length || seen.has(trimmed)) {
        continue
      }
      seen.add(trimmed)
      uniqueValues.push(trimmed)
    }

    return uniqueValues
  }

  buildSearchText(profile: PresetProfile): string {
    const parts: string[] = [
      profile.id,
      profile.displayName,
      profile.subtitle,
      profile.biography,
      ...profile.highlights,
      ...profile.suggestedTopics
    ]
    return this.normalizeKey(parts.join(' '))
  }

  resolvePresetCategory(profile: PresetProfile): SearchCategory {
    const override = PROFILE_CATEGORY_OVERRIDES[profile.id]
    if (override) {
      return override
    }

    const searchText = this.buildSearchText(profile)
    const keywordCategories: SearchCategory[] = [
      'finance',
      'tech',
      'business',
      'politics',
      'philosophy',
      'culture',
      'education',
      'entertainment',
      'sports'
    ]

    for (let i = 0; i < keywordCategories.length; i++) {
      const category = keywordCategories[i]
      if (this.containsKeyword(searchText, CATEGORY_KEYWORDS[category] || [])) {
        return category
      }
    }

    if (profile.category === 'history') {
      return 'politics'
    }
    if (profile.category === 'fictional') {
      return 'entertainment'
    }
    if (profile.category === 'self') {
      return 'education'
    }

    return 'business'
  }

  buildResultTags(profile: PresetProfile, category: SearchCategory): string[] {
    const categoryName = this.getCategoryName(category)
    const pool = this.dedupeStrings([...profile.highlights, ...profile.suggestedTopics], 8)
    const out: string[] = []
    for (let i = 0; i < pool.length && out.length < 3; i++) {
      const t = pool[i].trim()
      if (!t.length || t === categoryName) {
        continue
      }
      let dup = false
      for (let j = 0; j < out.length; j++) {
        if (out[j] === t) {
          dup = true
          break
        }
      }
      if (!dup) {
        out.push(t)
      }
    }
    return out
  }

  buildResultReasons(profile: PresetProfile, category: SearchCategory): string[] {
    return this.dedupeStrings(
      [this.getCategoryName(category), profile.subtitle, ...profile.highlights, ...profile.suggestedTopics],
      4
    )
  }

  buildHotLevel(profile: PresetProfile): number {
    const base = profile.highlights.length >= 3 ? 5 : 4
    return profile.suggestedTopics.length >= 3 ? base : Math.max(3, base - 1)
  }

  mapPresetToSearchResult(profile: PresetProfile): PersonaSearchResult {
    const category = this.resolvePresetCategory(profile)
    return {
      id: profile.id,
      displayName: profile.displayName,
      subtitle: profile.subtitle,
      category,
      coverSeed: profile.coverSeed,
      matchReason: this.buildResultReasons(profile, category),
      hotLevel: this.buildHotLevel(profile),
      tags: this.buildResultTags(profile, category)
    }
  }

  normalizeError(error: Object): string {
    const maybeMessage = error as Record<string, string>
    if (maybeMessage.message) {
      return maybeMessage.message
    }
    return '加载失败，请检查后端连接'
  }

  async hydratePresets(): Promise<void> {
    this.isLoadingPresets = true
    this.loadError = ''

    try {
      const presets = await PersonaApi.getPresets()
      const nextResults: PersonaSearchResult[] = []

      for (let index = 0; index < presets.length; index++) {
        nextResults.push(this.mapPresetToSearchResult(presets[index]))
      }

      nextResults.sort((a, b) => b.hotLevel - a.hotLevel)
      this.allResults = nextResults

      if (this.searchText.trim().length > 0) {
        this.performSearch(this.searchText)
      } else {
        this.applyResults(this.createBaseResults(), false)
      }
    } catch (error) {
      this.allResults = EMPTY_SEARCH_RESULTS
      this.applyResults(EMPTY_SEARCH_RESULTS, false)
      this.loadError = this.normalizeError(error as Object)
    } finally {
      this.isLoadingPresets = false
    }
  }

  applyResults(nextResults: PersonaSearchResult[], useSwapMotion: boolean = true): void {
    const revealToken = ++this.latestRevealToken

    if (!useSwapMotion) {
      this.searchResults = nextResults
      this.revealResults(revealToken)
      return
    }

    animateTo({
      duration: AnimationDuration.fast,
      curve: AnimationCurve.accelerated
    }, () => {
      this.resultsOpacity = 0.7
      this.resultsTranslateY = 12
      this.visibleCardCount = 0
    })

    setTimeout(() => {
      if (revealToken !== this.latestRevealToken) {
        return
      }

      this.searchResults = nextResults
      animateTo({
        duration: AnimationDuration.normal,
        curve: AnimationCurve.smooth
      }, () => {
        this.resultsOpacity = 1
        this.resultsTranslateY = 0
      })
      this.revealResults(revealToken)
    }, 90)
  }

  revealResults(revealToken: number): void {
    this.visibleCardCount = 0
    if (this.searchResults.length === 0) {
      return
    }

    const revealLimit = Math.min(this.searchResults.length, RESULT_REVEAL_BATCH)

    for (let index = 0; index < revealLimit; index++) {
      const delay = getStaggerDelay(index, 35)
      setTimeout(() => {
        if (revealToken !== this.latestRevealToken) {
          return
        }
        this.visibleCardCount = index + 1
      }, delay)
    }

    if (this.searchResults.length > revealLimit) {
      setTimeout(() => {
        if (revealToken !== this.latestRevealToken) {
          return
        }
        this.visibleCardCount = this.searchResults.length
      }, getStaggerDelay(revealLimit, 35))
    }
  }

  performSearch(keyword: string): void {
    const currentToken = ++this.latestSearchToken

    if (!keyword.trim()) {
      this.isSearching = false
      this.showHistory = false
      this.applyResults(this.createBaseResults())
      return
    }

    this.isSearching = true
    this.showHistory = false

    setTimeout(() => {
      if (currentToken !== this.latestSearchToken) {
        return
      }

      const lowerKeyword = keyword.toLowerCase()
      const baseResults = this.createBaseResults()

      const nextResults = baseResults.filter((person) => {
        const nameMatch = person.displayName.toLowerCase().includes(lowerKeyword)
        const tagMatch = person.tags.some(tag => tag.toLowerCase().includes(lowerKeyword))
        const reasonMatch = person.matchReason.some(reason => reason.toLowerCase().includes(lowerKeyword))
        const subtitleMatch = person.subtitle.toLowerCase().includes(lowerKeyword)

        return nameMatch || tagMatch || reasonMatch || subtitleMatch
      }).map((person) => {
        const matchReasons: string[] = []
        if (person.displayName.toLowerCase().includes(lowerKeyword)) {
          matchReasons.push(SEARCH_MATCH_LABEL)
        }
        person.tags.forEach(tag => {
          if (tag.toLowerCase().includes(lowerKeyword)) {
            matchReasons.push(tag)
          }
        })
        person.matchReason.forEach(reason => {
          if (reason.toLowerCase().includes(lowerKeyword)) {
            matchReasons.push(reason)
          }
        })

        const uniqueReasons: string[] = []
        const seen = new Set<string>()
        const combinedReasons = matchReasons.concat(person.matchReason)
        for (let i = 0; i < combinedReasons.length && uniqueReasons.length < 5; i++) {
          if (!seen.has(combinedReasons[i])) {
            seen.add(combinedReasons[i])
            uniqueReasons.push(combinedReasons[i])
          }
        }

      const result: PersonaSearchResult = {
          id: person.id,
          displayName: person.displayName,
          subtitle: person.subtitle,
          category: person.category,
          coverSeed: person.coverSeed,
          matchReason: uniqueReasons,
          hotLevel: person.hotLevel,
          tags: person.tags
        }
        return result
      })

      nextResults.sort((a, b) => b.hotLevel - a.hotLevel)
      this.applyResults(nextResults)
      this.isSearching = false
    }, 300)
  }

  filterByCategory(category: SearchCategory): void {
    this.selectedCategory = category

    if (this.searchText.trim()) {
      this.performSearch(this.searchText)
    } else {
      this.applyResults(this.createBaseResults())
    }
  }

  selectPersona(person: PersonaSearchResult): void {
    router.pushUrl({
      url: 'pages/ProfileDetail',
      params: {
        profileId: person.id
      }
    })
  }

  getCategoryName(categoryId: SearchCategory): string {
    const category = CATEGORIES.find(c => c.id === categoryId)
    return category ? category.name : ''
  }

  getCategoryGradient(category: SearchCategory): string[] {
    const gradientMap: Record<SearchCategory, string[]> = {
      'all': [MintColors.mintPale, MintColors.lavenderPale],
      'business': [MintColors.mintPale, 'rgba(78, 205, 196, 0.08)'],
      'finance': ['rgba(232, 184, 109, 0.1)', MintColors.lavenderPale],
      'tech': [MintColors.mintBg, 'rgba(78, 205, 196, 0.06)'],
      'politics': [MintColors.lavenderPale, 'rgba(184, 169, 217, 0.08)'],
      'culture': ['rgba(224, 120, 128, 0.08)', MintColors.lavenderPale],
      'sports': ['rgba(61, 189, 156, 0.1)', MintColors.mintPale],
      'entertainment': [MintColors.lavenderPale, 'rgba(168, 153, 199, 0.08)'],
      'education': [MintColors.mintBg, MintColors.lavenderPale],
      'philosophy': ['rgba(155, 138, 196, 0.1)', MintColors.lavenderPale]
    }
    return gradientMap[category] || gradientMap['all']
  }

  getAvatarGradient(category: SearchCategory): string[] {
    const gradientMap: Record<SearchCategory, string[]> = {
      'all': [MintColors.mintLight, MintColors.mint],
      'business': [MintColors.mintLight, MintColors.mintDark],
      'finance': ['#EDD48B', MintColors.warning],
      'tech': [MintColors.mintLight, MintColors.mint],
      'politics': [MintColors.lavenderLight, MintColors.lavender],
      'culture': [MintColors.lavenderLight, MintColors.lavender],
      'sports': ['#7FD4C0', MintColors.mintDark],
      'entertainment': [MintColors.lavenderLight, MintColors.lavenderDark],
      'education': [MintColors.mintLight, MintColors.mint],
      'philosophy': [MintColors.lavenderLight, MintColors.lavender]
    }
    return gradientMap[category] || gradientMap['all']
  }

  getCategoryChipBg(categoryId: string, isSelected: boolean): string {
    if (isSelected) {
      return MintColors.mint
    }
    const bgMap: Record<string, string> = {
      'all': MintColors.categoryAll,
      'business': MintColors.categoryBusiness,
      'finance': MintColors.categoryFinance,
      'tech': MintColors.categoryTech,
      'politics': MintColors.categoryPolitics,
      'culture': MintColors.categoryCulture,
      'sports': MintColors.categorySports,
      'entertainment': MintColors.categoryEntertainment,
      'education': MintColors.categoryEducation,
      'philosophy': MintColors.categoryPhilosophy
    }
    return bgMap[categoryId] || MintColors.categoryAll
  }

  getCategoryChipColor(categoryId: string, isSelected: boolean): string {
    if (isSelected) {
      return '#FFFFFF'
    }
    const colorMap: Record<string, string> = {
      'all': MintColors.mint,
      'business': MintColors.mintDark,
      'finance': MintColors.warning,
      'tech': MintColors.mint,
      'politics': MintColors.lavender,
      'culture': MintColors.error,
      'sports': MintColors.success,
      'entertainment': MintColors.lavender,
      'education': MintColors.mint,
      'philosophy': MintColors.lavenderDark
    }
    return colorMap[categoryId] || MintColors.mint
  }

  isResultVisible(personId: string): boolean {
    const index = this.searchResults.findIndex((item: PersonaSearchResult) => item.id === personId)
    return index >= 0 && index < this.visibleCardCount
  }

  isCategorySelected(categoryId: SearchCategory): boolean {
    return this.selectedCategory === categoryId
  }

  @Builder
  buildHotStars(level: number) {
    Row({ space: 2 }) {
      ForEach([0, 1, 2, 3, 4], (_: number, index: number) => {
        Icon({
          iconType: 'star',
          iconSize: 9,
          iconColor: index < level ? MintColors.warning : MintColors.border
        })
      })
    }
  }

  @Builder
  buildPersonaCard(person: PersonaSearchResult) {
    Column() {
      Row({ space: Spacing.md }) {
        PersonaAvatar({
          personaId: person.id,
          displayName: person.displayName,
          coverSeed: person.coverSeed,
          avatarSize: 52,
          fallbackColors: this.getAvatarGradient(person.category)
        })
        .shadow({
          radius: 12,
          color: 'rgba(78, 205, 196, 0.15)',
          offsetX: 0,
          offsetY: 4
        })

        Column({ space: 5 }) {
          Row({ space: Spacing.xs }) {
            Text(person.displayName)
              .fontSize(Typography.size.bodyLg)
              .fontWeight(FontWeight.Medium)
              .fontColor(MintColors.textPrimary)

            this.buildHotStars(person.hotLevel)
          }
          .width('100%')

          Text(person.subtitle)
            .fontSize(Typography.size.caption)
            .fontColor(MintColors.textMuted)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
            Column() {
              Text(this.getCategoryName(person.category))
                .fontSize(Typography.size.xs)
                .fontColor(MintColors.mintDark)
            }
            .margin({ right: 5, bottom: 5 })
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(MintColors.mintBg)
            .borderRadius(BorderRadius.tag)

            ForEach(person.tags, (tag: string, tagIndex: number) => {
              Column() {
                Text(tag)
                  .fontSize(Typography.size.xs)
                  .fontColor(MintColors.textMuted)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: '100%' })
              }
              .margin({ right: 5, bottom: 5 })
              .padding({ left: 6, right: 6, top: 3, bottom: 3 })
              .backgroundColor(MintColors.backgroundSecondary)
              .borderRadius(BorderRadius.tag)
              .constraintSize({ minWidth: 0 })
            }, (tag: string, tagIndex: number) => `${person.id}-tag-${tagIndex}`)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Icon({
          iconType: 'arrowRight',
          iconSize: 18,
          iconColor: MintColors.textMuted
        })
        .padding({ left: Spacing.xs })
      }
      .width('100%')

      if (this.searchText.trim() && person.matchReason.length > 0) {
        Column({ space: 5 }) {
          Text('匹配原因')
            .fontSize(Typography.size.xs)
            .fontColor(MintColors.textMuted)

          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Start }) {
            ForEach(person.matchReason.slice(0, 3), (reason: string, ri: number) => {
              Column() {
                Text(reason)
                  .fontSize(Typography.size.xs)
                  .fontColor(MintColors.mintDark)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: '100%' })
              }
              .margin({ right: 5, bottom: 3 })
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(MintColors.mintBg)
              .borderRadius(BorderRadius.chip)
              .constraintSize({ minWidth: 0 })
            }, (reason: string, ri: number) => `${person.id}-mr-${ri}`)
          }
          .width('100%')
        }
        .width('100%')
        .margin({ top: Spacing.sm })
        .padding({ left: Spacing.md, right: Spacing.md })
      }
    }
    .width('100%')
    .padding(Spacing.md)
    .backgroundColor(MintColors.cardPrimary)
    .borderRadius(BorderRadius.xxl)
    .border({
      width: 0.5,
      color: MintColors.border,
      radius: BorderRadius.xxl
    })
    .shadow({
      radius: 16,
      color: 'rgba(78, 205, 196, 0.06)',
      offsetX: 0,
      offsetY: 4
    })
    .opacity(this.isResultVisible(person.id) ? 1 : 0)
    .translate({ x: 0, y: this.isResultVisible(person.id) ? 0 : 22 })
    .scale({
      x: this.isResultVisible(person.id) ? 1 : 0.97,
      y: this.isResultVisible(person.id) ? 1 : 0.97
    })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.smooth
    })
    .onClick(() => {
      this.selectPersona(person)
    })
  }

  @Builder
  buildCategoryChip(category: CategoryInfo) {
    Column() {
      Row({ space: 4 }) {
        Icon({
          iconType: getCategoryIconType(category.id),
          iconSize: 10,
          iconColor: this.getCategoryChipColor(category.id, this.isCategorySelected(category.id))
        })
        Text(category.name)
          .fontSize(Typography.size.caption)
          .fontColor(this.getCategoryChipColor(category.id, this.isCategorySelected(category.id)))
      }
    }
    .padding({
      left: Spacing.md,
      right: Spacing.md,
      top: Spacing.sm,
      bottom: Spacing.sm
    })
    .backgroundColor(this.getCategoryChipBg(category.id, this.isCategorySelected(category.id)))
    .borderRadius(BorderRadius.xxl)
    .border({
      width: this.isCategorySelected(category.id) ? 0 : 0.5,
      color: MintColors.borderLight,
      radius: BorderRadius.xxl
    })
    .translate({ x: 0, y: this.isCategorySelected(category.id) ? -2 : 0 })
    .scale({
      x: this.isCategorySelected(category.id) ? 1.03 : 1,
      y: this.isCategorySelected(category.id) ? 1.03 : 1
    })
    .shadow({
      radius: this.isCategorySelected(category.id) ? 14 : 0,
      color: this.isCategorySelected(category.id)
        ? 'rgba(78, 205, 196, 0.12)'
        : 'rgba(78, 205, 196, 0)',
      offsetX: 0,
      offsetY: 5
    })
    .animation({
      duration: AnimationDuration.normal,
      curve: AnimationCurve.smooth
    })
    .onClick(() => {
      this.filterByCategory(category.id)
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(MintColors.background)

        Column()
          .width(280)
          .height(180)
          .borderRadius(140)
          .backgroundColor('rgba(78, 205, 196, 0.08)')
          .blur(80)
          .position({ x: -80, y: -50 })

        Column()
          .width(240)
          .height(160)
          .borderRadius(120)
          .backgroundColor('rgba(184, 169, 217, 0.07)')
          .blur(60)
          .position({ right: -60, y: -30 })
      }
      .width('100%')
      .height('100%')

      Scroll() {
        Column({ space: Spacing.md }) {
          Column({ space: Spacing.xs }) {
            Text('寻访前人')
              .fontSize(Typography.size.hero)
              .fontWeight(Typography.weight.bold)
              .fontColor(MintColors.textPrimary)

            Text('连接后端人物库，探索不同人生阶段的视角')
              .fontSize(Typography.size.body)
              .fontColor(MintColors.textMuted)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: this.topInsetVp() + 60 })
          .opacity(this.heroOpacity)
          .translate({ x: 0, y: this.heroTranslateY })
          .animation({
            duration: AnimationDuration.slow,
            curve: AnimationCurve.smooth
          })

          Column() {
            Row({ space: Spacing.sm }) {
              Icon({
                iconType: 'search',
                iconSize: 16,
                iconColor: MintColors.textMuted
              })

              TextInput({ placeholder: '搜索人物、角色或话题...', text: this.searchText })
                .layoutWeight(1)
                .placeholderColor(MintColors.textPlaceholder)
                .placeholderFont({
                  size: Typography.size.body,
                  weight: FontWeight.Normal
                })
                .fontSize(Typography.size.body)
                .fontColor(MintColors.textPrimary)
                .backgroundColor(Color.Transparent)
                .caretColor(MintColors.mint)
                .onChange((value: string) => {
                  this.searchText = value
                })
                .onSubmit(() => {
                  this.performSearch(this.searchText)
                })

              if (this.searchText.length > 0) {
                Column() {
                  Icon({
                    iconType: 'close',
                    iconSize: 12,
                    iconColor: MintColors.textMuted
                  })
                }
                .width(24)
                .height(24)
                .backgroundColor(MintColors.backgroundSecondary)
                .borderRadius(12)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  this.searchText = ''
                  this.performSearch('')
                })
              }
            }
            .width('100%')
            .padding({
              left: Spacing.md,
              right: Spacing.md,
              top: Spacing.sm,
              bottom: Spacing.sm
            })
          }
          .width('100%')
          .backgroundColor(MintColors.surfaceGlass)
          .borderRadius(BorderRadius.xxl)
          .border({
            width: 0.5,
            color: MintColors.border,
            radius: BorderRadius.xxl
          })
          .shadow({
            radius: 20,
            color: 'rgba(78, 205, 196, 0.08)',
            offsetX: 0,
            offsetY: 6
          })
          .opacity(this.searchPanelOpacity)
          .translate({ x: 0, y: this.searchPanelTranslateY })
          .scale({
            x: this.searchText.trim().length > 0 ? 1.01 : 1,
            y: this.searchText.trim().length > 0 ? 1.01 : 1
          })
          .animation({
            duration: AnimationDuration.normal,
            curve: AnimationCurve.smooth
          })

          Scroll() {
            Row({ space: Spacing.xs }) {
              ForEach(CATEGORIES, (category: CategoryInfo) => {
                this.buildCategoryChip(category)
              }, (category: CategoryInfo) => category.id)
            }
            .padding({
              left: 0,
              right: 0
            })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .padding({ left: 0, right: 0 })
          .opacity(this.categoryBarOpacity)
          .translate({ x: 0, y: this.categoryBarTranslateY })
          .animation({
            duration: AnimationDuration.normal,
            curve: AnimationCurve.smooth
          })

          Row() {
            if (this.isLoadingPresets) {
              Text('正在连接后端并加载人物...')
                .fontSize(Typography.size.sm)
                .fontColor(MintColors.textMuted)
            } else if (this.loadError.length > 0) {
              Text('人物库加载失败')
                .fontSize(Typography.size.sm)
                .fontColor(MintColors.error)
            } else {
              Text(`找到 ${this.searchResults.length} 个相关人物`)
                .fontSize(Typography.size.sm)
                .fontColor(MintColors.textMuted)
            }
          }
          .width('100%')
          .padding({ top: Spacing.xs })

          Column({ space: Spacing.sm }) {
            if (this.isLoadingPresets) {
              Column({ space: Spacing.sm }) {
                Text('正在从后端加载人物...')
                  .fontSize(Typography.size.bodyLg)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(MintColors.textSecondary)

                Text('首次加载可能需要几秒钟')
                  .fontSize(Typography.size.caption)
                  .fontColor(MintColors.textMuted)
              }
              .width('100%')
              .padding(Spacing.xl)
              .alignItems(HorizontalAlign.Center)
            } else if (this.loadError.length > 0) {
              Column({ space: Spacing.md }) {
                Icon({
                  iconType: 'sad',
                  iconSize: 32,
                  iconColor: MintColors.error
                })
                Text('后端连接失败')
                  .fontSize(Typography.size.bodyLg)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(MintColors.textSecondary)
                Text(this.loadError)
                  .fontSize(Typography.size.caption)
                  .fontColor(MintColors.textMuted)
                  .textAlign(TextAlign.Center)
                Button('重试')
                  .fontSize(Typography.size.caption)
                  .fontColor('#FFFFFF')
                  .backgroundColor(MintColors.mint)
                  .borderRadius(BorderRadius.xxl)
                  .padding({ left: Spacing.lg, right: Spacing.lg, top: Spacing.sm, bottom: Spacing.sm })
                  .onClick(() => {
                    void this.hydratePresets()
                  })
              }
              .width('100%')
              .padding(Spacing.xl)
              .alignItems(HorizontalAlign.Center)
            } else if (this.isSearching) {
              Column() {
                Text('搜索中...')
                  .fontSize(Typography.size.body)
                  .fontColor(MintColors.textSecondary)
              }
              .width('100%')
              .padding(Spacing.xl)
            } else if (this.searchResults.length === 0) {
              Column({ space: Spacing.md }) {
                Icon({
                  iconType: 'sad',
                  iconSize: 32,
                  iconColor: MintColors.textMuted
                })
                Text('暂无匹配结果')
                  .fontSize(Typography.size.bodyLg)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(MintColors.textSecondary)
                Text('试试其他关键词或分类')
                  .fontSize(Typography.size.caption)
                  .fontColor(MintColors.textMuted)
              }
              .width('100%')
              .padding(Spacing.xl)
              .alignItems(HorizontalAlign.Center)
            } else {
              ForEach(this.searchResults, (person: PersonaSearchResult) => {
                this.buildPersonaCard(person)
              }, (person: PersonaSearchResult) => person.id)
            }
          }
          .opacity(this.resultsOpacity)
          .translate({ x: 0, y: this.resultsTranslateY })
          .animation({
            duration: AnimationDuration.normal,
            curve: AnimationCurve.smooth
          })
          .padding({ bottom: this.safeBottomVp + Spacing.xl })
        }
        .padding({
          left: Spacing.page.horizontal,
          right: Spacing.page.horizontal
        })
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Button() {
        Icon({
          iconType: 'arrowLeft',
          iconSize: 16,
          iconColor: MintColors.mintDark
        })
      }
      .width(38)
      .height(38)
      .backgroundColor(MintColors.surfaceGlass)
      .borderRadius(19)
      .shadow({
        radius: 10,
        color: 'rgba(78, 205, 196, 0.1)',
        offsetX: 0,
        offsetY: 3
      })
      .position({ x: Spacing.page.horizontal, y: this.topInsetVp() + 12 })
      .onClick(() => {
        router.back()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MintColors.background)
  }
}

