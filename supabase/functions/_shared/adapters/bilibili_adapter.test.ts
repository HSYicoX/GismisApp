/**
 * Property-Based Tests for Bilibili Adapter
 * 
 * Feature: realtime-data-aggregation, Property 1: 数据转换完整性
 * Validates: Requirements 1.3, 2.2
 * 
 * For any platform raw data, the transformed AnimeInfo object SHALL contain
 * all required fields (id, platform, title, coverUrl, status, playUrl)
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import { BilibiliAdapterTransformer, BilibiliSeasonItem } from './bilibili_adapter.node';
import type { AnimeInfo } from '../models/anime_info.node';

// Create adapter instance for testing
const adapter = new BilibiliAdapterTransformer();

/**
 * Generator for valid Bilibili season item (with required fields)
 */
const validBilibiliSeasonItemArbitrary = fc.record({
  season_id: fc.integer({ min: 1, max: 999999 }),
  title: fc.string({ minLength: 1, maxLength: 100 }),
  cover: fc.webUrl(),
  is_finish: fc.integer({ min: 0, max: 1 }),
});

/**
 * Generator for Bilibili season item with optional fields
 */
const fullBilibiliSeasonItemArbitrary = fc.record({
  season_id: fc.integer({ min: 1, max: 999999 }),
  media_id: fc.option(fc.integer({ min: 1, max: 999999 }), { nil: undefined }),
  title: fc.string({ minLength: 1, maxLength: 100 }),
  season_title: fc.option(fc.string({ minLength: 1, maxLength: 100 }), { nil: undefined }),
  origin_name: fc.option(fc.string({ minLength: 1, maxLength: 100 }), { nil: undefined }),
  alias: fc.option(fc.string({ minLength: 1, maxLength: 100 }), { nil: undefined }),
  cover: fc.webUrl(),
  square_cover: fc.option(fc.webUrl(), { nil: undefined }),
  evaluate: fc.option(fc.string({ minLength: 1, maxLength: 500 }), { nil: undefined }),
  desc: fc.option(fc.string({ minLength: 1, maxLength: 500 }), { nil: undefined }),
  rating: fc.option(fc.record({ score: fc.float({ min: 0, max: 10 }) }), { nil: undefined }),
  stat: fc.option(fc.record({ view: fc.integer({ min: 0 }) }), { nil: undefined }),
  is_finish: fc.integer({ min: 0, max: 1 }),
  styles: fc.option(fc.array(fc.string({ minLength: 1, maxLength: 20 }), { maxLength: 5 }), { nil: undefined }),
  season_year: fc.option(fc.integer({ min: 1990, max: 2030 }), { nil: undefined }),
  total_count: fc.option(fc.integer({ min: 1, max: 1000 }), { nil: undefined }),
  new_ep: fc.option(fc.record({ index_show: fc.option(fc.string({ minLength: 1, maxLength: 20 }), { nil: undefined }) }), { nil: undefined }),
  day_of_week: fc.option(fc.integer({ min: 1, max: 7 }), { nil: undefined }),
  pub_time: fc.option(fc.string({ minLength: 5, maxLength: 10 }), { nil: undefined }),
});

/**
 * Helper to check if status is valid
 */
function isValidStatus(status: string): boolean {
  return ['ongoing', 'completed', 'upcoming'].includes(status);
}

describe('Property 1: 数据转换完整性 - Bilibili Adapter', () => {
  /**
   * Feature: realtime-data-aggregation, Property 1: 数据转换完整性
   * Validates: Requirements 1.3, 2.2
   */
  
  it('transformToAnimeInfo produces valid AnimeInfo with all required fields', () => {
    fc.assert(
      fc.property(validBilibiliSeasonItemArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // Check all required fields exist and have correct types
        expect(result.id).toBeDefined();
        expect(typeof result.id).toBe('string');
        
        expect(result.platform).toBeDefined();
        expect(typeof result.platform).toBe('string');
        expect(result.platform).toBe('bilibili');
        
        expect(result.title).toBeDefined();
        expect(typeof result.title).toBe('string');
        
        expect(result.coverUrl).toBeDefined();
        expect(typeof result.coverUrl).toBe('string');
        
        expect(result.status).toBeDefined();
        expect(typeof result.status).toBe('string');
        expect(isValidStatus(result.status)).toBe(true);
        
        expect(result.playUrl).toBeDefined();
        expect(typeof result.playUrl).toBe('string');
        
        // Check arrays are arrays
        expect(Array.isArray(result.titleAliases)).toBe(true);
        expect(Array.isArray(result.genres)).toBe(true);
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('ID is derived from season_id', () => {
    fc.assert(
      fc.property(validBilibiliSeasonItemArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // ID should be the string version of season_id
        expect(result.id).toBe(rawData.season_id.toString());
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('playUrl contains season_id and is valid bilibili URL', () => {
    fc.assert(
      fc.property(validBilibiliSeasonItemArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // playUrl should contain the season_id
        expect(result.playUrl).toContain(rawData.season_id.toString());
        
        // playUrl should be a valid bilibili URL
        expect(result.playUrl.startsWith('https://www.bilibili.com/bangumi/play/ss')).toBe(true);
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('status mapping is correct for is_finish values', () => {
    // Test is_finish = 1 maps to 'completed'
    const completedData: BilibiliSeasonItem = { 
      season_id: 123, 
      title: 'Test', 
      cover: 'https://example.com', 
      is_finish: 1 
    };
    const completedResult = adapter.transformToAnimeInfo(completedData);
    expect(completedResult.status).toBe('completed');
    
    // Test is_finish = 0 maps to 'ongoing'
    const ongoingData: BilibiliSeasonItem = { 
      season_id: 456, 
      title: 'Test', 
      cover: 'https://example.com', 
      is_finish: 0 
    };
    const ongoingResult = adapter.transformToAnimeInfo(ongoingData);
    expect(ongoingResult.status).toBe('ongoing');
    
    // Test undefined is_finish maps to 'ongoing'
    const undefinedData: BilibiliSeasonItem = { 
      season_id: 789, 
      title: 'Test', 
      cover: 'https://example.com' 
    };
    const undefinedResult = adapter.transformToAnimeInfo(undefinedData);
    expect(undefinedResult.status).toBe('ongoing');
  });

  it('titleAliases filters out falsy values', () => {
    fc.assert(
      fc.property(fullBilibiliSeasonItemArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // titleAliases should not contain undefined or empty strings
        for (const alias of result.titleAliases) {
          expect(typeof alias).toBe('string');
          expect(alias.length).toBeGreaterThan(0);
        }
        
        // Count expected aliases
        let expectedCount = 0;
        if (rawData.origin_name) expectedCount++;
        if (rawData.alias) expectedCount++;
        
        expect(result.titleAliases.length).toBe(expectedCount);
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('rating is preserved when present', () => {
    fc.assert(
      fc.property(
        fc.record({
          season_id: fc.integer({ min: 1 }),
          title: fc.string({ minLength: 1 }),
          cover: fc.webUrl(),
          rating: fc.record({ score: fc.float({ min: 0, max: 10 }) }),
        }),
        (rawData) => {
          const result = adapter.transformToAnimeInfo(rawData);
          
          // Rating should be preserved
          expect(result.rating).toBe(rawData.rating.score);
          
          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('synopsis uses evaluate or desc', () => {
    // Test evaluate takes precedence
    const withEvaluate: BilibiliSeasonItem = {
      season_id: 123,
      title: 'Test',
      cover: 'https://example.com',
      evaluate: 'Evaluate text',
      desc: 'Desc text',
    };
    const evaluateResult = adapter.transformToAnimeInfo(withEvaluate);
    expect(evaluateResult.synopsis).toBe('Evaluate text');
    
    // Test desc is used when evaluate is missing
    const withDesc: BilibiliSeasonItem = {
      season_id: 456,
      title: 'Test',
      cover: 'https://example.com',
      desc: 'Desc text',
    };
    const descResult = adapter.transformToAnimeInfo(withDesc);
    expect(descResult.synopsis).toBe('Desc text');
  });

  it('optional fields are correctly mapped', () => {
    fc.assert(
      fc.property(fullBilibiliSeasonItemArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // Check optional fields are correctly mapped
        if (rawData.stat?.view !== undefined) {
          expect(result.playCount).toBe(rawData.stat.view);
        }
        
        if (rawData.styles) {
          expect(result.genres).toEqual(rawData.styles);
        } else {
          expect(result.genres).toEqual([]);
        }
        
        if (rawData.season_year !== undefined) {
          expect(result.releaseYear).toBe(rawData.season_year);
        }
        
        if (rawData.total_count !== undefined) {
          expect(result.episodeCount).toBe(rawData.total_count);
        }
        
        if (rawData.day_of_week !== undefined) {
          expect(result.updateDay).toBe(rawData.day_of_week);
        }
        
        if (rawData.pub_time !== undefined) {
          expect(result.updateTime).toBe(rawData.pub_time);
        }
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('parseLatestEpisode extracts numbers correctly', () => {
    // Test various formats
    expect(adapter.parseLatestEpisode('第12集')).toBe(12);
    expect(adapter.parseLatestEpisode('更新至第5集')).toBe(5);
    expect(adapter.parseLatestEpisode('24')).toBe(24);
    expect(adapter.parseLatestEpisode(undefined)).toBeUndefined();
    expect(adapter.parseLatestEpisode('')).toBeUndefined();
  });
});
