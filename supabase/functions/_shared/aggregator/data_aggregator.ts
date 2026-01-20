/**
 * 数据聚合器
 * 负责从多个平台并行获取数据，处理容错和超时，并合并结果
 * 
 * @module data_aggregator
 * Requirements: 1.4, 5.1, 6.2, 8.5
 */

import { PlatformAdapter } from '../adapters/platform_adapter.ts';
import { AnimeInfo, MergedAnimeInfo } from '../models/anime_info.ts';
import { DataMerger } from './data_merger.ts';
import { CacheLayer } from './cache_layer.ts';

/**
 * 聚合器配置选项
 */
export interface AggregatorOptions {
  /** 单个平台请求超时时间（毫秒），默认 10000 */
  timeout?: number;
  /** 动漫列表缓存 TTL（秒），默认 3600（1小时） */
  listCacheTTL?: number;
  /** 搜索结果缓存 TTL（秒），默认 600（10分钟） */
  searchCacheTTL?: number;
  /** 时间表缓存 TTL（秒），默认 1800（30分钟） */
  scheduleCacheTTL?: number;
}

/**
 * 平台调用结果
 */
interface PlatformResult<T> {
  platform: string;
  success: boolean;
  data: T;
  error?: Error;
}

/**
 * 数据聚合器类
 * 实现多平台数据的并行获取、容错处理和智能合并
 * 
 * Property 2: 平台容错性
 * Property 6: 部分超时返回
 * Validates: Requirements 1.4, 8.5
 */
export class DataAggregator {
  private readonly adapters: PlatformAdapter[];
  private readonly merger: DataMerger;
  private readonly cache: CacheLayer;
  private readonly options: Required<AggregatorOptions>;

  constructor(
    adapters: PlatformAdapter[],
    cache: CacheLayer,
    options: AggregatorOptions = {}
  ) {
    this.adapters = adapters;
    this.merger = new DataMerger();
    this.cache = cache;
    this.options = {
      timeout: options.timeout ?? 30000, // 增加到 30 秒，适应代理网络
      listCacheTTL: options.listCacheTTL ?? 3600,
      searchCacheTTL: options.searchCacheTTL ?? 600,
      scheduleCacheTTL: options.scheduleCacheTTL ?? 1800,
    };
  }

  /**
   * 获取动漫列表（聚合多平台数据）
   * 
   * @param page 页码（从1开始）
   * @param pageSize 每页数量
   * @param forceRefresh 是否强制刷新（绕过缓存）
   * @returns 合并后的动漫列表
   * 
   * Requirements: 6.2 - 缓存未过期时直接返回缓存数据
   * Requirements: 6.4 - 用户强制刷新时绕过缓存
   */
  async getAnimeList(
    page: number,
    pageSize: number,
    forceRefresh = false
  ): Promise<MergedAnimeInfo[]> {
    const cacheKey = `anime_list:${page}:${pageSize}`;

    // 检查缓存（除非强制刷新）
    if (!forceRefresh) {
      const cached = await this.cache.get<MergedAnimeInfo[]>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    // 并行从所有平台获取数据
    const results = await this.fetchFromAllPlatforms(
      (adapter) => adapter.getAnimeList(page, pageSize)
    );

    // 收集所有成功获取的数据
    const allAnime = this.collectSuccessfulResults(results);

    // 合并去重
    const merged = this.merger.merge(allAnime);

    // 缓存结果
    await this.cache.set(cacheKey, merged, this.options.listCacheTTL);

    return merged;
  }

  /**
   * 搜索动漫（跨平台搜索）
   * 
   * @param keyword 搜索关键词
   * @param limit 返回数量限制
   * @returns 合并后的搜索结果
   * 
   * Requirements: 8.3 - 实现跨平台搜索
   */
  async searchAnime(
    keyword: string,
    limit = 20
  ): Promise<MergedAnimeInfo[]> {
    const cacheKey = `search:${keyword}:${limit}`;

    // 检查缓存
    const cached = await this.cache.get<MergedAnimeInfo[]>(cacheKey);
    if (cached) {
      return cached;
    }

    // 并行搜索所有平台
    const results = await this.fetchFromAllPlatforms(
      (adapter) => adapter.searchAnime(keyword, limit)
    );

    // 收集所有成功获取的数据
    const allResults = this.collectSuccessfulResults(results);

    // 合并去重
    const merged = this.merger.merge(allResults);

    // 搜索结果缓存时间短一些
    await this.cache.set(cacheKey, merged, this.options.searchCacheTTL);

    return merged.slice(0, limit);
  }

  /**
   * 获取更新时间表
   * 
   * @param day 星期几 (1-7)，不传则返回全部
   * @returns 时间表中的动漫列表
   * 
   * Requirements: 8.4 - 返回更新时间表
   */
  async getSchedule(day?: number): Promise<MergedAnimeInfo[]> {
    const cacheKey = `schedule:${day ?? 'all'}`;

    // 检查缓存
    const cached = await this.cache.get<MergedAnimeInfo[]>(cacheKey);
    if (cached) {
      return cached;
    }

    // 并行从所有平台获取时间表
    const results = await this.fetchFromAllPlatforms(
      (adapter) => adapter.getSchedule(day)
    );

    // 收集所有成功获取的数据
    const allSchedule = this.collectSuccessfulResults(results);

    // 合并去重
    const merged = this.merger.merge(allSchedule);

    // 缓存结果
    await this.cache.set(cacheKey, merged, this.options.scheduleCacheTTL);

    return merged;
  }

  /**
   * 从所有平台并行获取数据
   * 实现平台容错：单个平台失败不影响整体
   * 实现超时处理：超时的平台返回空数组
   * 
   * @param fetchFn 获取数据的函数
   * @returns 各平台的调用结果
   * 
   * Property 2: 平台容错性
   * Property 6: 部分超时返回
   * Validates: Requirements 1.4, 8.5
   */
  private async fetchFromAllPlatforms<T>(
    fetchFn: (adapter: PlatformAdapter) => Promise<T[]>
  ): Promise<PlatformResult<T[]>[]> {
    const promises = this.adapters.map(async (adapter): Promise<PlatformResult<T[]>> => {
      try {
        // 使用 Promise.race 实现超时控制
        const data = await this.withTimeout(
          fetchFn(adapter),
          this.options.timeout,
          adapter.platform
        );
        
        return {
          platform: adapter.platform,
          success: true,
          data,
        };
      } catch (error) {
        // 记录错误但不抛出，实现容错
        console.error(`[DataAggregator] ${adapter.platform} failed:`, error);
        
        return {
          platform: adapter.platform,
          success: false,
          data: [],
          error: error instanceof Error ? error : new Error(String(error)),
        };
      }
    });

    // 使用 Promise.allSettled 确保所有请求都完成
    const settledResults = await Promise.allSettled(promises);

    return settledResults.map((result) => {
      if (result.status === 'fulfilled') {
        return result.value;
      }
      // 这种情况理论上不会发生，因为我们在内部已经捕获了所有错误
      return {
        platform: 'unknown',
        success: false,
        data: [],
        error: result.reason,
      };
    });
  }

  /**
   * 带超时的 Promise 包装
   * 
   * @param promise 原始 Promise
   * @param timeoutMs 超时时间（毫秒）
   * @param platform 平台名称（用于错误信息）
   * @returns 原始 Promise 的结果或超时错误
   */
  private withTimeout<T>(
    promise: Promise<T>,
    timeoutMs: number,
    platform: string
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        reject(new Error(`[${platform}] Request timeout after ${timeoutMs}ms`));
      }, timeoutMs);

      promise
        .then((result) => {
          clearTimeout(timeoutId);
          resolve(result);
        })
        .catch((error) => {
          clearTimeout(timeoutId);
          reject(error);
        });
    });
  }

  /**
   * 收集所有成功的结果
   * 
   * @param results 平台调用结果数组
   * @returns 所有成功获取的数据的扁平数组
   */
  private collectSuccessfulResults<T>(results: PlatformResult<T[]>[]): T[] {
    return results
      .filter((r) => r.success)
      .flatMap((r) => r.data);
  }

  /**
   * 获取所有已注册的平台名称
   */
  getPlatforms(): string[] {
    return this.adapters.map((a) => a.platform);
  }

  /**
   * 检查特定平台是否可用
   */
  hasPlatform(platform: string): boolean {
    return this.adapters.some((a) => a.platform === platform);
  }
}
