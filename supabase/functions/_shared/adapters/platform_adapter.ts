import { AnimeInfo } from '../models/anime_info.ts';

/**
 * 平台适配器接口
 * 所有数据源适配器都需要实现此接口
 * 
 * Requirements: 1.1, 1.2
 * - 定义统一的 PlatformAdapter 接口
 * - 添加新平台时只需实现此接口
 */
export interface PlatformAdapter {
  /** 平台标识符 */
  readonly platform: string;

  /**
   * 获取动漫列表（分页）
   * @param page 页码（从1开始）
   * @param pageSize 每页数量
   * @returns 动漫信息列表
   */
  getAnimeList(page: number, pageSize: number): Promise<AnimeInfo[]>;

  /**
   * 搜索动漫
   * @param keyword 搜索关键词
   * @param limit 返回数量限制
   * @returns 搜索结果列表
   */
  searchAnime(keyword: string, limit?: number): Promise<AnimeInfo[]>;

  /**
   * 获取动漫详情
   * @param id 平台内部ID
   * @returns 动漫详情，不存在时返回 null
   */
  getAnimeDetail(id: string): Promise<AnimeInfo | null>;

  /**
   * 获取更新时间表
   * @param day 星期几 (1-7)，不传则返回全部
   * @returns 时间表中的动漫列表
   */
  getSchedule(day?: number): Promise<AnimeInfo[]>;
}

/**
 * 平台适配器基类
 * 提供通用的错误处理和超时逻辑
 */
export abstract class BasePlatformAdapter implements PlatformAdapter {
  abstract readonly platform: string;
  
  /** 请求超时时间（毫秒）- 通过代理访问需要更长时间 */
  protected readonly timeout: number = 25000;

  abstract getAnimeList(page: number, pageSize: number): Promise<AnimeInfo[]>;
  abstract searchAnime(keyword: string, limit?: number): Promise<AnimeInfo[]>;
  abstract getAnimeDetail(id: string): Promise<AnimeInfo | null>;
  abstract getSchedule(day?: number): Promise<AnimeInfo[]>;

  /**
   * 带超时的 fetch 请求
   */
  protected async fetchWithTimeout(
    url: string,
    options?: RequestInit,
  ): Promise<Response> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
      });
      return response;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  /**
   * 安全的 JSON 解析
   */
  protected async safeJsonParse<T>(response: Response): Promise<T | null> {
    try {
      return await response.json() as T;
    } catch {
      console.error(`[${this.platform}] Failed to parse JSON response`);
      return null;
    }
  }
}
