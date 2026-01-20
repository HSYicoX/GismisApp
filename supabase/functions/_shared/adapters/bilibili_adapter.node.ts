import { AnimeInfo, AnimeStatus } from '../models/anime_info.node';

/**
 * B站 API 响应类型定义
 */
export interface BilibiliSeasonItem {
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
  rating?: { score: number };
  stat?: { view: number };
  is_finish?: number;
  styles?: string[];
  season_year?: number;
  total_count?: number;
  new_ep?: { index_show?: string };
  day_of_week?: number;
  pub_time?: string;
}

/**
 * 哔哩哔哩平台适配器 - 数据转换逻辑
 * 
 * Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
 */
export class BilibiliAdapterTransformer {
  readonly platform = 'bilibili';

  /**
   * 将 B 站原始数据转换为统一的 AnimeInfo 格式
   * Requirements: 2.2, 2.3
   */
  transformToAnimeInfo(raw: BilibiliSeasonItem): AnimeInfo {
    const seasonId = raw.season_id?.toString() || raw.media_id?.toString() || '';
    
    return {
      id: seasonId,
      platform: this.platform,
      title: raw.title || raw.season_title || '',
      titleAliases: [raw.origin_name, raw.alias].filter((s): s is string => Boolean(s)),
      coverUrl: raw.cover || raw.square_cover || '',
      synopsis: raw.evaluate || raw.desc,
      rating: raw.rating?.score,
      playCount: raw.stat?.view,
      status: this.mapStatus(raw.is_finish),
      genres: raw.styles || [],
      releaseYear: raw.season_year,
      episodeCount: raw.total_count,
      latestEpisode: this.parseLatestEpisode(raw.new_ep?.index_show),
      updateDay: raw.day_of_week,
      updateTime: raw.pub_time,
      playUrl: seasonId ? `https://www.bilibili.com/bangumi/play/ss${seasonId}` : '',
    };
  }

  /**
   * 映射完结状态
   */
  mapStatus(isFinish?: number): AnimeStatus {
    return isFinish === 1 ? 'completed' : 'ongoing';
  }

  /**
   * 解析最新集数
   */
  parseLatestEpisode(indexShow?: string): number | undefined {
    if (!indexShow) return undefined;
    
    // 尝试从字符串中提取数字，如 "第12集" -> 12
    const match = indexShow.match(/\d+/);
    return match ? parseInt(match[0], 10) : undefined;
  }
}
