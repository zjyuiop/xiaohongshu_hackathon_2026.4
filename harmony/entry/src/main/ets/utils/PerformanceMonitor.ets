/**
 * 性能监控管理器
 *
 * HarmonyOS 特性：
 * 1. 页面加载性能监控
 * 2. 组件渲染性能监控
 * 3. 内存使用监控
 * 4. 帧率监控
 * 5. 网络请求性能监控
 */

interface PerformanceMetric {
  name: string
  startTime: number
  endTime?: number
  duration?: number
  metadata?: Record<string, ESObject>
}

interface PageLoadMetric {
  pageName: string
  loadTime: number
  timestamp: number
}

interface RenderMetric {
  componentName: string
  renderTime: number
  timestamp: number
}

export class PerformanceMonitor {
  private static instance: PerformanceMonitor | null = null
  private readonly metrics: Map<string, PerformanceMetric> = new Map()
  private readonly pageLoadMetrics: PageLoadMetric[] = []
  private readonly renderMetrics: RenderMetric[] = []
  private readonly maxMetricsCount: number = 100
  private isEnabled: boolean = true

  private constructor() {
    // 私有构造函数，实现单例模式
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): PerformanceMonitor {
    if (PerformanceMonitor.instance === null) {
      PerformanceMonitor.instance = new PerformanceMonitor()
    }
    return PerformanceMonitor.instance
  }

  /**
   * 启用/禁用性能监控
   * HarmonyOS 特性：生产环境可以禁用以提升性能
   */
  public setEnabled(enabled: boolean): void {
    this.isEnabled = enabled
  }

  /**
   * 开始性能测量
   * @param name 测量名称
   * @param metadata 附加元数据
   */
  public start(name: string, metadata?: Record<string, ESObject>): void {
    if (!this.isEnabled) {
      return
    }

    this.metrics.set(name, {
      name: name,
      startTime: Date.now(),
      metadata: metadata
    })
  }

  /**
   * 结束性能测量
   * @param name 测量名称
   * @returns 测量时长（毫秒）
   */
  public end(name: string): number {
    if (!this.isEnabled) {
      return 0
    }

    const metric = this.metrics.get(name)
    if (!metric) {
      console.warn(`Performance metric "${name}" not found`)
      return 0
    }

    const endTime = Date.now()
    const duration = endTime - metric.startTime

    metric.endTime = endTime
    metric.duration = duration

    // 输出性能日志
    this.logMetric(metric)

    return duration
  }

  /**
   * 测量异步操作性能
   * HarmonyOS 特性：自动处理异步操作的性能测量
   *
   * @param name 测量名称
   * @param asyncFn 异步函数
   * @returns Promise<T>
   */
  public async measure<T>(
    name: string,
    asyncFn: () => Promise<T>
  ): Promise<T> {
    if (!this.isEnabled) {
      return asyncFn()
    }

    this.start(name)
    try {
      const result = await asyncFn()
      this.end(name)
      return result
    } catch (error) {
      this.end(name)
      throw error
    }
  }

  /**
   * 记录页面加载性能
   * HarmonyOS 特性：监控页面加载时间
   *
   * @param pageName 页面名称
   * @param loadTime 加载时间（毫秒）
   */
  public recordPageLoad(pageName: string, loadTime: number): void {
    if (!this.isEnabled) {
      return
    }

    this.pageLoadMetrics.push({
      pageName: pageName,
      loadTime: loadTime,
      timestamp: Date.now()
    })

    // 限制数组大小
    if (this.pageLoadMetrics.length > this.maxMetricsCount) {
      this.pageLoadMetrics.shift()
    }

    console.info(`[Performance] Page "${pageName}" loaded in ${loadTime}ms`)
  }

  /**
   * 记录组件渲染性能
   * HarmonyOS 特性：监控组件渲染时间
   *
   * @param componentName 组件名称
   * @param renderTime 渲染时间（毫秒）
   */
  public recordRender(componentName: string, renderTime: number): void {
    if (!this.isEnabled) {
      return
    }

    this.renderMetrics.push({
      componentName: componentName,
      renderTime: renderTime,
      timestamp: Date.now()
    })

    // 限制数组大小
    if (this.renderMetrics.length > this.maxMetricsCount) {
      this.renderMetrics.shift()
    }

    // 如果渲染时间超过阈值，输出警告
    if (renderTime > 16) { // 60fps = 16.67ms per frame
      console.warn(`[Performance] Component "${componentName}" render took ${renderTime}ms (>16ms)`)
    }
  }

  /**
   * 获取页面加载性能统计
   */
  public getPageLoadStats(): {
    averageLoadTime: number
    minLoadTime: number
    maxLoadTime: number
    totalPages: number
  } {
    if (this.pageLoadMetrics.length === 0) {
      return {
        averageLoadTime: 0,
        minLoadTime: 0,
        maxLoadTime: 0,
        totalPages: 0
      }
    }

    const loadTimes = this.pageLoadMetrics.map((m: PageLoadMetric) => m.loadTime)
    const sum = loadTimes.reduce((a: number, b: number) => a + b, 0)

    return {
      averageLoadTime: sum / loadTimes.length,
      minLoadTime: Math.min(...loadTimes),
      maxLoadTime: Math.max(...loadTimes),
      totalPages: this.pageLoadMetrics.length
    }
  }

  /**
   * 获取组件渲染性能统计
   */
  public getRenderStats(): {
    averageRenderTime: number
    minRenderTime: number
    maxRenderTime: number
    totalRenders: number
    slowRenders: number
  } {
    if (this.renderMetrics.length === 0) {
      return {
        averageRenderTime: 0,
        minRenderTime: 0,
        maxRenderTime: 0,
        totalRenders: 0,
        slowRenders: 0
      }
    }

    const renderTimes = this.renderMetrics.map((m: RenderMetric) => m.renderTime)
    const sum = renderTimes.reduce((a: number, b: number) => a + b, 0)
    const slowRenders = renderTimes.filter((t: number) => t > 16).length

    return {
      averageRenderTime: sum / renderTimes.length,
      minRenderTime: Math.min(...renderTimes),
      maxRenderTime: Math.max(...renderTimes),
      totalRenders: this.renderMetrics.length,
      slowRenders: slowRenders
    }
  }

  /**
   * 输出性能日志
   */
  private logMetric(metric: PerformanceMetric): void {
    const duration = metric.duration || 0
    let level = 'info'

    // 根据时长判断日志级别
    if (duration > 1000) {
      level = 'warn'
    } else if (duration > 3000) {
      level = 'error'
    }

    const message = `[Performance] ${metric.name}: ${duration}ms`

    if (level === 'warn') {
      console.warn(message, metric.metadata)
    } else if (level === 'error') {
      console.error(message, metric.metadata)
    } else {
      console.info(message, metric.metadata)
    }
  }

  /**
   * 清空所有性能数据
   */
  public clear(): void {
    this.metrics.clear()
    this.pageLoadMetrics.length = 0
    this.renderMetrics.length = 0
  }

  /**
   * 导出性能报告
   * HarmonyOS 特性：生成性能分析报告
   */
  public exportReport(): string {
    const pageStats = this.getPageLoadStats()
    const renderStats = this.getRenderStats()

    const report = {
      timestamp: new Date().toISOString(),
      pageLoad: pageStats,
      render: renderStats,
      recentMetrics: Array.from(this.metrics.values())
        .filter((m: PerformanceMetric) => m.duration !== undefined)
        .slice(-20)
    }

    return JSON.stringify(report, null, 2)
  }

  /**
   * 打印性能摘要
   */
  public printSummary(): void {
    console.info('=== Performance Summary ===')
    console.info('Page Load Stats:', this.getPageLoadStats())
    console.info('Render Stats:', this.getRenderStats())
    console.info('========================')
  }
}

/**
 * 导出单例实例
 */
export const performanceMonitor = PerformanceMonitor.getInstance()

/**
 * 性能测量装饰器（用于方法）
 * HarmonyOS 特性：使用装饰器简化性能监控
 *
 * 使用示例：
 * @measurePerformance('loadUserData')
 * async loadUserData(): Promise<void> {
 *   // 方法实现
 * }
 */
export function measurePerformance(metricName: string) {
  return function (
    target: Object,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value

    descriptor.value = async function (...args: ESObject[]) {
      performanceMonitor.start(metricName)
      try {
        const result = await originalMethod.apply(this, args)
        performanceMonitor.end(metricName)
        return result
      } catch (error) {
        performanceMonitor.end(metricName)
        throw error
      }
    }

    return descriptor
  }
}
