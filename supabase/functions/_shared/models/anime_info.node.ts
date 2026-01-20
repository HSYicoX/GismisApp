/**
 * 动漫状态枚举
 */
export type AnimeStatus = 'ongoing' | 'completed' | 'upcoming';

/**
 * 统一的动漫信息接口
 * 所有平台适配器都将数据转换为此格式
 */
export interface AnimeInfo {
  /** 平台内部ID */
  id: string;
  /** 平台标识 (bilibili, tmdb, iqiyi, etc.) */
  platform: string;
  /** 标题 */
  title: string;
  /** 别名（日文、英文等） */
  titleAliases: string[];
  /** 封面图URL */
  coverUrl: string;
  /** 简介 */
  synopsis?: string;
  /** 评分 (0-10) */
  rating?: number;
  /** 播放量 */
  playCount?: number;
  /** 状态 */
  status: AnimeStatus;
  /** 类型标签 */
  genres: string[];
  /** 发布年份 */
  releaseYear?: number;
  /** 总集数 */
  episodeCount?: number;
  /** 最新集数 */
  latestEpisode?: number;
  /** 更新日 (1-7, 周一到周日) */
  updateDay?: number;
  /** 更新时间 (HH:mm) */
  updateTime?: string;
  /** 播放链接 */
  playUrl: string;
}

/**
 * 合并后的动漫信息接口
 * 包含多个平台的播放链接
 */
export interface MergedAnimeInfo extends AnimeInfo {
  /** 各平台播放链接映射 { platform: playUrl } */
  platformLinks: Record<string, string>;
}
