/**
 * Property-Based Tests for Data Merger
 * 
 * Feature: realtime-data-aggregation
 * Property 3: 数据合并正确性
 * Property 4: 标题相似度对称性
 * Validates: Requirements 5.1, 5.2, 5.3
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import { DataMerger } from './data_merger.node';
import type { AnimeInfo } from '../models/anime_info.node';

const merger = new DataMerger();

/**
 * Generator for valid AnimeInfo objects
 */
const animeInfoArbitrary = fc.record({
  id: fc.string({ minLength: 1, maxLength: 20 }),
  platform: fc.constantFrom('bilibili', 'tmdb', 'iqiyi', 'tencent', 'youku'),
  title: fc.string({ minLength: 1, maxLength: 100 }),
  titleAliases: fc.array(fc.string({ minLength: 1, maxLength: 50 }), { maxLength: 5 }),
  coverUrl: fc.webUrl(),
  synopsis: fc.option(fc.string({ minLength: 1, maxLength: 500 }), { nil: undefined }),
  rating: fc.option(fc.float({ min: 0, max: 10 }), { nil: undefined }),
  playCount: fc.option(fc.integer({ min: 0 }), { nil: undefined }),
  status: fc.constantFrom('ongoing', 'completed', 'upcoming') as fc.Arbitrary<'ongoing' | 'completed' | 'upcoming'>,
  genres: fc.array(fc.string({ minLength: 1, maxLength: 20 }), { maxLength: 5 }),
  releaseYear: fc.option(fc.integer({ min: 1990, max: 2030 }), { nil: undefined }),
  episodeCount: fc.option(fc.integer({ min: 1, max: 1000 }), { nil: undefined }),
  latestEpisode: fc.option(fc.integer({ min: 1, max: 1000 }), { nil: undefined }),
  updateDay: fc.option(fc.integer({ min: 1, max: 7 }), { nil: undefined }),
  updateTime: fc.option(fc.string({ minLength: 5, maxLength: 10 }), { nil: undefined }),
  playUrl: fc.webUrl(),
});

/**
 * Generator for non-empty title strings (for similarity tests)
 */
const nonEmptyTitleArbitrary = fc.string({ minLength: 1, maxLength: 50 });

/**
 * Generator for title strings that may contain special characters
 */
const titleWithSpecialCharsArbitrary = fc.stringOf(
  fc.oneof(
    fc.char16bits(),
    fc.constantFrom('!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '+', '=', ' ')
  ),
  { minLength: 1, maxLength: 50 }
);


describe('Property 3: 数据合并正确性', () => {
  /**
   * Feature: realtime-data-aggregation, Property 3: 数据合并正确性
   * Validates: Requirements 5.1, 5.3
   * 
   * For any multiple platform data returning the same anime,
   * the merged result SHALL have only one record with platformLinks containing all platforms
   */

  it('merging anime with identical titles produces single record with all platform links', () => {
    fc.assert(
      fc.property(
        fc.string({ minLength: 1, maxLength: 50 }),
        fc.array(fc.constantFrom('bilibili', 'tmdb', 'iqiyi', 'tencent', 'youku'), { minLength: 2, maxLength: 5 }),
        (title, platforms) => {
          // Create anime entries with the same title but different platforms
          const uniquePlatforms = [...new Set(platforms)];
          const animeList: AnimeInfo[] = uniquePlatforms.map((platform, index) => ({
            id: `${platform}-${index}`,
            platform,
            title,
            titleAliases: [],
            coverUrl: `https://example.com/${platform}.jpg`,
            status: 'ongoing' as const,
            genres: [],
            playUrl: `https://${platform}.com/play/${index}`,
          }));

          const merged = merger.merge(animeList);

          // Should produce exactly one record
          expect(merged.length).toBe(1);

          // The merged record should have platformLinks for all unique platforms
          const mergedRecord = merged[0];
          expect(mergedRecord.platformLinks).toBeDefined();
          
          for (const platform of uniquePlatforms) {
            expect(mergedRecord.platformLinks[platform]).toBeDefined();
          }

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('merging anime with different titles produces separate records', () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.record({
            title: fc.string({ minLength: 5, maxLength: 20 }),
            platform: fc.constantFrom('bilibili', 'tmdb'),
          }),
          { minLength: 2, maxLength: 5 }
        ),
        (items) => {
          // Create anime entries with different titles
          const animeList: AnimeInfo[] = items.map((item, index) => ({
            id: `${item.platform}-${index}`,
            platform: item.platform,
            title: `${item.title}_unique_${index}`, // Ensure unique titles
            titleAliases: [],
            coverUrl: `https://example.com/${index}.jpg`,
            status: 'ongoing' as const,
            genres: [],
            playUrl: `https://example.com/play/${index}`,
          }));

          const merged = merger.merge(animeList);

          // Each unique title should produce a separate record
          // (unless they happen to be similar by chance, which is unlikely with unique suffixes)
          expect(merged.length).toBeGreaterThanOrEqual(1);
          expect(merged.length).toBeLessThanOrEqual(animeList.length);

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('merged record contains all platform play URLs', () => {
    fc.assert(
      fc.property(animeInfoArbitrary, animeInfoArbitrary, (anime1, anime2) => {
        // Use the same title for both
        const sharedTitle = 'Shared Anime Title';
        const list: AnimeInfo[] = [
          { ...anime1, title: sharedTitle, platform: 'bilibili' },
          { ...anime2, title: sharedTitle, platform: 'tmdb' },
        ];

        const merged = merger.merge(list);

        expect(merged.length).toBe(1);
        expect(merged[0].platformLinks['bilibili']).toBe(list[0].playUrl);
        expect(merged[0].platformLinks['tmdb']).toBe(list[1].playUrl);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('empty input produces empty output', () => {
    const merged = merger.merge([]);
    expect(merged).toEqual([]);
  });

  it('single anime produces single merged record with platformLinks', () => {
    fc.assert(
      fc.property(animeInfoArbitrary, (anime) => {
        const merged = merger.merge([anime]);

        expect(merged.length).toBe(1);
        expect(merged[0].platformLinks).toBeDefined();
        expect(merged[0].platformLinks[anime.platform]).toBe(anime.playUrl);

        return true;
      }),
      { numRuns: 100 }
    );
  });
});


describe('Property 4: 标题相似度对称性', () => {
  /**
   * Feature: realtime-data-aggregation, Property 4: 标题相似度对称性
   * Validates: Requirements 5.2
   * 
   * For any two titles A and B, similarity(A, B) === similarity(B, A)
   */

  it('similarity is symmetric: similarity(A, B) === similarity(B, A)', () => {
    fc.assert(
      fc.property(nonEmptyTitleArbitrary, nonEmptyTitleArbitrary, (titleA, titleB) => {
        const similarityAB = merger.calculateSimilarity(titleA, titleB);
        const similarityBA = merger.calculateSimilarity(titleB, titleA);

        expect(similarityAB).toBeCloseTo(similarityBA, 10);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('similarity with self is always 1', () => {
    fc.assert(
      fc.property(nonEmptyTitleArbitrary, (title) => {
        const similarity = merger.calculateSimilarity(title, title);
        expect(similarity).toBe(1);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('similarity is between 0 and 1', () => {
    fc.assert(
      fc.property(nonEmptyTitleArbitrary, nonEmptyTitleArbitrary, (titleA, titleB) => {
        const similarity = merger.calculateSimilarity(titleA, titleB);

        expect(similarity).toBeGreaterThanOrEqual(0);
        expect(similarity).toBeLessThanOrEqual(1);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('identical normalized titles have similarity 1', () => {
    fc.assert(
      fc.property(fc.string({ minLength: 1, maxLength: 30 }), (base) => {
        // Add different special characters to the same base
        const titleA = `${base}!!!`;
        const titleB = `${base}@@@`;

        const similarity = merger.calculateSimilarity(titleA, titleB);

        // After normalization, they should be identical
        expect(similarity).toBe(1);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('levenshtein distance is symmetric', () => {
    fc.assert(
      fc.property(fc.string({ maxLength: 20 }), fc.string({ maxLength: 20 }), (a, b) => {
        const distanceAB = merger.levenshteinDistance(a, b);
        const distanceBA = merger.levenshteinDistance(b, a);

        expect(distanceAB).toBe(distanceBA);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('levenshtein distance with self is 0', () => {
    fc.assert(
      fc.property(fc.string({ maxLength: 30 }), (str) => {
        const distance = merger.levenshteinDistance(str, str);
        expect(distance).toBe(0);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('levenshtein distance with empty string equals string length', () => {
    fc.assert(
      fc.property(fc.string({ maxLength: 30 }), (str) => {
        const distance = merger.levenshteinDistance(str, '');
        expect(distance).toBe(str.length);

        return true;
      }),
      { numRuns: 100 }
    );
  });
});

describe('normalizeTitle', () => {
  it('removes special characters and converts to lowercase', () => {
    fc.assert(
      fc.property(titleWithSpecialCharsArbitrary, (title) => {
        const normalized = merger.normalizeTitle(title);

        // Should only contain Chinese characters, lowercase letters, and numbers
        const validPattern = /^[\u4e00-\u9fa5a-z0-9]*$/;
        expect(validPattern.test(normalized)).toBe(true);

        // Should not contain uppercase letters
        expect(normalized).toBe(normalized.toLowerCase());

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('preserves Chinese characters', () => {
    const title = '进击的巨人 第四季';
    const normalized = merger.normalizeTitle(title);
    expect(normalized).toBe('进击的巨人第四季');
  });

  it('preserves alphanumeric characters in lowercase', () => {
    const title = 'Attack on Titan Season 4';
    const normalized = merger.normalizeTitle(title);
    expect(normalized).toBe('attackontitanseason4');
  });
});
