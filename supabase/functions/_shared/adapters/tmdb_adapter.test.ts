/**
 * Property-Based Tests for TMDB Adapter
 * 
 * Feature: realtime-data-aggregation, Property 1: 数据转换完整性
 * Validates: Requirements 1.3, 4.2
 * 
 * For any platform raw data, the transformed AnimeInfo object SHALL contain
 * all required fields (id, platform, title, coverUrl, status, playUrl)
 */

import { describe, it, expect } from 'vitest';
import * as fc from 'fast-check';
import { TMDBAdapterTransformer, TMDBTVShow } from './tmdb_adapter.node';
import type { AnimeInfo } from '../models/anime_info.node';

// Create adapter instance for testing
const adapter = new TMDBAdapterTransformer();

/**
 * Generator for valid TMDB TV Show (with required fields)
 */
const validTMDBTVShowArbitrary = fc.record({
  id: fc.integer({ min: 1, max: 9999999 }),
  name: fc.string({ minLength: 1, maxLength: 200 }),
  poster_path: fc.option(
    fc.string({ minLength: 1, maxLength: 100 }).map(s => `/${s}.jpg`),
    { nil: undefined }
  ),
  status: fc.option(
    fc.constantFrom('Ended', 'Returning Series', 'Canceled', 'In Production', 'Planned'),
    { nil: undefined }
  ),
});

/**
 * Generator for TMDB TV Show with all optional fields
 */
const fullTMDBTVShowArbitrary = fc.record({
  id: fc.integer({ min: 1, max: 9999999 }),
  name: fc.string({ minLength: 1, maxLength: 200 }),
  original_name: fc.option(fc.string({ minLength: 1, maxLength: 200 }), { nil: undefined }),
  poster_path: fc.option(
    fc.string({ minLength: 1, maxLength: 100 }).map(s => `/${s}.jpg`),
    { nil: undefined }
  ),
  backdrop_path: fc.option(
    fc.string({ minLength: 1, maxLength: 100 }).map(s => `/${s}.jpg`),
    { nil: undefined }
  ),
  overview: fc.option(fc.string({ minLength: 1, maxLength: 1000 }), { nil: undefined }),
  vote_average: fc.option(fc.float({ min: 0, max: 10 }), { nil: undefined }),
  vote_count: fc.option(fc.integer({ min: 0 }), { nil: undefined }),
  first_air_date: fc.option(
    fc.date({ min: new Date('1950-01-01'), max: new Date('2030-12-31') })
      .map(d => d.toISOString().split('T')[0]),
    { nil: undefined }
  ),
  genre_ids: fc.option(fc.array(fc.integer({ min: 1, max: 100 }), { maxLength: 5 }), { nil: undefined }),
  origin_country: fc.option(fc.array(fc.string({ minLength: 2, maxLength: 2 }), { maxLength: 3 }), { nil: undefined }),
  status: fc.option(
    fc.constantFrom('Ended', 'Returning Series', 'Canceled', 'In Production', 'Planned'),
    { nil: undefined }
  ),
  number_of_episodes: fc.option(fc.integer({ min: 1, max: 1000 }), { nil: undefined }),
  number_of_seasons: fc.option(fc.integer({ min: 1, max: 50 }), { nil: undefined }),
});

/**
 * Helper to check if status is valid
 */
function isValidStatus(status: string): boolean {
  return ['ongoing', 'completed', 'upcoming'].includes(status);
}

describe('Property 1: 数据转换完整性 - TMDB Adapter', () => {
  /**
   * Feature: realtime-data-aggregation, Property 1: 数据转换完整性
   * Validates: Requirements 1.3, 4.2
   */
  
  it('transformToAnimeInfo produces valid AnimeInfo with all required fields', () => {
    fc.assert(
      fc.property(validTMDBTVShowArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // Check all required fields exist and have correct types
        expect(result.id).toBeDefined();
        expect(typeof result.id).toBe('string');
        
        expect(result.platform).toBeDefined();
        expect(typeof result.platform).toBe('string');
        expect(result.platform).toBe('tmdb');
        
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

  it('ID is derived from TMDB id', () => {
    fc.assert(
      fc.property(validTMDBTVShowArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // ID should be the string version of TMDB id
        expect(result.id).toBe(rawData.id.toString());
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('playUrl contains TMDB id and is valid TMDB URL', () => {
    fc.assert(
      fc.property(validTMDBTVShowArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // playUrl should contain the TMDB id
        expect(result.playUrl).toContain(rawData.id.toString());
        
        // playUrl should be a valid TMDB URL
        expect(result.playUrl.startsWith('https://www.themoviedb.org/tv/')).toBe(true);
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('status mapping is correct for TMDB status values', () => {
    // Test 'Ended' maps to 'completed'
    const endedData: TMDBTVShow = { id: 123, name: 'Test', status: 'Ended' };
    expect(adapter.transformToAnimeInfo(endedData).status).toBe('completed');
    
    // Test 'Canceled' maps to 'completed'
    const canceledData: TMDBTVShow = { id: 456, name: 'Test', status: 'Canceled' };
    expect(adapter.transformToAnimeInfo(canceledData).status).toBe('completed');
    
    // Test 'Returning Series' maps to 'ongoing'
    const returningData: TMDBTVShow = { id: 789, name: 'Test', status: 'Returning Series' };
    expect(adapter.transformToAnimeInfo(returningData).status).toBe('ongoing');
    
    // Test 'In Production' maps to 'ongoing'
    const productionData: TMDBTVShow = { id: 101, name: 'Test', status: 'In Production' };
    expect(adapter.transformToAnimeInfo(productionData).status).toBe('ongoing');
    
    // Test 'Planned' maps to 'upcoming'
    const plannedData: TMDBTVShow = { id: 102, name: 'Test', status: 'Planned' };
    expect(adapter.transformToAnimeInfo(plannedData).status).toBe('upcoming');
    
    // Test undefined status maps to 'ongoing'
    const undefinedData: TMDBTVShow = { id: 103, name: 'Test' };
    expect(adapter.transformToAnimeInfo(undefinedData).status).toBe('ongoing');
  });

  it('titleAliases contains original_name when present', () => {
    fc.assert(
      fc.property(fullTMDBTVShowArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        if (rawData.original_name) {
          expect(result.titleAliases).toContain(rawData.original_name);
          expect(result.titleAliases.length).toBe(1);
        } else {
          expect(result.titleAliases.length).toBe(0);
        }
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('coverUrl is correctly built from poster_path', () => {
    // Test with poster_path
    const withPoster: TMDBTVShow = { 
      id: 123, 
      name: 'Test', 
      poster_path: '/abc123.jpg' 
    };
    const withPosterResult = adapter.transformToAnimeInfo(withPoster);
    expect(withPosterResult.coverUrl).toBe('https://image.tmdb.org/t/p/w500/abc123.jpg');
    
    // Test without poster_path
    const withoutPoster: TMDBTVShow = { id: 456, name: 'Test' };
    const withoutPosterResult = adapter.transformToAnimeInfo(withoutPoster);
    expect(withoutPosterResult.coverUrl).toBe('');
  });

  it('rating is preserved when present', () => {
    fc.assert(
      fc.property(
        fc.record({
          id: fc.integer({ min: 1 }),
          name: fc.string({ minLength: 1 }),
          vote_average: fc.float({ min: 0, max: 10 }),
        }),
        (rawData) => {
          const result = adapter.transformToAnimeInfo(rawData);
          
          // Rating should be preserved
          expect(result.rating).toBe(rawData.vote_average);
          
          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('synopsis uses overview', () => {
    const withOverview: TMDBTVShow = {
      id: 123,
      name: 'Test',
      overview: 'This is the overview text',
    };
    const result = adapter.transformToAnimeInfo(withOverview);
    expect(result.synopsis).toBe('This is the overview text');
    
    const withoutOverview: TMDBTVShow = { id: 456, name: 'Test' };
    const resultWithout = adapter.transformToAnimeInfo(withoutOverview);
    expect(resultWithout.synopsis).toBeUndefined();
  });

  it('optional fields are correctly mapped', () => {
    fc.assert(
      fc.property(fullTMDBTVShowArbitrary, (rawData) => {
        const result = adapter.transformToAnimeInfo(rawData);
        
        // Check optional fields are correctly mapped
        if (rawData.number_of_episodes !== undefined) {
          expect(result.episodeCount).toBe(rawData.number_of_episodes);
        }
        
        // genres is always empty array (needs extra API call)
        expect(result.genres).toEqual([]);
        
        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('parseYear extracts year correctly from date string', () => {
    expect(adapter.parseYear('2024-01-15')).toBe(2024);
    expect(adapter.parseYear('2020-12-31')).toBe(2020);
    expect(adapter.parseYear('1999-06-01')).toBe(1999);
    expect(adapter.parseYear(undefined)).toBeUndefined();
    expect(adapter.parseYear('')).toBeUndefined();
  });

  it('releaseYear is correctly parsed from first_air_date', () => {
    fc.assert(
      fc.property(
        fc.record({
          id: fc.integer({ min: 1 }),
          name: fc.string({ minLength: 1 }),
          first_air_date: fc.date({ min: new Date('1950-01-01'), max: new Date('2030-12-31') })
            .map(d => d.toISOString().split('T')[0]),
        }),
        (rawData) => {
          const result = adapter.transformToAnimeInfo(rawData);
          const expectedYear = new Date(rawData.first_air_date).getFullYear();
          
          expect(result.releaseYear).toBe(expectedYear);
          
          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('buildImageUrl handles various inputs', () => {
    expect(adapter.buildImageUrl('/path/to/image.jpg')).toBe('https://image.tmdb.org/t/p/w500/path/to/image.jpg');
    expect(adapter.buildImageUrl(undefined)).toBe('');
    expect(adapter.buildImageUrl('')).toBe('');
  });
});
