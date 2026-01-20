/**
 * 缓存层 (Node.js 兼容版本，用于测试)
 * 负责管理动漫数据的缓存读写操作
 * 
 * @module cache_layer
 * Requirements: 6.1, 6.2, 6.3
 */

/**
 * 缓存条目接口
 */
export interface CacheEntry<T> {
  cache_key: string;
  data: T;
  expires_at: string;
  updated_at: string;
}

/**
 * 内存缓存条目
 */
interface CacheStoreEntry {
  data: unknown;
  expires_at: Date;
  updated_at: Date;
}

/**
 * 缓存层类（测试版本）
 * 使用内存存储模拟 Supabase 数据库缓存
 * 
 * Property 5: 缓存一致性
 * Validates: Requirements 6.2
 */
export class CacheLayer {
  private store: Map<string, CacheStoreEntry> = new Map();

  /**
   * 从缓存读取数据
   * 检查 TTL，如果过期则返回 null
   * 
   * @param key 缓存键
   * @returns 缓存数据或 null（如果不存在或已过期）
   * 
   * Requirements: 6.2 - 缓存未过期时直接返回缓存数据
   */
  async get<T>(key: string): Promise<T | null> {
    const entry = this.store.get(key);
    
    if (!entry) {
      return null;
    }

    const now = new Date();

    // 检查是否过期
    if (entry.expires_at < now) {
      // 删除过期缓存
      this.store.delete(key);
      return null;
    }

    return entry.data as T;
  }

  /**
   * 写入缓存数据
   * 设置过期时间
   * 
   * @param key 缓存键
   * @param value 要缓存的数据
   * @param ttlSeconds TTL（秒），默认 3600（1小时）
   * 
   * Requirements: 6.1 - 首次请求数据时缓存结果
   * Requirements: 6.3 - 支持配置缓存 TTL
   */
  async set<T>(key: string, value: T, ttlSeconds: number = 3600): Promise<void> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + ttlSeconds * 1000);

    this.store.set(key, {
      data: value,
      expires_at: expiresAt,
      updated_at: now,
    });
  }

  /**
   * 删除指定缓存
   * 
   * @param key 缓存键
   */
  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  /**
   * 清理所有过期缓存
   * 应定期调用以清理过期数据
   * 
   * @returns 删除的缓存条目数量
   */
  async clearExpired(): Promise<number> {
    const now = new Date();
    let count = 0;

    for (const [key, entry] of this.store.entries()) {
      if (entry.expires_at < now) {
        this.store.delete(key);
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
    const entry = this.store.get(key);
    
    if (!entry) {
      return -1;
    }

    const now = new Date();
    const ttl = Math.floor((entry.expires_at.getTime() - now.getTime()) / 1000);

    return ttl > 0 ? ttl : -1;
  }

  /**
   * 清空所有缓存（仅用于测试）
   */
  clear(): void {
    this.store.clear();
  }

  /**
   * 获取缓存条目数量（仅用于测试）
   */
  size(): number {
    return this.store.size;
  }

  /**
   * 手动设置缓存过期时间（仅用于测试）
   * 用于模拟缓存过期场景
   * 
   * @param key 缓存键
   * @param expiresAt 过期时间
   */
  setExpiration(key: string, expiresAt: Date): void {
    const entry = this.store.get(key);
    if (entry) {
      entry.expires_at = expiresAt;
    }
  }
}
