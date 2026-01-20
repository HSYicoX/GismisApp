import { AnimeInfo, AnimeStatus } from '../models/anime_info.ts';
import { BasePlatformAdapter } from './platform_adapter.ts';

/**
 * TMDB API 响应类型定义
 */
interface TMDBApiResponse<T> {
  page: number;
  results: T[];
  total_pages: number;
  total_results: number;
}

interface TMDBTVShow {
  id: number;
  name: string;
  original_name?: string;
  poster_path?: string;
  backdrop_path?: string;
  overview?: string;
  vote_average?: number;
  vote_count?: number;
  first_air_date?: string;
  genre_ids?: number[];
  origin_country?: string[];
  status?: string;
  number_of_episodes?: number;
  number_of_seasons?: number;
}

interface TMDBSearchResult {
  id: number;
  name: string;
  original_name?: string;
  poster_path?: string;
  overview?: string;
  vote_average?: number;
  first_air_date?: string;
  genre_ids?: number[];
}

/**
 * TMDB 平台适配器
 * 
 * Requirements: 4.1, 4.2, 4.4
 * - 使用 TMDB API 获取动漫元数据
 * - 获取动漫的国际评分、海报、简介
 * - 支持中文和日文标题搜索
 */
export class TMDBAdapter extends BasePlatformAdapter {
  readonly platform = 'tmdb';

  private readonly API_BASE = 'https://api.themoviedb.org/3';
  private readonly IMAGE_BASE = 'https://image.tmdb.org/t/p';
  private readonly API_TOKEN: string;

  // Animation genre ID in TMDB
  private readonly ANIMATION_GENRE_ID = 16;

  constructor() {
    super();
    // 从环境变量获取 API Token (Bearer Token)
    this.API_TOKEN = typeof Deno !== 'undefined' 
      ? Deno.env.get('TMDB_API_TOKEN') || ''
      : process.env.TMDB_API_TOKEN || '';
  }

  /**
   * 构建带认证的请求头
   */
  private getHeaders(): HeadersInit {
    return {
      'Authorization': `Bearer ${this.API_TOKEN}`,
      'accept': 'application/json',
    };
  }

  /**
   * 获取动漫列表（分页）
   * Requirements: 4.1
   */
  async getAnimeList(page: number, pageSize: number): Promise<AnimeInfo[]> {
    console.log(`[tmdb] getAnimeList called - page: ${page}, pageSize: ${pageSize}`);
    console.log(`[tmdb] API_TOKEN exists: ${!!this.API_TOKEN}, length: ${this.API_TOKEN?.length || 0}`);
    
    const url = `${this.API_BASE}/discover/tv`;
    const params = new URLSearchParams({
      with_genres: this.ANIMATION_GENRE_ID.toString(),
      with_origin_country: 'JP', // 日本动画
      sort_by: 'popularity.desc',
      page: page.toString(),
      language: 'zh-CN',
    });

    try {
      const fullUrl = `${url}?${params}`;
      console.log(`[tmdb] Request URL: ${fullUrl}`);
      
      const response = await this.fetchWithTimeout(fullUrl, {
        headers: this.getHeaders(),
      });
      
      console.log(`[tmdb] Response status: ${response.status}`);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[tmdb] API returned ${response.status}: ${errorText}`);
        return [];
      }

      const data = await this.safeJsonParse<TMDBApiResponse<TMDBTVShow>>(response);
      console.log(`[tmdb] Results count: ${data?.results?.length || 0}`);
      
      if (!data?.results) {
        return [];
      }

      // TMDB 的 pageSize 固定为 20，我们需要截取
      const results = data.results.slice(0, pageSize);
      return results.map((item) => this.transformToAnimeInfo(item));
    } catch (error) {
      console.error(`[tmdb] getAnimeList error:`, error);
      return [];
    }
  }

  /**
   * 搜索动漫
   * Requirements: 4.4
   */
  async searchAnime(keyword: string, limit = 20): Promise<AnimeInfo[]> {
    console.log(`[tmdb] searchAnime called - keyword: ${keyword}, limit: ${limit}`);
    console.log(`[tmdb] API_TOKEN exists: ${!!this.API_TOKEN}`);
    
    const url = `${this.API_BASE}/search/tv`;
    const params = new URLSearchParams({
      query: keyword,
      language: 'zh-CN',
      page: '1',
    });

    try {
      const fullUrl = `${url}?${params}`;
      console.log(`[tmdb] Search URL: ${fullUrl}`);
      
      const response = await this.fetchWithTimeout(fullUrl, {
        headers: this.getHeaders(),
      });
      
      console.log(`[tmdb] Search response status: ${response.status}`);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[tmdb] Search API returned ${response.status}: ${errorText}`);
        return [];
      }

      const data = await this.safeJsonParse<TMDBApiResponse<TMDBSearchResult>>(response);
      console.log(`[tmdb] Search total results: ${data?.total_results || 0}`);
      
      if (!data?.results) {
        return [];
      }

      // 过滤只保留动画类型
      const animeResults = data.results
        .filter((item) => item.genre_ids?.includes(this.ANIMATION_GENRE_ID))
        .slice(0, limit);

      console.log(`[tmdb] Filtered anime results: ${animeResults.length}`);
      return animeResults.map((item) => this.transformSearchResultToAnimeInfo(item));
    } catch (error) {
      console.error(`[tmdb] searchAnime error:`, error);
      return [];
    }
  }

  /**
   * 获取动漫详情
   */
  async getAnimeDetail(id: string): Promise<AnimeInfo | null> {
    const url = `${this.API_BASE}/tv/${id}`;
    const params = new URLSearchParams({
      language: 'zh-CN',
    });

    try {
      const response = await this.fetchWithTimeout(`${url}?${params}`, {
        headers: this.getHeaders(),
      });
      if (!response.ok) {
        return null;
      }

      const data = await this.safeJsonParse<TMDBTVShow>(response);
      if (!data) {
        return null;
      }

      return this.transformToAnimeInfo(data);
    } catch (error) {
      console.error(`[tmdb] getAnimeDetail error:`, error);
      return null;
    }
  }

  /**
   * 获取更新时间表
   * TMDB 不提供时间表 API，返回空数组
   */
  async getSchedule(_day?: number): Promise<AnimeInfo[]> {
    // TMDB 没有时间表功能
    return [];
  }

  /**
   * 将 TMDB TV Show 数据转换为统一的 AnimeInfo 格式
   * Requirements: 4.2
   */
  transformToAnimeInfo(raw: TMDBTVShow): AnimeInfo {
    return {
      id: raw.id.toString(),
      platform: this.platform,
      title: raw.name || '',
      titleAliases: raw.original_name ? [raw.original_name] : [],
      coverUrl: this.buildImageUrl(raw.poster_path),
      synopsis: raw.overview,
      rating: raw.vote_average,
      status: this.mapStatus(raw.status),
      genres: [], // 需要额外请求获取具体类型名称
      releaseYear: this.parseYear(raw.first_air_date),
      episodeCount: raw.number_of_episodes,
      playUrl: `https://www.themoviedb.org/tv/${raw.id}`,
    };
  }

  /**
   * 将搜索结果转换为 AnimeInfo
   */
  private transformSearchResultToAnimeInfo(raw: TMDBSearchResult): AnimeInfo {
    return {
      id: raw.id.toString(),
      platform: this.platform,
      title: raw.name || '',
      titleAliases: raw.original_name ? [raw.original_name] : [],
      coverUrl: this.buildImageUrl(raw.poster_path),
      synopsis: raw.overview,
      rating: raw.vote_average,
      status: 'ongoing', // 搜索结果没有状态信息
      genres: [],
      releaseYear: this.parseYear(raw.first_air_date),
      playUrl: `https://www.themoviedb.org/tv/${raw.id}`,
    };
  }

  /**
   * 构建图片 URL
   */
  buildImageUrl(path?: string): string {
    if (!path) return '';
    return `${this.IMAGE_BASE}/w500${path}`;
  }

  /**
   * 映射状态
   */
  mapStatus(status?: string): AnimeStatus {
    switch (status) {
      case 'Ended':
      case 'Canceled':
        return 'completed';
      case 'Returning Series':
      case 'In Production':
        return 'ongoing';
      case 'Planned':
        return 'upcoming';
      default:
        return 'ongoing';
    }
  }

  /**
   * 解析年份
   */
  parseYear(dateStr?: string): number | undefined {
    if (!dateStr) return undefined;
    const year = new Date(dateStr).getFullYear();
    return isNaN(year) ? undefined : year;
  }
}
