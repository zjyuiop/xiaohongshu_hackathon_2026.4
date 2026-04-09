/**
 * 图片缓存管理器
 *
 * HarmonyOS 特性：
 * 1. 使用 Map 实现内存缓存
 * 2. LRU（最近最少使用）淘汰策略
 * 3. 自动内存管理，避免内存泄漏
 * 4. 支持缓存大小限制
 */

interface CacheItem {
  data: PixelMap | string
  timestamp: number
  size: number
  accessCount: number
}

export class ImageCacheManager {
  private static instance: ImageCacheManager | null = null
  private readonly cache: Map<string, CacheItem> = new Map()
  private readonly maxCacheSize: number = 50 * 1024 * 1024 // 50MB
  private currentCacheSize: number = 0
  private readonly maxAge: number = 30 * 60 * 1000 // 30分钟过期

  private constructor() {
    // 私有构造函数，实现单例模式
  }

  /**
   * 获取单例实例
   * HarmonyOS 特性：单例模式确保全局唯一的缓存管理器
   */
  public static getInstance(): ImageCacheManager {
    if (ImageCacheManager.instance === null) {
      ImageCacheManager.instance = new ImageCacheManager()
    }
    return ImageCacheManager.instance
  }

  /**
   * 设置缓存
   * @param key 缓存键
   * @param data 图片数据
   * @param size 数据大小（字节）
   */
  public set(key: string, data: PixelMap | string, size: number): void {
    // 检查是否需要清理缓存
    if (this.currentCacheSize + size > this.maxCacheSize) {
      this.evictLRU(size)
    }

    // 如果键已存在，先移除旧数据
    if (this.cache.has(key)) {
      const oldItem = this.cache.get(key)
      if (oldItem) {
        this.currentCacheSize -= oldItem.size
      }
    }

    // 添加新缓存项
    const item: CacheItem = {
      data: data,
      timestamp: Date.now(),
      size: size,
      accessCount: 0
    }

    this.cache.set(key, item)
    this.currentCacheSize += size
  }

  /**
   * 获取缓存
   * @param key 缓存键
   * @returns 缓存的图片数据，如果不存在或已过期则返回 null
   */
  public get(key: string): PixelMap | string | null {
    const item = this.cache.get(key)

    if (!item) {
      return null
    }

    // 检查是否过期
    if (Date.now() - item.timestamp > this.maxAge) {
      this.remove(key)
      return null
    }

    // 更新访问计数
    item.accessCount++
    item.timestamp = Date.now()

    return item.data
  }

  /**
   * 移除指定缓存
   * @param key 缓存键
   */
  public remove(key: string): void {
    const item = this.cache.get(key)
    if (item) {
      this.currentCacheSize -= item.size
      this.cache.delete(key)
    }
  }

  /**
   * 清空所有缓存
   * HarmonyOS 特性：及时释放内存，避免内存泄漏
   */
  public clear(): void {
    this.cache.clear()
    this.currentCacheSize = 0
  }

  /**
   * LRU 淘汰策略
   * HarmonyOS 特性：根据访问频率和时间淘汰缓存
   * @param requiredSize 需要释放的空间大小
   */
  private evictLRU(requiredSize: number): void {
    // 将缓存项转换为数组并排序
    const entries = Array.from(this.cache.entries())

    // 按访问计数和时间戳排序（访问少且时间久的优先淘汰）
    entries.sort((a, b) => {
      const scoreA = a[1].accessCount / (Date.now() - a[1].timestamp)
      const scoreB = b[1].accessCount / (Date.now() - b[1].timestamp)
      return scoreA - scoreB
    })

    let freedSize = 0
    let index = 0

    // 淘汰缓存直到释放足够空间
    while (freedSize < requiredSize && index < entries.length) {
      const [key, item] = entries[index]
      freedSize += item.size
      this.remove(key)
      index++
    }
  }

  /**
   * 清理过期缓存
   * HarmonyOS 特性：定期清理，保持内存健康
   */
  public cleanExpired(): void {
    const now = Date.now()
    const keysToRemove: string[] = []

    this.cache.forEach((item: CacheItem, key: string) => {
      if (now - item.timestamp > this.maxAge) {
        keysToRemove.push(key)
      }
    })

    keysToRemove.forEach((key: string) => {
      this.remove(key)
    })
  }

  /**
   * 获取缓存统计信息
   */
  public getStats(): {
    itemCount: number
    totalSize: number
    maxSize: number
    usagePercent: number
  } {
    return {
      itemCount: this.cache.size,
      totalSize: this.currentCacheSize,
      maxSize: this.maxCacheSize,
      usagePercent: (this.currentCacheSize / this.maxCacheSize) * 100
    }
  }

  /**
   * 预加载图片
   * HarmonyOS 特性：异步加载，不阻塞主线程
   * @param urls 图片 URL 列表
   */
  public async preloadImages(urls: string[]): Promise<void> {
    const promises = urls.map(async (url: string) => {
      if (!this.cache.has(url)) {
        try {
          // 这里应该调用实际的图片加载逻辑
          // 示例：const pixelMap = await loadImageFromUrl(url)
          // this.set(url, pixelMap, estimatedSize)
        } catch (error) {
          console.error(`Failed to preload image: ${url}`, error)
        }
      }
    })

    await Promise.all(promises)
  }
}

/**
 * 导出单例实例
 */
export const imageCache = ImageCacheManager.getInstance()
