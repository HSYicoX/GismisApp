import { AnimeInfo, AnimeStatus } from '../models/anime_info.ts';
import { BasePlatformAdapter } from './platform_adapter.ts';

/**
 * B站 API 响应类型定义
 */
interface BilibiliApiResponse<T> {
  code: number;
  message: string;
  result?: T;
  data?: T;
}

interface BilibiliSeasonItem {
  season_id?: number;
  media_id?: number;
  title?: string;
  season_title?: string;
  origin_name?: string;
  alias?: string;
  cover?: string;
  square_cover?: string;
  evaluate?: string;
  desc?: string;
  rating?: { score: number } | string;
  stat?: { view: number; danmaku?: number; follow?: number };
  is_finish?: number;
  styles?: string[];
  season_year?: number;
  total_count?: number;
  new_ep?: { index_show?: string; cover?: string };
  day_of_week?: number;
  pub_time?: string;
  url?: string;
  badge?: string;
  rank?: number;
}

interface BilibiliSearchResult {
  result?: BilibiliSeasonItem[];
}

interface BilibiliIndexResult {
  list?: BilibiliSeasonItem[];
}

interface BilibiliTimelineDay {
  day_of_week: number;
  episodes: BilibiliTimelineEpisode[];
}

interface BilibiliTimelineEpisode {
  season_id?: number;
  title?: string;
  cover?: string;
  pub_time?: string;
  pub_index?: string;
  square_cover?: string;
}

/**
 * 哔哩哔哩平台适配器
 * 
 * Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
 * - 从 B 站 API 获取番剧和国创列表
 * - 获取动漫的封面、标题、简介、评分、播放量
 * - 获取动漫的播放链接
 * - 获取动漫的更新时间表
 * - 支持关键词搜索
 */
export class BilibiliAdapter extends BasePlatformAdapter {
  readonly platform = 'bilibili';

  private readonly API_BASE = 'https://api.bilibili.com';

  /**
   * B站 API 需要的请求头
   */
  private readonly BILIBILI_HEADERS: Record<string, string> = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bilibili.com/',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  /**
   * 获取动漫列表（分页）
   * Requirements: 2.1
   * 使用排行榜 API 获取热门番剧
   */
  async getAnimeList(page: number, pageSize: number): Promise<AnimeInfo[]> {
    // 使用排行榜 API，它更稳定
    const url = `${this.API_BASE}/pgc/web/rank/list`;
    const params = new URLSearchParams({
      day: '3', // 3天排行
      season_type: '1', // 1=番剧
    });

    const fullUrl = `${url}?${params}`;
    console.log(`[bilibili] Fetching anime list from: ${fullUrl}`);

    try {
      const response = await this.fetchWithTimeout(fullUrl, {
        headers: this.BILIBILI_HEADERS,
      });
      
      console.log(`[bilibili] Response status: ${response.status}`);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[bilibili] API returned ${response.status}: ${errorText.substring(0, 200)}`);
        return [];
      }

      const data = await this.safeJsonParse<BilibiliApiResponse<{ list: BilibiliSeasonItem[] }>>(response);
      
      console.log(`[bilibili] Response code: ${data?.code}, message: ${data?.message}`);
      
      if (!data?.result?.list) {
        console.error(`[bilibili] No list in response, data:`, JSON.stringify(data).substring(0, 300));
        return [];
      }

      console.log(`[bilibili] Got ${data.result.list.length} items`);

      // 分页处理
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pagedList = data.result.list.slice(start, end);

      return pagedList.map((item) => this.transformToAnimeInfo(item));
    } catch (error) {
      console.error(`[bilibili] getAnimeList error:`, error);
      return [];
    }
  }

  /**
   * 搜索动漫
   * Requirements: 2.5
   */
  async searchAnime(keyword: string, limit = 20): Promise<AnimeInfo[]> {
    const url = `${this.API_BASE}/x/web-interface/search/type`;
    const params = new URLSearchParams({
      search_type: 'media_bangumi',
      keyword: keyword,
      page: '1',
      pagesize: limit.toString(),
    });

    const fullUrl = `${url}?${params}`;
    console.log(`[bilibili] Searching anime: ${fullUrl}`);

    try {
      const response = await this.fetchWithTimeout(fullUrl, {
        headers: this.BILIBILI_HEADERS,
      });
      
      console.log(`[bilibili] Search response status: ${response.status}`);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[bilibili] Search API returned ${response.status}: ${errorText.substring(0, 200)}`);
        return [];
      }

      const data = await this.safeJsonParse<BilibiliApiResponse<BilibiliSearchResult>>(response);
      
      console.log(`[bilibili] Search response code: ${data?.code}, message: ${data?.message}`);
      
      if (!data?.data?.result) {
        console.error(`[bilibili] No result in search response`);
        return [];
      }

      console.log(`[bilibili] Found ${data.data.result.length} search results`);

      return data.data.result.map((item) => this.transformToAnimeInfo(item));
    } catch (error) {
      console.error(`[bilibili] searchAnime error:`, error);
      return [];
    }
  }

  /**
   * 获取动漫详情
   */
  async getAnimeDetail(id: string): Promise<AnimeInfo | null> {
    const url = `${this.API_BASE}/pgc/view/web/season`;
    const params = new URLSearchParams({
      season_id: id,
    });

    try {
      const response = await this.fetchWithTimeout(`${url}?${params}`, {
        headers: this.BILIBILI_HEADERS,
      });
      if (!response.ok) {
        return null;
      }

      const data = await this.safeJsonParse<BilibiliApiResponse<BilibiliSeasonItem>>(response);
      if (!data?.result) {
        return null;
      }

      return this.transformToAnimeInfo(data.result);
    } catch (error) {
      console.error(`[bilibili] getAnimeDetail error:`, error);
      return null;
    }
  }

  /**
   * 获取更新时间表
   * Requirements: 2.4
   */
  async getSchedule(day?: number): Promise<AnimeInfo[]> {
    const url = `${this.API_BASE}/pgc/web/timeline`;
    const params = new URLSearchParams({
      types: '1',
      before: '0',
      after: '7',
    });

    const fullUrl = `${url}?${params}`;
    console.log(`[bilibili] Fetching schedule from: ${fullUrl}`);

    try {
      const response = await this.fetchWithTimeout(fullUrl, {
        headers: this.BILIBILI_HEADERS,
      });
      
      console.log(`[bilibili] Schedule response status: ${response.status}`);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[bilibili] Timeline API returned ${response.status}: ${errorText.substring(0, 200)}`);
        return [];
      }

      const data = await this.safeJsonParse<BilibiliApiResponse<BilibiliTimelineDay[]>>(response);
      
      console.log(`[bilibili] Schedule response code: ${data?.code}, message: ${data?.message}`);
      
      if (!data?.result) {
        console.error(`[bilibili] No result in schedule response`);
        return [];
      }

      console.log(`[bilibili] Got ${data.result.length} days in schedule`);

      let timeline = data.result;
      
      // 如果指定了星期几，则过滤
      if (day !== undefined) {
        timeline = timeline.filter((d) => d.day_of_week === day);
      }

      return timeline.flatMap((d) =>
        d.episodes.map((ep) => this.transformTimelineEpisode(ep, d.day_of_week))
      );
    } catch (error) {
      console.error(`[bilibili] getSchedule error:`, error);
      return [];
    }
  }

  /**
   * 将 B 站原始数据转换为统一的 AnimeInfo 格式
   * Requirements: 2.2, 2.3
   */
  transformToAnimeInfo(raw: BilibiliSeasonItem): AnimeInfo {
    const seasonId = raw.season_id?.toString() || raw.media_id?.toString() || '';
    
    // 处理 rating，可能是对象或字符串
    let rating: number | undefined;
    if (typeof raw.rating === 'object' && raw.rating?.score) {
      rating = raw.rating.score;
    } else if (typeof raw.rating === 'string' && raw.rating) {
      rating = parseFloat(raw.rating);
    }
    
    return {
      id: seasonId,
      platform: this.platform,
      title: raw.title || raw.season_title || '',
      titleAliases: [raw.origin_name, raw.alias].filter((s): s is string => Boolean(s)),
      coverUrl: raw.cover || raw.square_cover || '',
      synopsis: raw.evaluate || raw.desc,
      rating: rating,
      playCount: raw.stat?.view,
      status: this.mapStatus(raw.is_finish),
      genres: raw.styles || [],
      releaseYear: raw.season_year,
      episodeCount: raw.total_count,
      latestEpisode: this.parseLatestEpisode(raw.new_ep?.index_show),
      updateDay: raw.day_of_week,
      updateTime: raw.pub_time,
      playUrl: raw.url || (seasonId ? `https://www.bilibili.com/bangumi/play/ss${seasonId}` : ''),
    };
  }

  /**
   * 将时间表条目转换为 AnimeInfo
   */
  private transformTimelineEpisode(
    ep: BilibiliTimelineEpisode,
    dayOfWeek: number
  ): AnimeInfo {
    const seasonId = ep.season_id?.toString() || '';
    
    return {
      id: seasonId,
      platform: this.platform,
      title: ep.title || '',
      titleAliases: [],
      coverUrl: ep.cover || ep.square_cover || '',
      status: 'ongoing',
      genres: [],
      updateDay: dayOfWeek,
      updateTime: ep.pub_time,
      latestEpisode: this.parseLatestEpisode(ep.pub_index),
      playUrl: seasonId ? `https://www.bilibili.com/bangumi/play/ss${seasonId}` : '',
    };
  }

  /**
   * 映射完结状态
   */
  private mapStatus(isFinish?: number): AnimeStatus {
    return isFinish === 1 ? 'completed' : 'ongoing';
  }

  /**
   * 解析最新集数
   */
  private parseLatestEpisode(indexShow?: string): number | undefined {
    if (!indexShow) return undefined;
    
    // 尝试从字符串中提取数字，如 "第12集" -> 12
    const match = indexShow.match(/\d+/);
    return match ? parseInt(match[0], 10) : undefined;
  }
}
