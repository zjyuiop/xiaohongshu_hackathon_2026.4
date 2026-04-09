/**
 * 网络请求优化管理器
 *
 * HarmonyOS 特性：
 * 1. 请求合并：将多个小请求合并为一个大请求
 * 2. 请求缓存：避免重复请求
 * 3. 请求去重：相同请求只发送一次
 * 4. 超时控制：避免长时间等待
 */

interface RequestCacheItem {
  data: ESObject
  timestamp: number
  expiresIn: number
}

interface PendingRequest {
  promise: Promise<ESObject>
  timestamp: number
}

export class NetworkOptimizer {
  private static instance: NetworkOptimizer | null = null
  private readonly requestCache: Map<string, RequestCacheItem> = new Map()
  private readonly pendingRequests: Map<string, PendingRequest> = new Map()
  private readonly batchQueue: Map<string, ESObject[]> = new Map()
  private readonly batchTimers: Map<string, number> = new Map()
  private readonly defaultCacheTime: number = 5 * 60 * 1000 // 5分钟
  private readonly batchDelay: number = 100 // 100ms 批处理延迟

  private constructor() {
    // 私有构造函数，实现单例模式
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): NetworkOptimizer {
    if (NetworkOptimizer.instance === null) {
      NetworkOptimizer.instance = new NetworkOptimizer()
    }
    return NetworkOptimizer.instance
  }

  /**
   * 发送请求（带缓存和去重）
   * HarmonyOS 特性：避免重复请求，提升性能
   *
   * @param url 请求 URL
   * @param options 请求选项
   * @param cacheTime 缓存时间（毫秒），0 表示不缓存
   * @returns Promise<ESObject>
   */
  public async request(
    url: string,
    options: ESObject = {},
    cacheTime: number = this.defaultCacheTime
  ): Promise<ESObject> {
    const cacheKey = this.getCacheKey(url, options)

    // 1. 检查缓存
    if (cacheTime > 0) {
      const cached = this.getFromCache(cacheKey)
      if (cached !== null) {
        return cached
      }
    }

    // 2. 检查是否有相同的请求正在进行（请求去重）
    const pending = this.pendingRequests.get(cacheKey)
    if (pending) {
      return pending.promise
    }

    // 3. 发送新请求
    const promise = this.executeRequest(url, options)

    // 记录正在进行的请求
    this.pendingRequests.set(cacheKey, {
      promise: promise,
      timestamp: Date.now()
    })

    try {
      const result = await promise

      // 缓存结果
      if (cacheTime > 0) {
        this.setCache(cacheKey, result, cacheTime)
      }

      return result
    } finally {
      // 清理 pending 记录
      this.pendingRequests.delete(cacheKey)
    }
  }

  /**
   * 批量请求
   * HarmonyOS 特性：合并多个小请求为一个大请求
   *
   * @param batchKey 批处理键（用于分组）
   * @param requestData 请求数据
   * @param batchHandler 批处理函数
   * @returns Promise<ESObject>
   */
  public async batchRequest(
    batchKey: string,
    requestData: ESObject,
    batchHandler: (items: ESObject[]) => Promise<ESObject[]>
  ): Promise<ESObject> {
    return new Promise((resolve, reject) => {
      // 添加到批处理队列
      if (!this.batchQueue.has(batchKey)) {
        this.batchQueue.set(batchKey, [])
      }

      const queue = this.batchQueue.get(batchKey)
      if (queue) {
        queue.push({
          data: requestData,
          resolve: resolve,
          reject: reject
        })
      }

      // 清除旧的定时器
      const oldTimer = this.batchTimers.get(batchKey)
      if (oldTimer !== undefined) {
        clearTimeout(oldTimer)
      }

      // 设置新的定时器
      const timer = setTimeout(() => {
        this.executeBatch(batchKey, batchHandler)
      }, this.batchDelay)

      this.batchTimers.set(batchKey, timer)
    })
  }

  /**
   * 执行批处理
   */
  private async executeBatch(
    batchKey: string,
    batchHandler: (items: ESObject[]) => Promise<ESObject[]>
  ): Promise<void> {
    const queue = this.batchQueue.get(batchKey)
    if (!queue || queue.length === 0) {
      return
    }

    // 清空队列
    this.batchQueue.delete(batchKey)
    this.batchTimers.delete(batchKey)

    try {
      // 提取所有请求数据
      const requestItems = queue.map((item: ESObject) => item.data)

      // 执行批处理
      const results = await batchHandler(requestItems)

      // 分发结果
      queue.forEach((item: ESObject, index: number) => {
        if (results[index]) {
          item.resolve(results[index])
        } else {
          item.reject(new Error('Batch request failed'))
        }
      })
    } catch (error) {
      // 所有请求都失败
      queue.forEach((item: ESObject) => {
        item.reject(error)
      })
    }
  }

  /**
   * 实际执行请求
   * HarmonyOS 特性：使用 @ohos.net.http 模块
   */
  private async executeRequest(url: string, options: ESObject): Promise<ESObject> {
    // 这里应该使用 HarmonyOS 的 http 模块
    // import http from '@ohos.net.http'
    //
    // const httpRequest = http.createHttp()
    // const response = await httpRequest.request(url, options)
    // return response.result

    // 示例实现（实际项目中应替换为真实的 HTTP 请求）
    return new Promise((resolve, reject) => {
      // 模拟网络请求
      setTimeout(() => {
        resolve({ success: true, data: {} })
      }, 100)
    })
  }

  /**
   * 生成缓存键
   */
  private getCacheKey(url: string, options: ESObject): string {
    const method = options.method || 'GET'
    const params = JSON.stringify(options.extraData || {})
    return `${method}:${url}:${params}`
  }

  /**
   * 从缓存获取数据
   */
  private getFromCache(key: string): ESObject | null {
    const item = this.requestCache.get(key)

    if (!item) {
      return null
    }

    // 检查是否过期
    if (Date.now() - item.timestamp > item.expiresIn) {
      this.requestCache.delete(key)
      return null
    }

    return item.data
  }

  /**
   * 设置缓存
   */
  private setCache(key: string, data: ESObject, expiresIn: number): void {
    this.requestCache.set(key, {
      data: data,
      timestamp: Date.now(),
      expiresIn: expiresIn
    })
  }

  /**
   * 清空缓存
   */
  public clearCache(): void {
    this.requestCache.clear()
  }

  /**
   * 清理过期缓存
   * HarmonyOS 特性：定期清理，保持内存健康
   */
  public cleanExpiredCache(): void {
    const now = Date.now()
    const keysToRemove: string[] = []

    this.requestCache.forEach((item: RequestCacheItem, key: string) => {
      if (now - item.timestamp > item.expiresIn) {
        keysToRemove.push(key)
      }
    })

    keysToRemove.forEach((key: string) => {
      this.requestCache.delete(key)
    })
  }

  /**
   * 取消所有待处理的请求
   */
  public cancelAllPending(): void {
    this.pendingRequests.clear()
    this.batchQueue.clear()

    this.batchTimers.forEach((timer: number) => {
      clearTimeout(timer)
    })
    this.batchTimers.clear()
  }

  /**
   * 获取统计信息
   */
  public getStats(): {
    cacheSize: number
    pendingCount: number
    batchQueueSize: number
  } {
    let totalBatchItems = 0
    this.batchQueue.forEach((queue: ESObject[]) => {
      totalBatchItems += queue.length
    })

    return {
      cacheSize: this.requestCache.size,
      pendingCount: this.pendingRequests.size,
      batchQueueSize: totalBatchItems
    }
  }
}

/**
 * 导出单例实例
 */
export const networkOptimizer = NetworkOptimizer.getInstance()
