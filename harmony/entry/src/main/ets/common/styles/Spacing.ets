// 统一间距规范

// 页面间距接口
export interface PageSpacing {
  horizontal: number
  vertical: number
  top: number
  bottom: number
}

// 卡片间距接口
export interface CardSpacing {
  small: number
  medium: number
  large: number
  xlarge: number
}

// 组件间距接口
export interface ComponentSpacing {
  tight: number
  normal: number
  relaxed: number
  loose: number
}

// 列表间距接口
export interface ListSpacing {
  item: number
  gap: number
  section: number
}

// Flex 主轴对齐接口
export interface MainAxisAlignment {
  start: FlexAlign
  center: FlexAlign
  end: FlexAlign
  spaceBetween: FlexAlign
  spaceAround: FlexAlign
}

// Flex 交叉轴对齐接口
export interface CrossAxisAlignment {
  start: VerticalAlign
  center: VerticalAlign
  end: VerticalAlign
}

// Flex 方向接口
export interface FlexDirectionOption {
  row: FlexDirection
  column: FlexDirection
  rowReverse: FlexDirection
  columnReverse: FlexDirection
}

// Flex 换行接口
export interface FlexWrapOption {
  wrap: FlexWrap
  nowrap: FlexWrap
}

// Spacing 主接口
export interface SpacingScheme {
  unit: number
  xxs: number
  xs: number
  sm: number
  md: number
  lg: number
  xl: number
  xxl: number
  xxxl: number
  huge: number
  giant: number
  massive: number
  page: PageSpacing
  card: CardSpacing
  component: ComponentSpacing
  list: ListSpacing
}

// FlexLayout 主接口
export interface FlexLayoutScheme {
  mainAxis: MainAxisAlignment
  crossAxis: CrossAxisAlignment
  direction: FlexDirectionOption
  wrap: FlexWrapOption
}

// Spacing 类
@Observed
class SpacingClass implements SpacingScheme {
  unit: number = 4
  xxs: number = 2
  xs: number = 4
  sm: number = 8
  md: number = 12
  lg: number = 16
  xl: number = 20
  xxl: number = 24
  xxxl: number = 28
  huge: number = 32
  giant: number = 40
  massive: number = 48

  page: PageSpacing = {
    horizontal: 24,
    vertical: 24,
    top: 24,
    bottom: 24
  }

  card: CardSpacing = {
    small: 16,
    medium: 20,
    large: 24,
    xlarge: 32
  }

  component: ComponentSpacing = {
    tight: 10,
    normal: 12,
    relaxed: 16,
    loose: 24
  }

  list: ListSpacing = {
    item: 12,
    gap: 14,
    section: 24
  }
}

// FlexLayout 类
@Observed
class FlexLayoutClass implements FlexLayoutScheme {
  mainAxis: MainAxisAlignment = {
    start: FlexAlign.Start,
    center: FlexAlign.Center,
    end: FlexAlign.End,
    spaceBetween: FlexAlign.SpaceBetween,
    spaceAround: FlexAlign.SpaceAround
  }

  crossAxis: CrossAxisAlignment = {
    start: VerticalAlign.Top,
    center: VerticalAlign.Center,
    end: VerticalAlign.Bottom
  }

  direction: FlexDirectionOption = {
    row: FlexDirection.Row,
    column: FlexDirection.Column,
    rowReverse: FlexDirection.RowReverse,
    columnReverse: FlexDirection.ColumnReverse
  }

  wrap: FlexWrapOption = {
    wrap: FlexWrap.Wrap,
    nowrap: FlexWrap.NoWrap
  }
}

// 导出实例
export const Spacing: SpacingScheme = new SpacingClass()
export const FlexLayout: FlexLayoutScheme = new FlexLayoutClass()
