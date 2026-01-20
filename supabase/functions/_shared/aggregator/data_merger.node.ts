/**
 * 数据合并器 (Node.js 兼容版本，用于测试)
 * 负责将多个平台返回的动漫数据进行去重和合并
 * 
 * @module data_merger
 * Requirements: 5.1, 5.2, 5.3, 5.4
 */

import { AnimeInfo, MergedAnimeInfo } from '../models/anime_info.node';

/**
 * 将 AnimeInfo 转换为 MergedAnimeInfo
 */
export function toMergedAnimeInfo(anime: AnimeInfo): MergedAnimeInfo {
  return {
    ...anime,
    platformLinks: {
      [anime.platform]: anime.playUrl,
    },
  };
}

/**
 * 数据合并器类
 * 实现多平台动漫数据的智能合并
 */
export class DataMerger {
  /** 标题相似度阈值，超过此值认为是同一部动漫 */
  private readonly SIMILARITY_THRESHOLD = 0.8;

  /**
   * 合并多个平台的动漫数据
   * @param animeList 来自多个平台的动漫列表
   * @returns 合并去重后的动漫列表
   * 
   * Property 3: 数据合并正确性
   * Validates: Requirements 5.1, 5.3
   */
  merge(animeList: AnimeInfo[]): MergedAnimeInfo[] {
    const merged: MergedAnimeInfo[] = [];
    const processedTitles = new Set<string>();

    for (const anime of animeList) {
      const normalizedTitle = this.normalizeTitle(anime.title);

      // 检查是否已处理过完全相同的规范化标题
      if (processedTitles.has(normalizedTitle)) {
        const existing = merged.find(
          (m) => this.normalizeTitle(m.title) === normalizedTitle
        );
        if (existing) {
          this.mergeInto(existing, anime);
        }
        continue;
      }

      // 检查是否有相似标题的记录
      const similar = merged.find(
        (m) => this.calculateSimilarity(m.title, anime.title) >= this.SIMILARITY_THRESHOLD
      );

      if (similar) {
        this.mergeInto(similar, anime);
      } else {
        // 新记录，转换为合并格式
        merged.push(toMergedAnimeInfo(anime));
        processedTitles.add(normalizedTitle);
      }
    }

    return merged;
  }


  /**
   * 将源动漫数据合并到目标记录中
   * @param target 目标合并记录
   * @param source 源动漫数据
   * 
   * Validates: Requirements 5.3, 5.4
   */
  private mergeInto(target: MergedAnimeInfo, source: AnimeInfo): void {
    // 合并播放链接
    if (!target.platformLinks) {
      target.platformLinks = {};
    }
    target.platformLinks[source.platform] = source.playUrl;

    // 补充缺失的简介
    if (!target.synopsis && source.synopsis) {
      target.synopsis = source.synopsis;
    }

    // 补充缺失的评分
    if (!target.rating && source.rating) {
      target.rating = source.rating;
    }

    // 补充缺失的封面
    if (!target.coverUrl && source.coverUrl) {
      target.coverUrl = source.coverUrl;
    }

    // 优先使用 B 站的封面（通常质量更高）
    if (source.platform === 'bilibili' && source.coverUrl) {
      target.coverUrl = source.coverUrl;
    }

    // 合并别名（去重）
    if (source.titleAliases?.length) {
      target.titleAliases = [
        ...new Set([...(target.titleAliases || []), ...source.titleAliases]),
      ];
    }

    // 补充其他缺失字段
    if (!target.playCount && source.playCount) {
      target.playCount = source.playCount;
    }
    if (!target.releaseYear && source.releaseYear) {
      target.releaseYear = source.releaseYear;
    }
    if (!target.episodeCount && source.episodeCount) {
      target.episodeCount = source.episodeCount;
    }
    if (!target.latestEpisode && source.latestEpisode) {
      target.latestEpisode = source.latestEpisode;
    }
    if (!target.updateDay && source.updateDay) {
      target.updateDay = source.updateDay;
    }
    if (!target.updateTime && source.updateTime) {
      target.updateTime = source.updateTime;
    }

    // 合并类型标签（去重）
    if (source.genres?.length) {
      target.genres = [...new Set([...(target.genres || []), ...source.genres])];
    }
  }

  /**
   * 规范化标题
   * 移除特殊字符，转为小写，只保留中文、字母、数字
   * @param title 原始标题
   * @returns 规范化后的标题
   * 
   * Validates: Requirements 5.2
   */
  normalizeTitle(title: string): string {
    return title
      .toLowerCase()
      .replace(/[^\u4e00-\u9fa5a-z0-9]/g, '') // 只保留中文、字母、数字
      .trim();
  }

  /**
   * 计算两个标题的相似度
   * 使用 Levenshtein 距离算法
   * @param a 标题A
   * @param b 标题B
   * @returns 相似度 (0-1)，1表示完全相同
   * 
   * Property 4: 标题相似度对称性
   * Validates: Requirements 5.2
   */
  calculateSimilarity(a: string, b: string): number {
    const normA = this.normalizeTitle(a);
    const normB = this.normalizeTitle(b);

    // 完全相同
    if (normA === normB) return 1;

    // 空字符串处理
    if (normA.length === 0 && normB.length === 0) return 1;
    if (normA.length === 0 || normB.length === 0) return 0;

    // 计算 Levenshtein 距离
    const distance = this.levenshteinDistance(normA, normB);
    const maxLen = Math.max(normA.length, normB.length);

    return 1 - distance / maxLen;
  }

  /**
   * 计算两个字符串的 Levenshtein 距离
   * @param a 字符串A
   * @param b 字符串B
   * @returns 编辑距离
   */
  levenshteinDistance(a: string, b: string): number {
    // 边界情况
    if (a.length === 0) return b.length;
    if (b.length === 0) return a.length;

    // 创建距离矩阵
    const matrix: number[][] = [];

    // 初始化第一列
    for (let i = 0; i <= b.length; i++) {
      matrix[i] = [i];
    }

    // 初始化第一行
    for (let j = 0; j <= a.length; j++) {
      matrix[0][j] = j;
    }

    // 填充矩阵
    for (let i = 1; i <= b.length; i++) {
      for (let j = 1; j <= a.length; j++) {
        if (b.charAt(i - 1) === a.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1, // 替换
            matrix[i][j - 1] + 1,     // 插入
            matrix[i - 1][j] + 1      // 删除
          );
        }
      }
    }

    return matrix[b.length][a.length];
  }
}
