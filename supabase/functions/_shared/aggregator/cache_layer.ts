/**
 * 缓存层
 * 负责管理动漫数据的缓存读写操作
 * 
 * 使用内存缓存，避免外部依赖
 * 
 * @module cache_layer
 * Requirements: 6.1, 6.2, 6.3
 */

/**
 * 缓存条目接口
 */
interface CacheEntry<T> {
  data: T;
  expiresAt: number; // Unix timestamp in ms
}

/**
 * 内存缓存存储
 */
const memoryCache = new Map<string, CacheEntry<unknown>>();

/**
 * 缓存层类
 * 实现基于内存的缓存机制（无外部依赖）
 * 
 * Property 5: 缓存一致性
 * Validates: Requirements 6.2
 */
export class CacheLayer {
  /**
   * 从缓存读取数据
   * 检查 TTL，如果过期则返回 null
   * 
   * @param key 缓存键
   * @returns 缓存数据或 null（如果不存在或已过期）
   */
  async get<T>(key: string): Promise<T | null> {
    try {
      const entry = memoryCache.get(key) as CacheEntry<T> | undefined;
      
      if (!entry) {
        return null;
      }

      // 检查是否过期
      if (Date.now() > entry.expiresAt) {
        memoryCache.delete(key);
        return null;
      }

      return entry.data;
    } catch (error) {
      console.error(`[CacheLayer] Error reading cache for key "${key}":`, error);
      return null;
    }
  }

  /**
   * 写入缓存数据
   * 设置过期时间
   * 
   * @param key 缓存键
   * @param value 要缓存的数据
   * @param ttlSeconds TTL（秒），默认 3600（1小时）
   */
  async set<T>(key: string, value: T, ttlSeconds: number = 3600): Promise<void> {
    try {
      const entry: CacheEntry<T> = {
        data: value,
        expiresAt: Date.now() + ttlSeconds * 1000,
      };
      
      memoryCache.set(key, entry);
    } catch (error) {
      console.error(`[CacheLayer] Error writing cache for key "${key}":`, error);
    }
  }

  /**
   * 删除指定缓存
   * 
   * @param key 缓存键
   */
  async delete(key: string): Promise<void> {
    memoryCache.delete(key);
  }

  /**
   * 清理所有过期缓存
   * 
   * @returns 删除的缓存条目数量
   */
  async clearExpired(): Promise<number> {
    const now = Date.now();
    let count = 0;
    
    for (const [key, entry] of memoryCache.entries()) {
      if (now > entry.expiresAt) {
        memoryCache.delete(key);
        count++;
      }
    }
    
    return count;
  }

  /**
   * 检查缓存是否存在且未过期
   * 
   * @param key 缓存键
   * @returns 是否存在有效缓存
   */
  async has(key: string): Promise<boolean> {
    const data = await this.get(key);
    return data !== null;
  }

  /**
   * 获取缓存的剩余 TTL（秒）
   * 
   * @param key 缓存键
   * @returns 剩余 TTL（秒），如果不存在或已过期返回 -1
   */
  async getTTL(key: string): Promise<number> {
    const entry = memoryCache.get(key);
    
    if (!entry) {
      return -1;
    }

    const ttl = Math.floor((entry.expiresAt - Date.now()) / 1000);
    return ttl > 0 ? ttl : -1;
  }

  /**
   * 清空所有缓存
   */
  async clear(): Promise<void> {
    memoryCache.clear();
  }
}
