import { AnimeInfo, AnimeStatus } from '../models/anime_info.node';

/**
 * TMDB API 响应类型定义
 */
export interface TMDBTVShow {
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

/**
 * TMDB 平台适配器 - 数据转换逻辑
 * 
 * Requirements: 4.1, 4.2, 4.4
 */
export class TMDBAdapterTransformer {
  readonly platform = 'tmdb';

  private readonly IMAGE_BASE = 'https://image.tmdb.org/t/p';

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
