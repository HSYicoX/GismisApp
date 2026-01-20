/**
 * Property-Based Tests for Cache Layer
 * 
 * Feature: realtime-data-aggregation
 * Property 5: 缓存一致性
 * Validates: Requirements 6.2
 */

import { describe, it, expect, beforeEach } from 'vitest';
import * as fc from 'fast-check';
import { CacheLayer } from './cache_layer.node';

describe('Property 5: 缓存一致性', () => {
  /**
   * Feature: realtime-data-aggregation, Property 5: 缓存一致性
   * Validates: Requirements 6.2
   * 
   * For any cached data, reading within TTL SHALL return the same data;
   * reading after TTL expiration SHALL return null or re-fetch
   */

  let cache: CacheLayer;

  beforeEach(() => {
    cache = new CacheLayer();
  });

  /**
   * Generator for valid cache keys
   */
  const cacheKeyArbitrary = fc.stringOf(
    fc.constantFrom(
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_', ':', '-'
    ),
    { minLength: 1, maxLength: 50 }
  );

  /**
   * Generator for cacheable data (simple JSON-serializable values)
   */
  const cacheDataArbitrary = fc.oneof(
    fc.string(),
    fc.integer(),
    fc.boolean(),
    fc.array(fc.string(), { maxLength: 10 }),
    fc.record({
      id: fc.string(),
      name: fc.string(),
      value: fc.integer(),
    })
  );

  /**
   * Generator for valid TTL values (1 second to 1 hour)
   */
  const ttlArbitrary = fc.integer({ min: 1, max: 3600 });

  it('data written to cache can be read back within TTL', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, cacheDataArbitrary, ttlArbitrary, async (key, data, ttl) => {
        // Write data to cache
        await cache.set(key, data, ttl);

        // Read data back immediately (within TTL)
        const retrieved = await cache.get(key);

        // Should return the same data
        expect(retrieved).toEqual(data);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('expired cache returns null', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, cacheDataArbitrary, async (key, data) => {
        // Write data with very short TTL
        await cache.set(key, data, 1);

        // Manually expire the cache by setting expiration to past
        const pastDate = new Date(Date.now() - 1000);
        cache.setExpiration(key, pastDate);

        // Read data after expiration
        const retrieved = await cache.get(key);

        // Should return null
        expect(retrieved).toBeNull();

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('non-existent cache key returns null', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, async (key) => {
        // Read non-existent key
        const retrieved = await cache.get(key);

        // Should return null
        expect(retrieved).toBeNull();

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('cache can be deleted', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, cacheDataArbitrary, ttlArbitrary, async (key, data, ttl) => {
        // Write data to cache
        await cache.set(key, data, ttl);

        // Verify it exists
        const beforeDelete = await cache.get(key);
        expect(beforeDelete).toEqual(data);

        // Delete the cache
        await cache.delete(key);

        // Verify it's gone
        const afterDelete = await cache.get(key);
        expect(afterDelete).toBeNull();

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('cache upsert overwrites existing data', async () => {
    await fc.assert(
      fc.asyncProperty(
        cacheKeyArbitrary,
        cacheDataArbitrary,
        cacheDataArbitrary,
        ttlArbitrary,
        async (key, data1, data2, ttl) => {
          // Write initial data
          await cache.set(key, data1, ttl);

          // Overwrite with new data
          await cache.set(key, data2, ttl);

          // Read back
          const retrieved = await cache.get(key);

          // Should return the new data
          expect(retrieved).toEqual(data2);

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  it('clearExpired removes only expired entries', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(cacheKeyArbitrary, { minLength: 2, maxLength: 5 }),
        cacheDataArbitrary,
        async (keys, data) => {
          // Ensure unique keys
          const uniqueKeys = [...new Set(keys)];
          if (uniqueKeys.length < 2) return true;

          // Clear any existing cache
          cache.clear();

          // Write half with valid TTL, half with expired TTL
          const midpoint = Math.floor(uniqueKeys.length / 2);
          
          for (let i = 0; i < uniqueKeys.length; i++) {
            await cache.set(uniqueKeys[i], data, 3600);
            
            // Expire the first half
            if (i < midpoint) {
              const pastDate = new Date(Date.now() - 1000);
              cache.setExpiration(uniqueKeys[i], pastDate);
            }
          }

          // Clear expired
          const clearedCount = await cache.clearExpired();

          // Should have cleared the expired entries
          expect(clearedCount).toBe(midpoint);

          // Valid entries should still exist
          for (let i = midpoint; i < uniqueKeys.length; i++) {
            const retrieved = await cache.get(uniqueKeys[i]);
            expect(retrieved).toEqual(data);
          }

          // Expired entries should be gone
          for (let i = 0; i < midpoint; i++) {
            const retrieved = await cache.get(uniqueKeys[i]);
            expect(retrieved).toBeNull();
          }

          return true;
        }
      ),
      { numRuns: 50 }
    );
  });

  it('has() returns true for valid cache and false for expired/missing', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, cacheDataArbitrary, ttlArbitrary, async (key, data, ttl) => {
        // Initially should not exist
        expect(await cache.has(key)).toBe(false);

        // Write data
        await cache.set(key, data, ttl);

        // Should exist now
        expect(await cache.has(key)).toBe(true);

        // Expire it
        const pastDate = new Date(Date.now() - 1000);
        cache.setExpiration(key, pastDate);

        // Should not exist after expiration
        expect(await cache.has(key)).toBe(false);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('getTTL() returns positive value for valid cache', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, cacheDataArbitrary, async (key, data) => {
        const ttl = 3600; // 1 hour

        // Write data
        await cache.set(key, data, ttl);

        // Get TTL
        const remainingTTL = await cache.getTTL(key);

        // Should be positive and close to original TTL
        expect(remainingTTL).toBeGreaterThan(0);
        expect(remainingTTL).toBeLessThanOrEqual(ttl);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('getTTL() returns -1 for expired or missing cache', async () => {
    await fc.assert(
      fc.asyncProperty(cacheKeyArbitrary, cacheDataArbitrary, async (key, data) => {
        // Non-existent key
        expect(await cache.getTTL(key)).toBe(-1);

        // Write and expire
        await cache.set(key, data, 3600);
        const pastDate = new Date(Date.now() - 1000);
        cache.setExpiration(key, pastDate);

        // Expired key
        expect(await cache.getTTL(key)).toBe(-1);

        return true;
      }),
      { numRuns: 100 }
    );
  });

  it('multiple independent cache entries do not interfere', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(
          fc.record({
            key: cacheKeyArbitrary,
            data: cacheDataArbitrary,
          }),
          { minLength: 2, maxLength: 10 }
        ),
        async (entries) => {
          // Ensure unique keys
          const uniqueEntries = entries.filter(
            (entry, index, self) =>
              index === self.findIndex((e) => e.key === entry.key)
          );

          if (uniqueEntries.length < 2) return true;

          // Clear cache
          cache.clear();

          // Write all entries
          for (const entry of uniqueEntries) {
            await cache.set(entry.key, entry.data, 3600);
          }

          // Verify all entries are independent
          for (const entry of uniqueEntries) {
            const retrieved = await cache.get(entry.key);
            expect(retrieved).toEqual(entry.data);
          }

          // Delete one entry
          await cache.delete(uniqueEntries[0].key);

          // Other entries should still exist
          for (let i = 1; i < uniqueEntries.length; i++) {
            const retrieved = await cache.get(uniqueEntries[i].key);
            expect(retrieved).toEqual(uniqueEntries[i].data);
          }

          return true;
        }
      ),
      { numRuns: 50 }
    );
  });
});

describe('CacheLayer edge cases', () => {
  let cache: CacheLayer;

  beforeEach(() => {
    cache = new CacheLayer();
  });

  it('handles empty string as cache key', async () => {
    // Note: Empty string is technically valid but not recommended
    await cache.set('', 'test-data', 3600);
    const retrieved = await cache.get('');
    expect(retrieved).toBe('test-data');
  });

  it('handles null and undefined data', async () => {
    await cache.set('null-key', null, 3600);
    const nullRetrieved = await cache.get('null-key');
    expect(nullRetrieved).toBeNull();

    await cache.set('undefined-key', undefined, 3600);
    const undefinedRetrieved = await cache.get('undefined-key');
    expect(undefinedRetrieved).toBeUndefined();
  });

  it('handles complex nested objects', async () => {
    const complexData = {
      anime: {
        id: '123',
        title: '进击的巨人',
        platforms: ['bilibili', 'tmdb'],
        metadata: {
          rating: 9.5,
          genres: ['action', 'drama'],
        },
      },
      pagination: {
        page: 1,
        pageSize: 20,
        total: 100,
      },
    };

    await cache.set('complex-key', complexData, 3600);
    const retrieved = await cache.get('complex-key');
    expect(retrieved).toEqual(complexData);
  });

  it('handles array data', async () => {
    const arrayData = [
      { id: '1', title: 'Anime 1' },
      { id: '2', title: 'Anime 2' },
      { id: '3', title: 'Anime 3' },
    ];

    await cache.set('array-key', arrayData, 3600);
    const retrieved = await cache.get('array-key');
    expect(retrieved).toEqual(arrayData);
  });

  it('size() returns correct count', async () => {
    expect(cache.size()).toBe(0);

    await cache.set('key1', 'data1', 3600);
    expect(cache.size()).toBe(1);

    await cache.set('key2', 'data2', 3600);
    expect(cache.size()).toBe(2);

    await cache.delete('key1');
    expect(cache.size()).toBe(1);

    cache.clear();
    expect(cache.size()).toBe(0);
  });
});
