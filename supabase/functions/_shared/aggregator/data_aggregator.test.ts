/**
 * Property-Based Tests for Data Aggregator
 * 
 * Feature: realtime-data-aggregation
 * Property 2: 平台容错性
 * Property 6: 部分超时返回
 * Validates: Requirements 1.4, 8.5
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fc from 'fast-check';
import { 
  DataAggregator, 
  PlatformAdapter, 
  CacheLayer
} from './data_aggregator.node';
import type { AnimeInfo } from '../models/anime_info.node';

/**
 * Mock cache layer for testing
 */
class MockCacheLayer implements CacheLayer {
  private cache = new Map<string, { data: unknown; expiresAt: number }>();

  async get<T>(key: string): Promise<T | null> {
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return entry.data as T;
  }

  async set<T>(key: string, value: T, ttlSeconds = 3600): Promise<void> {
    this.cache.set(key, {
      data: value,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async delete(key: string): Promise<void> {
    this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }
}

/**
 * Create a mock platform adapter
 */
function createMockAdapter(
  platform: string,
  options: {
    getAnimeList?: () => Promise<AnimeInfo[]>;
    searchAnime?: () => Promise<AnimeInfo[]>;
    getSchedule?: () => Promise<AnimeInfo[]>;
    shouldFail?: boolean;
    delay?: number;
  } = {}
): PlatformAdapter {
  const defaultAnime: AnimeInfo[] = [{
    id: `${platform}-1`,
    platform,
    title: `Test Anime from ${platform}`,
    titleAliases: [],
    coverUrl: `https://${platform}.com/cover.jpg`,
    status: 'ongoing',
    genres: [],
    playUrl: `https://${platform}.com/play/1`,
  }];

  const maybeDelay = async <T>(fn: () => Promise<T>): Promise<T> => {
    if (options.delay) {
      await new Promise(resolve => setTimeout(resolve, options.delay));
    }
    if (options.shouldFail) {
      throw new Error(`${platform} failed intentionally`);
    }
    return fn();
  };

  return {
    platform,
    getAnimeList: async (_page: number, _pageSize: number) => 
      maybeDelay(async () => options.getAnimeList?.() ?? Promise.resolve(defaultAnime)),
    searchAnime: async (_keyword: string, _limit?: number) => 
      maybeDelay(async () => options.searchAnime?.() ?? Promise.resolve(defaultAnime)),
    getAnimeDetail: async (_id: string) => Promise.resolve(null),
    getSchedule: async (_day?: number) => 
      maybeDelay(async () => options.getSchedule?.() ?? Promise.resolve(defaultAnime)),
  };
}

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
 * Generator for platform names
 */
const platformArbitrary = fc.constantFrom('bilibili', 'tmdb', 'iqiyi', 'tencent', 'youku');

/**
 * Generator for array of platform names (at least 2, at most 5)
 */
const platformsArbitrary = fc.array(platformArbitrary, { minLength: 2, maxLength: 5 })
  .map(platforms => [...new Set(platforms)]);

let mockCache: MockCacheLayer;

beforeEach(() => {
  mockCache = new MockCacheLayer();
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Property 2: 平台容错性', () => {
  /**
   * Feature: realtime-data-aggregation, Property 2: 平台容错性
   * Validates: Requirements 1.4
   * 
   * For any combination of platforms, when one or more platforms fail,
   * the aggregator SHALL return data from other successful platforms
   */

  it('when some platforms fail, aggregator returns data from successful platforms', async () => {
    await fc.assert(
      fc.asyncProperty(
        platformsArbitrary,
        fc.integer({ min: 0, max: 4 }), // Number of failing platforms
        async (platforms, numFailing) => {
          // Ensure we have at least one platform
          if (platforms.length < 2) return true;
          
          // Determine which platforms will fail
          const actualNumFailing = Math.min(numFailing, platforms.length - 1);
          const failingPlatforms = new Set(platforms.slice(0, actualNumFailing));
          const successfulPlatforms = platforms.filter(p => !failingPlatforms.has(p));

          // Create adapters
          const adapters = platforms.map(platform => 
            createMockAdapter(platform, {
              shouldFail: failingPlatforms.has(platform),
            })
          );

          const aggregator = new DataAggregator(adapters, mockCache, { timeout: 5000 });
          
          // Clear cache to ensure fresh fetch
          mockCache.clear();

          const result = await aggregator.getAnimeList(1, 20);

          // Should have results from successful platforms
          if (successfulPlatforms.length > 0) {
            expect(result.length).toBeGreaterThan(0);
            
            // All results should be from successful platforms
            for (const anime of result) {
              expect(successfulPlatforms).toContain(anime.platform);
            }
          }

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('when all platforms fail, aggregator returns empty array', async () => {
    await fc.assert(
      fc.asyncProperty(
        platformsArbitrary,
        async (platforms) => {
          // All platforms fail
          const adapters = platforms.map(platform => 
            createMockAdapter(platform, { shouldFail: true })
          );

          const aggregator = new DataAggregator(adapters, mockCache, { timeout: 5000 });
          mockCache.clear();

          const result = await aggregator.getAnimeList(1, 20);

          // Should return empty array, not throw
          expect(result).toEqual([]);

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('failed platforms do not affect successful platform data integrity', async () => {
    await fc.assert(
      fc.asyncProperty(
        animeInfoArbitrary,
        async (expectedAnime) => {
          // One successful platform with specific data, one failing platform
          const successAdapter = createMockAdapter('bilibili', {
            getAnimeList: async () => [expectedAnime],
          });
          const failAdapter = createMockAdapter('tmdb', { shouldFail: true });

          const aggregator = new DataAggregator([successAdapter, failAdapter], mockCache, { timeout: 5000 });
          mockCache.clear();

          const result = await aggregator.getAnimeList(1, 20);

          // Should have exactly the data from successful platform
          expect(result.length).toBe(1);
          expect(result[0].id).toBe(expectedAnime.id);
          expect(result[0].title).toBe(expectedAnime.title);

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('searchAnime handles platform failures gracefully', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 20 }),
        platformsArbitrary,
        async (keyword, platforms) => {
          if (platforms.length < 2) return true;

          // First platform fails, rest succeed
          const adapters = platforms.map((platform, index) => 
            createMockAdapter(platform, {
              shouldFail: index === 0,
            })
          );

          const aggregator = new DataAggregator(adapters, mockCache, { timeout: 5000 });
          mockCache.clear();

          const result = await aggregator.searchAnime(keyword);

          // Should have results from successful platforms
          expect(result.length).toBeGreaterThan(0);
          
          // First platform should not be in results
          const failedPlatform = platforms[0];
          for (const anime of result) {
            expect(anime.platform).not.toBe(failedPlatform);
          }

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('getSchedule handles platform failures gracefully', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.option(fc.integer({ min: 1, max: 7 }), { nil: undefined }),
        platformsArbitrary,
        async (day, platforms) => {
          if (platforms.length < 2) return true;

          // Last platform fails, rest succeed
          const adapters = platforms.map((platform, index) => 
            createMockAdapter(platform, {
              shouldFail: index === platforms.length - 1,
            })
          );

          const aggregator = new DataAggregator(adapters, mockCache, { timeout: 5000 });
          mockCache.clear();

          const result = await aggregator.getSchedule(day);

          // Should have results from successful platforms
          expect(result.length).toBeGreaterThan(0);

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });
});


describe('Property 6: 部分超时返回', () => {
  /**
   * Feature: realtime-data-aggregation, Property 6: 部分超时返回
   * Validates: Requirements 8.5
   * 
   * For any aggregation request, when some platforms timeout,
   * the aggregator SHALL return data from platforms that responded in time
   */

  it('when some platforms timeout, aggregator returns data from fast platforms', async () => {
    vi.useRealTimers(); // Need real timers for timeout testing
    
    await fc.assert(
      fc.asyncProperty(
        platformsArbitrary,
        async (platforms) => {
          if (platforms.length < 2) return true;

          // First platform is slow (will timeout), rest are fast
          const adapters = platforms.map((platform, index) => 
            createMockAdapter(platform, {
              delay: index === 0 ? 200 : 10, // First platform slow
            })
          );

          const aggregator = new DataAggregator(adapters, new MockCacheLayer(), { 
            timeout: 100 // Short timeout to trigger timeout for slow platform
          });

          const result = await aggregator.getAnimeList(1, 20);

          // Should have results from fast platforms only
          if (platforms.length > 1) {
            expect(result.length).toBeGreaterThan(0);
            
            // Slow platform should not be in results
            const slowPlatform = platforms[0];
            for (const anime of result) {
              expect(anime.platform).not.toBe(slowPlatform);
            }
          }

          return true;
        }
      ),
      { numRuns: 50 } // Fewer runs due to real timers
    );
    
    vi.useFakeTimers();
  });

  it('when all platforms timeout, aggregator returns empty array', async () => {
    vi.useRealTimers();
    
    await fc.assert(
      fc.asyncProperty(
        platformsArbitrary,
        async (platforms) => {
          // All platforms are slow
          const adapters = platforms.map(platform => 
            createMockAdapter(platform, { delay: 200 })
          );

          const aggregator = new DataAggregator(adapters, new MockCacheLayer(), { 
            timeout: 50 // Very short timeout
          });

          const result = await aggregator.getAnimeList(1, 20);

          // Should return empty array, not throw
          expect(result).toEqual([]);

          return true;
        }
      ),
      { numRuns: 50 }
    );
    
    vi.useFakeTimers();
  });

  it('timeout does not affect data integrity from fast platforms', async () => {
    vi.useRealTimers();
    
    await fc.assert(
      fc.asyncProperty(
        animeInfoArbitrary,
        async (expectedAnime) => {
          // Fast platform with specific data
          const fastAdapter = createMockAdapter('bilibili', {
            getAnimeList: async () => [expectedAnime],
            delay: 10,
          });
          
          // Slow platform that will timeout
          const slowAdapter = createMockAdapter('tmdb', {
            delay: 200,
          });

          const aggregator = new DataAggregator(
            [fastAdapter, slowAdapter], 
            new MockCacheLayer(), 
            { timeout: 100 }
          );

          const result = await aggregator.getAnimeList(1, 20);

          // Should have exactly the data from fast platform
          expect(result.length).toBe(1);
          expect(result[0].id).toBe(expectedAnime.id);
          expect(result[0].title).toBe(expectedAnime.title);

          return true;
        }
      ),
      { numRuns: 50 }
    );
    
    vi.useFakeTimers();
  }, 30000); // Extended timeout for real timer tests with delays

  it('searchAnime handles partial timeouts correctly', async () => {
    vi.useRealTimers();
    
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 20 }),
        async (keyword) => {
          // Mix of fast and slow adapters
          const fastAdapter = createMockAdapter('bilibili', { delay: 10 });
          const slowAdapter = createMockAdapter('tmdb', { delay: 200 });

          const aggregator = new DataAggregator(
            [fastAdapter, slowAdapter], 
            new MockCacheLayer(), 
            { timeout: 100 }
          );

          const result = await aggregator.searchAnime(keyword);

          // Should have results from fast platform only
          expect(result.length).toBeGreaterThan(0);
          expect(result.every(a => a.platform === 'bilibili')).toBe(true);

          return true;
        }
      ),
      { numRuns: 50 }
    );
    
    vi.useFakeTimers();
  }, 30000); // Extended timeout for real timer tests with delays
});


describe('DataAggregator utility methods', () => {
  it('getPlatforms returns all registered platform names', () => {
    fc.assert(
      fc.property(
        platformsArbitrary,
        (platforms) => {
          const adapters = platforms.map(p => createMockAdapter(p));
          const aggregator = new DataAggregator(adapters, mockCache);

          const registeredPlatforms = aggregator.getPlatforms();

          expect(registeredPlatforms.sort()).toEqual(platforms.sort());

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('hasPlatform correctly identifies registered platforms', () => {
    fc.assert(
      fc.property(
        platformsArbitrary,
        platformArbitrary,
        (platforms, queryPlatform) => {
          const adapters = platforms.map(p => createMockAdapter(p));
          const aggregator = new DataAggregator(adapters, mockCache);

          const hasPlatform = aggregator.hasPlatform(queryPlatform);
          const shouldHave = platforms.includes(queryPlatform);

          expect(hasPlatform).toBe(shouldHave);

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });
});


describe('Cache integration', () => {
  it('uses cached data when available', async () => {
    const adapter = createMockAdapter('bilibili');
    const aggregator = new DataAggregator([adapter], mockCache);

    // First call - should fetch and cache
    const result1 = await aggregator.getAnimeList(1, 20);
    expect(result1.length).toBeGreaterThan(0);

    // Modify adapter to return different data
    const modifiedAdapter = createMockAdapter('bilibili', {
      getAnimeList: async () => [{
        id: 'different-id',
        platform: 'bilibili',
        title: 'Different Anime',
        titleAliases: [],
        coverUrl: 'https://example.com/different.jpg',
        status: 'ongoing',
        genres: [],
        playUrl: 'https://example.com/different',
      }],
    });

    const aggregator2 = new DataAggregator([modifiedAdapter], mockCache);

    // Second call - should use cache
    const result2 = await aggregator2.getAnimeList(1, 20);
    
    // Should return cached data, not new data
    expect(result2[0].id).toBe(result1[0].id);
  });

  it('forceRefresh bypasses cache', async () => {
    const originalAnime: AnimeInfo = {
      id: 'original-id',
      platform: 'bilibili',
      title: 'Original Anime',
      titleAliases: [],
      coverUrl: 'https://example.com/original.jpg',
      status: 'ongoing',
      genres: [],
      playUrl: 'https://example.com/original',
    };

    const newAnime: AnimeInfo = {
      id: 'new-id',
      platform: 'bilibili',
      title: 'New Anime',
      titleAliases: [],
      coverUrl: 'https://example.com/new.jpg',
      status: 'ongoing',
      genres: [],
      playUrl: 'https://example.com/new',
    };

    let currentAnime = originalAnime;
    const adapter: PlatformAdapter = {
      platform: 'bilibili',
      getAnimeList: async () => [currentAnime],
      searchAnime: async () => [currentAnime],
      getAnimeDetail: async () => null,
      getSchedule: async () => [currentAnime],
    };

    const aggregator = new DataAggregator([adapter], mockCache);

    // First call - caches original data
    const result1 = await aggregator.getAnimeList(1, 20);
    expect(result1[0].id).toBe('original-id');

    // Change the data
    currentAnime = newAnime;

    // Normal call - should return cached data
    const result2 = await aggregator.getAnimeList(1, 20);
    expect(result2[0].id).toBe('original-id');

    // Force refresh - should get new data
    const result3 = await aggregator.getAnimeList(1, 20, true);
    expect(result3[0].id).toBe('new-id');
  });
});
